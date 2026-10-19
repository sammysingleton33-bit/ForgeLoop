--!strict
--[[
	Feedback/Signals (game-001, FORGE-04) — who each G9 event is about, with the CONTRACTS G9
	attribution rules. Server-side resolvers for the framework's Experience/Subjects hook: game-001's
	config/Onboarding.luau and config/Analytics.luau pass `Signals.subjects` to OnboardingService and
	AnalyticsService (the framework never requires game code; the game hands the functions in).

	Attribution (CONTRACTS G9):
		"spawn" = KingdomJoined (the joining player)
		"first build placed" credits Building.placedBy
		building completions and captures credit every current member of the kingdom
	Members come from KingdomService (G3: getKingdom(id).rulers = userIds), found through ctx.registry;
	without KingdomService nobody is credited for kingdom-wide events (logged by the caller as no-ops).

	| Event              | Payload (G9)                                   | Subjects                          | info (primitives only)                       |
	| KingdomJoined      | (player, kingdomId)                            | the player                        | kingdom                                      |
	| MatchPhaseChanged  | (phase)                                        | every player                      | phase                                        |
	| BuildingPlaced     | (building, player?)                            | building.placedBy (else player)   | buildingType, level, kingdom, placedBy=true  |
	| BuildingCompleted / BuildingUpgraded / BuildingDestroyed | (building, player?) | members of building.kingdom | buildingType, level, kingdom           |
	| ResourceGathered   | (player?, kingdomId, resourceId, amount, source) | ruler: the player; citizen: members | resource, amount, source, kingdom       |
	| UnitsRecruited     | (player, kingdomId, count)                     | the player                        | count, kingdom                               |
	| CitizenAnswered    | (player, kingdomId, citizenId, decisionId, secondsOpen?) | the answering player    | kingdom, decision, secondsOpen, occupation (no ids) |
	| ObjectiveCaptured  | (objectiveId, kingdomId)                       | members of kingdomId              | objectiveId, kingdom                         |
	| KingdomEliminated  | (kingdomId, by?)                               | members of kingdomId / of by      | role = "eliminated" / "victor", kingdom, by  |
	| WarChanged         | (kingdomId, otherId, atWar, by?)               | members of both kingdoms          | role, atWar, kingdom, other (FL-0137)        |
	| SiegeChanged / RaidChanged | (kingdomId, on, { byKingdomIds, ... }) | members of kingdomId / of each attacker | role = "defender" / "attacker", on, kingdom, other |
	| MatchEnded         | ({ winner?, standings, durationSec })          | every player                      | won, durationSec, winner                     |
]]

local Signals = {}

type Subject = { player: any, info: { [string]: any } }

local function kingdomService(ctx: any): any
	local registry = ctx and ctx.registry
	if registry == nil then
		return nil
	end
	local ok, service = pcall(registry.find, registry, "KingdomService")
	return if ok then service else nil
end

-- The citizen's occupation, read through CitizenService:inspect (G13.2); nil when the service or the
-- citizen is gone (an answer whose consequence removed the citizen still counts, without it).
local function occupationOf(ctx: any, citizenId: any): string?
	local registry = ctx and ctx.registry
	if registry == nil then
		return nil
	end
	local found, citizens = pcall(registry.find, registry, "CitizenService")
	if not found or citizens == nil or citizens.inspect == nil then
		return nil
	end
	local ok, view = pcall(citizens.inspect, citizens, citizenId)
	local occupation = if ok and type(view) == "table" then view.occupation else nil
	return if type(occupation) == "string" then occupation else nil
end

-- Players currently in the kingdom (G3 rulers are userIds; players that left are skipped).
function Signals.members(ctx: any, kingdomId: any): { any }
	local service = kingdomService(ctx)
	if service == nil or type(kingdomId) ~= "string" then
		return {}
	end
	local ok, kingdom = pcall(service.getKingdom, service, kingdomId)
	if not ok or type(kingdom) ~= "table" or type(kingdom.rulers) ~= "table" then
		return {}
	end
	local out = {}
	for _, userId in kingdom.rulers do
		local player = ctx.byUserId(userId)
		if player then
			table.insert(out, player)
		end
	end
	return out
end

function Signals.kingdomOf(ctx: any, player: any): string?
	local service = kingdomService(ctx)
	if service == nil then
		return nil
	end
	local ok, id = pcall(service.getKingdomOf, service, player)
	return if ok and type(id) == "string" then id else nil
end

local function each(players: { any }, info: { [string]: any }): { Subject }
	local out = {}
	for _, player in players do
		table.insert(out, { player = player, info = table.clone(info) })
	end
	return out
end

local function buildingInfo(building: any): { [string]: any }
	if type(building) ~= "table" then
		return {}
	end
	return { buildingType = building.type, level = building.level, kingdom = building.kingdom }
end

-- WarChanged roles (G9): a declaration's kingdomId is the declarer and otherId the target; a peace's
-- kingdomId accepted what otherId proposed.
local function warRoles(atWar: boolean): (string, string)
	if atWar then
		return "declarer", "target"
	end
	return "acceptor", "proposer"
