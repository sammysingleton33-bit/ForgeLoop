--!strict
--[[
	FeedbackController (game-001, FORGE-04, FL-0062; CONTRACTS G4.1): citizens and the ruler get an
	answer for their work. Hooks only the G4.1 client signals (never Sim.*), found with registry:find:
		InteractionController.gathered(nodeId, resource, amount)
		    -> gather sound + chips at the node (Layout.resourceNodes) + "+N Wood" float
		EntityController.event(id, cue, payload, model)
		    "deposit"   -> a small clink + glint at the citizen, coalesced (DEPOSIT_GAP_SEC)
		    "celebrate" -> a cheer (G5: keep level 2) at the citizen
		    "swing"     -> the citizen's work sound by job, at most one per SWING_GAP_SEC per citizen,
		                   only within MAX_STUDS of the camera focus (a proposed cue that EntityController
		                   would fire locally from its pose loop: nothing on the network, so G4's "no
		                   per-swing events" holds; inert until FORGE-01 adds it)
		EntityController.released(id, model) -> stops every effect attached to that rig (pooled rigs
		    must not carry effects to their next citizen); finished effects leave that list after
		    ATTACH_KEEP_SEC, so it never grows with the match
	Burning buildings (FL-0091, FORGE-01's FL-0082 handoff; D-050 (1b)): every BURN_POLL_SEC it reads the
	`Burning` attribute of the building models under Workspace.ForgeKingdoms/<kingdom>/Buildings (set by
	WorldView while a riot burns one). A building that starts burning gets the continuous
	"kingdom.building.fire" effect (flames and smoke) and the looping "kingdom.fire" crackle above its roof;
	both stop when the attribute goes or the model does. An effect the VFX budget skipped is tried again on
	the next read.
	Building damage (FL-0143; FORGE-00's ruling: this controller is the one writer of `Damage`, on the
	client): on the same read, each building Model's `Damage` attribute follows its `Hp` and `MaxHp` (set by
	WorldView) through Kit.damageFromHp, written only when the value changes, and Kit.applyDamage (FORGE-02's
	FL-0128 war kit: cracks, soot, missing merlons, a collapsed corner) runs only when the damage state
	(Kit.damageState: 0..4) changes. A repaired building (Hp back up) gets its parts back the same way; a
	rebuilt one is a new model that starts undamaged. A building without both numbers, or with MaxHp <= 0,
	is left alone, and so are the plain-part stand-ins (not Models). No per-frame work: one pass every
	BURN_POLL_SEC.
	Distances are measured from the overview's focus (RulerCameraController:getFocus() while mode is
	"overview"), else from the camera (walk mode, whose focus would be the stale overview one), so a
	zoomed-out overview (up to 220 studs) still hears and sees the citizens under the view. Floats
	("+3 Wood") follow the same rule and carry no engine MaxDistance (VFXController opts.maxDistance 0),
	which would measure from the camera, 220 studs up.
	Registers the kingdom presets (Feedback/Presets) with VFXController at start; presets already
	registered are skipped, so a second boot never fails.
	Every sound here has a visual counterpart (the effect or the float), the accessibility rule.
]]

local Kit = require("@game/ReplicatedStorage/Game/Kit/Kit")
local Layout = require("@game/ReplicatedStorage/Game/World/Layout")
local Presets = require("@game/ReplicatedStorage/Game/Feedback/Presets")
local VfxPresets = require("@game/ReplicatedStorage/Forge/Experience/VfxPresets")

local FeedbackController = {}
FeedbackController.__index = FeedbackController

local Def = { name = "FeedbackController", dependencies = {} }

Def.DEPOSIT_GAP_SEC = 1.5
Def.SWING_GAP_SEC = 1.5
Def.CHEER_GAP_SEC = 0.5 -- a keep upgrade makes every citizen cheer at once: one cheer sound per gap
Def.MAX_STUDS = 150 -- from the camera focus
Def.ATTACH_KEEP_SEC = 5 -- longer than any burst preset in Feedback/Presets
Def.BURN_POLL_SEC = 0.5 -- how often the building models' Burning attribute is read
Def.FIRE = table.freeze({ vfx = "kingdom.building.fire", sound = "kingdom.fire" })
Def.RESOURCE = table.freeze({
	wood = table.freeze({ sound = "kingdom.chop", vfx = "kingdom.harvest.wood", label = "Wood" }),
	stone = table.freeze({ sound = "kingdom.mine", vfx = "kingdom.harvest.stone", label = "Stone" }),
	food = table.freeze({ sound = "kingdom.harvest", vfx = "kingdom.harvest.food", label = "Food" }),
	gold = table.freeze({ sound = "kingdom.pickup", vfx = "reward.burst", label = "Gold" }),
})
Def.JOB_SOUND = table.freeze({
	woodcutter = "kingdom.chop",
	miner = "kingdom.mine",
	farmer = "kingdom.harvest",
	builder = "kingdom.hammer",
})

