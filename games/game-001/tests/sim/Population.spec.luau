--[[
	Sim/Population (FL-0078, CONTRACTS G13.2): the generated starting population. Determinism, trait
	rules, occupations, relationship symmetry, ranges, obedience and Population.validate, against a
	fixture content library in the generated shape (content/SPEC.md §7). The last test runs the real
	library (src/shared/Content) once FORGE-00's modules are on the branch.
]]
local fs = require("@lune/fs")

local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local ContentQuery = require("@game/ReplicatedStorage/Game/Content/ContentQuery")
local Population = require("@game/ReplicatedStorage/Game/Sim/Population")
local Types = require("@game/ReplicatedStorage/Game/Kingdom/Types")
local Kingdoms = require("@game/ReplicatedStorage/Forge/Config/Kingdoms")

-- ---------------------------------------------------------------- fixture content (generated shape)
local CATEGORIES = { "compassion", "honor", "competence", "courage", "authority", "fear" }

local function trait(id: string, opposite: string?, bias: number, weights: { number })
	local w = {}
	for i, category in CATEGORIES do
		w[category] = weights[i]
	end
	return {
		id = id,
		name = string.upper(string.sub(id, 1, 1)) .. string.sub(id, 2),
		description = `Fixture trait {id}.`,
		opposite = opposite,
		weights = w,
		obedience_bias = bias,
		productivity = 1,
		hunger_sensitivity = 1,
		gossip = 1,
		volatility = 1,
	}
end

local function occupation(id: string, job: string, keyRole: string?, affinity: { [string]: number })
	return { id = id, name = id, job = job, key_role = keyRole, needs = { "food", "rest" }, trait_affinity = affinity }
end

local CONTENT = {
	traits = {
		brave = trait("brave", "timid", -1, { 0, 1, 0, 2, 1, -1 }),
		timid = trait("timid", "brave", 2, { 1, 0, 1, 1, 1, -1 }),
		kind = trait("kind", "cruel", 0, { 2, 1, 0, 0, 0, -2 }),
		cruel = trait("cruel", "kind", 1, { -1, -1, 0, 1, 1, 2 }),
		honest = trait("honest", "cunning", 0, { 1, 2, 0, 0, 0, -1 }),
		cunning = trait("cunning", "honest", -1, { 0, -1, 2, 0, 0, 1 }),
		loyal = trait("loyal", "fickle", 2, { 0, 1, 0, 0, 2, 0 }),
		fickle = trait("fickle", "loyal", -1, { 0, -1, 1, 1, 0, 1 }),
		hardworking = trait("hardworking", "lazy", 1, { 0, 0, 2, 0, 1, 0 }),
		lazy = trait("lazy", "hardworking", -1, { 1, 0, -1, 0, -1, -1 }),
		proud = trait("proud", "humble", -2, { 0, 1, 1, 1, 0, -2 }),
		humble = trait("humble", "proud", 1, { 1, 0, 0, 0, 1, 0 }),
		cheerful = trait("cheerful", "grumpy", 0, { 1, 0, 0, 1, 0, -1 }),
		grumpy = trait("grumpy", "cheerful", 0, { -1, 0, 1, 0, 1, 1 }),
		devout = trait("devout", "skeptical", 1, { 1, 2, 0, 0, 1, -1 }),
		skeptical = trait("skeptical", "devout", -1, { 0, 0, 2, 0, -1, 0 }),
		stoic = trait("stoic", nil, 0, { 0, 1, 1, 1, 0, 0 }),
	},
	names = {
		given_f = { "Agnes", "Alys", "Beatrix", "Cecily", "Edith", "Elinor", "Gisela" },
		given_m = { "Aldric", "Ansel", "Bram", "Corwin", "Dunstan", "Edric", "Godwin" },
		given_n = { "Arden", "Briar", "Ellis", "Rowan", "Wren", "Sorrel" },
		family = {
			"Ashdown",
			"Birchwood",
			"Blackthorn",
			"Coldwell",
			"Dewhurst",
			"Fenwick",
			"Foxglove",
			"Hartwell",
			"Larkspur",
			"Millbrook",
			"Oakhart",
			"Redfern",
		},
	},
	occupations = {
		farmer = occupation("farmer", "farmer", nil, { hardworking = 3, humble = 2, lazy = 0 }),
		elder = occupation("elder", "farmer", "elder", { devout = 3, honest = 2, humble = 2 }),
		woodcutter = occupation("woodcutter", "woodcutter", nil, { brave = 2, hardworking = 2 }),
		miner = occupation("miner", "miner", nil, { grumpy = 2, skeptical = 2, timid = 2 }),
		builder = occupation("builder", "builder", nil, { hardworking = 3, proud = 2 }),
		blacksmith = occupation("blacksmith", "builder", "blacksmith", { honest = 1, proud = 3 }),
		hauler = occupation("hauler", "hauler", nil, { cheerful = 2, cunning = 2, hardworking = 1 }),
		healer = occupation("healer", "hauler", "healer", { kind = 3 }),
		merchant = occupation("merchant", "hauler", "merchant", { cunning = 3 }),
	},
}