end

-- SiegeChanged and RaidChanged (G9, Sim/WarWatch): the attacked kingdom's members defend; each
-- attacking kingdom's members (byKingdomIds, once each) attack. info.other names the other side.
local function warWatch(args: { any }, ctx: any): { Subject }
	local kingdomId, on, details = args[1], args[2] == true, args[3]
	if type(kingdomId) ~= "string" then
		return {}
	end
	local attackers = if type(details) == "table" and type(details.byKingdomIds) == "table"
		then details.byKingdomIds
		else {}
	local out =
		each(Signals.members(ctx, kingdomId), { role = "defender", on = on, kingdom = kingdomId, other = attackers[1] })
	local seen = { [kingdomId] = true }
	for _, attacker in attackers do
		if type(attacker) == "string" and not seen[attacker] then
			seen[attacker] = true
			for _, subject in
				each(
					Signals.members(ctx, attacker),
					{ role = "attacker", on = on, kingdom = attacker, other = kingdomId }
				)
			do
				table.insert(out, subject)
			end
		end
	end
	return out
end

local function forMembers(args: { any }, ctx: any): { Subject }
	local building = args[1]
	if type(building) ~= "table" then
		return {}
	end
	return each(Signals.members(ctx, building.kingdom), buildingInfo(building))
end

Signals.subjects = table.freeze({
	KingdomJoined = function(args: { any }): { Subject }
		return { { player = args[1], info = { kingdom = args[2] } } }
	end,
	MatchPhaseChanged = function(args: { any }, ctx: any): { Subject }
		return each(ctx.all(), { phase = args[1] })
	end,
	BuildingPlaced = function(args: { any }, ctx: any): { Subject }
		local building = args[1]
		if type(building) ~= "table" then
			return {}
		end
		local placer = if type(building.placedBy) == "number" then ctx.byUserId(building.placedBy) else args[2]
		if placer == nil then
			return {}
		end
		local info = buildingInfo(building)
		info.placedBy = true
		return { { player = placer, info = info } }
	end,
	BuildingCompleted = forMembers,
	BuildingUpgraded = forMembers,
	BuildingDestroyed = forMembers,
	ResourceGathered = function(args: { any }, ctx: any): { Subject }
		local info = { kingdom = args[2], resource = args[3], amount = args[4], source = args[5] }
		if args[5] == "ruler" then
			return if args[1] then { { player = args[1], info = info } } else {}
		end
		return each(Signals.members(ctx, args[2]), info)
	end,
	UnitsRecruited = function(args: { any }): { Subject }
		return { { player = args[1], info = { kingdom = args[2], count = args[3] } } }
	end,
	-- G9 (D-044 (3), FL-0107): the ruler whose answer was accepted; the citizen's id stays out of info,
	-- only its occupation goes in (ConversationAnswered's field, FL-0108)
	CitizenAnswered = function(args: { any }, ctx: any): { Subject }
		local player = args[1]
		if player == nil then
			return {}
		end
		local info = {
			kingdom = args[2],
			decision = if type(args[4]) == "string" then args[4] else nil,
			secondsOpen = if type(args[5]) == "number" and args[5] == args[5] then args[5] else nil,
			occupation = occupationOf(ctx, args[3]),
		}
		return { { player = player, info = info } }
	end,
	ObjectiveCaptured = function(args: { any }, ctx: any): { Subject }
		return each(Signals.members(ctx, args[2]), { objectiveId = args[1], kingdom = args[2] })
	end,
	KingdomEliminated = function(args: { any }, ctx: any): { Subject }
		local out = each(Signals.members(ctx, args[1]), { role = "eliminated", kingdom = args[1], by = args[2] })
		for _, subject in each(Signals.members(ctx, args[2]), { role = "victor", kingdom = args[2], by = args[2] }) do
			table.insert(out, subject)
		end
		return out
	end,
	WarChanged = function(args: { any }, ctx: any): { Subject }
		local first, other, atWar = args[1], args[2], args[3] == true
		if type(first) ~= "string" or type(other) ~= "string" then
			return {}
		end
		local firstRole, otherRole = warRoles(atWar)
		local out =
			each(Signals.members(ctx, first), { role = firstRole, atWar = atWar, kingdom = first, other = other })
		for _, subject in
			each(Signals.members(ctx, other), { role = otherRole, atWar = atWar, kingdom = other, other = first })
		do
			table.insert(out, subject)
		end
		return out
	end,
	SiegeChanged = warWatch,
	RaidChanged = warWatch,
	MatchEnded = function(args: { any }, ctx: any): { Subject }
		local result = args[1]
		if type(result) ~= "table" then
			return {}
		end
		local out = {}
		for _, player in ctx.all() do
			local mine = Signals.kingdomOf(ctx, player)
			table.insert(out, {
				player = player,
				info = {
					won = mine ~= nil and mine == result.winner,
					durationSec = result.durationSec,
					winner = result.winner,
				},
			})
		end
		return out
	end,
})

return table.freeze(Signals)
