--!strict
--[[
	Sim/People — gives a simulation's citizens their generated identities (CONTRACTS G13.2, FL-0078).
	Pure: no instances or services. Sim/Population generates the people from the match seed and the
	content library (Content Names, Traits, Occupations); this module puts them on the simulation's
	citizens through `sim.profiler` (Sim/Simulation), so every kingdom's starting citizens get theirs
	the moment they spawn (slice mode: on the first ruler) and so does every later arrival.

	API
		People.install(sim, seed, content)    -- sets sim.profiler and profiles kingdoms already populated
			content  { names = Content.Names, traits = Content.Traits, occupations = Content.Occupations }
		People.CONTENT                         -- that table for the real content library
		People.startReputation(): { [Category]: number }   -- Content.Reputation category starts
		People.DEFAULT_LOOK: CitizenLook       -- for a citizen without a profile
	Each profiled citizen gets
		citizen.name                          "<given> <family name>" (replaces the simulation's placeholder)
		citizen.profile = { key, given, familyName, gender, occupation, keyRole?, traits, household,
		                    chemistryBase, look, family, friends, rivals }   -- relations as entity ids
		citizen.chemistry, citizen.loyalty    current values (start: rolled chemistry and
		                                      ContentQuery.startLoyalty(chemistry) = round(50 + chemistry/4))
	Starting citizens are matched to the generated people in job order, which both sides use
	(Population.generate with the catalog's jobOrder). An arrival (birth) is one more generated person
	of its job, from its own stream ("<kingdomId>#<n>"), with no family, friends or rivals yet; it is
	re-rolled until its name (and, within People.ARRIVAL_TRIES, its look) is unique in the kingdom.
]]

local ContentQuery = require("../Content/ContentQuery")
local Names = require("../Content/Names")
local Occupations = require("../Content/Occupations")
local ReputationContent = require("../Content/Reputation")
local Traits = require("../Content/Traits")
local Population = require("./Population")

local People = {}

People.CONTENT = table.freeze({ names = Names, traits = Traits, occupations = Occupations })
People.DEFAULT_LOOK = table.freeze({ skin = 1, hair = 1, hairColor = 1, outfit = 1 })

function People.startReputation(): { [string]: number }
	local out = {}
	for _, category in ContentQuery.CATEGORIES do
		local def = ReputationContent.categories[category]
		out[category] = if def then def.start else 0
	end
	return out
end

local function apply(citizen: any, person: Population.Citizen, idOf: { [string]: number })
	local function ids(keys: { string }): { number }
		local out = {}
		for _, key in keys do
			local id = idOf[key]
			if id then
				table.insert(out, id)
			end
		end
		return out
	end
	citizen.name = person.name
	citizen.profile = {
		key = person.key,
		given = person.given,
		familyName = person.familyName,
		gender = person.gender,
		occupation = person.occupation,
		keyRole = person.keyRole,
		traits = table.clone(person.traits),
		household = person.household,
		chemistryBase = person.chemistry,
		look = table.clone(person.look),
		family = ids(person.family),
		friends = ids(person.friends),
		rivals = ids(person.rivals),
	}
	citizen.chemistry = person.chemistry
	citizen.loyalty = ContentQuery.startLoyalty(person.chemistry)
end

local function jobCounts(citizens: { any }): { [string]: number }
	local counts = {}
	for _, c in citizens do
		counts[c.job] = (counts[c.job] or 0) + 1
	end
	return counts
end

local function profileStart(sim: any, seed: number, content: any, kingdom: any, citizens: { any })
	if #citizens == 0 then
		return
	end
	local people = Population.generate(seed, kingdom.id, jobCounts(citizens), content, {
		jobOrder = sim.catalog.jobOrder,
	})
	-- both lists are in job order, one by one: pair them up per job
	local queue: { [string]: { Population.Citizen } } = {}
	for _, person in people do
		queue[person.job] = queue[person.job] or {}
		table.insert(queue[person.job], person)
	end
	local idOf: { [string]: number } = {}
	local matched = {}
	for _, c in citizens do
		local person = table.remove(queue[c.job], 1)
		idOf[person.key] = c.id
		table.insert(matched, { c, person })
	end
	for _, pair in matched do
		apply(pair[1], pair[2], idOf)
	end
end

-- An arrival re-rolls (stream "<kingdomId>#<n>", then "<kingdomId>#<n>/<try>") until its full name is
-- unique among the kingdom's living citizens, and its look too when ARRIVAL_TRIES allow (FORGE-05 #61 M).
People.ARRIVAL_TRIES = 24

local function profileArrival(sim: any, seed: number, content: any, kingdom: any, citizen: any)
	local names, looks = {}, {}
	for _, id in kingdom.citizenIds do
		local other = sim.citizens[id]
		if other and other.profile then -- the arrival itself has no profile yet
			names[other.name] = true
			looks[Population.lookKey(other.profile.look)] = true
		end
	end
	local n = kingdom.stats.born
	local unique, nameOnly, last
	for try = 1, People.ARRIVAL_TRIES do
		local stream = if try == 1 then `{kingdom.id}#{n}` else `{kingdom.id}#{n}/{try}`
		last = Population.generate(seed, stream, { [citizen.job] = 1 }, content)[1]
		if not names[last.name] then
			if not looks[Population.lookKey(last.look)] then
				unique = last
				break
			end
			nameOnly = nameOnly or last
		end
	end
	local person = unique or nameOnly or last
	person.key = `{kingdom.id}:b{n}`
	apply(citizen, person, {})
end

function People.install(sim: any, seed: number, content: any)
	sim.profiler = {
		start = function(s: any, kingdom: any, citizens: { any })
			profileStart(s, seed, content, kingdom, citizens)
		end,
		birth = function(s: any, kingdom: any, citizen: any)
			profileArrival(s, seed, content, kingdom, citizen)
		end,
	}
	sim.peopleSeed = seed
	for _, kid in sim.kingdomOrder do
		local kingdom = sim.kingdoms[kid]
		if kingdom.populated then
			local citizens = {}
			for _, id in kingdom.citizenIds do
				table.insert(citizens, sim.citizens[id])
			end
			profileStart(sim, seed, content, kingdom, citizens)
		end
	end
end

return People
