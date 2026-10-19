--!strict
--[[
	FeedbackWarController (game-001, FORGE-04, FL-0130 part 2; CONTRACTS G4.1, G8): battles read from the
	aerial view, without gore (13+ fantasy violence, BRIEF §11). Hooks only client signals and remotes,
	found with registry:find (each optional; nothing breaks without one):
		EntityController.event(id, cue, payload, model)
		    "hit"  -> a short bright flash on the rig (one Highlight from a small pool), sparks and a
		              clash, at most one per FLASH_GAP_SEC per entity and only within MAX_STUDS of the view
		              (the server sends the G4 `hit` cue once FORGE-01 adds it: handoff
		              2026-10-18-forge-04-to-forge-01-war-events.md)
		    "die"  -> the rig fades out (LocalTransparencyModifier, client-only) over DEATH_FADE while it
		              lies in EntityController's dead pose, so nobody lingers on the field
		EntityController.released(id, model) -> the rig's transparency and flash are reset first: rigs
		    are pooled, and the next citizen must not inherit a half-faded body
		Build.Buildings (G8 serverEvent, the changed building views)
		    hp drops on a standing building -> dust and stone chips at its roof and a short shake of
		              the model (no shake with reduced motion; never on a burning building, whose fire
		              already shows and whose hp falls every second), at most one per HIT_GAP_SEC each
		    state "destroyed" after it stood (complete or damaged) -> the collapse: a dust cloud and
		              debris where it stood, one crash sound per batch, a small camera shake when it is near
		              the view; at most COLLAPSE_MAX per batch (the nearest). A cancelled site (planned or
		              constructing) never collapses, and neither does a new world: BuildingService sends
		              every old building as destroyed in one batch when a match ends, keeps of two or more
		              kingdoms at once, which no conquest does
		AnnouncerController.moment
		    raid on  -> the raid's position becomes an alert: a red beacon there (war.raid.ping) until
		              the raid ends; G (keyboard) or DPadUp (gamepad), or goToAlert() from a HUD button,
		              takes the overview camera to it
		    siege on -> the same for our besieged keep (the moment's position is the keep's): go defend
		    raid off / siege off -> that alert and its beacon end; kingdomFell -> both end
		    A siege outranks a raid: while both are on, the alert (and G) is the keep.
	Battle music: every hit shown near the view (a flash or a building hit) calls
	MusicController:combatNear(), so the attacker hears the battle too, not only the raided kingdom.
	Battle places (hotspots): every building hit and every flashed rig is remembered for HOTSPOT_SEC,
	merged within HOTSPOT_STUDS, for the spectate camera (RulerSpectateController) and the HUD.

	API
		controller:goToAlert() -> boolean          the camera to the current alert (false: none)
		controller:alert() -> { kind = "siege" | "raid", position, kingdom?, at }?
		controller:hotspots(now?) -> { { position, at, count } }   newest first
		controller:step(dt)                        one frame of fades, flashes and shakes (specs)
	Engine access is guarded: without a Workspace, input or remotes it boots and does nothing.
]]

local RemoteLink = require("@game/ReplicatedStorage/Forge/Experience/RemoteLink")

local FeedbackWarController = {}
FeedbackWarController.__index = FeedbackWarController

local Def = { name = "FeedbackWarController", dependencies = {} }

