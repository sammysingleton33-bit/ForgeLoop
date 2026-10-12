--!strict
--[[
	MatchService — the AI Kingdoms match on this server (CONTRACTS G3, FL-0048). Owner: FORGE-01.

	Hosts the match (Game/Kingdom/MatchHost: Match + Simulation + remotes + teams + world view) and runs
	its fixed tick. Other services and FORGE-03/04 read phases from here; kingdom membership is
	KingdomService. Match state is per server and in memory only (never written to player data).

	API (G3)
		MatchService:getPhase(): MatchPhase
		MatchService:getEndsAt(): number?           -- serverTimeNow deadline of the countdown / phase / results
		MatchService.phaseChanged: Signal<(MatchPhase, { endsAt: number? })>
	Extra
		MatchService.host                           -- the MatchHost (after start); simulation at host.match.sim
	Dependencies: RemoteService. Optional (registry:find in start): TreasuryService (G7, FORGE-03) —
	when present the simulation charges and deposits through it; until then the local TreasuryDouble.
	Phase lengths: config Match.phaseDurations until FORGE-04's Pacing.phaseDurations() exists (G11).
	Events: GameEvents.MatchPhaseChanged / KingdomEliminated / MatchEnded and the other G9 events are fired
	exactly once by the host's event fan-out (see Game/Kingdom/MatchHost).
]]

local MatchConfig = require("@game/ReplicatedStorage/Forge/Config/Match")
local Signal = require("@game/ReplicatedStorage/Forge/Core/Signal")
local MatchHost = require("@game/ReplicatedStorage/Game/Kingdom/MatchHost")

local MatchService = {}
MatchService.__index = MatchService

local Def = { name = "MatchService", dependencies = { "RemoteService" } }

function Def.new(env: any, registry: any)
	local self = setmetatable({}, MatchService)
	self._env = env
	self._registry = registry
	self._remotes = registry:get("RemoteService")
	self.phaseChanged = Signal.new()
	self.host = nil :: any
	return self
end

function MatchService:start()
	local treasury = self._registry:find("TreasuryService")
	self.host = MatchHost.new(self._env, self._remotes, {
		tickSeconds = MatchConfig.tickSeconds,
		match = {
			countdownSec = MatchConfig.countdownSec,
			resultsSec = MatchConfig.resultsSec,
			minPlayers = MatchConfig.minPlayers,
			phaseDurations = MatchConfig.phaseDurations,
			treasury = treasury,
		},
	})
	self.host.events:connect(function(name: string, event: any)
		if name == "MatchPhaseChanged" or name == "CountdownChanged" then
			self.phaseChanged:fire(self:getPhase(), { endsAt = self:getEndsAt() })
		end
	end)
	self.host:start()
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
	if self.host then
		self.host:destroy()
	end
	self.phaseChanged:disconnectAll()
end

return Def
