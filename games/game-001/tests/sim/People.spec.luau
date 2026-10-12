--[[
	Sim/People (CONTRACTS G13.2, FL-0078): the generated people on a simulation's citizens, with the
	real content library (Content Names, Traits, Occupations).
]]

local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local F = require("./KingdomFixtures")
local ContentQuery = require("@game/ReplicatedStorage/Game/Content/ContentQuery")
local Match = require("@game/ReplicatedStorage/Game/Kingdom/Match")
local People = require("@game/ReplicatedStorage/Game/Sim/People")
local Population = require("@game/ReplicatedStorage/Game/Sim/Population")
local Simulation = require("@game/ReplicatedStorage/Game/Sim/Simulation")
local Traits = require("@game/ReplicatedStorage/Game/Content/Traits")

-- a kingdom populated after People.install (the hook path), and one populated before (install profiles it)
local function world(seed: number, populateFirst: boolean?)
	local sim = Simulation.new({ random = Random.new(3), catalog = F.catalog() })
	local crimson = sim:addKingdom({ id = "crimson", name = "Crimson", x = 0, z = 0, populate = populateFirst == true })
	local azure = sim:addKingdom({ id = "azure", name = "Azure", x = 400, z = 0, populate = false })
	People.install(sim, seed, People.CONTENT)
	sim:populate("crimson")
	sim:populate("azure")
	return sim, crimson, azure
end

local function people(sim, k)
	local out = {}
	for _, id in k.citizenIds do
		table.insert(out, sim.citizens[id])
	end
	return out
end

local function summary(sim, k)
	local out = {}
	for _, c in people(sim, k) do
		table.insert(out, { c.name, c.job, c.profile.traits, c.chemistry, c.profile.look, c.profile.family })
	end
	return out
end

