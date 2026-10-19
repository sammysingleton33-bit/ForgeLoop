--!strict
--[[
	CrowdStageController (game-001, FORGE-04, FL-0074 part 2b; CONTRACTS G12.4 / G12.6; design crown-arena.md §7
	"Intro"): the Crown Arena's staging for everyone in the match, the champions and the watching rulers.
		- Intro: when Arena.State reaches "intro", the herald's horn (arena.horn) sounds and the overview camera
		  passes over both stands, then settles on the ring (RulerCameraController:playShots): the other
		  kingdom's stand first, then your own, then the ring seen from your own stand, so each side sees its
		  own crowd's mood. A ruler of neither kingdom sees stand A, stand B, then the ring from A's side.
		  The pass fits the intro's time left (ArenaState.endsAt, the server's clock: FORGE-00's one-source
		  ruling, so the intro's length is config Arena's, FORGE-01; config Crowd `intro` sets the shots),
		  cuts instead of gliding with reduced motion, and any pan, zoom, turn or "go to" takes over.
		  FORGE-03's versus card (ArenaIntroController) sits on top of it.
		- Duel: a ruler who missed the intro (a late joiner) gets the ring shot alone. The champions' camera
		  follows them in the arena input mode (FL-0075), which ends any pass.
		- Music: the scene "arena" (MusicController:setScene, music.arena) from the intro to the end of the
		  crowning; any other stage, Results and Lobby end it.
		- Crowning: the fanfare (arena.fanfare) once, when ArenaState.winner names a champion (a duel or a
		  forfeit) or ArenaState.coronation names a kingdom crowned without a duel (a single qualifier;
		  FORGE-07 #231 L1). A duel that is called off (a draw: neither is set) gets none (FORGE-00's draw
		  ruling).
	Where: FORGE-02's arena model (CollectionService tag "CrownArena"; attachments on its Root:
	StandA_RoyalBox, StandB_RoyalBox, Centre), else Layout.arena's frame (Stand A at -Z, B at +Z,
	Def.STAND_STUDS from the centre). With neither, the pass is skipped (one info line); the music and the
	stingers still play.
	Whose stand: Kingdom.State `mine` (G8) when it is one duellist's kingdom, else the duellist whose userId
	is the local player's.

	Studio preview (E18): in Studio only, the local player's attribute ForgeArenaPreview = "a", "b" or
	"neutral" plays the intro (horn, music, the camera pass) as that viewer, with crimson as A and azure as
	B; any other value ends it. A real arena stage is never interrupted.

	API
		controller.stage                           -- the last ArenaStage seen, nil outside the arena
		controller:onArenaState(state) / :onKingdomState(state) / :onPhase(phase)
		controller:geometry() -> { centre: Vector3, a: Vector3, b: Vector3 }?
		controller:preview(spec) -> boolean        -- Studio only
		Def.pass(geometry, side?, seconds?, config) -> { shot }   -- pure: the intro pass for a viewer
		Def.yawToward(from, to) -> number?         -- pure: the overview yaw that looks from `from` to `to`
	Engine access is guarded: without a camera, music, audio, the arena or the remotes it does what it can.
]]

local Crowd = require("@game/ReplicatedStorage/Forge/Config/Crowd")
local Layout = require("@game/ReplicatedStorage/Game/World/Layout")
local RemoteLink = require("@game/ReplicatedStorage/Forge/Experience/RemoteLink")

local Controller = {}
Controller.__index = Controller

local Def = { name = "CrowdStageController", dependencies = {} }

Def.TAG = "CrownArena"
Def.STAND_STUDS = 30 -- the Layout fallback: a stand's centre from the ring's centre, along the arena's Z axis
Def.SCENE = "arena"
Def.SCENE_STAGES = table.freeze({ intro = true, duel = true, crowning = true })
Def.HORN = "arena.horn"
Def.FANFARE = "arena.fanfare"
Def.PREVIEW_ATTRIBUTE = "ForgeArenaPreview"
Def.END_PHASES = table.freeze({ Results = true, Lobby = true })

local function finite(value: any): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

function Def.yawToward(from: Vector3, to: Vector3): number?
	local flat = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	if flat.Magnitude < 1e-3 then
		return nil
	end
	local d = flat.Unit
	return math.atan2(-d.X, -d.Z) -- RulerCameraController.aerialCFrame: yaw 0 looks toward -Z
end