Def.FX = table.freeze({
	hit = "war.hit",
	buildingHit = "war.building.hit",
	collapse = "war.building.collapse",
	ping = "war.raid.ping", -- the beacon of a raid and of a siege on our keep
})
Def.SOUND = table.freeze({ hit = "war.hit", collapse = "war.collapse" })
Def.MAX_STUDS = 220 -- from the view's focus: the overview's widest zoom
Def.FLASH_SEC = 0.15
Def.FLASH_GAP_SEC = 0.25
Def.FLASH_MAX = 8 -- Highlights in the pool (Roblox renders at most 31 at once; hover uses two)
Def.FLASH_COLOR = Color3.fromRGB(255, 238, 220)
Def.DEATH_FADE = table.freeze({ from = 0.8, to = 2 }) -- seconds after "die" (EntityController.DEATH_DELAY 2)
Def.HIT_GAP_SEC = 0.75
Def.SHAKE = table.freeze({ studs = 0.35, sec = 0.3, max = 3 })
Def.COLLAPSE_MAX = 6
Def.COLLAPSE_SHAKE = table.freeze({ magnitude = 0.25, duration = 0.4, studs = 120 })
Def.ALERT_ORDER = table.freeze({ "siege", "raid" }) -- the first one on is the alert
Def.HOTSPOT_SEC = 20
Def.HOTSPOT_STUDS = 40
Def.HOTSPOT_MAX = 12
Def.STEP_SEC = 1 / 30
Def.ALERT_KEYS = table.freeze({ Enum.KeyCode.G, Enum.KeyCode.DPadUp })
Def.STANDING = table.freeze({ complete = true, damaged = true })

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

local function finite(value: any): boolean
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

local function pivotOf(model: any): Vector3?
	local ok, position = pcall(function()
		local primary = model.PrimaryPart
		return if primary then primary.CFrame.Position else model:GetPivot().Position
	end)
	return if ok and typeof(position) == "Vector3" then position else nil
end

local function roofOf(model: any): Vector3?
	local ok, cframe, size = pcall(function()
		return model:GetBoundingBox()
	end)
	if ok and typeof(cframe) == "CFrame" and typeof(size) == "Vector3" then
		return cframe.Position + Vector3.new(0, size.Y / 2, 0)
	end
	return pivotOf(model)
end

local function partsOf(model: any): { any }
	local out = {}
	pcall(function()
		for _, item in model:GetDescendants() do
			if item:IsA("BasePart") then
				table.insert(out, item)
			end
		end
	end)
	return out
end

-- Where a building view stands (G2 Building.cframe), a little above the ground.
local function viewPosition(view: any): Vector3?
	local ok, position = pcall(function()
		return view.cframe.Position
	end)
	if ok and typeof(position) == "Vector3" then
		return position + Vector3.new(0, 4, 0)
	end
	return nil
end

-- A batch that destroys the keeps of two or more kingdoms is a new world, not a war (header).
function Def.isWorldReset(views: { any }): boolean
	local kingdoms = {}
	local count = 0
	for _, view in views do
		if type(view) == "table" and view.state == "destroyed" and view.type == "keep" then
			local kingdom = view.kingdom
			if kingdom ~= nil and not kingdoms[kingdom] then
				kingdoms[kingdom] = true
				count += 1
			end
		end
	end
	return count >= 2
end

function Def.create(env: any, registry: any, opts: { [string]: any }?)
	local options = opts or {}
	return setmetatable({
		_env = env,
		_registry = registry,
		_userInputOverride = options.userInput,
		_connections = {},
		_links = {},
		_running = false,
		_lastFlash = {} :: { [number]: number },
		_flashes = {} :: { [any]: { highlight: any, ends: number } },
		_pool = {} :: { any },
		_dying = {} :: { [number]: { model: any, parts: { any }, at: number } },
		_views = {} :: { [number]: { state: string?, hp: number?, kingdom: string?, type: string? } },
		_lastHit = {} :: { [number]: number },
		_shakes = {} :: { [any]: { parts: { any }, offset: Vector3, age: number, seed: number } },
		_hotspots = {} :: { { position: Vector3, at: number, count: number } },
		_alerts = {} :: { [string]: { position: Vector3, kingdom: string?, at: number, effect: any } },
		stats = { flashes = 0, fades = 0, hits = 0, shakes = 0, collapses = 0, resets = 0, skipped = 0 },
	}, FeedbackWarController)
end

function Def.new(env: any, registry: any)
	return Def.create(env, registry, nil)
end

