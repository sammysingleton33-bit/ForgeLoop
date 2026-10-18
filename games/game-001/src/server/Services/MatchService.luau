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
		MatchService.mode                           -- "slice" | "match" (config Match.mode: "match" by default, D-053)
		MatchService.durationsSource                -- "pacing" | "defaults"
	Crown Arena hooks (FL-0125; the ArenaService of FL-0071 plugs in, until then Crown Points decide the match)
		MatchService:registerArena(handler?)        -- handler.beginArena(qualifiers: { KingdomId }): boolean and
		                                              handler.cancelArena(reason)? ; when Endgame ends with two or more
		                                              kingdoms standing the match calls beginArena with the top two by
		                                              Crown Points: true = the duel runs and the match waits for
		                                              arenaEnded; false (or an error) = the Crown Points result at once
		MatchService:arenaEnded(winner: KingdomId?): boolean   -- the duel is over: the winner wins the match
		                                              (reason "arena"); nil or a kingdom outside the duel = the Crown
		                                              Points result. false = no duel was running
	Dependencies: RemoteService. Optional (registry:find in start):
		- PacingService (G11, FORGE-04): phase lengths from phaseDurations(mode); without it, or when it
		  fails or returns lengths Match.checkDurations rejects, the built-in config Match.durations[mode]
		  (same numbers as config Pacing) and a warning.
		- TreasuryService (G7, FORGE-03): the simulation charges and deposits through it; until then the
		  local TreasuryDouble.
	Studio debug (FL-0068): command match.phase (Founding/Expansion/Conflict/Endgame); match.mode (slice/match)
	restarts the match in that mode (D-053 (7): the VS-1 slice stays reachable, so its checklists still run).
	Events: GameEvents.MatchPhaseChanged / KingdomEliminated / MatchEnded and the other G9 events are fired
	exactly once by the host's event fan-out (see Game/Kingdom/MatchHost).
]]

local Costs = require("@game/ReplicatedStorage/Forge/Config/Costs")
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

local function isRegistered(name: string): boolean
	for _, command in DebugCommands.list() do
		if command.name == name then
			return true
		end
	end
	return false
end

local function registerDebugCommands()
	if isRegistered("match.phase") then
		return
	end
	DebugCommands.register({
		name = "match.mode",
		label = "Restart the match in slice or match mode (the VS-1 slice or the full match)",
		args = { Validate.enum({ "slice", "match" }) },
		run = function(_player: any, mode: string): string?
			if active == nil or active.host == nil then
				return "no match is running"
			end
			return active:restartIn(mode)
		end,
	})
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
	self._arena = nil :: any
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
		worldViewEntities = false, -- clients render citizens and soldiers (EntityController, D-023/D-026)
		worldViewBuildings = "kit", -- FORGE-02's Kit models for every building (G6/G10)
		worldViewGround = false, -- WorldService (FORGE-02) owns the terrain and the river; no slab over them
		match = {
			mode = self.mode,
			phaseDurations = durations,
			arena = self._arena,
			minPlayers = MatchConfig.minPlayers,
			treasury = treasury,
			costs = Costs, -- FORGE-03's Costs.luau (G6/G7)
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

-- Studio debug (match.mode): throw the world away and start over in `mode`.
function MatchService:restartIn(mode: string): string
	self.mode = mode
	local durations = self:_pacedDurations()
	self.durationsSource = if durations then "pacing" else "defaults"
	self.host.match:restart(mode, durations)
	return `match restarted in {mode} mode`
end

-- Crown Arena hooks (see the header).
function MatchService:registerArena(handler: any?)
	self._arena = handler
	if self.host then
		self.host.match:setArenaHost(handler)
	end
end

function MatchService:arenaEnded(winner: string?): boolean
	return self.host ~= nil and self.host.match:arenaEnded(winner)
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
