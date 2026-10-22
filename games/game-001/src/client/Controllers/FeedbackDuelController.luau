--!strict
--[[
	FeedbackDuelController (game-001, FORGE-04, FL-0141; CONTRACTS G12.4 Arena.Events, G12.6; design
	crown-arena.md §5): the Crown Arena champions move with their actions. Every client poses both
	champions from FORGE-01's DuelController: its `events` (G12.1 DuelEvent, one Arena.Events entry each)
	drive Feedback/DuelPoses, and Feedback/DuelRig writes the poses to each champion's joints every frame.
	Self-made procedural poses (D-026 (2)): no animation asset, nothing uploaded.

	When
		- The arena state comes from DuelController (a dependency; stateChanged and getState, so a client
		  that joins mid-duel starts with its one Arena.GetState answer; this controller never asks).
		- From the duel stage through the crowning, both champions hold a ready stance between actions.
		  A new pair of duellists resets both. Any other stage fades the poses out over DuelPoses.XFADE,
		  then gives each avatar back to its Animator (a Kit rig goes back to rest).
		- A late joiner animates from the next event (the next snapshot, at most 0.2 s away). A pair first
		  seen in the crowning (a late join, or a coronation with no duel) is not posed at all.
		- Your own presses play at once (FORGE-00's ruling): InputModeArenaController.sent fires for each
		  action DuelController:act() sent, and the local champion's track predicts it (DuelPoses
		  predict: a cosmetic guess on this client; the server's next state or event confirms it, or it
		  stops after DuelPoses.CONFIRM_SEC). Everyone else's actions come from the events.
	Who
		- A human champion (ArenaState a/b, isAI false): that player's Character.
		- An AI champion: the Model tagged ArenaChampion whose attribute ArenaSide is its side (FORGE-01's
		  FL-0140 figure; until then an AI side has no body and nothing is posed).
		- Each rig is scanned once when its model appears (a respawn makes a new one); without a rig, the
		  side is looked up again every Def.RESOLVE_SEC.
		- What the champion holds sets its pose style (FL-0141 follow-up 3): a one-handed champion who
		  wears Kit.shield on the left hand (DuelRig.leftShield) fights in DuelPoses' "shield" style, the
		  shield kept facing the opponent. Checked when the rig is found, then every Def.RESOLVE_SEC (the
		  gear may come after the body); a shield on the weapon (no LeftGripAttachment) stays "slash".
	Cost: an event only changes a track's state (no instance work), so a burst of events costs nothing
	per event; each frame samples two tracks and writes at most 11 joints each.
	Frame: RunService.PreSimulation (else Stepped), after the Animator's pass, so the pose is laid over
	the avatar's own animation that frame (DuelRig). Reduced motion (SettingsController:reducedMotion())
	keeps every pose but drops the periodic parts (the stagger's wobble, the victory pump, the stance's
	breathing): an action is information, not decoration.

	Studio preview (E21): in Studio only, the local player's attribute ForgeDuelPreview = a weapon
	(swordShield, greatsword, spear, mace; anything else reads as swordShield) plays Def.PREVIEW on your
	own character as side a, one step every few tenths of a second, through the same path; "" stops it.
	A real duel stage is never interrupted.

	API
		controller.poses                          -- the Feedback/DuelPoses duel
		controller:onArenaState(state) / :onEvent(event)
		controller:onPress(action)                -- the local champion's own sent press
		controller:step(now?)                     -- one frame; PreSimulation calls it live
		controller:rig(side) -> DuelRig.Rig?      -- the side's rig, if found
		controller:preview(spec) -> boolean       -- Studio only
	opts (specs): { adapter, characterOf(userId) -> Model?, champions() -> { Model }, studio, player }
]]

local DuelPoses = require("@game/ReplicatedStorage/Game/Feedback/DuelPoses")
local DuelRig = require("@game/ReplicatedStorage/Game/Feedback/DuelRig")

local Controller = {}
Controller.__index = Controller

local Def = { name = "FeedbackDuelController", dependencies = { "DuelController" } }

Def.TAG = "ArenaChampion"
Def.SIDE_ATTRIBUTE = "ArenaSide"
Def.STAGES = table.freeze({ duel = true, crowning = true })
Def.RESOLVE_SEC = 0.5
Def.PREVIEW_ATTRIBUTE = "ForgeDuelPreview"
Def.WEAPONS = table.freeze({ swordShield = true, greatsword = true, spear = true, mace = true })

-- The Studio preview, side a = you: { seconds after the previous step, event }
local function snap(state: string, weapon: string): any
	return { kind = "snapshot", side = "a", data = { a = { state = state, weapon = weapon } } }