-- The intro pass for a viewer of side "a", "b" or nil (neither): the other stand, your own, then the ring
-- from your own side. It lasts at most `seconds` (the intro time left) and never longer than its own
-- full length, shrinking every shot alike, never below minShotSec.
function Def.pass(geometry: any, side: string?, seconds: number?, config: any): { any }
	local intro = config.intro
	local home = if side == "b" then "b" else "a"
	local away = if home == "a" then "b" else "a"
	local order = if side == nil then { "a", "b" } else { away, home }
	local full = 2 * intro.standSec + intro.ringSec
	local budget = if finite(seconds) and (seconds :: number) > 0 then seconds :: number else full
	local scale = math.min(1, budget / full) -- never longer than the full pass
	local stand = math.max(intro.minShotSec, intro.standSec * scale)
	local ring = math.max(intro.minShotSec, intro.ringSec * scale)
	local shots = {}
	for _, key in order do
		local yaw = Def.yawToward(geometry.centre, geometry[key])
		if yaw ~= nil then
			table.insert(shots, { focus = geometry[key], yaw = yaw, zoom = intro.standZoom, seconds = stand })
		end
	end
	local yaw = Def.yawToward(geometry[home], geometry.centre)
	if yaw ~= nil then
		table.insert(shots, { focus = geometry.centre, yaw = yaw, zoom = intro.ringZoom, seconds = ring })
	end
	return shots
end

function Def.create(env: any, registry: any, opts: any?)
	return setmetatable({
		_env = env,
		_registry = registry,
		_opts = opts or {},
		_links = {} :: { any },
		_connections = {} :: { any },
		_logged = {} :: { [string]: boolean },
		_mine = nil :: string?,
		_previewing = false,
		stage = nil :: string?,
	}, Controller)
end

function Def.new(env: any, registry: any)
	return Def.create(env, registry, nil)
end

function Controller:start()
	local env = self._env
	local registry = self._registry
	self._camera = registry:find("RulerCameraController")
	self._music = registry:find("MusicController")
	self._audio = registry:find("AudioController")
	for _, link in
		{
			RemoteLink.on(env, "Arena.State", function(state)
				self:onArenaState(state)
			end),
			RemoteLink.on(env, "Kingdom.State", function(state)
				self:onKingdomState(state)
			end),
			RemoteLink.on(env, "Match.State", function(phase)
				self:onPhase(phase)
			end),
		}
	do
		table.insert(self._links, link)
	end
	self:_watchPreview()
end

function Controller:destroy()
	for _, link in self._links do
		link:disconnect()
	end
	for _, connection in self._connections do
		pcall(function()
			connection:Disconnect()
		end)
	end
	table.clear(self._links)
	table.clear(self._connections)
end

function Controller:_logOnce(key: string, message: string)
	if not self._logged[key] then
		self._logged[key] = true
		self._env.log("info", message)
	end
end

function Controller:onKingdomState(state: any)
	if type(state) == "table" and type(state.mine) == "string" then
		self._mine = state.mine
	end
end

function Controller:onPhase(phase: any)
	if Def.END_PHASES[phase] then
		self:_endStage()
	end
end

function Controller:onArenaState(state: any)
	if type(state) ~= "table" or type(state.stage) ~= "string" then
		return
	end
	local stage = state.stage
	if stage == self.stage then
		return -- a repeated push of the same stage plays nothing twice
	end
	if self._previewing then
		self:_stopPreview() -- the real arena takes over
	end
	local previous = self.stage
	self.stage = stage
	self:_scene(Def.SCENE_STAGES[stage] == true)
	if stage == "intro" then
		self:_play(Def.HORN)
		self:_intro(state, self:_side(state))
	elseif stage == "duel" then
		if previous ~= "intro" then
			self:_ringShot(state) -- a late joiner missed the intro
		end
	elseif stage == "crowning" then
		local crowned = type(state.coronation) == "string" and state.coronation ~= ""
		if type(state.winner) == "number" or crowned then
			self:_play(Def.FANFARE)
		end
	end
end

function Controller:_endStage()
	self.stage = nil
	self:_scene(false)
	local camera = self._camera
	if camera ~= nil and camera.stopShots ~= nil then
		pcall(camera.stopShots, camera)
	end
end

-- "a" or "b" when the local player belongs to that duellist's kingdom (or is that champion), else nil.
function Controller:_side(state: any): string?
	local userId = self:_userId()
	for _, side in { "a", "b" } do
		local duellist = state[side]
		if type(duellist) == "table" then
			if self._mine ~= nil and duellist.kingdom == self._mine then
				return side
			end
			if userId ~= nil and duellist.userId == userId then
				return side
			end
		end
	end
	return nil
end

function Controller:_userId(): number?
	local ok, userId = pcall(function()
		local player = self._opts.player or self._env.Players.LocalPlayer
		return player.UserId
	end)
	return if ok and type(userId) == "number" then userId else nil
end