function FeedbackWarController:start()
	local registry = self._registry
	self._audio = registry:find("AudioController")
	self._vfx = registry:find("VFXController")
	self._camera = registry:find("RulerCameraController")
	self._settings = registry:find("SettingsController")
	self._music = registry:find("MusicController")
	local entities = registry:find("EntityController")
	local announcer = registry:find("AnnouncerController")
	for _, connection in
		{
			connect(entities, "event", function(id, cue, payload, model)
				self:onEntityEvent(id, cue, payload, model)
			end),
			connect(entities, "released", function(id, model)
				self:released(id, model)
			end),
			connect(announcer, "moment", function(moment)
				self:onMoment(moment)
			end),
		}
	do
		table.insert(self._connections, connection)
	end
	table.insert(
		self._links,
		RemoteLink.on(self._env, "Build.Buildings", function(views)
			self:onBuildings(views)
		end)
	)
	self:_bindKeys()
	self._running = true
	local env = self._env
	env.spawn(function()
		local last = env.clock()
		while self._running do
			env.wait(Def.STEP_SEC)
			local now = env.clock()
			self:step(now - last)
			last = now
		end
	end)
end

function FeedbackWarController:destroy()
	self._running = false
	for _, connection in self._connections do
		pcall(function()
			connection:disconnect()
		end)
	end
	table.clear(self._connections)
	for _, link in self._links do
		pcall(function()
			link:disconnect()
		end)
	end
	table.clear(self._links)
	for id, dying in self._dying do
		self:_fade(dying.parts, 0)
		self._dying[id] = nil
	end
	for key in self._shakes do
		self:_endShake(key)
	end
	for key in self._flashes do
		self:_endFlash(key)
	end
	self:_clearAlert()
end

-- ---------------------------------------------------------------- settings and helpers

function FeedbackWarController:_reducedMotion(): boolean
	local settings = self._settings
	if settings == nil then
		return false
	end
	local ok, reduced = pcall(function()
		return if settings.reducedMotion then settings:reducedMotion() else settings:get("reducedMotion")
	end)
	return ok and reduced == true
end

function FeedbackWarController:_focus(): Vector3?
	local camera = self._camera
	if camera ~= nil and camera.mode == "overview" and camera.getFocus ~= nil then
		local ok, focus = pcall(camera.getFocus, camera)
		if ok and typeof(focus) == "Vector3" then
			return focus
		end
	end
	local ok, position = pcall(function()
		return self._env.Workspace.CurrentCamera.CFrame.Position
	end)
	return if ok and typeof(position) == "Vector3" then position else nil
end

function FeedbackWarController:_near(position: Vector3?, studs: number?): boolean
	if position == nil then
		return false
	end
	local focus = self:_focus()
	if focus == nil then
		return true -- no view to measure from (specs, boot): do not hide the battle
	end
	return (position - focus).Magnitude <= (studs or Def.MAX_STUDS)
end

function FeedbackWarController:_play(effect: string, position: Vector3): any
	local vfx = self._vfx
	if vfx == nil or vfx.play == nil then
		return nil
	end
	local ok, handle = pcall(vfx.play, vfx, effect, { position = position })
	return if ok then handle else nil
end

function FeedbackWarController:_sound(id: string, position: Vector3?)
	local audio = self._audio
	if audio == nil or audio.play == nil then
		return
	end
	pcall(audio.play, audio, id, if position then { position = position } else nil)
end

function FeedbackWarController:_battleMusic()
	local music = self._music
	if music ~= nil and music.combatNear ~= nil then
		pcall(music.combatNear, music)
	end
end

function FeedbackWarController:_remember(position: Vector3?)
	if position == nil then
		return
	end
	local now = self._env.clock()
	for _, spot in self._hotspots do
		if (spot.position - position).Magnitude <= Def.HOTSPOT_STUDS then
			spot.at = now
			spot.count += 1
			return
		end
	end
	table.insert(self._hotspots, { position = position, at = now, count = 1 })
	if #self._hotspots > Def.HOTSPOT_MAX then
		table.sort(self._hotspots, function(a, b)
			return a.at > b.at
		end)
		table.remove(self._hotspots)
	end
end