end
function Def.previewSteps(weapon: string): { { any } }
	return {
		{ 0.2, snap("idle", weapon) },
		{ 0.6, snap("windup", weapon) }, -- light
		{ 0.15, { kind = "hit", side = "a", data = { heavy = false } } },
		{ 0.25, snap("recover", weapon) },
		{ 0.8, { kind = "heavyWindup", side = "a", data = { impactIn = 0.8, warned = 0 } } }, -- heavy
		{ 0.8, { kind = "hit", side = "a", data = { heavy = true } } },
		{ 0.9, snap("block", weapon) }, -- block, a hit on the guard, release
		{ 0.5, { kind = "hit", side = "b", data = { heavy = false } } },
		{ 0.7, snap("idle", weapon) },
		{ 0.6, snap("parry", weapon) }, -- parry
		{ 0.1, { kind = "parry", side = "a" } },
		{ 0.6, snap("dodge", weapon) }, -- dodge left, then right
		{ 0.6, snap("idle", weapon) },
		{ 0.1, snap("dodge", weapon) },
		{ 0.6, snap("idle", weapon) },
		{ 0.4, { kind = "hit", side = "b", data = { heavy = false } } }, -- flinches
		{ 0.8, { kind = "hit", side = "b", data = { heavy = true } } },
		{ 0.9, { kind = "stagger", side = "a" } }, -- stagger
		{ 1.4, { kind = "ended", side = "b", data = { reason = "ko" } } }, -- KO: you kneel and slump
	}
end

local function connect(target: any, name: string, handler: (...any) -> ()): any
	local ok, connection = pcall(function()
		local signal = target[name]
		if signal == nil then
			return nil
		end
		if type(signal) == "table" and type(signal.connect) == "function" then
			return signal:connect(handler)
		end
		return signal:Connect(handler)
	end)
	return if ok then connection else nil
end

local function disconnect(connection: any)
	pcall(function()
		if type(connection) == "table" and connection.disconnect ~= nil then
			connection:disconnect() -- a Forge Signal (DuelController, InputModeArenaController)
		else
			connection:Disconnect() -- an engine connection (RunService, the preview attribute)
		end
	end)
end

function Def.create(env: any, registry: any, opts: { [string]: any }?)
	return setmetatable({
		_env = env,
		_registry = registry,
		_opts = opts or {},
		_connections = {} :: { any },
		_state = nil :: any,
		_pair = nil :: string?,
		_running = false,
		_sawDuel = false, -- this pair's duel stage was seen here (not only its crowning)
		_stoppedAt = nil :: number?,
		_sides = { a = {}, b = {} } :: { [string]: any }, -- { model, rig, lookedAt, shieldAt }
		_out = { a = { weight = 0, body = 0 }, b = { weight = 0, body = 0 } } :: { [string]: any },
		_preview = nil :: any,
		poses = DuelPoses.newDuel(),
	}, Controller)
end

function Def.new(env: any, registry: any)
	return Def.create(env, registry, nil)
end

function Controller:_now(): number
	return self._env.clock()
end

function Controller:start()
	local duel = self._registry:find("DuelController")
	table.insert(
		self._connections,
		duel.events:connect(function(event)
			self:onEvent(event)
		end)
	)
	table.insert(
		self._connections,
		duel.stateChanged:connect(function(state)
			self:onArenaState(state)
		end)
	)
	local ok, state = pcall(duel.getState, duel)
	if ok and state ~= nil then
		self:onArenaState(state)
	end
	local input = self._registry:find("InputModeArenaController")
	if input ~= nil and type(input.sent) == "table" then
		table.insert(
			self._connections,
			input.sent:connect(function(action)
				self:onPress(action)
			end)
		)
	end
	local runService = self._env.RunService
	if runService ~= nil then
		local frame = function()
			self:step()
		end
		local connection = connect(runService, "PreSimulation", frame) or connect(runService, "Stepped", frame)
		if connection ~= nil then
			table.insert(self._connections, connection)
		end
	end
	self:_watchPreview()
end

function Controller:destroy()
	for _, connection in self._connections do
		disconnect(connection)
	end
	table.clear(self._connections)
	self:_releaseAll()
	self._running = false
end

-- ------------------------------------------------------------------ the arena state

local function pairKey(state: any): string?
	local a, b = state.a, state.b
	if type(a) ~= "table" or type(b) ~= "table" then
		return nil
	end
	return `{tostring(a.userId)}:{tostring(a.isAI)}|{tostring(b.userId)}:{tostring(b.isAI)}`
end