function Controller:_scene(on: boolean)
	local music = self._music
	if music ~= nil and music.setScene ~= nil then
		pcall(music.setScene, music, if on then Def.SCENE else nil)
	end
end

function Controller:_play(id: string)
	local audio = self._audio
	if audio ~= nil and audio.play ~= nil then
		pcall(audio.play, audio, id)
	end
end

function Controller:_arenaModel(): any
	local ok, model = pcall(function()
		return self._env.CollectionService:GetTagged(Def.TAG)[1]
	end)
	return if ok then model else nil
end

function Controller:geometry(): { centre: Vector3, a: Vector3, b: Vector3 }?
	local model = self:_arenaModel()
	if model ~= nil then
		local ok, geometry = pcall(function()
			local root = model:FindFirstChild("Root")
			local function at(name: string): Vector3?
				local attachment = root and root:FindFirstChild(name)
				if attachment == nil or not attachment:IsA("Attachment") then
					return nil
				end
				return (root.CFrame * attachment.CFrame).Position
			end
			local a, b, centre = at("StandA_RoyalBox"), at("StandB_RoyalBox"), at("Centre")
			if a ~= nil and b ~= nil and centre ~= nil then
				return { centre = centre, a = a, b = b }
			end
			return nil
		end)
		if ok and geometry ~= nil then
			return geometry
		end
	end
	local arena = Layout.arena
	if type(arena) == "table" and typeof(arena.cframe) == "CFrame" then
		local frame = arena.cframe
		return {
			centre = frame.Position,
			a = (frame * CFrame.new(0, 0, -Def.STAND_STUDS)).Position,
			b = (frame * CFrame.new(0, 0, Def.STAND_STUDS)).Position,
		}
	end
	return nil
end

-- Seconds left in the intro (endsAt), nil when the state or the clock does not say.
function Controller:_timeLeft(state: any): number?
	if type(state.endsAt) ~= "number" then
		return nil
	end
	local ok, now = pcall(self._env.serverTimeNow)
	if not ok or type(now) ~= "number" then
		return nil
	end
	return state.endsAt - now
end

function Controller:_shots(shots: { any }): boolean
	local camera = self._camera
	if camera == nil or camera.playShots == nil or #shots == 0 then
		return false
	end
	local ok, played = pcall(camera.playShots, camera, shots)
	return ok and played == true
end

function Controller:_intro(state: any, side: string?): boolean
	local geometry = self:geometry()
	if geometry == nil then
		self:_logOnce(
			"arena",
			"CrowdStageController: no CrownArena model or Layout.arena (FL-0072); intro pass skipped"
		)
		return false
	end
	local left = self:_timeLeft(state)
	local shots = Def.pass(geometry, side, left, Crowd)
	if left ~= nil and left <= 0 then
		shots = { shots[#shots] } -- the intro is already over: the ring alone
	end
	return self:_shots(shots)
end

function Controller:_ringShot(state: any): boolean
	local geometry = self:geometry()
	if geometry == nil then
		return false
	end
	local shots = Def.pass(geometry, self:_side(state), nil, Crowd)
	return self:_shots({ shots[#shots] })
end

-- Studio preview (E18) -------------------------------------------------------------------------------

function Controller:_isStudio(): boolean
	if self._opts.studio ~= nil then
		return self._opts.studio == true
	end
	local ok, studio = pcall(function()
		return self._env.RunService:IsStudio()
	end)
	return ok and studio == true
end

function Controller:_watchPreview()
	if not self:_isStudio() then
		return
	end
	pcall(function()
		local player = self._opts.player or self._env.Players.LocalPlayer
		local function read()
			self:preview(player:GetAttribute(Def.PREVIEW_ATTRIBUTE))
		end
		table.insert(self._connections, player:GetAttributeChangedSignal(Def.PREVIEW_ATTRIBUTE):Connect(read))
		read()
	end)
end

function Controller:_stopPreview()
	self._previewing = false
	self:_scene(false)
	local camera = self._camera
	if camera ~= nil and camera.stopShots ~= nil then
		pcall(camera.stopShots, camera)
	end
end

-- "a", "b" or "neutral" plays the intro as that viewer; anything else ends a running preview.
function Controller:preview(spec: any): boolean
	if not self:_isStudio() then
		return false
	end
	local side = if spec == "a" or spec == "b" then spec elseif spec == "neutral" then false else nil
	if side == nil then
		if self._previewing then
			self:_stopPreview()
		end
		return true
	end
	if self.stage ~= nil then
		return false -- a real arena stage is never interrupted
	end
	self._previewing = true
	self:_scene(true)
	self:_play(Def.HORN)
	return self:_intro({ stage = "intro" }, if side == false then nil else side :: string)
end

return Def
