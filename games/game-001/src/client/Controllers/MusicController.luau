--!strict
--[[
	MusicController (game-001, FORGE-04, FL-0062): the match's music follows its phase (EXPERIENCE.md §4).
		Founding -> calm, Expansion -> build, Conflict / Endgame -> tension, Results -> calm;
		victory / defeat at the end (Feedback.Moment matchEnded), at once.
	Phase input: `Match.State` (G8, FORGE-01: (phase, endsAt?, startedAt)) and AnnouncerController's
	phase moments, whichever arrives. The rules (minimum dwell, urgent states) are the framework's
	Experience/MusicDirector; AudioController crossfades (1.5 s) and plays the registry tracks.
	The day ambience bed (ambience.birds) starts with the first phase.
	Combat music (battle) is VS-2: VS-1 has no fights.

		MusicController:setPhase(phase) / :setResult("won" | "lost") / :update() -> state?
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
	local announcer = registry:find("AnnouncerController")
	if announcer and announcer.moment then
		table.insert(
			self._connections,
			announcer.moment:connect(function(moment)
				if moment.kind == "phase" then
					self:setPhase(moment.phase)
				elseif moment.kind == "matchEnded" then
					self:setResult(if moment.won then "won" else "lost")
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
	if not self._ambience and self._audio and self._audio.setAmbience then
		self._ambience = true
		self._audio:setAmbience(Def.AMBIENCE)
	end
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
	local state = self._director:update(self._env.clock(), {
		phase = self.phase,
		inMatch = self.phase ~= "Lobby",
		result = self.result,
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