-- Battle places of the last HOTSPOT_SEC, newest first.
function FeedbackWarController:hotspots(now: number?): { { position: Vector3, at: number, count: number } }
	local clock = now or self._env.clock()
	local out = {}
	for _, spot in self._hotspots do
		if clock - spot.at <= Def.HOTSPOT_SEC then
			table.insert(out, table.clone(spot))
		end
	end
	table.sort(out, function(a, b)
		return a.at > b.at
	end)
	return out
end

-- ---------------------------------------------------------------- units: hits and deaths

function FeedbackWarController:onEntityEvent(id: any, cue: any, _payload: any, model: any)
	if type(id) ~= "number" or id ~= id then
		return
	end
	if cue == "hit" then
		self:_hit(id, model)
	elseif cue == "die" and model ~= nil and self._dying[id] == nil then
		self._dying[id] = { model = model, parts = partsOf(model), at = self._env.clock() }
		self.stats.fades += 1
	end
end

function FeedbackWarController:_hit(id: number, model: any)
	local now = self._env.clock()
	if model == nil or now - (self._lastFlash[id] or -math.huge) < Def.FLASH_GAP_SEC then
		return
	end
	local position = pivotOf(model)
	if not self:_near(position) then
		self.stats.skipped += 1
		return
	end
	self._lastFlash[id] = now
	self:_remember(position)
	self:_battleMusic()
	local highlight = self:_takeHighlight()
	if highlight ~= nil then
		pcall(function()
			highlight.Adornee = model
			highlight.Enabled = true
		end)
		self._flashes[model] = { highlight = highlight, ends = now + Def.FLASH_SEC }
		self.stats.flashes += 1
	end
	if position ~= nil then
		self:_play(Def.FX.hit, position + Vector3.new(0, 3, 0))
		self:_sound(Def.SOUND.hit, position)
	end
end

function FeedbackWarController:_takeHighlight(): any
	local free = table.remove(self._pool)
	if free ~= nil then
		return free
	end
	local live = 0
	for _ in self._flashes do
		live += 1
	end
	if live >= Def.FLASH_MAX then
		return nil
	end
	local ok, highlight = pcall(function()
		local made = self._env.newInstance("Highlight")
		made.Name = "ForgeHitFlash"
		made.FillColor = Def.FLASH_COLOR
		made.FillTransparency = 0.35
		made.OutlineTransparency = 1
		made.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		made.Enabled = false
		made.Parent = self._env.Workspace
		return made
	end)
	return if ok then highlight else nil
end

function FeedbackWarController:_endFlash(key: any)
	local flash = self._flashes[key]
	self._flashes[key] = nil
	if flash == nil then
		return
	end
	pcall(function()
		flash.highlight.Enabled = false
	end)
	pcall(function()
		flash.highlight.Adornee = nil -- (Lune cannot clear a reference; the disabled Highlight shows nothing)
	end)
	table.insert(self._pool, flash.highlight)
end

function FeedbackWarController:_fade(parts: { any }, alpha: number)
	for _, part in parts do
		pcall(function()
			part.LocalTransparencyModifier = alpha
		end)
	end
end

-- A rig going back to the pool: whole again, no flash.
function FeedbackWarController:released(id: any, model: any)
	local dying = self._dying[id]
	if dying ~= nil then
		self:_fade(dying.parts, 0)
		self._dying[id] = nil
	end
	if model ~= nil and self._flashes[model] ~= nil then
		self:_endFlash(model)
	end
	self._lastFlash[id] = nil
end

-- ---------------------------------------------------------------- buildings: hits and collapses

function FeedbackWarController:_modelOf(buildingId: number): any
	local ok, found = pcall(function()
		local root = self._env.Workspace:FindFirstChild("ForgeKingdoms")
		for _, folder in (if root then root:GetChildren() else {}) do
			local buildings = folder:FindFirstChild("Buildings")
			for _, model in (if buildings then buildings:GetChildren() else {}) do
				if model:GetAttribute("BuildingId") == buildingId then
					return model
				end
			end
		end
		return nil
	end)
	return if ok then found else nil
