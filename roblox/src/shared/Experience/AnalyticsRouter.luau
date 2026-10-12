--!strict
--[[
	Experience/AnalyticsRouter — turns server bus events (GameEvents §4 + Experience/KingdomSignals)
	into "subjects" for the analytics track rules. Pure: the caller passes a player lookup.

		Router.normalize(eventName, args: { any, n: number }, lookup) -> { Subject }
			Subject = { player: Player, info: { [string]: string | number | boolean } }
			lookup = { byUserId: (userId: number) -> Player?, all: () -> { Player } }
		Router.matches(rule, info) -> boolean          -- every rule.match entry equals info[key]
		Router.eventFields(rule, info) -> { [string]: any } -- rule.fields copied from info

	Info only keeps strings, numbers and booleans (positions, tables and Instances are dropped), so
	analytics never stores payload objects. Derived keys:
		RoundStateChanged  state, roundId, matchId                  (one subject per player in the server)
		RoundEnded         matchId, mode, placement, eliminations, survivedSec, won, completed = true,
		                   durationSec                              (one subject per participant still here)
		CurrencyChanged    currency, newBalance, delta, reason, gained (delta > 0)
		PurchaseCompleted  kind, productId, robux
		RewardRolled       tableId, rarity, itemId, pityTriggered
		kingdom events     every primitive info field + role = "actor"; the second party (KingdomSignals.OTHER_PARTY)
		                   gets the same info with role = "defender" (battle/siege) or "loser" (territory)
]]

local KingdomSignals = require("./KingdomSignals")

local Router = {}

export type Subject = { player: any, info: { [string]: any } }
export type Lookup = { byUserId: (userId: number) -> any, all: () -> { any } }

local function primitives(source: any): { [string]: any }
	local out = {}
	if type(source) ~= "table" then
		return out
	end
	for key, value in source do
		local kind = type(value)
		if type(key) == "string" and (kind == "string" or kind == "number" or kind == "boolean") then
			out[key] = value
		end
	end
	return out
end

local function isPlayer(value: any): boolean
	return typeof(value) == "Instance" and value:IsA("Player")
end

local function single(player: any, info: { [string]: any }): { Subject }
	if not isPlayer(player) then
		return {}
	end
	return { { player = player, info = info } }
end

local NORMALIZERS: { [string]: (args: { any }, lookup: Lookup) -> { Subject } } = {
	PlayerReady = function(args)
		return single(args[1], {})
	end,
	RoundStateChanged = function(args, lookup)
		local info = primitives(args[2])
		info.state = args[1]
		info.matchId = info.roundId
		local out = {}
		for _, player in lookup.all() do
			table.insert(out, { player = player, info = table.clone(info) })
		end
		return out
	end,
	PlayerEliminated = function(args)
		local info = primitives(args[2])
		info.matchId = info.roundId
		return single(args[1], info)
	end,
	RoundEnded = function(args, lookup)
		local result = args[1]
		if type(result) ~= "table" or type(result.participants) ~= "table" then
			return {}
		end
		local winners = if type(result.winners) == "table" then result.winners else {}
		local duration = if type(result.endedAt) == "number" and type(result.startedAt) == "number"
			then math.max(0, result.endedAt - result.startedAt)
			else nil
		local out = {}
		for _, participant in result.participants do
			local player = if type(participant) == "table" then lookup.byUserId(participant.userId) else nil
			if player then
				table.insert(out, {
					player = player,
					info = {
						matchId = result.roundId,
						roundId = result.roundId,
						mode = result.mode,
						placement = participant.placement,
						eliminations = participant.eliminations,
						survivedSec = participant.survivedSec,
						won = table.find(winners, participant.userId) ~= nil,
						completed = true,
						durationSec = duration,
					},
				})
			end
		end
		return out
	end,
	CurrencyChanged = function(args)
		local delta = if type(args[4]) == "number" then args[4] else 0
		return single(args[1], {
			currency = args[2],
			newBalance = args[3],
			delta = delta,
			reason = args[5],
			gained = delta > 0,
		})
	end,
	ItemGranted = function(args)
		return single(args[1], { itemId = args[2], qty = args[3], source = args[4] })
	end,
	PurchaseCompleted = function(args)
		return single(args[1], { kind = args[2], productId = args[3], robux = args[4] })
	end,
	RewardRolled = function(args)
		local info = primitives(args[3])
		info.tableId = args[2]
		return single(args[1], info)
	end,
	OnboardingStep = function(args)
		return single(args[1], { flow = args[2], step = args[3], stepName = args[4] })
	end,
	ShopViewed = function(args)
		return single(args[1], { shopId = args[2], itemId = args[3] })
	end,
}

local OTHER_ROLE = { TerritoryChanged = "loser" }

-- Did this side win? BattleEnded: winnerKingdomId; SiegeEnded: only "Breached" is an attacker win.
local function sideWon(eventName: string, info: { [string]: any }, attacker: boolean): boolean?
	if eventName == "BattleEnded" and info.winnerKingdomId ~= nil then
		local mine = if attacker then info.kingdomId else info.defenderKingdomId
		return info.winnerKingdomId == mine
	elseif eventName == "SiegeEnded" and info.outcome ~= nil then
		return (info.outcome == "Breached") == attacker
	end
	return nil
end

local function kingdomEvent(eventName: string, args: { any }, lookup: Lookup): { Subject }
	local info = primitives(args[2])
	local out = {}
	if isPlayer(args[1]) then
		local actor = table.clone(info)
		actor.role = "actor"
		actor.won = sideWon(eventName, info, true)
		table.insert(out, { player = args[1], info = actor })
	end
	local otherKey = KingdomSignals.OTHER_PARTY[eventName]
	local otherId = if otherKey then info[otherKey] else nil
	if type(otherId) == "number" then
		local other = lookup.byUserId(otherId)
		if other and other ~= args[1] then
			local copy = table.clone(info)
			copy.role = OTHER_ROLE[eventName] or "defender"
			copy.won = sideWon(eventName, info, false)
			table.insert(out, { player = other, info = copy })
		end
	end
	return out
end

function Router.normalize(eventName: string, args: { any }, lookup: Lookup): { Subject }
	local normalizer = NORMALIZERS[eventName]
	if normalizer then
		return normalizer(args, lookup)
	end
	if KingdomSignals.isProposed(eventName) then
		return kingdomEvent(eventName, args, lookup)
	end
	return {}
end

function Router.matches(rule: any, info: { [string]: any }): boolean
	if rule.match == nil then
		return true
	end
	for key, expected in rule.match do
		if info[key] ~= expected then
			return false
		end
	end
	return true
end

function Router.eventFields(rule: any, info: { [string]: any }): { [string]: any }
	local out = {}
	for _, key in rule.fields or {} do
		out[key] = info[key]
	end
	return out
end

function Router.knownEvents(bus: any): { string }
	local names = {}
	for _, name in (if type(bus) == "table" and type(bus.EVENT_NAMES) == "table" then bus.EVENT_NAMES else {}) do
		table.insert(names, name)
	end
	for _, name in KingdomSignals.PROPOSED do
		if not table.find(names, name) then
			table.insert(names, name)
		end
	end
	return names
end

return table.freeze(Router)