describe("Sim/People (G13.2)", function()
	it("gives every starting citizen a generated identity; the same seed gives the same people", function()
		local sim, crimson = world(77)
		expect(#crimson.citizenIds).toBe(12) -- VS-1 size
		for _, c in people(sim, crimson) do
			expect(c.profile).never.toBeNil()
			expect(c.name).toBe(`{c.profile.given} {c.profile.familyName}`)
			expect(c.profile.occupation).never.toBeNil()
		end
		local again = world(77)
		expect(summary(again, again.kingdoms.crimson)).toEqual(summary(sim, crimson))
		local other = world(78)
		expect(summary(other, other.kingdoms.crimson)).never.toEqual(summary(sim, crimson))
	end)

	it("matches Population.generate for the seed, citizen by citizen in job order", function()
		local sim, crimson = world(5)
		local counts = {}
		for _, c in people(sim, crimson) do
			counts[c.job] = (counts[c.job] or 0) + 1
		end
		local generated = Population.generate(5, "crimson", counts, People.CONTENT, { jobOrder = sim.catalog.jobOrder })
		local byJob = {}
		for _, person in generated do
			byJob[person.job] = byJob[person.job] or {}
			table.insert(byJob[person.job], person)
		end
		for _, c in people(sim, crimson) do
			local person = table.remove(byJob[c.job], 1)
			expect(c.name).toBe(person.name)
			expect(c.profile.traits).toEqual(person.traits)
			expect(c.profile.look).toEqual(person.look)
			expect(c.chemistry).toBe(person.chemistry)
		end
	end)

	it("keeps the G13.2 rules: traits, households, mutual friends and rivals, chemistry, loyalty, looks", function()
		local links = 0
		for seed = 1, 10 do
			local sim, crimson = world(seed)
			local households = {}
			for _, c in people(sim, crimson) do
				households[c.profile.household] = (households[c.profile.household] or 0) + 1
			end
			for _, c in people(sim, crimson) do
				local p = c.profile
				expect(#p.family).toBe(households[p.household] - 1) -- everyone else in the household
				links += #p.family
				expect(#p.traits >= 2 and #p.traits <= 3).toBe(true)
				for _, a in p.traits do
					for _, b in p.traits do
						expect(Traits[a].opposite == b).toBe(false)
					end
				end
				expect(c.chemistry >= -20 and c.chemistry <= 20).toBe(true)
				expect(c.loyalty).toBe(ContentQuery.startLoyalty(c.chemistry))
				expect(#p.friends >= 1 and #p.friends <= 3).toBe(true)
				expect(#p.rivals <= 1).toBe(true)
				for _, id in p.family do
					local relative = sim.citizens[id]
					expect(relative.profile.familyName).toBe(p.familyName)
					expect(table.find(relative.profile.family, c.id)).never.toBeNil()
				end
				for _, id in p.friends do
					expect(table.find(sim.citizens[id].profile.friends, c.id)).never.toBeNil()
				end
				for _, id in p.rivals do
					expect(table.find(sim.citizens[id].profile.rivals, c.id)).never.toBeNil()
				end
				for field, range in Population.LOOK_RANGES do
					local v = p.look[field]
					expect(v >= range.min and v <= range.max).toBe(true)
				end
			end
		end
		expect(links > 0).toBe(true) -- households of two or more exist
	end)

	it("gives each kingdom of a match its own people, and profiles kingdoms populated before install", function()
		local sim, crimson, azure = world(9, true)
		for _, c in people(sim, crimson) do
			expect(c.profile).never.toBeNil()
		end
		local crimsonNames = {}
		for _, c in people(sim, crimson) do
			crimsonNames[c.name] = true
		end
		local shared = 0
		for _, c in people(sim, azure) do
			if crimsonNames[c.name] then
				shared += 1
			end
		end
		expect(shared < 12).toBe(true)
		expect(summary(sim, azure)).never.toEqual(summary(sim, crimson))
	end)

	it("profiles an arrival (birth) deterministically, with no relations yet", function()
		local function arrival(seed)
			local sim, crimson = world(seed)
			F.stock(sim, crimson):add("food", 2000)
			local house = sim:_createBuilding(crimson, "house", 40, 40) -- room above the keep's 12
			sim:_completeInstantly(house)
			sim:_recompute(crimson)
			sim.active = true
			local before = #crimson.citizenIds
			while #crimson.citizenIds == before and sim.time < 3600 do
				sim:advance(5)
			end
			expect(#crimson.citizenIds).toBe(before + 1)
			return sim.citizens[crimson.citizenIds[#crimson.citizenIds]]
		end
		local born = arrival(21)
		expect(born.profile).never.toBeNil()
		expect(born.profile.family).toEqual({})
		expect(born.profile.friends).toEqual({})
		expect(born.profile.rivals).toEqual({})
		expect(born.loyalty).toBe(ContentQuery.startLoyalty(born.chemistry))
		-- each arrival has its own stream: two arrivals of one job are different people
		local sim, crimson = world(21)
		local function arrive(n)
			local c = sim:_spawnCitizen(crimson, "farmer", 0, 0)
			crimson.stats.born = n
			sim.profiler.birth(sim, crimson, c)
			return c
		end
		local a, b = arrive(1), arrive(2)
		expect({ a.name, a.profile.look }).never.toEqual({ b.name, b.profile.look })
		local again = arrival(21)
		expect({ again.name, again.profile.traits, again.profile.look }).toEqual({
			born.name,
			born.profile.traits,
			born.profile.look,
		})
	end)

	it("Match: people per world from a seed drawn per world once options.people is set", function()
		local match = Match.new({
			random = Random.new(4),
			mode = "match",
			countdownSec = 1,
			now = function()
				return 1700000000
			end,
		})
		expect(match.sim.profiler).toBeNil() -- off by default
		match:setPeople(People.CONTENT)
		local first = match.sim
		expect(first.profiler).never.toBeNil()
		for _, kid in first.kingdomOrder do
			for _, id in first.kingdoms[kid].citizenIds do
				expect(first.citizens[id].profile).never.toBeNil()
			end
		end
		match:_newWorld()
		expect(match.sim).never.toBe(first)
		expect(match.sim.profiler).never.toBeNil()
		expect(match.sim.peopleSeed).never.toBe(first.peopleSeed)
	end)

	it("startReputation reads the Content category starts", function()
		local rep = People.startReputation()
		for _, category in ContentQuery.CATEGORIES do
			expect(type(rep[category])).toBe("number")
		end
		expect(Population.obedience({}, rep, People.CONTENT)).toBe(
			math.floor(0.5 * rep.authority + 0.5 * rep.fear + 0.5)
		)
	end)
end)