local function connect(target: any, name: string, handler: (...any) -> ()): any
	local signal = target and target[name]
	if signal == nil then
		return nil
	end
	local ok, connection = pcall(function()
		return signal:connect(handler)
	end)
	return if ok then connection else nil
end

local function pivotOf(model: any): Vector3?
	local ok, position = pcall(function()
		local primary = model.PrimaryPart
		return if primary then primary.CFrame.Position else model:GetPivot().Position
	end)
	return if ok then position else nil
end

-- The top centre of a model's box: flames and smoke rise above the roof, where the aerial camera sees them.
local function roofOf(model: any): Vector3?
	local ok, cframe, size = pcall(function()
		return model:GetBoundingBox()
	end)
	if ok and typeof(cframe) == "CFrame" and typeof(size) == "Vector3" then
		return cframe.Position + Vector3.new(0, size.Y / 2, 0)
	end
	return pivotOf(model)
end

-- Building models burning now (Burning = true), by BuildingId, under Workspace.ForgeKingdoms.
function Def.burningBuildings(workspace: any): { [any]: any }
	local out = {}
	local root = workspace and workspace:FindFirstChild("ForgeKingdoms")
	if root == nil then
		return out
	end
	for _, kingdom in root:GetChildren() do
		local buildings = kingdom:FindFirstChild("Buildings")
		if buildings ~= nil then
			for _, model in buildings:GetChildren() do
				local id = model:GetAttribute("BuildingId")
				if id ~= nil and model:GetAttribute("Burning") == true then
					out[id] = model
				end
			end
		end
	end
	return out
end

-- Building Models under Workspace.ForgeKingdoms/<kingdom>/Buildings that carry Hp and MaxHp.
function Def.damageable(workspace: any): { any }
	local out = {}
	local root = workspace and workspace:FindFirstChild("ForgeKingdoms")
	if root == nil then
		return out
	end
	for _, kingdom in root:GetChildren() do
		local buildings = kingdom:FindFirstChild("Buildings")
		if buildings ~= nil then
			for _, model in buildings:GetChildren() do
				if model:IsA("Model") then
					local hp, maxHp = model:GetAttribute("Hp"), model:GetAttribute("MaxHp")
					if type(hp) == "number" and hp == hp and type(maxHp) == "number" and maxHp > 0 then
						table.insert(out, model)
					end
				end
			end
		end
	end
	return out
end

-- opts (specs): { layout, origin = () -> Vector3, kit }
function Def.create(env: any, registry: any, opts: { [string]: any }?)
	local options = opts or {}
	local nodes = {}
	for _, node in ((options.layout or Layout).resourceNodes or {}) do
		if type(node) == "table" and type(node.id) == "string" and typeof(node.cframe) == "CFrame" then
			nodes[node.id] = node.cframe.Position
		end
	end
	return setmetatable({
		_env = env,
		_registry = registry,
		_origin = options.origin,
		_kit = options.kit or Kit,
		_nodes = nodes,
		_connections = {},
		_attached = {} :: { [number]: { { effect: any, at: number } } },
		_lastDeposit = -math.huge,
		_lastCheer = -math.huge,
		_lastSwing = {} :: { [number]: number },
		_fires = {} :: { [any]: { model: any, effect: any, voice: any } },
		_running = false,
		registered = {} :: { string },
	}, FeedbackController)
end

function Def.new(env: any, registry: any)
	return Def.create(env, registry, nil)
end