function Controller:onArenaState(state: any)
	if type(state) ~= "table" or type(state.stage) ~= "string" then
		return
	end
	if self._preview ~= nil then
		if not Def.STAGES[state.stage] then
			return -- no duel: the preview goes on
		end
		self:_stopPreview() -- a real duel takes over
	end
	self._state = state
	local now = self:_now()
	if Def.STAGES[state.stage] then
		local key = pairKey(state)
		if key ~= self._pair then
			self._pair = key
			self.poses:reset()
			self:_releaseAll()
			self._running = false
			self._sawDuel = false
		end
		if state.stage == "duel" then
			self._sawDuel = true
		end
		-- A pair first seen in the crowning (a late join, or a coronation with no duel) is not posed: this
		-- client saw no `ended`, so it has no end pose to show, and a ready stance would be wrong.
		if not self._running and self._sawDuel then
			self._running = true
			self._stoppedAt = nil
			self.poses:start(now)
		end
	elseif self._running then
		self._running = false
		self._stoppedAt = now
		self.poses:stop(now)
	end
end

function Controller:onEvent(event: any)
	if self._preview ~= nil then
		return -- the Studio preview owns the poses until a real stage arrives
	end
	self.poses:onEvent(event, self:_now())
end

function Controller:_userId(): number?
	if type(self._opts.userId) == "number" then
		return self._opts.userId
	end
	local ok, id = pcall(function()
		return self._env.Players.LocalPlayer.UserId
	end)
	return if ok and type(id) == "number" then id else nil
end

-- The side the local player champions (not an AI namesake), nil for a spectator.
function Controller:_localSide(): string?
	local state, me = self._state, self:_userId()
	if type(state) ~= "table" or me == nil then
		return nil
	end
	for _, side in { "a", "b" } do
		local duellist = state[side]
		if type(duellist) == "table" and duellist.userId == me and duellist.isAI ~= true then
			return side
		end
	end
	return nil
end

-- The local champion's own press, sent: it plays at once on this client (DuelPoses predict).
function Controller:onPress(action: any)
	if self._preview ~= nil or type(action) ~= "string" then
		return
	end
	-- Outside a duel the tracks are not active, so predict refuses the press.
	local side = self:_localSide()
	if side ~= nil then
		self.poses:predict(side, action, self:_now())
	end
end

-- ------------------------------------------------------------------ finding the champions

function Controller:_characterOf(userId: any): any
	if self._opts.characterOf ~= nil then
		return self._opts.characterOf(userId)
	end
	local ok, model = pcall(function()
		local player = self._env.Players:GetPlayerByUserId(userId)
		return player and player.Character
	end)
	return if ok then model else nil
end

function Controller:_aiFigure(side: string): any
	local ok, tagged = pcall(function()
		if self._opts.champions ~= nil then
			return self._opts.champions()
		end
		return self._env.CollectionService:GetTagged(Def.TAG)
	end)
	if not ok or type(tagged) ~= "table" then
		return nil
	end
	for _, model in tagged do
		local okSide, value = pcall(function()
			return model:GetAttribute(Def.SIDE_ATTRIBUTE)
		end)
		if okSide and value == side then
			return model
		end
	end
	return nil
end

function Controller:_modelFor(side: string): any
	local state = self._state
	local duellist = if type(state) == "table" then state[side] else nil
	if type(duellist) ~= "table" then
		return nil
	end
	if duellist.isAI == true then
		return self:_aiFigure(side)
	end
	return self:_characterOf(duellist.userId)
end

local function alive(model: any): boolean
	local ok, parent = pcall(function()
		return model.Parent
	end)
	return ok and parent ~= nil
end

function Controller:rig(side: string): any
	return self._sides[side].rig
end

-- The side's rig: kept while its model lives. Without one (no model yet, a model that left, or a
-- model whose joints have not streamed in), the side is looked up and scanned again every RESOLVE_SEC.
function Controller:_rigFor(side: string, now: number): any
	local entry = self._sides[side]
	if entry.rig ~= nil and alive(entry.model) then
		self:_wornShield(side, entry, now)
		return entry.rig
	end
	if entry.rig == nil and entry.lookedAt ~= nil and now - entry.lookedAt < Def.RESOLVE_SEC then
		return nil -- (a rig whose model just left is looked up at once: a respawn)
	end
	entry.lookedAt = now
	local model = self:_modelFor(side)
	if entry.rig ~= nil then
		DuelRig.release(entry.rig, self._opts.adapter) -- its model left (a respawn makes a new one)
	end
	entry.model, entry.rig = model, nil
	if model ~= nil then
		local rig = DuelRig.scan(model)
		entry.rig = rig
		if rig == nil then
			self:_logOnce(`norig:{side}`, `{Def.name}: champion {side} has no joints to pose yet`)
		else
			-- one line per model found: what Studio E21 step 1 copies (which rig, which joints)
			self._env.log("info", `{Def.name}: champion {side} is a {rig.kind} rig, {rig.count} {rig.class} joints`)
			entry.shieldAt = nil
			self:_wornShield(side, entry, now)
		end
	end
	return entry.rig