local START = Kingdoms.startCitizens
local SEEDS = {}
for i = 1, 40 do
	SEEDS[i] = i * 7919
end

-- every (seed, kingdom) population of the sweep
local function sweep(): { { any } }
	local all = {}
	for _, seed in SEEDS do
		for _, kingdomId in Types.KINGDOM_IDS do
			table.insert(all, Population.generate(seed, kingdomId, START, CONTENT))
		end
	end
	return all
end
local SWEEP = sweep()

local function field(population: { any }, name: string): { any }
	local values = {}
	for i, citizen in population do
		values[i] = citizen[name]
	end
	return values
end

local function byKey(population: { any }): { [string]: any }
	local map = {}
	for _, citizen in population do
		map[citizen.key] = citizen
	end
	return map
end

local function deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in value do
		copy[k] = deepCopy(v)
	end
	return copy
end

local function total(jobs: { [string]: number }): number
	local n = 0
	for _, count in jobs do
		n += count
	end
	return n
end

describe("Population.generate", function()
	it("fills a kingdom with exactly the configured VS-1 population (Kingdoms.startCitizens = 12)", function()
		expect(total(START)).toBe(12)
		local population = Population.generate(1, "crimson", START, CONTENT)
		expect(#population).toBe(12)
		for i, citizen in population do
			expect(citizen.key).toBe(`crimson:{i}`)
			expect(citizen.index).toBe(i)
		end
		local jobs = field(population, "job")
		local expected = {}
		for _, job in Types.JOB_IDS do
			for _ = 1, START[job] or 0 do
				table.insert(expected, job)
			end
		end
		expect(jobs).toEqual(expected)
	end)

	it("makes exactly Σ jobs citizens for other sizes, each a valid population", function()
		local cases = {
			{},
			{ farmer = 1 },
			{ farmer = 1, hauler = 1 },
			{ miner = 3 },
			{ farmer = 4, woodcutter = 4, miner = 4, builder = 4, hauler = 4 },
		}
		for _, jobs in cases do
			for _, seed in { 1, 2, 3, 99 } do
				local population = Population.generate(seed, "azure", jobs, CONTENT)
				expect(#population).toBe(total(jobs))
				expect(Population.validate(population, CONTENT)).toEqual({})
			end
		end
	end)

	it("gives the identical population for the same seed and kingdom", function()
		local a = Population.generate(424242, "emerald", START, CONTENT)
		Population.generate(424242, "gold", START, CONTENT)
		Population.generate(7, "emerald", START, CONTENT)
		local b = Population.generate(424242, "emerald", START, CONTENT)
		expect(a).toEqual(b)
		expect(a).never.toBe(b)
	end)

	it("gives different names and traits for a different seed", function()
		local a = Population.generate(1, "crimson", START, CONTENT)
		local b = Population.generate(2, "crimson", START, CONTENT)
		expect(field(a, "name")).never.toEqual(field(b, "name"))
		expect(field(a, "traits")).never.toEqual(field(b, "traits"))
		local seen = {}
		for seed = 1, 30 do
			local names = table.concat(field(Population.generate(seed, "crimson", START, CONTENT), "name"), ",")
			expect(seen[names]).toBeNil()
			seen[names] = true
		end
	end)

	it("gives each kingdom of one match seed a different population", function()
		local seen = {}
		for _, kingdomId in Types.KINGDOM_IDS do
			local population = Population.generate(2026, kingdomId, START, CONTENT)
			local names = table.concat(field(population, "name"), ",")
			expect(seen[names]).toBeNil()
			seen[names] = true
		end
	end)

	it("passes validate for every seed and kingdom of the sweep", function()
		expect(#SWEEP).toBe(#SEEDS * #Types.KINGDOM_IDS)
		for _, population in SWEEP do
			expect(Population.validate(population, CONTENT)).toEqual({})
		end
	end)

	it("rejects malformed input", function()
		expect(function()
			Population.generate(0 / 0, "crimson", START, CONTENT)
		end).toThrow("seed")
		expect(function()
			Population.generate(1, "crimson", { farmer = 1.5 }, CONTENT)
		end).toThrow("jobs.farmer")
		expect(function()
			Population.generate(
				1,
				"crimson",
				START,
				{ traits = CONTENT.traits, occupations = {}, names = { family = {} } }
			)
		end).toThrow("family names")
	end)
end)

describe("Population traits", function()
	it("gives 2–3 distinct traits and never an opposite pair", function()
		local counts = { [2] = 0, [3] = 0 }
		for _, population in SWEEP do
			for _, citizen in population do
				local n = #citizen.traits
				expect(n >= 2 and n <= 3).toBe(true)
				counts[n] += 1
				for i, id in citizen.traits do
					expect(table.find(citizen.traits, id)).toBe(i)
					local opposite = CONTENT.traits[id].opposite
					if opposite then
						expect(table.find(citizen.traits, opposite)).toBeNil()
					end
				end
			end
		end
		expect(counts[2]).toBeGreaterThan(0)
		expect(counts[3]).toBeGreaterThan(0)
	end)

	it("weights traits by the occupation's trait_affinity (0 = never)", function()
		local rate = { farmer = { n = 0, hardworking = 0 }, hauler = { n = 0, hardworking = 0 } }
		for _, population in SWEEP do
			for _, citizen in population do
				if citizen.occupation == "farmer" then
					expect(table.find(citizen.traits, "lazy")).toBeNil()
				end
				local r = rate[citizen.occupation]
				if r then
					r.n += 1
					r.hardworking += if table.find(citizen.traits, "hardworking") then 1 else 0
				end
			end
		end
		-- affinity 3 (farmer) against 1 (hauler)
		expect(rate.farmer.hardworking / rate.farmer.n).toBeGreaterThan(1.5 * rate.hauler.hardworking / rate.hauler.n)
	end)

	it("still gives 2 traits when the affinities rule out all but one trait", function()
		local content = deepCopy(CONTENT)
		local affinity = {}
		for id in content.traits do
			affinity[id] = 0
		end
		affinity.loyal = 5
		content.occupations.miner.trait_affinity = affinity
		for _, seed in { 1, 2, 3, 4, 5 } do
			local population = Population.generate(seed, "gold", { miner = 6 }, content)
			for _, citizen in population do
				expect(citizen.traits[1]).toBe("loyal")
				expect(#citizen.traits >= 2).toBe(true)
			end
			expect(Population.validate(population, content)).toEqual({})
		end
	end)
end)

describe("Population occupations", function()
	it("takes the base occupation first and each key role once, matching the job", function()
		local population = Population.generate(5, "crimson", START, CONTENT)
		expect(field(population, "occupation")).toEqual({
			"farmer",
			"elder",
			"farmer",
			"woodcutter",
			"woodcutter",
			"woodcutter",
			"miner",
			"miner",
			"builder",
			"blacksmith",
			"hauler",
			"healer",
		})
		for _, citizen in population do
			expect(CONTENT.occupations[citizen.occupation].job).toBe(citizen.job)
			expect(citizen.keyRole).toBe(CONTENT.occupations[citizen.occupation].key_role)
		end
	end)

	it("cycles extra citizens through plain occupations without repeating a key role", function()
		local population = Population.generate(5, "crimson", { hauler = 6 }, CONTENT)
		expect(field(population, "occupation")).toEqual({ "hauler", "healer", "merchant", "hauler", "hauler", "hauler" })
		expect(Population.validate(population, CONTENT)).toEqual({})
	end)

	it("gives a key role to one citizen per kingdom even when two occupations share it", function()
		local content = deepCopy(CONTENT)
		content.occupations.herbalist = occupation("herbalist", "farmer", "healer", { kind = 2 })
		local population = Population.generate(5, "crimson", START, content)
		local occupations = field(population, "occupation")
		expect({ occupations[3], occupations[11], occupations[12] }).toEqual({ "herbalist", "hauler", "merchant" })
		local healers = 0
		for _, citizen in population do
			healers += if citizen.keyRole == "healer" then 1 else 0
		end
		expect(healers).toBe(1)
		expect(Population.validate(population, content)).toEqual({})
	end)

	it("keeps occupation = job when no occupation runs the job", function()
		local population = Population.generate(5, "crimson", { soldier = 2, farmer = 1 }, CONTENT)
		expect(field(population, "occupation")).toEqual({ "farmer", "soldier", "soldier" })
		expect(population[2].keyRole).toBeNil()
		expect(Population.validate(population, CONTENT)).toEqual({})
	end)
end)

describe("Population relationships", function()
	it("makes friends mutual, 1–3 each, never self and never a rival", function()
		for _, population in SWEEP do
			local map = byKey(population)
			for _, citizen in population do
				expect(#citizen.friends >= 1 and #citizen.friends <= 3).toBe(true)
				for _, key in citizen.friends do
					expect(key).never.toBe(citizen.key)
					expect(map[key]).never.toBeNil()
					expect(map[key].friends).toContain(citizen.key)
					expect(table.find(citizen.rivals, key)).toBeNil()
				end
			end
		end
	end)

	it("makes rivals mutual, 0–1 each and outside the household", function()
		local withRival, citizens = 0, 0
		for _, population in SWEEP do
			local map = byKey(population)
			for _, citizen in population do
				citizens += 1
				expect(#citizen.rivals <= 1).toBe(true)
				for _, key in citizen.rivals do
					withRival += 1
					expect(key).never.toBe(citizen.key)
					expect(map[key].rivals).toEqual({ citizen.key })
					expect(map[key].household).never.toBe(citizen.household)
				end
			end
		end
		expect(withRival).toBeGreaterThan(0)
		expect(withRival).toBeLessThan(citizens)
	end)

	it("groups households of 1–4 that share a family name; family lists the other members", function()
		local sizes = {}
		for _, population in SWEEP do
			local households = {}
			for _, citizen in population do
				households[citizen.household] = households[citizen.household] or {}
				table.insert(households[citizen.household], citizen)
			end
			local surnames = {}
			for _, members in households do
				expect(#members >= 1 and #members <= 4).toBe(true)
				sizes[#members] = true
				expect(surnames[members[1].familyName]).toBeNil()
				surnames[members[1].familyName] = true
				for _, citizen in members do
					expect(citizen.familyName).toBe(members[1].familyName)
					local others = {}
					for _, other in members do
						if other ~= citizen then
							table.insert(others, other.key)
						end
					end
					expect(citizen.family).toEqual(others)
				end
			end
		end
		expect(sizes).toEqual({ true, true, true, true })
	end)

	it("handles tiny populations: 1 citizen has no relations, 2 are friends", function()
		local one = Population.generate(3, "azure", { farmer = 1 }, CONTENT)
		expect(one[1].friends).toEqual({})
		expect(one[1].rivals).toEqual({})
		expect(Population.validate(one, CONTENT)).toEqual({})
		local two = Population.generate(3, "azure", { farmer = 2 }, CONTENT)
		expect(two[1].friends).toEqual({ "azure:2" })
		expect(two[2].friends).toEqual({ "azure:1" })
		expect(Population.validate(two, CONTENT)).toEqual({})
	end)
end)

describe("Population ranges", function()
	it("keeps chemistry an integer in −20..+20, centred, with both signs", function()
		local low, high, sum, n = math.huge, -math.huge, 0, 0
		for _, population in SWEEP do
			for _, citizen in population do
				expect(citizen.chemistry % 1).toBe(0)
				low, high = math.min(low, citizen.chemistry), math.max(high, citizen.chemistry)
				sum += citizen.chemistry
				n += 1
			end
		end
		expect(low >= -20 and high <= 20).toBe(true)
		expect(low).toBeLessThan(-8)
		expect(high).toBeGreaterThan(8)
		expect(math.abs(sum / n)).toBeLessThan(2)
	end)

	it("starts loyalty at round(50 + chemistry/4), exactly ContentQuery.startLoyalty", function()
		local cases = { [-20] = 45, [-3] = 49, [-2] = 50, [0] = 50, [1] = 50, [2] = 51, [3] = 51, [20] = 55, [30] = 55 }
		for chemistry, loyalty in cases do
			expect(Population.loyaltyFor(chemistry)).toBe(loyalty)
			expect(Population.loyaltyFor(chemistry)).toBe(ContentQuery.startLoyalty(chemistry))
		end
		for _, population in SWEEP do
			for _, citizen in population do
				expect(citizen.loyalty).toBe(Population.loyaltyFor(citizen.chemistry))
			end
		end
	end)

	it("keeps looks inside LOOK_RANGES, distinct per kingdom, skin shared per household", function()
		local ranges = Population.LOOK_RANGES
		expect(Population.LOOK_FIELDS).toEqual({ "skin", "hair", "hairColor", "outfit" })
		for _, population in SWEEP do
			local looks, skins = {}, {}
			for _, citizen in population do
				for _, name in Population.LOOK_FIELDS do
					local value = citizen.look[name]
					expect(value % 1).toBe(0)
					expect(value >= ranges[name].min and value <= ranges[name].max).toBe(true)
				end
				local key = `{citizen.look.skin}/{citizen.look.hair}/{citizen.look.hairColor}/{citizen.look.outfit}`
				expect(looks[key]).toBeNil()
				looks[key] = true
				skins[citizen.household] = skins[citizen.household] or citizen.look.skin
				expect(citizen.look.skin).toBe(skins[citizen.household])
			end
		end
	end)

	it("names citizens '<given> <familyName>' from their gender's bucket, unique per kingdom", function()
		local genders = {}
		for _, population in SWEEP do
			local names = {}
			for _, citizen in population do
				expect(citizen.name).toBe(`{citizen.given} {citizen.familyName}`)
				expect(CONTENT.names["given_" .. citizen.gender]).toContain(citizen.given)
				expect(CONTENT.names.family).toContain(citizen.familyName)
				expect(names[citizen.given]).toBeNil()
				names[citizen.given] = true
				genders[citizen.gender] = true
			end
		end
		expect(genders).toEqual({ f = true, m = true, n = true })
	end)
end)

describe("Population.obedience", function()
	local START_REP = { compassion = 50, honor = 50, competence = 50, courage = 50, authority = 50, fear = 20 }

	it("follows 0.5·authority + 0.5·fear + 5·Σ obedience_bias", function()
		expect(Population.obedience({}, START_REP, CONTENT)).toBe(35)
		expect(Population.obedience({ "loyal", "timid" }, START_REP, CONTENT)).toBe(55)
		expect(Population.obedience({ "proud", "brave" }, START_REP, CONTENT)).toBe(20)
		expect(Population.obedience({ "stoic" }, { authority = 71, fear = 0 }, CONTENT)).toBe(36) -- 35.5 rounds up
	end)

	it("stays within 0..100 at the extremes", function()
		local lowest = { "proud", "fickle", "lazy" } -- bias −4
		local highest = { "loyal", "timid", "humble" } -- bias +5
		expect(Population.obedience(lowest, { authority = 0, fear = 0 }, CONTENT)).toBe(0)
		expect(Population.obedience(highest, { authority = 100, fear = 100 }, CONTENT)).toBe(100)
		expect(Population.obedience(highest, { authority = 900, fear = 900 }, CONTENT)).toBe(100)
		expect(Population.obedience(lowest, { authority = -50, fear = -50 }, CONTENT)).toBe(0)
	end)

	it("never falls when authority, fear or the trait bias rises", function()
		local traitSets = { { "proud", "fickle" }, { "brave" }, {}, { "humble" }, { "loyal" }, { "loyal", "timid" } }
		for _, traits in traitSets do
			local previous = -1
			for value = 0, 100, 5 do
				local o = Population.obedience(traits, { authority = value, fear = 20 }, CONTENT)
				expect(o >= previous).toBe(true)
				expect(o >= 0 and o <= 100).toBe(true)
				previous = o
			end
			previous = -1
			for value = 0, 100, 5 do
				local o = Population.obedience(traits, { authority = 50, fear = value }, CONTENT)
				expect(o >= previous).toBe(true)
				previous = o
			end
		end
		local previous = -1
		for _, traits in traitSets do
			local o = Population.obedience(traits, START_REP, CONTENT)
			expect(o).toBeGreaterThan(previous)
			previous = o
		end
	end)

	it("counts unknown traits and missing reputation as 0, and is never stored on a citizen", function()
		expect(Population.obedience({ "unknown_trait" }, {}, CONTENT)).toBe(0)
		expect(Population.obedience({ "loyal" }, {}, CONTENT)).toBe(10)
		for _, citizen in SWEEP[1] do
			expect(citizen.obedience).toBeNil()
		end
	end)
end)

describe("Population.validate", function()
	local function broken(mutate: (population: { any }, map: { [string]: any }) -> ()): { string }
		local population = deepCopy(Population.generate(31, "crimson", START, CONTENT))
		mutate(population, byKey(population))
		return Population.validate(population, CONTENT)
	end

	local function expectReported(problems: { string }, fragment: string)
		local text = table.concat(problems, "\n")
		if not string.find(text, fragment, 1, true) then
			error(`expected a violation containing '{fragment}', got:\n{text}`)
		end
	end

	it("reports an opposite trait pair, a fourth trait and an unknown trait", function()
		expectReported(
			broken(function(p)
				p[1].traits = { "kind", "cruel" }
			end),
			"traits 'kind' and 'cruel' are opposites"
		)
		expectReported(
			broken(function(p)
				p[1].traits = { "kind", "loyal", "honest", "stoic" }
			end),
			"has 4 traits"
		)
		expectReported(
			broken(function(p)
				p[1].traits = { "kind", "telepathic" }
			end),
			"trait 'telepathic' is unknown"
		)
	end)

	it("reports a one-sided friendship, a self friend and a friend who is also a rival", function()
		expectReported(
			broken(function(p, map)
				local friend = map[p[1].friends[1]]
				table.remove(friend.friends, table.find(friend.friends, p[1].key))
			end),
			"is not mutual"
		)
		expectReported(
			broken(function(p)
				p[1].friends = { p[1].key }
			end),
			"crimson:1: is in their own friends"
		)
		expectReported(
			broken(function(p, map)
				local a, b = p[1], map[p[1].friends[1]]
				a.rivals, b.rivals = { b.key }, { a.key }
			end),
			"is both friend and rival"
		)
		expectReported(
			broken(function(p)
				for _, citizen in p do
					citizen.friends = {}
				end
			end),
			"has 0 friends (1–3 required)"
		)
	end)

	it("reports a one-sided rival, a household of 5 and a household that does not share a name", function()
		expectReported(
			broken(function(p)
				for _, citizen in p do
					citizen.rivals = {}
				end
				p[1].rivals = { p[12].key }
			end),
			"rivals: 'crimson:12' is not mutual"
		)
		expectReported(
			broken(function(p)
				for i = 1, 5 do
					p[i].household = 99
				end
			end),
			"household 99 has 5 members"
		)
		expectReported(
			broken(function(p)
				local a = p[1]
				for _, citizen in p do
					if #citizen.family > 0 then
						a = citizen
						break
					end
				end
				a.familyName = "Nobody"
				a.name = `{a.given} Nobody`
			end),
			"differs from household"
		)
	end)

	it("reports ranges: chemistry, the loyalty formula and look indices", function()
		expectReported(
			broken(function(p)
				p[1].chemistry = 21
			end),
			"chemistry 21 is not an integer in -20..20"
		)
		expectReported(
			broken(function(p)
				p[1].loyalty += 1
			end),
			"is not round(50 + chemistry/4)"
		)
		expectReported(
			broken(function(p)
				p[1].look.hairColor = Population.LOOK_RANGES.hairColor.max + 1
			end),
			"look.hairColor"
		)
	end)

	it("reports a wrong occupation, a mismatched name and duplicates", function()
		expectReported(
			broken(function(p)
				p[1].occupation = "miner"
			end),
			"occupation 'miner' runs job 'miner'"
		)
		expectReported(
			broken(function(p)
				p[1].name = "Somebody Else"
			end),
			'is not "<given> <familyName>"'
		)
		expectReported(
			broken(function(p)
				p[2].look = table.clone(p[1].look)
			end),
			"is not unique"
		)
	end)

	it("needs content only for the content rules", function()
		local population = deepCopy(Population.generate(31, "crimson", START, CONTENT))
		population[1].traits = { "kind", "cruel" }
		expect(Population.validate(population)).toEqual({})
		expect(#Population.validate(population, CONTENT)).toBe(1)
	end)
end)

describe("Population with the real content library", function()
	it("generates valid populations from Content/Names, Traits and Occupations when they exist", function()
		local dir = T.root .. "/games/game-001/src/shared/Content/"
		local present = 0
		for _, name in { "Names", "Traits", "Occupations" } do
			present += if fs.isFile(dir .. name .. ".luau") then 1 else 0
		end
		if present == 0 then
			return -- FORGE-00's library (FL-0083) is not on this branch yet; runs once it merges
		end
		expect(present).toBe(3)
		local content = {
			names = require("@game/ReplicatedStorage/Game/Content/Names"),
			traits = require("@game/ReplicatedStorage/Game/Content/Traits"),
			occupations = require("@game/ReplicatedStorage/Game/Content/Occupations"),
		}
		for seed = 1, 25 do
			for _, kingdomId in Types.KINGDOM_IDS do
				local population = Population.generate(seed, kingdomId, START, content)
				expect(#population).toBe(total(START))
				expect(Population.validate(population, content)).toEqual({})
				for _, citizen in population do
					local o = Population.obedience(citizen.traits, { authority = 50, fear = 20 }, content)
					expect(o >= 0 and o <= 100).toBe(true)
				end
			end
		end
	end)
end)