function FeedbackController:start()
	local registry = self._registry
	self._audio = registry:find("AudioController")
	self._vfx = registry:find("VFXController")
	self._camera = registry:find("RulerCameraController")
	self:_registerPresets()
	local interaction = registry:find("InteractionController")
	local entities = registry:find("EntityController")
	for _, connection in
		{
			connect(interaction, "gathered", function(nodeId, resource, amount)
				self:gathered(nodeId, resource, amount)
			end),
			connect(entities, "event", function(id, cue, payload, model)
				self:onEntityEvent(id, cue, payload, model)
			end),
			connect(entities, "released", function(id)
				self:released(id)
			end),
		}
	do
		table.insert(self._connections, connection)
	end
	if entities == nil then
		self._env.log("info", "FeedbackController: no EntityController yet; citizen work feedback waits for FORGE-01")
	end
	self._running = true
	self._env.spawn(function()
		while self._running do
			self:refreshFires()
			self:refreshDamage()
			self._env.wait(Def.BURN_POLL_SEC)
		end
	end)
end

function FeedbackController:destroy()
	for _, connection in self._connections do
		pcall(function()
			connection:disconnect()
		end)
	end
	table.clear(self._connections)
	for id in self._attached do
		self:released(id)
	end
	self._running = false
	for id in self._fires do
		self:_putOut(id)
	end
end

-- Starts the fire on buildings that began burning and puts it out on those that stopped or are gone.
function FeedbackController:refreshFires()
	local ok, burning = pcall(Def.burningBuildings, self._env.Workspace)
	if not ok then
		return
	end
	for id, fire in self._fires do
		if burning[id] ~= fire.model then
			self:_putOut(id)
		end
	end
	for id, model in burning do
		local fire = self._fires[id]
		if fire == nil or fire.effect == nil then -- new, or the budget skipped its effect last time
			local entry = fire or { model = model }
			local position = roofOf(model)
			local vfx, audio = self._vfx, self._audio
			if vfx ~= nil and vfx.play ~= nil then
				local okPlay, effect = pcall(vfx.play, vfx, Def.FIRE.vfx, { position = position })
				entry.effect = if okPlay then effect else nil
			end
			if entry.voice == nil and audio ~= nil and audio.play ~= nil then
				local okSound, voice = pcall(audio.play, audio, Def.FIRE.sound, { position = position })
				entry.voice = if okSound then voice else nil
			end
			self._fires[id] = entry
		end
	end
end

-- Each building's Damage follows its Hp (FL-0143): the attribute when its value changes, the parts
-- (Kit.applyDamage) only when its damage state does. Returns how many models were re-dressed (specs).
function FeedbackController:refreshDamage(): number
	local kit = self._kit
	if type(kit.applyDamage) ~= "function" or type(kit.damageFromHp) ~= "function" then
		return 0
	end
	local ok, models = pcall(Def.damageable, self._env.Workspace)
	if not ok then
		return 0
	end
	local applied = 0
	for _, model in models do
		local damage = kit.damageFromHp(model:GetAttribute("Hp"), model:GetAttribute("MaxHp"))
		local before = model:GetAttribute("Damage")
		if before ~= damage then
			model:SetAttribute("Damage", damage)
			local was = if type(before) == "number" then before else 0
			if kit.damageState(damage) ~= kit.damageState(was) then
				local okApply, err = pcall(kit.applyDamage, model)
				if okApply then
					applied += 1
				else
					self._env.log("warn", "FeedbackController: Kit.applyDamage failed", { error = tostring(err) })
				end
			end
		end
	end
	return applied
end

-- Buildings burning now, with their effect and sound (specs, debug).
function FeedbackController:fires(): { [any]: { model: any, effect: any, voice: any } }
	return self._fires
end

function FeedbackController:_putOut(id: any)
	local fire = self._fires[id]
	self._fires[id] = nil
	if fire == nil then
		return
	end
	if fire.effect ~= nil and self._vfx ~= nil and self._vfx.stop ~= nil then
		pcall(self._vfx.stop, self._vfx, fire.effect)
	end
	if fire.voice ~= nil and self._audio ~= nil and self._audio.stop ~= nil then
		pcall(self._audio.stop, self._audio, fire.voice)
	end
end

function FeedbackController:_registerPresets()
	local vfx = self._vfx
	if vfx == nil or vfx.register == nil then
		return
	end
	local missing = {}
	for _, preset in Presets do
		if VfxPresets.get(preset.id) == nil then
			table.insert(missing, preset)
		end
	end
	if #missing == 0 then
		return
	end
	local problems = vfx:register(missing)
	if #problems > 0 then
		self._env.log("warn", "FeedbackController: presets rejected", { problems = table.concat(problems, "; ") })
		return
	end
	for _, preset in missing do
		table.insert(self.registered, preset.id)
	end