end

function FeedbackWarController:onBuildings(views: any)
	if type(views) ~= "table" then
		return
	end
	if Def.isWorldReset(views) then
		table.clear(self._views)
		table.clear(self._lastHit)
		self.stats.resets += 1
		return
	end
	local collapses = {}
	for _, view in views do
		if type(view) == "table" and type(view.id) == "number" then
			local id = view.id
			local before = self._views[id]
			if view.state == "destroyed" then
				self._views[id] = nil
				self._lastHit[id] = nil
				if before ~= nil and Def.STANDING[before.state or ""] then
					local position = viewPosition(view)
					if position ~= nil then
						table.insert(collapses, position)
					end
				end
			else
				local hp = if finite(view.hp) then view.hp else nil
				if before ~= nil and hp ~= nil and before.hp ~= nil and hp < before.hp then
					self:_buildingHit(id, view)
				end
				self._views[id] = { state = view.state, hp = hp, kingdom = view.kingdom, type = view.type }
			end
		end
	end
	if #collapses > 0 then
		self:_collapse(collapses)
	end
end

function FeedbackWarController:_buildingHit(id: number, view: any)
	local now = self._env.clock()
	if now - (self._lastHit[id] or -math.huge) < Def.HIT_GAP_SEC then
		return
	end
	local model = self:_modelOf(id)
	local burning = false
	if model ~= nil then
		pcall(function()
			burning = model:GetAttribute("Burning") == true
		end)
	end
	if burning then
		return -- a riot's fire shows already, and its damage ticks every second
	end
	local position = if model ~= nil then roofOf(model) else viewPosition(view)
	self:_remember(position)
	if not self:_near(position) then
		self.stats.skipped += 1
		return
	end
	self._lastHit[id] = now
	self.stats.hits += 1
	self:_battleMusic()
	if position ~= nil then
		self:_play(Def.FX.buildingHit, position)
	end
	if model ~= nil and not self:_reducedMotion() then
		self:_startShake(model)
	end
end

function FeedbackWarController:_startShake(model: any)
	if self._shakes[model] ~= nil then
		return
	end
	local live = 0
	for _ in self._shakes do
		live += 1
	end
	if live >= Def.SHAKE.max then
		return
	end
	self._shakes[model] = { parts = partsOf(model), offset = Vector3.zero, age = 0, seed = live + 1 }
	self.stats.shakes += 1
end

-- Moves every part of a shaking model by `delta` (translation only, so it works headless too).
local function moveParts(parts: { any }, delta: Vector3)
	if delta.Magnitude == 0 then
		return
	end
	for _, part in parts do
		pcall(function()
			part.CFrame = part.CFrame + delta
		end)
	end
end

function FeedbackWarController:_endShake(key: any)
	local shake = self._shakes[key]
	self._shakes[key] = nil
	if shake ~= nil then
		moveParts(shake.parts, -shake.offset) -- back exactly where the server put it
	end
end

