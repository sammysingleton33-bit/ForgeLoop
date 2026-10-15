--[[
	ConsequenceService (FL-0082; living-kingdom §5, CONTRACTS G13.3/G13.4) on the real match: strikes,
	food shortage, riots, the gated rebellion and morale. Every rule needs its condition sustained (a single
	moment or decision is never enough), clears when the cause is fixed, and leaves a healthy kingdom alone.
	Obedience is under the spec's control: CitizenService.reputationOf returns `w.rep`.
]]

local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect, afterEach = T.describe, T.it, T.expect, T.afterEach

local MockEnv = require("../../../../roblox/tests/mocks/MockEnv")
local GameEvents = require("@game/ReplicatedStorage/Forge/Contracts/GameEvents")
local Loader = require("@game/ReplicatedStorage/Forge/Contracts/Loader")
local DebugCommands = require("@game/ReplicatedStorage/Forge/Debug/DebugCommands")
local EventCodec = require("@game/ReplicatedStorage/Game/Sim/EventCodec")
local Society = require("@game/ReplicatedStorage/Forge/Config/Society")
local Reputation = require("@game/ReplicatedStorage/Game/Kingdom/Reputation")
local KingdomRemotes = require("@game/ReplicatedStorage/Game/Kingdom/Remotes")
local MatchRemotes = require("@game/ReplicatedStorage/Game/Match/Remotes")
local SimRemotes = require("@game/ReplicatedStorage/Game/Sim/Remotes")
local TreasuryRemotes = require("@game/ReplicatedStorage/Game/Treasury/Remotes")

local function service(name)
	return require(`@game/ServerScriptService/{if name == "RemoteService" then "Forge" else "Game"}/Services/{name}`)
end

local function deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local out = {}
	for k, v in value do
		out[k] = deepCopy(v)
	end
	return out
end

-- The shipped Society config with every wait shortened (spec speed: each simulated second runs the whole
-- match). The rules read only the config, so the logic under test is the same; the specs marked "shipped"
-- run on Society itself.
local FAST = deepCopy(Society)
FAST.strike.sustainSeconds = 10
FAST.consequences.shortage.sustainSeconds = 10
FAST.consequences.shortage.every = 3
FAST.consequences.riot.sustainSeconds = 20
FAST.consequences.riot.maxSeconds = 15
FAST.consequences.riot.cooldownSeconds = 30
FAST.consequences.rebellion.sustainSeconds = 30
FAST.consequences.rebellion.cooldownSeconds = 100

local STRIKE = FAST.strike
local SHORTAGE = FAST.consequences.shortage
local RIOT = FAST.consequences.riot
local REBELLION = FAST.consequences.rebellion

local booted = {}

afterEach(function()
	for _, b in booted do
		b.registry:destroy()
		for _, entry in b.env.mock.logs do
			if entry.level == "error" then
				error(`server logged an error: {entry.message} {entry.fields and entry.fields.error or ""}`)
			end
		end
	end
	table.clear(booted)
	GameEvents.disconnectAll()
end)

-- The match with one ruler seated in crimson, the rules on `config` (default FAST). `extra` adds services
-- (the full kingdom stack for the integration specs); the default stack has no ReputationService, so the
-- conditions stay where a spec puts them.
local function boot(extra: { string }?, config: any?)
	local env = MockEnv.new({
		seed = 8,
		sharedModules = {
			Remotes = { Kingdom = KingdomRemotes, Match = MatchRemotes, Sim = SimRemotes, Treasury = TreasuryRemotes },
		},
	})
	local names =
		{ "RemoteService", "MatchService", "KingdomService", "CitizenService", "EntityService", "ConsequenceService" }
	for _, name in extra or {} do
		table.insert(names, name)
	end
	local definitions = {}
	for _, name in names do
		table.insert(definitions, service(name))
	end
	local registry = Loader.load(env, definitions)
	table.insert(booted, { registry = registry, env = env })
	registry:get("KingdomService").adapter = {
		partyOf = function()
			return nil
		end,
		load = function()
			return nil
		end,
		pivot = function() end,
		attach = function() end,
		onDied = function()
			return nil
		end,
		respawnDelay = function()
			return 5
		end,
	}
	local w = {
		env = env,
		registry = registry,
		service = registry:get("ConsequenceService"),
		citizens = registry:get("CitizenService"),
		changes = {},
		sent = {},
		rep = { authority = 0, fear = 0 }, -- obedience = 5 x the traits' bias: low
	}
	w.service.config = config or FAST
	w.citizens.reputationOf = function()
		return w.rep
	end
	w.service.changed:connect(function(kid, rule, on, info)
		-- where the instigator stood when the riot started (citizens keep walking afterwards)
		local instigator = if info.instigator then w.sim.citizens[info.instigator] else nil
		local at = if instigator then { x = instigator.x, z = instigator.z } else nil
		table.insert(w.changes, { kid = kid, rule = rule, on = on, info = info, at = at, t = w.sim.time })
	end)
	local entities = registry:get("EntityService")
	local send = entities.sendKingdomEvent
	entities.sendKingdomEvent = function(self, kid, event)
		table.insert(w.sent, { kid = kid, event = deepCopy(event) })
		return send(self, kid, event)
	end
	env.mock.players:add({ userId = 1 })
	env.mock:advance(1)
	w.sim = registry:get("MatchService").host.match.sim
	w.k = w.sim.kingdoms.crimson
	assert(w.sim.active and w.k.populated, "the match runs with crimson populated")
	w.k.conditions = w.k.conditions or Reputation.newConditions() -- as ReputationService does (G13.4)
	return w
