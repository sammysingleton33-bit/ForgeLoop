--!strict
--[[
	MusicController (game-001, FORGE-04, FL-0062): the match's music follows its phase (EXPERIENCE.md §4).
		Founding -> calm, Expansion -> build, Conflict / Endgame -> tension, Results -> calm;
		victory / defeat at the end (Feedback.Moment matchEnded), at once.
	Phase input: `Match.State` (G8, FORGE-01: (phase, endsAt?, startedAt)) and AnnouncerController's
	phase moments, whichever arrives. At start it also asks `Match.GetState` once, because the
	Match.State sent to an arriving player can come before this controller listens (a late joiner
	would otherwise hear nothing until the next phase); the answer applies only if no phase came yet.
	Victory / defeat music only for a ruler who won or lost (a draw or a spectator keeps the phase music). The rules (minimum dwell, urgent states) are the framework's
	Experience/MusicDirector; AudioController crossfades (1.5 s) and plays the registry tracks.
	The day ambience bed (ambience.birds) starts with the first phase.
	Battle music (FL-0130) while our lands are raided or our keep is besieged: the raid and siege moments'
	start and end (AnnouncerController), held while any is on and ringing out calmTailSec after the last
	one ends; our keep falling, Results and a new match end them. A battle in view (FeedbackWarController:
	a hit flash or a building hit near the camera) also calls combatNear(), so an attacker hears it too;
	it rings out after MusicDirector's combatHoldSec without another.

	The Crown Arena (FL-0074 part 2b): CrowdStageController sets the scene "arena" from the intro to the
	end of the crowning, so music.arena plays over everything but the match result; Results and Lobby
	end any scene left set.

		MusicController:setPhase(phase) / :setResult("won" | "lost") / :setScene(scene?) / :update() -> state?
]]

local MusicDirector = require("@game/ReplicatedStorage/Forge/Experience/MusicDirector")
local RemoteLink = require("@game/ReplicatedStorage/Forge/Experience/RemoteLink")

local MusicController = {}
MusicController.__index = MusicController

local Def = { name = "MusicController", dependencies = {} }

Def.PHASE_STATES = table.freeze({
	Lobby = "calm",
	Founding = "calm",
	Expansion = "build",
	Conflict = "tension",
	Endgame = "tension",
	Results = "calm",
})
Def.TICK_SEC = 0.5
Def.AMBIENCE = table.freeze({ "ambience.birds" })

function Def.create(env: any, registry: any)
	return setmetatable({
		_env = env,
		_registry = registry,
		_director = MusicDirector.new({ phaseStates = Def.PHASE_STATES }),
		_links = {},
		_connections = {},
		_running = false,
		_ambience = false,
		phase = nil :: string?,
		result = nil :: string?,
		alerts = {} :: { [string]: boolean }, -- raid / siege on (FL-0130)
		scene = nil :: string?, -- "arena" during the Crown Arena (FL-0074)
		state = nil :: string?,
	}, MusicController)
end

function Def.new(env: any, registry: any)
	return Def.create(env, registry)
end

function MusicController:start()
	local registry = self._registry
	self._audio = registry:find("AudioController")
	table.insert(
		self._links,
		RemoteLink.on(self._env, "Match.State", function(phase)
			self:setPhase(phase)
		end)
	)
	RemoteLink.request(self._env, "Match.GetState", function(phase)
		if self.phase == nil and not self._destroyed then -- a late reply after destroy plays nothing
			self:setPhase(phase)
		end
	end)
	local announcer = registry:find("AnnouncerController")
	if announcer and announcer.moment then
		table.insert(
			self._connections,
			announcer.moment:connect(function(moment)
				if moment.kind == "phase" then
					self:setPhase(moment.phase)
				elseif moment.kind == "raid" or moment.kind == "siege" then
					self:setAlert(moment.kind, moment.on == true)
				elseif moment.kind == "kingdomFell" then
					self:clearAlerts()
				elseif moment.kind == "matchEnded" then
					local outcome = moment.outcome or (if moment.won then "won" else "lost")
					if outcome == "won" or outcome == "lost" then
						self:setResult(outcome)
					end
				end
			end)
		)
	end
	self._running = true
	local env = self._env
	env.spawn(function()
		while self._running do
			self:update()
			env.wait(Def.TICK_SEC)
		end
	end)
end

function MusicController:destroy()
	self._destroyed = true
	self._running = false
	for _, link in self._links do
		link:disconnect()
	end
	for _, connection in self._connections do
		connection:disconnect()
	end
	table.clear(self._links)
	table.clear(self._connections)
end

function MusicController:setPhase(phase: any)
	if type(phase) ~= "string" or Def.PHASE_STATES[phase] == nil then
		return
	end
	self.phase = phase
	if phase ~= "Results" then
		self.result = nil -- a new match
	end
	if phase == "Results" or phase == "Lobby" then
		self:clearAlerts()
		self.scene = nil
	end
	if not self._ambience and self._audio and self._audio.setAmbience then
		self._ambience = true
		self._audio:setAmbience(Def.AMBIENCE)
	end
	self:update()
end

-- A raid or siege started (on) or ended for our kingdom: battle music while any is on.
function MusicController:setAlert(kind: string, on: boolean)
	if on then
		self.alerts[kind] = true
		self._director:combat(self._env.clock())
	elseif self.alerts[kind] then
		self.alerts[kind] = nil
		if next(self.alerts) == nil then
			self._director:calm(self._env.clock())
		end
	end
	self:update()
end

-- A battle in view (any side): battle music now, held while more follow (MusicDirector combatHoldSec).
function MusicController:combatNear()
	self._director:combat(self._env.clock())
	self:update()
end

function MusicController:clearAlerts()
	if next(self.alerts) ~= nil then
		table.clear(self.alerts)
		self._director:calm(self._env.clock())
	end
end

-- A scene that outranks the phase and battle music while set (nil ends it); the result still wins.
function MusicController:setScene(scene: string?)
	local value = if type(scene) == "string" and scene ~= "" then scene else nil
	if value == self.scene then
		return
	end
	self.scene = value
	self:update()
end

function MusicController:setResult(result: string)
	self.result = result
	self:update()
end

function MusicController:update(): string?
	if self.phase == nil then
		return self.state
	end
	if next(self.alerts) ~= nil then
		self._director:combat(self._env.clock()) -- a long raid keeps the battle music up
	end
	local state = self._director:update(self._env.clock(), {
		phase = self.phase,
		inMatch = self.phase ~= "Lobby",
		result = self.result,
		scene = self.scene,
	})
	if state ~= nil and state ~= self.state then
		self.state = state
		if self._audio and self._audio.setMusic then
			self._audio:setMusic(state)
		end
	end
	return self.state
end

return Def