end

function FeedbackController:_near(position: Vector3?): boolean
	if position == nil then
		return false
	end
	local origin
	local camera = self._camera
	if self._origin then
		origin = self._origin()
	elseif camera ~= nil and camera.mode == "overview" and camera.getFocus ~= nil then
		local okFocus, focus = pcall(camera.getFocus, camera)
		origin = if okFocus and typeof(focus) == "Vector3" then focus else nil
	end
	if origin == nil and not self._origin then
		local ok, cameraPosition = pcall(function()
			return self._env.Workspace.CurrentCamera.CFrame.Position
		end)
		origin = if ok then cameraPosition else nil
	end
	return origin == nil or (position - origin).Magnitude <= Def.MAX_STUDS
end

function FeedbackController:gathered(nodeId: any, resource: any, amount: any)
	local spec = Def.RESOURCE[resource]
	if spec == nil then
		return
	end
	local position = if type(nodeId) == "string" then self._nodes[nodeId] else nil
	if self._audio then
		self._audio:play(spec.sound, { position = position })
	end
	if self._vfx then
		if position then
			self._vfx:play(spec.vfx, { position = position })
		end
		if type(amount) == "number" and amount > 0 and self:_near(position) then
			self._vfx:float(`+{amount} {spec.label}`, position, { maxDistance = 0 })
		end
	end
end

function FeedbackController:onEntityEvent(id: any, cue: string, payload: any, model: any)
	if type(id) == "number" and id ~= id then
		return -- NaN: never a table key
	end
	local position = if model then pivotOf(model) else nil
	if cue == "deposit" then
		local now = self._env.clock()
		if now - self._lastDeposit < Def.DEPOSIT_GAP_SEC or not self:_near(position) then
			return
		end
		self._lastDeposit = now
		if self._audio then
			self._audio:play("kingdom.deposit", { position = position })
		end
		self:_attach(id, "kingdom.deposit", model, position)
	elseif cue == "celebrate" then
		if not self:_near(position) then
			return -- far from the view: nobody sees or hears it
		end
		local now = self._env.clock()
		if self._audio and now - self._lastCheer >= Def.CHEER_GAP_SEC then
			self._lastCheer = now
			self._audio:play("kingdom.cheer", { position = position })
		end
		self:_attach(id, "reward.burst", model, position) -- each nearby citizen still bursts (VFX budget)
	elseif cue == "swing" then
		local job = type(payload) == "table" and payload.job or nil
		local sound = Def.JOB_SOUND[job]
		if sound == nil or type(id) ~= "number" or not self:_near(position) then
			return
		end
		local now = self._env.clock()
		if now - (self._lastSwing[id] or -math.huge) < Def.SWING_GAP_SEC then
			return
		end
		self._lastSwing[id] = now
		if self._audio then
			self._audio:play(sound, { position = position })
		end
		if job == "woodcutter" or job == "miner" or job == "farmer" then
			local vfx = if job == "woodcutter"
				then "kingdom.harvest.wood"
				elseif job == "miner" then "kingdom.harvest.stone"
				else "kingdom.harvest.food"
			self:_attach(id, vfx, model, position)
		end
	end
end

function FeedbackController:_attach(id: any, presetId: string, model: any, position: Vector3?)
	local vfx = self._vfx
	if vfx == nil or position == nil then
		return
	end
	local effect = vfx:play(presetId, { position = position, parent = model })
	if effect ~= nil and type(id) == "number" then
		local now = self._env.clock()
		local list = {}
		for _, entry in self._attached[id] or {} do
			if now - entry.at < Def.ATTACH_KEEP_SEC then
				table.insert(list, entry) -- older bursts have ended (VFXController cleans them up)
			end
		end
		table.insert(list, { effect = effect, at = now })
		self._attached[id] = list
	end
end

-- The rig goes back to the pool: stop every effect attached to it.
function FeedbackController:released(id: any)
	if type(id) == "number" and id ~= id then
		return
	end
	local list = self._attached[id]
	self._attached[id] = nil
	self._lastSwing[id] = nil
	if list == nil or self._vfx == nil then
		return
	end
	for _, entry in list do
		pcall(self._vfx.stop, self._vfx, entry.effect)
	end
end

return Def
