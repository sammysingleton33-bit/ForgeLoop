--!strict
--[[
	MatchService — the AI Kingdoms match on this server (CONTRACTS G3, FL-0048). Owner: FORGE-01.

	Hosts the match (Game/Kingdom/MatchHost: Match + Simulation + remotes + teams + world view) and runs
	its fixed tick. Other services and FORGE-03/04 read phases from here; kingdom membership is
	KingdomService. Match state is per server and in memory only (never written to player data).

	API (G3)
		MatchService:getPhase(): MatchPhase
		MatchService:getEndsAt(): number?           -- serverTimeNow deadline of the countdown / phase / results;
		                                              nil = untimed (or no countdown running)
		MatchService.phaseChanged: Signal<(MatchPhase, { endsAt: number? })>   -- phase or countdown changes
	Extra
		MatchService.host                           -- the MatchHost (after start); simulation at host.match.sim
		MatchService.mode                           -- "slice" | "match" (config Match.mode, PROVISIONAL)
		MatchService.durationsSource                -- "pacing" | "defaults"
	Dependencies: RemoteService. Optional (registry:find in start):
		- PacingService (G11, FORGE-04): phase lengths from phaseDurations(mode); without it, or when it
		  fails or returns lengths Match.checkDurations rejects, the built-in config Match.durations[mode]
		  (same numbers as config Pacing) and a warning.
		- TreasuryService (G7, FORGE-03): the simulation charges and deposits through it; until then the
		  local TreasuryDouble.
	Studio debug (FL-0068): command match.phase (Founding/Expansion/Conflict/Endgame).
	Events: GameEvents.MatchPhaseChanged / KingdomEliminated / MatchEnded and the other G9 events are fired
	exactly once by the host's event fan-out (see Game/Kingdom/MatchHost).
]]

local MatchConfig = require("@game/ReplicatedStorage/Forge/Config/Match")
local Signal = require("@game/ReplicatedStorage/Forge/Core/Signal")
local Validate = require("@game/ReplicatedStorage/Forge/Core/Validate")
local DebugCommands = require("@game/ReplicatedStorage/Forge/Debug/DebugCommands")
local Match = require("@game/ReplicatedStorage/Game/Kingdom/Match")
local MatchHost = require("@game/ReplicatedStorage/Game/Kingdom/MatchHost")

local MatchService = {}
MatchService.__index = MatchService

local Def = { name = "MatchService", dependencies = { "RemoteService" } }

-- The running service, for the Studio debug commands (registered once per process: Lune specs boot
-- many servers in one process, a real server boots one).
local active: any = nil

local function registerDebugCommands()
	for _, command in DebugCommands.list() do
		if command.name == "match.phase" then
			return
		end
	end
	DebugCommands.register({
		name = "match.phase",
		label = "Set the match phase (Founding, Expansion, Conflict or Endgame)",
		args = { Validate.enum({ "Founding", "Expansion", "Conflict", "Endgame" }) },
		run = function(_player: any, phase: string): string?
			if active == nil or active.host == nil then
				return "no match is running"
			end
			local ok, err = active.host.match:debugSetPhase(phase)
			return if ok then `phase is now {phase}` else `not changed: {err}`
		end,
	})
end

function Def.new(env: any, registry: any)
	local self = setmetatable({}, MatchService)
	self._env = env
	self._registry = registry
	self._remotes = registry:get("RemoteService")
	self.phaseChanged = Signal.new()
	self.host = nil :: any
	self.mode = MatchConfig.mode
	self.durationsSource = "defaults"
	return self
end

-- PacingService:phaseDurations(mode) when present and well-formed, else nil (the config defaults apply).
function MatchService:_pacedDurations(): { [string]: number }?
	local pacing = self._registry:find("PacingService")
	if pacing == nil then
		return nil
	end
	local ok, durations = pcall(pacing.phaseDurations, pacing, self.mode)
	local problem = if ok then Match.checkDurations(durations) else tostring(durations)
	if problem then
		self._env.log(
			"warn",
			"MatchService: PacingService durations unusable; using built-in durations",
			{ mode = self.mode, problem = problem }
		)
		return nil
	end
	return durations
end

function MatchService:start()
	local treasury = self._registry:find("TreasuryService")
	local durations = self:_pacedDurations()
	self.durationsSource = if durations then "pacing" else "defaults"
	self.host = MatchHost.new(self._env, self._remotes, {
		tickSeconds = MatchConfig.tickSeconds,
		match = {
			mode = self.mode,
			phaseDurations = durations,
			minPlayers = MatchConfig.minPlayers,
			treasury = treasury,
		},
	})
	self.host.events:connect(function(name: string)
		if name == "MatchPhaseChanged" or name == "CountdownChanged" then
			self.phaseChanged:fire(self:getPhase(), { endsAt = self:getEndsAt() })
		end
	end)
	self.host:start()
	active = self
	registerDebugCommands()
end

function MatchService:getPhase(): string
	return if self.host then self.host.match.state else "Lobby"
end

function MatchService:getEndsAt(): number?
	if self.host == nil then
		return nil
	end
	local remaining = self.host.match:remaining()
	return if remaining then self._env.serverTimeNow() + remaining else nil
end

function MatchService:destroy()
	if active == self then
		active = nil
	end
	if self.host then
		self.host:destroy()
	end
	self.phaseChanged:disconnectAll()
end

return Def