end

local function changesOf(w, rule: string, on: boolean?): { any }
	local out = {}
	for _, change in w.changes do
		if change.rule == rule and (on == nil or change.on == on) then
			table.insert(out, change)
		end
	end
	return out
end

local function sentOf(w, kind: string, cue: string?): { any }
	local out = {}
	for _, entry in w.sent do
		if entry.event.type == kind and (cue == nil or entry.event.cue == cue) then
			table.insert(out, entry.event)
		end
	end
	return out
end

local function citizensOf(w): { any }
	local out = {}
	for _, id in w.k.citizenIds do
		table.insert(out, w.sim.citizens[id])
	end
	return out
end

-- The largest occupation (ties: the first by name) and its members, by id.
local function biggestOccupation(w): (string, { any })
	local groups, names = {}, {}
	for _, c in citizensOf(w) do
		local occupation = c.profile.occupation
		if groups[occupation] == nil then
			groups[occupation] = {}
			table.insert(names, occupation)
		end
		table.insert(groups[occupation], c)
	end
	table.sort(names)
	local best = names[1]
	for _, name in names do
		if #groups[name] > #groups[best] then
			best = name
		end
	end
	table.sort(groups[best], function(a, b)
		return a.id < b.id
	end)
	assert(#groups[best] >= 2, "an occupation with at least two citizens")
	return best, groups[best]
end

local function aggrieve(c, loyalty: number?)
	c.loyalty = loyalty or 10
	c.pinned = { pay_refused = true }
	c.profile.traits = {} -- no obedience bias: obedience 0 with w.rep
end

local function idsOf(list: { any }): { number }
	local out = {}
	for i, c in list do
		out[i] = c.id
	end
	table.sort(out)
	return out
end

local function sorted(ids: { number }): { number }
	local out = table.clone(ids)
	table.sort(out)
	return out
end

-- Everyone content: no instigator, nobody disloyal.
local function content(w)
	for _, c in citizensOf(w) do
		c.loyalty = 60
	end
end

local function finishedBuilding(w, kind: string, dx: number, dz: number): any
	local keep = w.sim.buildings[w.k.keepId]
	local b = w.sim:_createBuilding(w.k, kind, keep.x + dx, keep.z + dz) -- scenario setup: no cost
	w.sim:_completeInstantly(b)
	return b
end

-- the riot target the rule must pick: the nearest finished building other than the keep (ties: lowest id)
local function nearestTarget(w, from): any
	local best, bestD = nil, math.huge
	for _, bid in w.k.buildingIds do
		local b = w.sim.buildings[bid]
		if not b.destroyed and b.level >= 1 and b.id ~= w.k.keepId then
			local d = (b.x - from.x) ^ 2 + (b.z - from.z) ^ 2
			if d < bestD or (d == bestD and b.id < best.id) then
				best, bestD = b, d
			end
		end
	end
	return best
end

describe("ConsequenceService: strikes (G13.3 strike events)", function()
	it("(shipped config) an occupation aggrieved for strike.sustainSeconds strikes, not a moment before", function()
		local w = boot(nil, Society)
		local occupation, members = biggestOccupation(w)
		local need = math.ceil(#members * Society.strike.shareOfOccupation)
		local strikers = table.move(members, 1, need, 1, {})
		for _, c in strikers do
			aggrieve(c)
		end
		w.env.mock:advance(Society.strike.sustainSeconds - 2)
		expect(#changesOf(w, "strike")).toBe(0)
		for _, c in strikers do
			expect(w.sim:isStriking(c)).toBe(false)
		end
		w.env.mock:advance(3)
		local started = changesOf(w, "strike", true)
		expect(#started).toBe(1)
		expect(started[1].kid).toBe("crimson")
		expect(started[1].info.occupation).toBe(occupation)
		expect(sorted(started[1].info.entityIds)).toEqual(idsOf(strikers))
		for _, c in strikers do
			expect(w.sim:isStriking(c)).toBe(true)
		end
		for i = need + 1, #members do
			expect(w.sim:isStriking(members[i])).toBe(false) -- the content colleagues keep working
		end
		expect(sorted(w.service:active("crimson").strike[occupation])).toEqual(idsOf(strikers))
		-- the strike_placard cue lists exactly the strikers (G13.3)
		local placards = sentOf(w, "kcue", "strike_placard")
		expect(#placards).toBe(1)
		expect(sorted(placards[1].entityIds)).toEqual(idsOf(strikers))
		w.env.mock:advance(30)
		expect(#changesOf(w, "strike", true)).toBe(1) -- one start, not one per check
		for _, c in strikers do
			expect(w.sim:isStriking(c)).toBe(true) -- held off work while it lasts
		end
	end)

	it("a break in the grievance starts the wait over: a single moment never strikes", function()
		local w = boot()
		local _, members = biggestOccupation(w)
		local need = math.ceil(#members * STRIKE.shareOfOccupation)
		local function setAll(loyalty)
			for i = 1, need do
				aggrieve(members[i], loyalty)
			end
		end
		setAll(10)
		w.env.mock:advance(STRIKE.sustainSeconds - 10)
		setAll(STRIKE.loyaltyBelow) -- loyal enough for a moment
		w.env.mock:advance(2)
		setAll(10)
		w.env.mock:advance(STRIKE.sustainSeconds - 10)
		expect(#changesOf(w, "strike")).toBe(0) -- 2 x (sustain - 10) aggrieved, but not without a break
		w.env.mock:advance(12)
		expect(#changesOf(w, "strike", true)).toBe(1)
	end)

	it("ends when the strikers' mean loyalty rises above endLoyaltyAbove; they work again within two checks", function()
		local w = boot()
		local occupation, members = biggestOccupation(w)
		local need = math.ceil(#members * STRIKE.shareOfOccupation)
		for i = 1, need do
			aggrieve(members[i])
		end
		w.env.mock:advance(STRIKE.sustainSeconds + 1)
		expect(#changesOf(w, "strike", true)).toBe(1)
		for i = 1, need do
			members[i].loyalty = STRIKE.endLoyaltyAbove -- at the bar: not above it
		end
		w.env.mock:advance(5)
		expect(#changesOf(w, "strike", false)).toBe(0)
		for i = 1, need do
			members[i].loyalty = STRIKE.endLoyaltyAbove + 1
		end
		w.env.mock:advance(1.5)
		local ended = changesOf(w, "strike", false)
		expect(#ended).toBe(1)
		expect(ended[1].info.occupation).toBe(occupation)
		expect(w.service:active("crimson").strike[occupation]).toBeNil()
		w.env.mock:advance(Society.consequences.tick * 2 + 0.5)
		for i = 1, need do
			expect(w.sim:isStriking(members[i])).toBe(false)
		end
	end)

	it("a striker who dies leaves the strike; when none is left the strike ends", function()
		local w = boot()
		local _, members = biggestOccupation(w)
		local need = math.ceil(#members * STRIKE.shareOfOccupation)
		local strikers = table.move(members, 1, need, 1, {})
		for _, c in strikers do
			aggrieve(c)
		end
		w.env.mock:advance(STRIKE.sustainSeconds + 1)
		w.sim:killCitizen(strikers[1], "test")
		w.env.mock:advance(1)
		if need > 1 then
			expect(#changesOf(w, "strike", false)).toBe(0)
			expect(#w.service:active("crimson").strike[strikers[2].profile.occupation]).toBe(need - 1)
		end
		for i = 2, need do
			w.sim:killCitizen(strikers[i], "test")
		end
		w.env.mock:advance(1)
		expect(#changesOf(w, "strike", false)).toBe(1)
	end)

	it("never strikes: obedient citizens, no grievance memory, or below the occupation's share", function()
		local w = boot()
		local _, members = biggestOccupation(w)
		local need = math.ceil(#members * STRIKE.shareOfOccupation)
		for i = 1, need do
			aggrieve(members[i])
		end
		w.rep = { authority = 100, fear = 100 } -- obedience 100: they grumble but stay
		w.env.mock:advance(STRIKE.sustainSeconds * 2)
		expect(#changesOf(w, "strike")).toBe(0)

		w.rep = { authority = 0, fear = 0 }
		for i = 1, need do
			members[i].pinned = { pardoned = true } -- a memory, but not a grievance
		end
		w.env.mock:advance(STRIKE.sustainSeconds * 2)
		expect(#changesOf(w, "strike")).toBe(0)

		for i = 1, need do
			aggrieve(members[i])
		end
		local below = need - 1
		for i = below + 1, need do
			members[i].loyalty = 60 -- one short of the share
		end
		w.env.mock:advance(STRIKE.sustainSeconds * 2)
		expect(#changesOf(w, "strike")).toBe(0)
	end)

	it("strikes need no kingdom conditions (without ReputationService only the strike rule applies)", function()
		local w = boot()
		w.k.conditions = nil
		w.citizens:setFedRatio("crimson", 0)
		local _, members = biggestOccupation(w)
		for i = 1, math.ceil(#members * STRIKE.shareOfOccupation) do
			aggrieve(members[i])
		end
		w.env.mock:advance(STRIKE.sustainSeconds + 1)
		expect(#changesOf(w, "strike", true)).toBe(1)
		expect(#changesOf(w, "shortage")).toBe(0) -- nothing to move without conditions
	end)

	it("with the full stack: a strike event per occupation goes on and then off (ConversationService)", function()
		local w = boot({ "ReputationService", "TreasuryService", "ProductionService", "ConversationService" })
		local occupation, members = biggestOccupation(w)
		local need = math.ceil(#members * STRIKE.shareOfOccupation)
		local strikers = table.move(members, 1, need, 1, {})
		for _, c in strikers do
			aggrieve(c)
		end
		w.env.mock:advance(STRIKE.sustainSeconds + 1)
		local on = sentOf(w, "strike")
		expect(#on).toBe(1)
		expect(on[1].on).toBe(true)
		expect(on[1].occupation).toBe(occupation)
		expect(sorted(on[1].entityIds)).toEqual(idsOf(strikers))
		for _, c in strikers do
			c.loyalty = STRIKE.endLoyaltyAbove + 5
		end
		w.env.mock:advance(5)
		local events = sentOf(w, "strike")
		local off = events[#events]
		expect(off.on).toBe(false)
		expect(sorted(off.entityIds)).toEqual(idsOf(strikers))
	end)
end)

describe("ConsequenceService: food shortage", function()
	it("fed ratio below fedBelow for sustainSeconds: conditions fall every `every` s, unrest pressure rises", function()
		local w = boot()
		local before = table.clone(w.k.conditions)
		w.citizens:setFedRatio("crimson", SHORTAGE.fedBelow - 0.1)
		w.env.mock:advance(SHORTAGE.sustainSeconds - 2)
		expect(#changesOf(w, "shortage")).toBe(0)
		expect(w.k.unrestPressure or 0).toBe(0)
		expect(w.k.conditions.happiness).toBe(before.happiness)
		w.env.mock:advance(3)
		expect(#changesOf(w, "shortage", true)).toBe(1)
		expect(w.k.unrestPressure).toBe(SHORTAGE.unrestPressure)
		expect(w.k.conditions.happiness).toBe(before.happiness + SHORTAGE.conditions.happiness)
		expect(w.k.conditions.stability).toBe(before.stability + SHORTAGE.conditions.stability)
		expect(w.service:active("crimson").shortage).toBe(true)
		w.env.mock:advance(SHORTAGE.every)
		expect(w.k.conditions.happiness).toBe(before.happiness + 2 * SHORTAGE.conditions.happiness)
		expect(w.k.unrestPressure).toBe(SHORTAGE.unrestPressure) -- pressure is added once, not per check
		-- the hungriest share grumble (their ids), plus one grumble without ids for the HUD / keep
		local grumbles = sentOf(w, "kcue", "grumble")
		expect(#grumbles).toBe(2)
		expect(#grumbles[1].entityIds).toBe(math.ceil(#w.k.citizenIds * SHORTAGE.grumbleShare))
		expect(grumbles[2].entityIds).toBeNil()
	end)

	it("holds between fedBelow and endFedAbove; ends at endFedAbove and the pressure goes", function()
		local w = boot()
		w.k.unrestPressure = 3 -- someone else's pressure (a decision) is left alone
		w.citizens:setFedRatio("crimson", 0)
		w.env.mock:advance(SHORTAGE.sustainSeconds + 1)
		expect(w.k.unrestPressure).toBe(3 + SHORTAGE.unrestPressure)
		w.citizens:setFedRatio("crimson", (SHORTAGE.fedBelow + SHORTAGE.endFedAbove) / 2)
		w.env.mock:advance(5)
		expect(#changesOf(w, "shortage", false)).toBe(0)
		w.citizens:setFedRatio("crimson", SHORTAGE.endFedAbove)
		w.env.mock:advance(1.5)
		expect(#changesOf(w, "shortage", false)).toBe(1)
		expect(w.k.unrestPressure).toBe(3)
		expect(w.service:active("crimson").shortage).toBe(false)
		local happiness = w.k.conditions.happiness
		w.env.mock:advance(SHORTAGE.every * 3)
		expect(w.k.conditions.happiness).toBe(happiness) -- no more shortage effects
	end)

	it("short dips never count, however many", function()
		local w = boot()
		for _ = 1, 4 do
			w.citizens:setFedRatio("crimson", 0)
			w.env.mock:advance(SHORTAGE.sustainSeconds - 5)
			w.citizens:setFedRatio("crimson", 1)
			w.env.mock:advance(2)
		end
		expect(#changesOf(w, "shortage")).toBe(0)
		expect(w.k.unrestPressure or 0).toBe(0)
	end)
end)

describe("ConsequenceService: riots", function()
	it(
		"(shipped config) prolonged instability with an instigator: a fire on the nearest building, rioters off work",
		function()
			local w = boot(nil, Society)
			content(w)
			finishedBuilding(w, "house", 40, 0)
			finishedBuilding(w, "farm", -60, 0)
			local citizens = citizensOf(w)
			local instigator = citizens[3]
			instigator.loyalty = Society.consequences.riot.instigatorLoyaltyBelow - 5
			local follower = citizens[5]
			follower.loyalty = Society.consequences.riot.rioterLoyaltyBelow - 1
			w.k.conditions.stability = Society.consequences.riot.stabilityBelow - 1
			w.env.mock:advance(Society.consequences.riot.sustainSeconds - 2)
			expect(#changesOf(w, "riot")).toBe(0)
			w.env.mock:advance(3)
			local started = changesOf(w, "riot", true)
			expect(#started).toBe(1)
			local target = nearestTarget(w, started[1].at)
			expect(started[1].info.buildingId).toBe(target.id)
			expect(started[1].info.instigator).toBe(instigator.id)
			expect(target.burning).toBe(true)
			local rioters = started[1].info.entityIds
			expect(rioters[1]).toBe(instigator.id)
			local expectFollowers = math.min(1, math.floor(#citizens * Society.consequences.riot.rioterShare))
			expect(#rioters).toBe(1 + expectFollowers)
			-- rioters are rioting, not striking: their own state (D-050 (1d))
			expect(w.sim:isRioting(instigator)).toBe(true)
			expect(w.sim:isStriking(instigator)).toBe(false)
			if expectFollowers == 1 then
				expect(rioters[2]).toBe(follower.id)
				expect(w.sim:isRioting(follower)).toBe(true)
				expect(w.sim:isStriking(follower)).toBe(false)
			end
			expect(w.sim:isRioting(citizens[1])).toBe(false) -- content citizens keep working
			expect(w.sim:isStriking(citizens[1])).toBe(false)
			local hp = target.hp
			w.env.mock:advance(10)
			expect(target.hp < hp).toBe(true)
			expect(#sentOf(w, "kcue", "cower")).toBe(1) -- the HUD / keep alarm
			expect(w.service:active("crimson").riot.buildingId).toBe(target.id)
		end
	)

	it("instability alone is not a riot without an instigator; it starts once someone leads it", function()
		local w = boot()
		content(w)
		finishedBuilding(w, "house", 40, 0)
		w.k.conditions.stability = 0
		w.env.mock:advance(RIOT.sustainSeconds * 2)
		expect(#changesOf(w, "riot")).toBe(0) -- nobody disloyal enough to lead it
		local instigator = citizensOf(w)[1]
		instigator.loyalty = 0
		w.env.mock:advance(1.5) -- the condition kept holding: the riot starts as soon as someone leads it
		expect(#changesOf(w, "riot", true)).toBe(1)
	end)

	it("nothing but the keep to burn: no riot, and the keep never burns", function()
		local w = boot()
		content(w)
		for _, bid in w.k.buildingIds do
			local b = w.sim.buildings[bid]
			if b.id ~= w.k.keepId then
				b.level = 0 -- only the keep is finished
			end
		end
		citizensOf(w)[1].loyalty = 0
		w.k.conditions.stability = 0
		w.env.mock:advance(RIOT.sustainSeconds * 2)
		expect(#changesOf(w, "riot")).toBe(0)
		expect(w.sim.buildings[w.k.keepId].burning).toBeNil()
	end)

	it("unrest pressure counts against stability", function()
		local w = boot()
		content(w)
		finishedBuilding(w, "house", 40, 0)
		citizensOf(w)[1].loyalty = 0
		w.k.conditions.stability = RIOT.stabilityBelow + 5
		w.env.mock:advance(RIOT.sustainSeconds + 5)
		expect(#changesOf(w, "riot")).toBe(0)
		w.k.unrestPressure = 10 -- effective stability 15
		w.env.mock:advance(RIOT.sustainSeconds + 1)
		expect(#changesOf(w, "riot", true)).toBe(1)
	end)

	it("the fire never burns below fireFloor; the riot ends after maxSeconds, then a cooldown", function()
		local w = boot()
		content(w)
		finishedBuilding(w, "house", 40, 0)
		citizensOf(w)[1].loyalty = 0
		w.k.conditions.stability = 0
		w.env.mock:advance(RIOT.sustainSeconds + 1)
		local started = changesOf(w, "riot", true)
		expect(#started).toBe(1)
		local b = w.sim.buildings[started[1].info.buildingId]
		expect(b.burning).toBe(true)
		local floor = math.ceil(b.maxHp * RIOT.fireFloor)
		b.hp = floor + 3
		w.env.mock:advance(10)
		expect(b.hp).toBe(floor)
		expect(b.destroyed).toBe(false)
		w.env.mock:advance(RIOT.maxSeconds)
		local ended = changesOf(w, "riot", false)
		expect(#ended).toBe(1)
		expect(ended[1].info.buildingId).toBe(b.id)
		expect(b.burning).toBeNil()
		expect(b.hp >= floor).toBe(true) -- the fire is out: the building starts to heal (D-050 (1c))
		-- still unstable: no new riot until the cooldown, then the full wait again
		local nextRiot = ended[1].t + RIOT.cooldownSeconds + RIOT.sustainSeconds
		w.env.mock:advance(nextRiot - w.sim.time - 3)
		expect(#changesOf(w, "riot", true)).toBe(1)
		w.env.mock:advance(5)
		expect(#changesOf(w, "riot", true)).toBe(2)
	end)

	it("ends once stability reaches endStabilityAbove; the building stops burning and rioters work again", function()
		local w = boot()
		content(w)
		finishedBuilding(w, "house", 40, 0)
		local instigator = citizensOf(w)[1]
		instigator.loyalty = 0
		w.k.conditions.stability = 0
		w.env.mock:advance(RIOT.sustainSeconds + 1)
		local started = changesOf(w, "riot", true)
		expect(#started).toBe(1)
		local b = w.sim.buildings[started[1].info.buildingId]
		w.k.conditions.stability = RIOT.endStabilityAbove - 1
		w.env.mock:advance(3)
		expect(#changesOf(w, "riot", false)).toBe(0)
		w.k.conditions.stability = RIOT.endStabilityAbove
		w.env.mock:advance(1.5)
		expect(#changesOf(w, "riot", false)).toBe(1)
		expect(b.burning).toBeNil()
		expect(w.service:active("crimson").riot).toBeNil()
		w.env.mock:advance(Society.consequences.tick * 2 + 0.5)
		expect(w.sim:isRioting(instigator)).toBe(false)
		expect(w.sim:isStriking(instigator)).toBe(false)
		local hp = b.hp
		w.env.mock:advance(20)
		expect(b.hp >= hp).toBe(true) -- no more fire damage
	end)

	it("rioters wear their own placard: a strike event marked riot names exactly them, on and off, once", function()
		local w = boot({ "ReputationService", "TreasuryService", "ProductionService", "ConversationService" })
		content(w)
		finishedBuilding(w, "house", 40, 0)
		local citizens = citizensOf(w)
		citizens[1].loyalty = 0
		citizens[2].loyalty = RIOT.rioterLoyaltyBelow - 1
		w.k.conditions.stability = 0
		w.env.mock:advance(RIOT.sustainSeconds + 1)
		local started = changesOf(w, "riot", true)
		expect(#started).toBe(1)
		local rioters = started[1].info.entityIds
		local function riotEvents(on: boolean): { any }
			local out = {}
			for _, event in sentOf(w, "strike") do
				if event.occupation == EventCodec.RIOT and event.on == on then
					table.insert(out, event)
				end
			end
			return out
		end
		local onEvents = riotEvents(true)
		expect(#onEvents).toBe(1)
		local named = table.clone(onEvents[1].entityIds)
		table.sort(named)
		local want = table.clone(rioters)
		table.sort(want)
		expect(named).toEqual(want)
		-- nobody is told they are "on strike" because of the riot
		for _, event in sentOf(w, "strike") do
			if event.occupation ~= EventCodec.RIOT and event.on then
				for _, id in event.entityIds do
					expect(table.find(rioters, id)).toBeNil()
				end
			end
		end
		expect(#riotEvents(false)).toBe(0)
		w.k.conditions.stability = RIOT.endStabilityAbove
		w.env.mock:advance(3)
		local offEvents = riotEvents(false)
		expect(#offEvents).toBe(1)
		local gone = table.clone(offEvents[1].entityIds)
		table.sort(gone)
		expect(gone).toEqual(want)
		w.env.mock:advance(10)
		expect(#riotEvents(false)).toBe(1) -- once
		expect(#riotEvents(true)).toBe(1)
	end)

	it(
		"the burning building halts while the riot lasts and heals itself afterwards, never permanently damaged",
		function()
			local w = boot()
			content(w)
			local farm = finishedBuilding(w, "farm", -60, 0)
			finishedBuilding(w, "house", 40, 0)
			citizensOf(w)[1].loyalty = 0
			w.k.conditions.stability = 0
			w.env.mock:advance(RIOT.sustainSeconds + 1)
			local started = changesOf(w, "riot", true)
			expect(#started).toBe(1)
			local b = w.sim.buildings[started[1].info.buildingId]
			expect(b.burning).toBe(true)
			local before = b.hpBeforeFire
			expect(before).toBe(b.maxHp) -- it caught fire undamaged
			w.env.mock:advance(20)
			expect(b.hp < before).toBe(true)
			-- the fire ends: from here the hit points climb back at regenPerSecond of the maximum, up to before
			w.k.conditions.stability = RIOT.endStabilityAbove
			w.env.mock:advance(3)
			expect(#changesOf(w, "riot", false)).toBe(1)
			expect(b.burning).toBeNil()
			local low = b.hp
			w.env.mock:advance(10)
			expect(b.hp > low).toBe(true)
			expect(b.hp - low <= b.maxHp * RIOT.regenPerSecond * 11 + 1e-6).toBe(true) -- slow
			local needed = (before - b.hp) / (b.maxHp * RIOT.regenPerSecond)
			w.env.mock:advance(needed + 5)
			expect(b.hp).toBe(before)
			expect(b.regenPerSecond).toBeNil()
			expect(farm.burning).toBeNil()
		end
	)
end)

describe("ConsequenceService: rebellion (gated) and morale", function()
	it("(shipped config) gated off in the slice: never fires, whatever the kingdom's state", function()
		local w = boot(nil, Society)
		expect(Society.consequences.rebellion.enabled).toBe(false)
		for _, c in citizensOf(w) do
			c.loyalty = 0
			c.profile.traits = {}
		end
		w.k.conditions.stability = 0
		local population = #w.k.citizenIds
		w.env.mock:advance(Society.consequences.rebellion.sustainSeconds + 10)
		expect(#changesOf(w, "rebellion")).toBe(0)
		expect(#w.k.citizenIds).toBe(population)
		expect(w.service._state.crimson.tracker.since.rebellion).toBeNil() -- not even tracked
	end)

	it("when enabled (VS-2/3): the disloyal leave after the sustained wait, then a cooldown", function()
		local w = boot()
		local config = deepCopy(FAST)
		config.consequences.rebellion.enabled = true
		config.consequences.riot.stabilityBelow = -1 -- keep riots out of this spec
		w.service.config = config
		local citizens = citizensOf(w)
		local need = math.ceil(#citizens * REBELLION.disloyalShareAtLeast)
		for i, c in citizens do
			c.loyalty = if i <= need then 5 else 60
			c.profile.traits = {}
		end
		w.k.conditions.stability = REBELLION.stabilityBelow - 1
		local died = {}
		w.env.mock:advance(REBELLION.sustainSeconds - 2)
		expect(#changesOf(w, "rebellion")).toBe(0)
		w.env.mock:advance(3)
		local fired = changesOf(w, "rebellion", true)
		expect(#fired).toBe(1)
		expect(#fired[1].info.entityIds).toBe(need)
		for i = 1, need do
			expect(w.sim.citizens[citizens[i].id]).toBeNil()
			table.insert(died, citizens[i].id)
		end
		expect(sorted(fired[1].info.entityIds)).toEqual(sorted(died))
		expect(w.sim.citizens[citizens[need + 1].id] ~= nil).toBe(true) -- the loyal stay
	end)

	it("when enabled, below the disloyal share or with high obedience nobody leaves", function()
		local w = boot()
		local config = deepCopy(FAST)
		config.consequences.rebellion.enabled = true
		config.consequences.riot.stabilityBelow = -1
		w.service.config = config
		local citizens = citizensOf(w)
		local need = math.ceil(#citizens * REBELLION.disloyalShareAtLeast)
		for i, c in citizens do
			c.loyalty = if i < need then 5 else 60 -- one short of the share
			c.profile.traits = {}
		end
		w.k.conditions.stability = 0
		w.env.mock:advance(REBELLION.sustainSeconds + 5)
		expect(#changesOf(w, "rebellion")).toBe(0)
		citizens[need].loyalty = 5
		w.rep = { authority = 100, fear = 100 } -- obedient: disloyal but they stay
		w.env.mock:advance(REBELLION.sustainSeconds + 5)
		expect(#changesOf(w, "rebellion")).toBe(0)
	end)

	it("moraleState follows the kingdom's morale against the config thresholds", function()
		local w = boot()
		local morale = Society.consequences.morale
		w.k.conditions.morale = morale.retreatBelow
		expect(w.service:moraleState("crimson")).toBe("steady")
		w.k.conditions.morale = morale.retreatBelow - 1
		expect(w.service:moraleState("crimson")).toBe("retreat")
		w.k.conditions.morale = morale.surrenderBelow - 1
		expect(w.service:moraleState("crimson")).toBe("surrender")
		expect(w.service:moraleState("nowhere")).toBe("surrender") -- unknown kingdom: no army to hold
	end)
end)

describe("ConsequenceService: a healthy kingdom and a new world", function()
	it("(shipped config) a fed, stable kingdom runs five minutes on the full stack without a consequence", function()
		local w = boot({ "ReputationService", "TreasuryService", "ProductionService", "ConversationService" }, Society)
		w.env.mock:advance(300)
		expect(#w.changes).toBe(0)
		expect(w.k.unrestPressure or 0).toBe(0)
		for _, bid in w.k.buildingIds do
			expect(w.sim.buildings[bid].burning).toBeNil()
		end
	end)

	it("Studio hook: debugUnrest leads to a riot after the full wait, and its pressure lifts on time", function()
		local w = boot()
		content(w)
		finishedBuilding(w, "house", 40, 0)
		w.k.conditions.stability = 60
		local ok, message = w.service:debugUnrest("crimson", 300)
		expect(ok).toBe(true)
		expect(message).toContain("crimson")
		expect(w.k.unrestPressure > 60).toBe(true)
		w.env.mock:advance(RIOT.sustainSeconds - 2)
		expect(#changesOf(w, "riot")).toBe(0) -- the rule's own wait, even for the debug hook
		w.env.mock:advance(3)
		expect(#changesOf(w, "riot", true)).toBe(1)
		w.env.mock:advance(300 - RIOT.sustainSeconds)
		expect(w.k.unrestPressure).toBe(0)
		local refused = w.service:debugUnrest("nowhere", 60)
		expect(refused).toBe(false)
		-- through the Studio command, as the presser's kingdom; the seconds are validated
		local player = w.env.mock.players:get(1)
		local ran = DebugCommands.run(player, "consequence.unrest", 60)
		expect(ran).toBe(true)
		local tooShort = DebugCommands.run(player, "consequence.unrest", 5)
		expect(tooShort).toBe(false)
		w.env.mock:advance(61)
		expect(w.k.unrestPressure).toBe(0)
	end)

	it("a new world starts every rule over", function()
		local w = boot()
		w.citizens:setFedRatio("crimson", 0)
		w.env.mock:advance(SHORTAGE.sustainSeconds + 1)
		expect(w.service:active("crimson").shortage).toBe(true)
		local match = w.registry:get("MatchService").host.match
		match:_newWorld()
		expect(w.service:active("crimson")).toEqual({ strike = {}, shortage = false })
	end)
end)
