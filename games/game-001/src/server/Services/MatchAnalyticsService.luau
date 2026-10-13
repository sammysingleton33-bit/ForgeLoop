--!strict
--[[
	MatchAnalyticsService (game-001, FORGE-04, FL-0063; CONTRACTS G9, BRIEF §13): match length, outcomes
	and disconnects for the VS-1 analytics (analytics/schemas/events.md §5). The VS1 funnel itself is
	declarative (config Analytics.luau track rules + Feedback/Signals); this service covers what needs
	match state.

	G9 bus (server-only), through Experience/Bus:
		KingdomJoined(player, kingdomId)  -> who rules where (kept here, so a leaving ruler is still known
		                                     whatever order the PlayerRemoving handlers run in)
		MatchPhaseChanged(phase)          -> the current phase; Founding starts the match clock; the last
		                                     playing phase before Results is the phase the match was decided in
		MatchEnded({ winner?, standings, durationSec })
		    -> AnalyticsService:event(player, "MatchEnded", { durationSec, won, phase, mode }) for every ruler
		       still in the server (spectators are not counted)

		MatchAnalyticsService:leftInfo(player) -> { phase, minute }?
		    config Analytics.session.leftInfo calls it when a session ends; AnalyticsService then logs
		    PhaseLeft (before SessionEnd). nil outside a playing phase or for a spectator.
		MatchAnalyticsService.phase / .decidedPhase / .ended   -- state (specs, debug)

	Optional (registry:find in start): AnalyticsService (without it nothing is logged), MatchService
	(`mode`; "unknown" without it).
]]

local Bus = require("@game/ReplicatedStorage/Forge/Experience/Bus")
local GameEvents = require("@game/ReplicatedStorage/Forge/Contracts/GameEvents")

local MatchAnalyticsService = {}
MatchAnalyticsService.__index = MatchAnalyticsService

local Def = { name = "MatchAnalyticsService", dependencies = {} }

-- Phases in which a ruler is playing (CONTRACTS G1 MatchPhase; Arena is VS-2, G12).
Def.PLAYING = table.freeze({ Founding = true, Expansion = true, Conflict = true, Endgame = true, Arena = true })
Def.EVENTS = table.freeze({ "KingdomJoined", "MatchPhaseChanged", "MatchEnded" })

function Def.create(env: any, registry: any, options: { bus: any? }?)
	local opts = options or {}
	return setmetatable({
		_env = env,
		_registry = registry,
		_bus = opts.bus or GameEvents,
		_connections = {},
		_kingdomOf = {} :: { [number]: string },
		_startedAt = nil :: number?,
		phase = nil :: string?,
		decidedPhase = nil :: string?,
		ended = 0,
	}, MatchAnalyticsService)
end

function Def.new(env: any, registry: any)
	return Def.create(env, registry, nil)
end

function MatchAnalyticsService:start()
	local registry = self._registry
	self._analytics = registry:find("AnalyticsService")
	self._match = registry:find("MatchService")
	local connections, missing = Bus.connectAll(self._bus, {
		KingdomJoined = function(player, kingdomId)
			self:_joined(player, kingdomId)
		end,
		MatchPhaseChanged = function(phase)
			self:_phaseChanged(phase)
		end,
		MatchEnded = function(result)
			self:_matchEnded(result)
		end,
	})
	self._connections = connections
	if #missing > 0 then
		self._env.log("info", "match analytics: waiting for bus events", { events = table.concat(missing, ",") })
	end
end

function MatchAnalyticsService:destroy()
	Bus.disconnect(self._connections)
end

function MatchAnalyticsService:leftInfo(player: any): { [string]: any }?
	local phase = self.phase
	if phase == nil or not Def.PLAYING[phase] or self._startedAt == nil then
		return nil
	end
	local ok, userId = pcall(function()
		return player.UserId
	end)
	if not ok or self._kingdomOf[userId] == nil then
		return nil -- a spectator
	end
	return { phase = phase, minute = math.floor((self._env.clock() - self._startedAt) / 60) }
end

-- ------------------------------------------------------------------ internals

function MatchAnalyticsService:_joined(player: any, kingdomId: any)
	local ok, userId = pcall(function()
		return player.UserId
	end)
	if ok and type(userId) == "number" and type(kingdomId) == "string" then
		self._kingdomOf[userId] = kingdomId
	end
end

function MatchAnalyticsService:_phaseChanged(phase: any)
	if type(phase) ~= "string" then
		return
	end
	self.phase = phase
	if phase == "Founding" then
		self._startedAt = self._env.clock()
		self.decidedPhase = phase
		self:_forgetDeparted()
	elseif Def.PLAYING[phase] then
		self.decidedPhase = phase
	end
end

function MatchAnalyticsService:_matchEnded(result: any)
	if type(result) ~= "table" then
		return
	end
	self.ended += 1
	local analytics = self._analytics
	if analytics == nil then
		return
	end
	local mode = self._match and self._match.mode
	local fields = {
		durationSec = result.durationSec,
		phase = self.decidedPhase or "unknown",
		mode = if type(mode) == "string" then mode else "unknown",
	}
	local ok, players = pcall(function()
		return self._env.Players:GetPlayers()
	end)
	for _, player in (if ok then players else {}) do
		local kingdomId = self._kingdomOf[player.UserId]
		if kingdomId ~= nil then
			local own = table.clone(fields)
			own.won = kingdomId == result.winner
			analytics:event(player, "MatchEnded", own)
		end
	end
end

-- Rulers who left the server no longer need a kingdom entry (a new match starts at Founding).
function MatchAnalyticsService:_forgetDeparted()
	local players = self._env.Players
	for userId in self._kingdomOf do
		local ok, player = pcall(players.GetPlayerByUserId, players, userId)
		if not ok or player == nil then
			self._kingdomOf[userId] = nil
		end
	end
end

return Def