function FeedbackWarController:_collapse(positions: { Vector3 })
	local focus = self:_focus()
	if focus ~= nil then
		table.sort(positions, function(a, b)
			return (a - focus).Magnitude < (b - focus).Magnitude
		end)
	end
	local nearest = positions[1]
	for index = 1, math.min(#positions, Def.COLLAPSE_MAX) do
		local position = positions[index]
		self:_remember(position)
		self:_play(Def.FX.collapse, position)
		self.stats.collapses += 1
	end
	self:_sound(Def.SOUND.collapse, nearest)
	local camera = self._camera
	if nearest ~= nil and camera ~= nil and camera.shake ~= nil and self:_near(nearest, Def.COLLAPSE_SHAKE.studs) then
		pcall(camera.shake, camera, Def.COLLAPSE_SHAKE.magnitude, Def.COLLAPSE_SHAKE.duration) -- honours reduced motion
	end
end

-- ---------------------------------------------------------------- the raid alert

function FeedbackWarController:onMoment(moment: any)
	if type(moment) ~= "table" then
		return
	end
	local kind = moment.kind
	if kind == "raid" or kind == "siege" then
		if moment.on == true and typeof(moment.position) == "Vector3" then
			self:_clearAlert(kind)
			self._alerts[kind] = {
				position = moment.position,
				kingdom = if type(moment.kingdom) == "string" then moment.kingdom else nil,
				at = self._env.clock(),
				effect = self:_play(Def.FX.ping, moment.position),
			}
		elseif moment.on == false then
			self:_clearAlert(kind)
		end
	elseif kind == "kingdomFell" then
		self:_clearAlert()
	end
end

-- Ends one alert ("raid" or "siege"), or every alert when kind is nil.
function FeedbackWarController:_clearAlert(kind: string?)
	for _, name in Def.ALERT_ORDER do
		local alert = self._alerts[name]
		if alert ~= nil and (kind == nil or kind == name) then
			self._alerts[name] = nil
			if alert.effect ~= nil and self._vfx ~= nil and self._vfx.stop ~= nil then
				pcall(self._vfx.stop, self._vfx, alert.effect)
			end
		end
	end
end

-- The alert that counts: a siege on our keep before a raid in our lands.
function FeedbackWarController:_current(): (string?, any)
	for _, name in Def.ALERT_ORDER do
		local alert = self._alerts[name]
		if alert ~= nil then
			return name, alert
		end
	end
	return nil, nil
end

function FeedbackWarController:alert(): { kind: string, position: Vector3, kingdom: string?, at: number }?
	local kind, alert = self:_current()
	if kind == nil then
		return nil
	end
	return { kind = kind :: string, position = alert.position, kingdom = alert.kingdom, at = alert.at }
end

-- The overview camera to the current alert (the HUD's ping button calls this too).
function FeedbackWarController:goToAlert(): boolean
	local _, alert = self:_current()
	local camera = self._camera
	if alert == nil or camera == nil or camera.focusOn == nil then
		return false
	end
	if camera.mode ~= "overview" and camera.setMode ~= nil then
		pcall(camera.setMode, camera, "overview")
	end
	local ok, moved = pcall(camera.focusOn, camera, alert.position)
	return ok and moved ~= false
end

function FeedbackWarController:_bindKeys()
	local env = self._env
	local userInput = self._userInputOverride
	if userInput == nil then
		local ok, found = pcall(function()
			local uis = env.UserInputService
			local _ = uis.InputBegan -- the boot gate's unmocked guard errors here
			return uis
		end)
		userInput = if ok then found else nil
	end
	if userInput == nil then
		return
	end
	local ok, connection = pcall(function()
		return userInput.InputBegan:Connect(function(input, processed)
			if processed then
				return -- typing in a TextBox, or a GUI that took the key
			end
			if table.find(Def.ALERT_KEYS, input.KeyCode) then
				self:goToAlert()
			end
		end)
	end)
	if ok then
		table.insert(self._connections, connection)
	end
end

-- ---------------------------------------------------------------- per frame

function FeedbackWarController:step(dt: number)
	local now = self._env.clock()
	for key, flash in self._flashes do
		if now >= flash.ends then
			self:_endFlash(key)
		end
	end
	local fade = Def.DEATH_FADE
	for _, dying in self._dying do
		local alpha = math.clamp((now - dying.at - fade.from) / (fade.to - fade.from), 0, 1)
		self:_fade(dying.parts, alpha)
	end
	local seconds = if finite(dt) and dt > 0 then dt else 0
	local reduced = self:_reducedMotion()
	for key, shake in self._shakes do
		shake.age += seconds
		if reduced or shake.age >= Def.SHAKE.sec then
			self:_endShake(key)
		else
			local strength = Def.SHAKE.studs * (1 - shake.age / Def.SHAKE.sec)
			local angle = (shake.age * 47 + shake.seed) * 2.3
			local target = Vector3.new(math.sin(angle) * strength, 0, math.cos(angle * 1.7) * strength)
			moveParts(shake.parts, target - shake.offset)
			shake.offset = target
		end
	end
end

return Def