end

-- The side's left-hand shield sets its style: checked when the rig is found, then every RESOLVE_SEC.
function Controller:_wornShield(side: string, entry: any, now: number)
	if entry.shieldAt ~= nil and now - entry.shieldAt < Def.RESOLVE_SEC then
		return
	end
	entry.shieldAt = now
	self.poses[side]:setShield(DuelRig.leftShield(entry.model))
end

function Controller:_releaseAll()
	for _, side in { "a", "b" } do
		local entry = self._sides[side]
		if entry.rig ~= nil then
			DuelRig.release(entry.rig, self._opts.adapter)
		end
		self._sides[side] = {}
	end
end

function Controller:_logOnce(key: string, message: string)
	self._logged = self._logged or {}
	if not self._logged[key] then
		self._logged[key] = true
		self._env.log("info", message)
	end
end

-- ------------------------------------------------------------------ the frame

function Controller:_reducedMotion(): boolean
	local settings = self._registry:find("SettingsController")
	if settings == nil then
		return false
	end
	local ok, reduced = pcall(function()
		return if type(settings.reducedMotion) == "function"
			then settings:reducedMotion()
			else settings:get("reducedMotion")
	end)
	return ok and reduced == true
end

function Controller:step(now: number?)
	local t = now or self:_now()
	if self._preview ~= nil then
		self:_advancePreview(t)
	end
	local fading = self._stoppedAt ~= nil and t - self._stoppedAt <= DuelPoses.XFADE + 0.05
	if not self._running and not fading then
		if self._stoppedAt ~= nil then
			self._stoppedAt = nil
			self:_releaseAll() -- after the fade: back to the Animator, or to rest
		end
		return
	end
	local motion = not self:_reducedMotion()
	for _, side in { "a", "b" } do
		local rig = self:_rigFor(side, t)
		if rig ~= nil then
			local out = self.poses[side]:sample(t, self._out[side], motion)
			DuelRig.apply(rig, out, self._opts.adapter)
		end
	end
end

-- ------------------------------------------------------------------ Studio preview (E21)

function Controller:_isStudio(): boolean
	if self._opts.studio ~= nil then
		return self._opts.studio == true
	end
	local ok, studio = pcall(function()
		return self._env.RunService:IsStudio()
	end)
	return ok and studio == true
end

function Controller:_player(): any
	return self._opts.player or self._env.Players.LocalPlayer
end

function Controller:_watchPreview()
	if not self:_isStudio() then
		return
	end
	pcall(function()
		local player = self:_player()
		local function read()
			self:preview(player:GetAttribute(Def.PREVIEW_ATTRIBUTE))
		end
		table.insert(self._connections, player:GetAttributeChangedSignal(Def.PREVIEW_ATTRIBUTE):Connect(read))
		read()
	end)
end

function Controller:_stopPreview()
	self._preview = nil
	self._running = false
	self._stoppedAt = self:_now()
	self.poses:stop(self._stoppedAt)
	self._state = nil
	self._pair = nil
end

-- A weapon name (or any other text: swordShield) plays the preview on your character; "" or nil stops it.
function Controller:preview(spec: any): boolean
	if not self:_isStudio() then
		return false
	end
	if type(spec) ~= "string" or spec == "" then
		if self._preview ~= nil then
			self:_stopPreview()
		end
		return true
	end
	local state = self._state
	if type(state) == "table" and Def.STAGES[state.stage] then
		return false -- a real duel is never interrupted
	end
	local weapon = if Def.WEAPONS[spec] then spec else "swordShield"
	local userId = nil
	pcall(function()
		userId = self:_player().UserId
	end)
	local now = self:_now()
	self:_releaseAll()
	self.poses:reset()
	self._state = { stage = "duel", a = { userId = userId, isAI = false } }
	self._pair = nil
	self._running, self._stoppedAt = true, nil
	self.poses:start(now)
	self._preview = { steps = Def.previewSteps(weapon), index = 1, nextAt = now }
	return true
end

function Controller:_advancePreview(now: number)
	local preview = self._preview
	while preview ~= nil and preview.steps[preview.index] ~= nil do
		local step = preview.steps[preview.index]
		local at = preview.nextAt + step[1]
		if now < at then
			return
		end
		preview.nextAt = at
		preview.index += 1
		self.poses:onEvent(step[2], at)
	end
end

return Def
