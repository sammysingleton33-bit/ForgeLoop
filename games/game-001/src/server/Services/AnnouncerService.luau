--!strict
--[[
	AnnouncerService (game-001, FORGE-04, FL-0062; CONTRACTS G11): turns G9 events into kingdom-scoped
	moments for each player and sends them through `Feedback.Moment` (Feedback/Remotes.luau).
	The audience and the payload come from Feedback/Moments (pure); the client controllers decide how
	to present them (AnnouncerController: toasts and celebrations; FeedbackController: sounds and
	effects at the position; MusicController: phase music).

	Dependencies: RemoteService (framework). Optional, found in start(): KingdomService (G3) for
	members, kingdom names and each player's kingdom. Without it only the joiner and every-player
	moments go out (phases, match end), and kingdom-scoped events reach nobody (logged once).
	AnalyticsService (interfaces §8), optional: a sent moment that celebrates (Moments.present) logs
	CelebrationShown (kind) for that player, here on the server at the G9 event and never on a client's
	report (FORGE-00's review M3). Studio samples (fx.announce) log nothing.

	Studio only (Debug/DebugCommands, FL-0068): `fx.announce <kind>` sends a sample moment to the
	presser; `fx.burst` sends six notices at once (roblox/studio-tests/experience.md E7).

		AnnouncerService.sent: { number }   -- per-kind counters (specs, debug)
]]

local DebugCommands = require("@game/ReplicatedStorage/Forge/Debug/DebugCommands")
local GameEvents = require("@game/ReplicatedStorage/Forge/Contracts/GameEvents")
local Validate = require("@game/ReplicatedStorage/Forge/Core/Validate")
local Bus = require("@game/ReplicatedStorage/Forge/Experience/Bus")
local Moments = require("@game/ReplicatedStorage/Game/Feedback/Moments")

local AnnouncerService = {}
AnnouncerService.__index = AnnouncerService

local Def = { name = "AnnouncerService", dependencies = { "RemoteService" } }

Def.EVENTS = table.freeze({
	"KingdomJoined",
	"BuildingPlaced",
	"BuildingCompleted",
	"BuildingUpgraded",
	"BuildingDestroyed",
	"UnitsRecruited",
	"ObjectiveCaptured",
	"MatchPhaseChanged",
	"MatchEnded",
	"ConsequenceChanged", -- FORGE-01's ConsequenceService (G9 v0.4-g10c; fired from #173)
})

-- Sample moments for `fx.announce` (Studio): one per kind a player can see.
Def.SAMPLES = table.freeze({
	kingdomFounded = { kind = "kingdomFounded", kingdom = "crimson", kingdomName = "Emberhold" },
	buildingPlaced = { kind = "buildingPlaced", buildingType = "house", actor = "You" },
	buildingCompleted = { kind = "buildingCompleted", buildingType = "farm" },
	keepUpgraded = { kind = "keepUpgraded", buildingType = "keep", level = 2 },
	unitsRecruited = { kind = "unitsRecruited", count = 3, actor = "You" },
	objectiveCaptured = { kind = "objectiveCaptured", objectiveId = "watchtower" },
	rivalCaptured = { kind = "rivalCaptured", kingdomName = "Frostmere", objectiveId = "watchtower" },
	phase = { kind = "phase", phase = "Conflict" },
	victory = { kind = "matchEnded", outcome = "won", won = true, kingdomName = "Emberhold" },
	defeat = { kind = "matchEnded", outcome = "lost", won = false, kingdomName = "Frostmere" },
	draw = { kind = "matchEnded", outcome = "draw", won = false },
	strike = { kind = "consequence", rule = "strike", on = true, occupation = "farmer", count = 4 },
	riot = { kind = "consequence", rule = "riot", on = true, count = 3, buildingType = "storehouse" },
	riotOver = { kind = "consequence", rule = "riot", on = false, buildingType = "storehouse" },
})

-- Debug commands are registered once per server (DebugCommands is module-level); they send through
-- the service that started last, so a restarted service never leaves a stale command behind.
local current: any = nil

local function titleCase(id: string): string
	return (string.gsub(id, "^%l", string.upper))
end

function Def.create(env: any, registry: any, options: { bus: any? }?)
	local opts = options or {}
	return setmetatable({
		_env = env,
		_registry = registry,
		_bus = opts.bus or GameEvents,
		_remotes = registry:get("RemoteService"),
		_connections = {},
		_warned = false,
		sent = {},
	}, AnnouncerService)
end

function Def.new(env: any, registry: any)
	return Def.create(env, registry, nil)
end

function AnnouncerService:start()
	current = self
	self._kingdoms = self._registry:find("KingdomService")
	self._analytics = self._registry:find("AnalyticsService")
	local handlers = {}
	for _, name in Def.EVENTS do
		handlers[name] = function(...)
			self:announce(name, table.pack(...))
		end
	end
	local connections, missing = Bus.connectAll(self._bus, handlers)
	self._connections = connections
	if #missing > 0 then
		self._env.log(
			"info",
			"announcer: waiting for bus events not declared yet",
			{ events = table.concat(missing, ",") }
		)
	end
	self:_registerDebug()
end

function AnnouncerService:destroy()
	Bus.disconnect(self._connections)
	if current == self then
		current = nil
	end
end

-- Sends the moments for one G9 event. Returns how many were sent.
function AnnouncerService:announce(eventName: string, args: { any }): number
	local ok, deliveries = pcall(Moments.fromEvent, eventName, args, self:_ctx())
	if not ok then
		self._env.log("warn", "announcer: could not build moments", { event = eventName, error = tostring(deliveries) })
		return 0
	end
	local count = 0
	for _, delivery in deliveries do
		if self:_send(delivery.player, delivery.moment) then
			count += 1
			self:_celebrated(delivery.player, delivery.moment)
		end
	end
	return count
end

-- CelebrationShown for a sent moment that celebrates (analytics never breaks an announcement).
function AnnouncerService:_celebrated(player: any, moment: any)
	local analytics = self._analytics
	if analytics == nil or analytics.event == nil then
		return
	end
	local ok, celebrate = pcall(function()
		return Moments.present(moment).celebrate
	end)
	if ok and type(celebrate) == "string" then
		pcall(analytics.event, analytics, player, "CelebrationShown", { kind = celebrate })
	end
end

function AnnouncerService:_send(player: any, moment: any): boolean
	local ok = pcall(function()
		self._remotes:fire("Feedback.Moment", player, moment)
	end)
	if ok then
		self.sent[moment.kind] = (self.sent[moment.kind] or 0) + 1
	end
	return ok
end

function AnnouncerService:_ctx(): any
	local env = self._env
	local kingdoms = self._kingdoms
	local function kingdom(id: any): any
		if kingdoms == nil or type(id) ~= "string" then
			return nil
		end
		local ok, value = pcall(kingdoms.getKingdom, kingdoms, id)
		return if ok and type(value) == "table" then value else nil
	end
	local function byUserId(userId: any): any
		local ok, player = pcall(function()
			return env.Players:GetPlayerByUserId(userId)
		end)
		return if ok then player else nil
	end
	return {
		all = function(): { any }
			local ok, players = pcall(function()
				return env.Players:GetPlayers()
			end)
			return if ok then players else {}
		end,
		members = function(id: any): { any }
			local value = kingdom(id)
			if value == nil then
				if kingdoms == nil and not self._warned then
					self._warned = true
					env.log("info", "announcer: no KingdomService yet; kingdom-scoped moments reach nobody")
				end
				return {}
			end
			local out = {}
			for _, userId in (if type(value.rulers) == "table" then value.rulers else {}) do
				local player = byUserId(userId)
				if player then
					table.insert(out, player)
				end
			end
			return out
		end,
		kingdomName = function(id: any): string?
			local value = kingdom(id)
			if value and type(value.name) == "string" and value.name ~= "" then
				return value.name
			end
			return if type(id) == "string" then titleCase(id) else nil
		end,
		displayName = function(player: any): string
			local ok, name = pcall(function()
				return player.DisplayName ~= "" and player.DisplayName or player.Name
			end)
			return if ok and type(name) == "string" then name else "A ruler"
		end,
		byUserId = byUserId,
		kingdomOf = function(player: any): string?
			if kingdoms == nil then
				return nil
			end
			local ok, id = pcall(kingdoms.getKingdomOf, kingdoms, player)
			return if ok and type(id) == "string" then id else nil
		end,
		-- a building's type from its world model (WorldView: BuildingId and Kind attributes)
		buildingKind = function(buildingId: any): string?
			local ok, kind = pcall(function()
				local root = env.Workspace:FindFirstChild("ForgeKingdoms")
				for _, folder in (if root then root:GetChildren() else {}) do
					local buildings = folder:FindFirstChild("Buildings")
					for _, model in (if buildings then buildings:GetChildren() else {}) do
						if model:GetAttribute("BuildingId") == buildingId then
							return model:GetAttribute("Kind")
						end
					end
				end
				return nil
			end)
			return if ok and type(kind) == "string" then kind else nil
		end,
	}
end

function AnnouncerService:_registerDebug()
	local names = {}
	for _, command in DebugCommands.list() do
		names[command.name] = true
	end
	local kinds = {}
	for kind in Def.SAMPLES do
		table.insert(kinds, kind)
	end
	table.sort(kinds)
	pcall(function()
		if not names["fx.announce"] then
			DebugCommands.register({
				name = "fx.announce",
				label = "Announce a sample moment (" .. table.concat(kinds, ", ") .. ")",
				args = { Validate.enum(kinds) },
				run = function(player, kind)
					if current == nil then
						return "no AnnouncerService running"
					end
					current:_send(player, table.clone(Def.SAMPLES[kind]))
					return `announced {kind}`
				end,
			})
		end
		if not names["fx.burst"] then
			DebugCommands.register({
				name = "fx.burst",
				label = "Six notices at once (notification stack test)",
				run = function(player)
					if current == nil then
						return "no AnnouncerService running"
					end
					for _, kind in
						{
							"buildingPlaced",
							"buildingPlaced",
							"buildingCompleted",
							"rivalCaptured",
							"unitsRecruited",
							"phase",
						}
					do
						current:_send(player, table.clone(Def.SAMPLES[kind]))
					end
					return "sent 6"
				end,
			})
		end
	end)
end

return Def
