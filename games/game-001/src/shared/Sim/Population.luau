--!strict
--[[
	Sim/Population — the generated starting population of one kingdom (CONTRACTS G13.2, FL-0078,
	design/living-kingdom.md §1). Pure and deterministic: no instances, no services, no clock, no
	global randomness. The content tables (Content/Names, Traits, Occupations in the generated shape of
	content/SPEC.md §7) are passed in, so specs use fixtures and CitizenService the real library.

	Randomness is an own MINSTD stream (Park–Miller: x ← 48271·x mod 2^31−1) seeded from a hash of
	(seed, kingdomId, aspect). So: the same seed gives the same people, in Studio and in Lune alike;
	kingdoms of one match get different people; and each aspect (households, names, traits,
	chemistry, relations, looks) has its own stream, so changing one does not reshuffle the others.

	API
		Population.generate(seed, kingdomId, jobs, content, options?): { Citizen }
			jobs     { [JobId]: count }, e.g. config Kingdoms.startCitizens (12 citizens in VS-1)
			content  { names = Content.Names, traits = Content.Traits, occupations = Content.Occupations }
			options  { jobOrder = Types.JOB_IDS (jobs not listed follow, sorted), rivalChance = RIVAL_CHANCE }
			Exactly Σ jobs citizens, in job order then one by one; citizen i has key "<kingdomId>:<i>".
		Population.obedience(traits, rep, content): number   -- 0..100; derived, never stored
		Population.loyaltyFor(chemistry): number              -- the starting loyalty
		Population.validate(citizens, content?): { string }   -- rule violations; {} = valid.
			                                                      Checks marked (content) need content.
		Population.LOOK_RANGES, LOOK_FIELDS, RULES, GENDERS, RIVAL_CHANCE, OBEDIENCE
	Citizen = { key, index, given, familyName, name = "<given> <familyName>",
		gender = "f" | "m" | "n" (the Names bucket given_<gender> the given name came from),
		job, occupation, keyRole?, traits, chemistry, loyalty, household (1..H),
		family / friends / rivals = { key }, look = CitizenLook }

	Rules (validate checks each one)
		- Names: given names (content) come from Names.given_<gender>, unique within the kingdom while
		  the lists last; households take distinct Names.family entries while the list lasts.
		- Occupation (content): its `job` is the citizen's job. Per job, the first citizen takes the base
		  occupation (id = job, else the first without key_role), each next one a further occupation
		  of that job once (sorted by id; a key_role at most once per kingdom), then the rest cycle
		  through the occupations without a key_role. A job no occupation runs keeps occupation = job.
		- Traits: 2 or 3 distinct ids, never an opposite pair (content). Each pick is weighted by the
		  occupation's trait_affinity (missing = 1; 0 = never, unless the citizen would otherwise end
		  up with fewer than 2).
		- Chemistry: integer −20..+20, the sum of two uniform rolls −10..+10 (most citizens near 0).
		- Loyalty (start): 50 + chemistry/4 (ContentQuery.startLoyalty), clamped 0..100, so 45..55.
		- Households: 1–4 members (odds 1:3:3:2 for sizes 1..4) over a seeded shuffle; members share
		  familyName; family = the keys of the other members.
		- Friends: 1–3, mutual, never self, never the rival; outside the household when possible.
		  A population of 1 has none.
		- Rivals: 0–1, mutual, outside the household; only in populations of 3 or more. In a seeded
		  order each citizen without a rival starts a rivalry with chance rivalChance.
		- Look: integers inside LOOK_RANGES (palette indices; FORGE-02's Kit maps them to colours and
		  hair models); household members share skin; looks are distinct within the kingdom.

	Obedience (living-kingdom §1: compliance, separate from loyalty), with rep = the ruler's
	ReputationService values (each clamped 0..100; missing = 0) and bias = Σ obedience_bias of the
	citizen's traits (unknown ids count 0):
		obedience = clamp(floor(0.5·authority + 0.5·fear + 5·bias + 0.5), 0, 100)
	It rises with authority, fear and bias. Start reputation (authority 50, fear 20) gives 35 + 5·bias.
]]

local Types = require("../Kingdom/Types")

export type CitizenLook = { skin: number, hair: number, hairColor: number, outfit: number }
export type Citizen = {
	key: string,
	index: number,
	given: string,
	familyName: string,
	name: string,
	gender: string,
	job: string,
	occupation: string,
	keyRole: string?,
	traits: { string },
	chemistry: number,
	loyalty: number,
	household: number,
	family: { string },
	friends: { string },
	rivals: { string },
	look: CitizenLook,
}
export type Content = { names: any, traits: any, occupations: any }
export type Options = { jobOrder: { string }?, rivalChance: number? }

type Range = { min: number, max: number }
type Rng = { state: number }

local Population = {}

Population.LOOK_FIELDS = table.freeze({ "skin", "hair", "hairColor", "outfit" })
Population.LOOK_RANGES = table.freeze({
	skin = table.freeze({ min = 1, max = 6 }),
	hair = table.freeze({ min = 1, max = 6 }),
	hairColor = table.freeze({ min = 1, max = 8 }),
	outfit = table.freeze({ min = 1, max = 6 }),
})
Population.RULES = table.freeze({
	traits = table.freeze({ min = 2, max = 3 }),
	chemistry = table.freeze({ min = -20, max = 20 }),
	household = table.freeze({ min = 1, max = 4 }),
	friends = table.freeze({ min = 1, max = 3 }),
	rivals = table.freeze({ min = 0, max = 1 }),
	loyaltyBase = 50,
	rivalsFromPopulation = 3,
})
Population.GENDERS = table.freeze({ "f", "m", "n" })
Population.RIVAL_CHANCE = 0.2 -- about a third of a 12-citizen kingdom ends up with a rival
Population.OBEDIENCE = table.freeze({ authority = 0.5, fear = 0.5, perBias = 5 })

local RULES = Population.RULES
local HOUSEHOLD_WEIGHTS = { 1, 3, 3, 2 } -- relative odds of household sizes 1, 2, 3, 4
local FRIEND_WEIGHTS = { 2, 2, 1 } -- relative odds of wanting 1, 2, 3 friends
local LOOK_TRIES = 16

-- ---------------------------------------------------------------- random stream
local MODULUS = 2147483647
local MULTIPLIER = 48271

local function newRng(seed: number, kingdomId: string, aspect: string): Rng
	local text = string.format("%.0f|%s|%s", seed, kingdomId, aspect)
	local h = 0
	for i = 1, #text do
		h = (h * 257 + string.byte(text, i)) % MODULUS
	end
	local rng = { state = if h == 0 then 1 else h }
	for _ = 1, 4 do
		rng.state = rng.state * MULTIPLIER % MODULUS
	end
	return rng
end

local function unit(rng: Rng): number -- [0, 1)
	rng.state = rng.state * MULTIPLIER % MODULUS
	return (rng.state - 1) / (MODULUS - 1)
end

local function int(rng: Rng, low: number, high: number): number
	return low + math.floor(unit(rng) * (high - low + 1))
end

local function weighted(rng: Rng, weights: { number }): number?
	local total = 0
	for _, w in weights do
		total += w
	end
	if total <= 0 then
		return nil
	end
	local roll = unit(rng) * total
	local last: number? = nil
	for i, w in weights do
		if w > 0 then
			roll -= w
			last = i
			if roll < 0 then
				return i
			end
		end
	end
	return last
end

local function shuffle<T>(rng: Rng, list: { T }): { T }
	for i = #list, 2, -1 do
		local j = int(rng, 1, i)
		list[i], list[j] = list[j], list[i]
	end
	return list
end

local function sequence(n: number): { number }
	local list = table.create(n)
	for i = 1, n do
		list[i] = i
	end
	return list
end

-- ---------------------------------------------------------------- content helpers
local function sortedKeys(map: { [string]: any }): { string }
	local keys = {}
	for key in map do
		table.insert(keys, key)
	end
	table.sort(keys)
	return keys
end

-- trait id -> set of its opposites, from both directions (content opposites are symmetric, SPEC §5.5)
local function oppositeSets(traits: { [string]: any }): { [string]: { [string]: boolean } }
	local sets: { [string]: { [string]: boolean } } = {}
	for id, def in traits do
		sets[id] = sets[id] or {}
		if def.opposite ~= nil then
			sets[id][def.opposite] = true
			sets[def.opposite] = sets[def.opposite] or {}
			sets[def.opposite][id] = true
		end
	end
	return sets
end

local function checkContent(content: any)
	local where = "Population.generate"
	assert(type(content) == "table", `{where}: content \{ names, traits, occupations \} required`)
	local names = content.names
	assert(type(names) == "table" and type(names.family) == "table" and #names.family > 0, `{where}: no family names`)
	local given = 0
	for _, gender in Population.GENDERS do
		given += #(names["given_" .. gender] or {})
	end
	assert(given > 0, `{where}: no given names`)
	assert(type(content.traits) == "table", `{where}: content.traits required`)
	assert(type(content.occupations) == "table", `{where}: content.occupations required`)
end

local function jobSequence(jobs: { [string]: number }, order: { string }): { string }
	local list, seen = {}, {}
	local function add(job: string)
		local count = jobs[job]
		if count == nil or seen[job] then
			return
		end
		seen[job] = true
		assert(
			type(count) == "number" and count >= 0 and count % 1 == 0,
			`Population.generate: jobs.{job} must be a whole number >= 0`
		)
		for _ = 1, count do
			table.insert(list, job)
		end
	end
	for _, job in order do
		add(job)
	end
	for _, job in sortedKeys(jobs) do
		add(job)
	end
	return list
end

-- ---------------------------------------------------------------- generation steps
local function assignOccupations(citizens: { Citizen }, occupations: { [string]: any })
	local byJob: { [string]: { string } } = {}
	for _, id in sortedKeys(occupations) do
		local job = occupations[id].job
		byJob[job] = byJob[job] or {}
		table.insert(byJob[job], id)
	end
	local takenRoles: { [string]: boolean } = {}
	local plans: { [string]: { order: { string }, plain: { string }, next: number, cycle: number } } = {}
	local function planFor(job: string)
		local ids = byJob[job]
		if ids == nil then
			return nil
		end
		if plans[job] == nil then
			local base = if table.find(ids, job) then job else nil
			for _, id in ids do
				base = base or (if occupations[id].key_role == nil then id else nil)
			end
			base = base or ids[1]
			local order, plain = { base :: string }, {}
			for _, id in ids do
				if id ~= base then
					table.insert(order, id)
				end
			end
			for _, id in order do
				if occupations[id].key_role == nil then
					table.insert(plain, id)
				end
			end
			plans[job] = { order = order, plain = if #plain > 0 then plain else ids, next = 1, cycle = 0 }
		end
		return plans[job]
	end
	for _, citizen in citizens do
		local plan = planFor(citizen.job)
		local chosen = citizen.job
		if plan then
			local picked = nil
			while picked == nil and plan.next <= #plan.order do
				local id = plan.order[plan.next]
				plan.next += 1
				local role = occupations[id].key_role
				if role == nil or not takenRoles[role] then
					picked = id
				end
			end
			if picked == nil then
				plan.cycle += 1
				picked = plan.plain[((plan.cycle - 1) % #plan.plain) + 1]
			end
			chosen = picked :: string
		end
		local def = occupations[chosen]
		citizen.occupation = chosen
		citizen.keyRole = if def then def.key_role else nil
		if citizen.keyRole then
			takenRoles[citizen.keyRole :: string] = true
		end
	end
end

local function assignHouseholds(rng: Rng, citizens: { Citizen }, familyNames: { string })
	local order = shuffle(rng, sequence(#citizens))
	local surnames = shuffle(rng, table.clone(familyNames))
	local pos, household = 1, 0
	while pos <= #order do
		local weights = {}
		for size = 1, math.min(#HOUSEHOLD_WEIGHTS, #order - pos + 1) do
			weights[size] = HOUSEHOLD_WEIGHTS[size]
		end
		local size = weighted(rng, weights) :: number
		household += 1
		local surname = surnames[((household - 1) % #surnames) + 1]
		local members = {}
		for k = pos, pos + size - 1 do
			table.insert(members, order[k])
		end
		table.sort(members)
		for _, i in members do
			local citizen = citizens[i]
			citizen.household = household
			citizen.familyName = surname
			for _, other in members do
				if other ~= i then
					table.insert(citizen.family, citizens[other].key)
				end
			end
		end
		pos += size
	end
end

local function assignNames(rng: Rng, citizens: { Citizen }, names: any)
	local used: { [string]: boolean } = {}
	for _, citizen in citizens do
		local pool: { { gender: string, given: string } } = {}
		for pass = 1, 2 do
			for _, gender in Population.GENDERS do
				for _, given in names["given_" .. gender] or {} do
					if pass == 2 or not used[given] then
						table.insert(pool, { gender = gender, given = given })
					end
				end
			end
			if #pool > 0 then
				break
			end
		end
		local pick = pool[int(rng, 1, #pool)]
		used[pick.given] = true
		citizen.gender = pick.gender
		citizen.given = pick.given
		citizen.name = `{pick.given} {citizen.familyName}`
	end
end

local function rollTraits(
	rng: Rng,
	ids: { string },
	opposites: { [string]: { [string]: boolean } },
	affinity: { [string]: number }?
): { string }
	local count = int(rng, RULES.traits.min, RULES.traits.max)
	local chosen: { string } = {}
	local blocked: { [string]: boolean } = {}
	while #chosen < count do
		local pool, weights = {}, {}
		for _, id in ids do
			local w = if affinity then affinity[id] or 1 else 1
			if not blocked[id] and w > 0 then
				table.insert(pool, id)
				table.insert(weights, w)
			end
		end
		if #pool == 0 and #chosen < RULES.traits.min then
			for _, id in ids do
				if not blocked[id] then
					table.insert(pool, id)
					table.insert(weights, 1)
				end
			end
		end
		local pick = weighted(rng, weights)
		if pick == nil then
			break
		end
		local id = pool[pick]
		table.insert(chosen, id)
		blocked[id] = true
		for other in opposites[id] or {} do
			blocked[other] = true
		end
	end
	return chosen
end

local function assignTraits(rng: Rng, citizens: { Citizen }, content: Content)
	local ids = sortedKeys(content.traits)
	local opposites = oppositeSets(content.traits)
	for _, citizen in citizens do
		local occupation = content.occupations[citizen.occupation]
		citizen.traits = rollTraits(rng, ids, opposites, if occupation then occupation.trait_affinity else nil)
	end
end

local function assignChemistry(rng: Rng, citizens: { Citizen })
	local half = RULES.chemistry.max / 2
	for _, citizen in citizens do
		citizen.chemistry = int(rng, -half, half) + int(rng, -half, half)
		citizen.loyalty = Population.loyaltyFor(citizen.chemistry)
	end
end

local function assignRelations(rng: Rng, citizens: { Citizen }, rivalChance: number)
	local n = #citizens
	local friends: { { [number]: boolean } } = {}
	local degree: { number } = {}
	local rival: { [number]: number } = {}
	for i = 1, n do
		friends[i], degree[i] = {}, 0
	end
	local function sameHousehold(i: number, j: number): boolean
		return citizens[i].household == citizens[j].household
	end
	local function canBefriend(i: number, j: number, cap: number): boolean
		return j ~= i and not friends[i][j] and rival[i] ~= j and degree[j] < cap
	end
	local function link(i: number, j: number, on: boolean)
		friends[i][j], friends[j][i] = if on then true else nil, if on then true else nil
		local step = if on then 1 else -1
		degree[i] += step
		degree[j] += step
	end
	local function candidates(i: number, cap: (number) -> number, household: boolean): { number }
		local list = {}
		for j = 1, n do
			if canBefriend(i, j, cap(j)) and sameHousehold(i, j) == household then
				table.insert(list, j)
			end
		end
		return list
	end
	local function atMost(_: number): number
		return RULES.friends.max
	end

	if n >= RULES.rivalsFromPopulation then
		for _, i in shuffle(rng, sequence(n)) do
			if rival[i] == nil and unit(rng) < rivalChance then
				local list = {}
				for j = 1, n do
					if j ~= i and rival[j] == nil and not sameHousehold(i, j) then
						table.insert(list, j)
					end
				end
				if #list > 0 then
					local j = list[int(rng, 1, #list)]
					rival[i], rival[j] = j, i
				end
			end
		end
	end

	local want: { number } = {}
	for i = 1, n do
		want[i] = weighted(rng, FRIEND_WEIGHTS) :: number
	end
	local function wanted(j: number): number
		return want[j]
	end
	for _, i in shuffle(rng, sequence(n)) do
		while degree[i] < want[i] do
			local list = candidates(i, wanted, false)
			if #list == 0 then
				break
			end
			link(i, list[int(rng, 1, #list)], true)
		end
	end
	-- nobody stays without a friend: outside the household, else inside, else take over a friendship
	-- of someone at the maximum whose friend keeps at least one other
	for i = 1, n do
		if degree[i] == 0 and n >= 2 then
			local list = candidates(i, atMost, false)
			if #list == 0 then
				list = candidates(i, atMost, true)
			end
			if #list > 0 then
				link(i, list[int(rng, 1, #list)], true)
			else
				for j = 1, n do
					if degree[i] == 0 and j ~= i and rival[i] ~= j then
						for k = 1, n do
							if friends[j][k] and k ~= i and degree[k] >= 2 then
								link(j, k, false)
								link(i, j, true)
								break
							end
						end
					end
				end
			end
		end
	end

	for i, citizen in citizens do
		for j = 1, n do
			if friends[i][j] then
				table.insert(citizen.friends, citizens[j].key)
			end
		end
		if rival[i] then
			table.insert(citizen.rivals, citizens[rival[i]].key)
		end
	end
end

local function lookKey(look: CitizenLook): string
	return `{look.skin}/{look.hair}/{look.hairColor}/{look.outfit}`
end

local function assignLooks(rng: Rng, citizens: { Citizen })
	local ranges = Population.LOOK_RANGES
	local skins: { [number]: number } = {}
	local seen: { [string]: boolean } = {}
	for _, citizen in citizens do
		skins[citizen.household] = skins[citizen.household] or int(rng, ranges.skin.min, ranges.skin.max)
		local function roll(): CitizenLook
			return {
				skin = skins[citizen.household],
				hair = int(rng, ranges.hair.min, ranges.hair.max),
				hairColor = int(rng, ranges.hairColor.min, ranges.hairColor.max),
				outfit = int(rng, ranges.outfit.min, ranges.outfit.max),
			}
		end
		local look = roll()
		for _ = 2, LOOK_TRIES do
			if not seen[lookKey(look)] then
				break
			end
			look = roll()
		end
		seen[lookKey(look)] = true
		citizen.look = look
	end
end

-- ---------------------------------------------------------------- API
-- = ContentQuery.startLoyalty (one formula, FORGE-00/FORGE-05 #46 review (d)): 50 + chemistry/4
function Population.loyaltyFor(chemistry: number): number
	return math.clamp(RULES.loyaltyBase + chemistry / 4, 0, 100)
end

function Population.obedience(traits: { string }, rep: { [string]: number }, content: Content): number
	local bias = 0
	for _, id in traits do
		local def = content.traits[id]
		if def then
			bias += def.obedience_bias or 0
		end
	end
	local w = Population.OBEDIENCE
	local authority = math.clamp(rep.authority or 0, 0, 100)
	local fear = math.clamp(rep.fear or 0, 0, 100)
	local value = w.authority * authority + w.fear * fear + w.perBias * bias
	return math.clamp(math.floor(value + 0.5), 0, 100)
end

function Population.generate(
	seed: number,
	kingdomId: string,
	jobs: { [string]: number },
	content: Content,
	options: Options?
): { Citizen }
	assert(
		type(seed) == "number" and seed == seed and math.abs(seed) ~= math.huge,
		"Population.generate: seed must be a finite number"
	)
	assert(type(kingdomId) == "string" and kingdomId ~= "", "Population.generate: kingdomId required")
	assert(type(jobs) == "table", "Population.generate: jobs { [JobId]: count } required")
	checkContent(content)
	local opts: Options = options or {}
	local citizens: { Citizen } = {}
	for i, job in jobSequence(jobs, opts.jobOrder or Types.JOB_IDS) do
		citizens[i] = {
			key = `{kingdomId}:{i}`,
			index = i,
			given = "",
			familyName = "",
			name = "",
			gender = "",
			job = job,
			occupation = job,
			keyRole = nil,
			traits = {},
			chemistry = 0,
			loyalty = Population.loyaltyFor(0),
			household = 0,
			family = {},
			friends = {},
			rivals = {},
			look = { skin = 0, hair = 0, hairColor = 0, outfit = 0 },
		}
	end
	local function stream(aspect: string): Rng
		return newRng(seed, kingdomId, aspect)
	end
	assignOccupations(citizens, content.occupations)
	assignHouseholds(stream("households"), citizens, content.names.family)
	assignNames(stream("names"), citizens, content.names)
	assignTraits(stream("traits"), citizens, content)
	assignChemistry(stream("chemistry"), citizens)
	assignRelations(stream("relations"), citizens, opts.rivalChance or Population.RIVAL_CHANCE)
	assignLooks(stream("looks"), citizens)
	return citizens
end

-- ---------------------------------------------------------------- validation
type Report = (string) -> ()

local function isInt(value: any, range: Range): boolean
	return type(value) == "number" and value % 1 == 0 and value >= range.min and value <= range.max
end

local function count(list: any): string
	return if type(list) == "table" then tostring(#list) else "no"
end

local function countIn(list: any, range: Range): boolean
	return type(list) == "table" and #list >= range.min and #list <= range.max
end

local function checkNames(c: any, report: Report, content: Content?)
	if type(c.given) ~= "string" or type(c.familyName) ~= "string" or c.name ~= `{c.given} {c.familyName}` then
		report(`name '{tostring(c.name)}' is not "<given> <familyName>"`)
	end
	if not table.find(Population.GENDERS, c.gender) then
		report(`gender '{tostring(c.gender)}' is not one of f, m, n`)
	elseif content then
		if not table.find(content.names["given_" .. c.gender] or {}, c.given) then
			report(`given name '{tostring(c.given)}' is not in Names.given_{c.gender}`)
		end
		if not table.find(content.names.family, c.familyName) then
			report(`family name '{tostring(c.familyName)}' is not in Names.family`)
		end
	end
end

local function checkOccupation(c: any, report: Report, content: Content?)
	if type(c.job) ~= "string" or type(c.occupation) ~= "string" then
		report("job and occupation must be strings")
		return
	end
	if content == nil then
		return
	end
	local def = content.occupations[c.occupation]
	if def then
		if def.job ~= c.job then
			report(`occupation '{c.occupation}' runs job '{def.job}', not '{c.job}'`)
		end
		if c.keyRole ~= def.key_role then
			report(`keyRole '{tostring(c.keyRole)}' differs from occupation '{c.occupation}'`)
		end
		return
	end
	for _, id in sortedKeys(content.occupations) do
		if content.occupations[id].job == c.job then
			report(`occupation '{c.occupation}' is unknown although '{id}' runs job '{c.job}'`)
			return
		end
	end
	if c.occupation ~= c.job then
		report(`occupation '{c.occupation}' is unknown (the fallback is the job '{c.job}')`)
	end
end

local function checkTraits(c: any, report: Report, content: Content?, opposites: { [string]: { [string]: boolean } })
	if not countIn(c.traits, RULES.traits) then
		report(`has {count(c.traits)} traits (2–3 required)`)
		return
	end
	for i, id in c.traits do
		if table.find(c.traits, id) ~= i then
			report(`trait '{tostring(id)}' appears twice`)
		end
		if content and content.traits[id] == nil then
			report(`trait '{tostring(id)}' is unknown`)
		end
		for j = i + 1, #c.traits do
			if opposites[id] and opposites[id][c.traits[j]] then
				report(`traits '{id}' and '{c.traits[j]}' are opposites`)
			end
		end
	end
end

local function checkNumbers(c: any, report: Report)
	if not isInt(c.chemistry, RULES.chemistry) then
		report(`chemistry {tostring(c.chemistry)} is not an integer in -20..20`)
	elseif c.loyalty ~= Population.loyaltyFor(c.chemistry) then
		report(`loyalty {tostring(c.loyalty)} is not 50 + chemistry/4 ({Population.loyaltyFor(c.chemistry)})`)
	end
	if type(c.look) ~= "table" then
		report("has no look")
		return
	end
	for _, field in Population.LOOK_FIELDS do
		local range = Population.LOOK_RANGES[field]
		if not isInt(c.look[field], range) then
			report(`look.{field} {tostring(c.look[field])} is outside {range.min}..{range.max}`)
		end
	end
end

-- friends ("friends") or rivals ("rivals"): existing, not self, listed once, mutual
local function checkLinks(c: any, report: Report, byKey: { [string]: any }, field: string, range: Range)
	local keys = c[field]
	if not countIn(keys, range) then
		report(`has {count(keys)} {field} ({range.min}–{range.max} required)`)
	end
	for i, key in if type(keys) == "table" then keys else {} do
		local other = byKey[key]
		if key == c.key then
			report(`is in their own {field}`)
		elseif other == nil then
			report(`{field}: '{tostring(key)}' does not exist`)
		elseif table.find(keys, key) ~= i then
			report(`{field}: '{key}' is listed twice`)
		elseif type(other[field]) ~= "table" or not table.find(other[field], c.key) then
			report(`{field}: '{key}' is not mutual`)
		end
	end
end

local function checkRelations(c: any, report: Report, byKey: { [string]: any }, total: number)
	local friends = if total >= 2 then RULES.friends else { min = 0, max = RULES.friends.max }
	checkLinks(c, report, byKey, "friends", friends)
	checkLinks(c, report, byKey, "rivals", RULES.rivals)
	if type(c.friends) ~= "table" or type(c.rivals) ~= "table" then
		return
	end
	for _, key in c.rivals do
		if table.find(c.friends, key) then
			report(`'{tostring(key)}' is both friend and rival`)
		end
		local other = byKey[key]
		if other and other ~= c and other.household == c.household then
			report(`rival '{key}' is in the same household`)
		end
	end
end

local function checkHouseholds(citizens: { any }, reportFor: (any, string) -> ())
	local members: { [number]: { any } } = {}
	for _, c in citizens do
		if type(c.household) ~= "number" then
			reportFor(c, "has no household")
		else
			members[c.household] = members[c.household] or {}
			table.insert(members[c.household], c)
		end
	end
	for household, list in members do
		if not countIn(list, RULES.household) then
			reportFor(list[1], `household {household} has {#list} members (1–4 allowed)`)
		end
		for _, c in list do
			if c.familyName ~= list[1].familyName then
				reportFor(c, `family name '{tostring(c.familyName)}' differs from household {household}`)
			end
			local family = if type(c.family) == "table" then c.family else {}
			local others = 0
			for _, other in list do
				if other ~= c then
					others += 1
					if not table.find(family, other.key) then
						reportFor(c, `family misses household member '{tostring(other.key)}'`)
					end
				end
			end
			if #family ~= others then
				reportFor(c, `family lists {#family} keys; the household has {others} other members`)
			end
		end
	end
end

function Population.validate(citizens: { any }, content: Content?): { string }
	local problems: { string } = {}
	local function reportFor(c: any, message: string)
		table.insert(problems, `{tostring(c.key)}: {message}`)
	end
	local byKey: { [string]: any } = {}
	for _, c in citizens do
		if type(c.key) ~= "string" or c.key == "" or byKey[c.key] then
			reportFor(c, "key is missing or not unique")
		else
			byKey[c.key] = c
		end
	end
	local opposites = if content then oppositeSets(content.traits) else {}
	local names, looks, roles = {}, {}, {}
	for _, c in citizens do
		local function report(message: string)
			reportFor(c, message)
		end
		checkNames(c, report, content)
		checkOccupation(c, report, content)
		checkTraits(c, report, content, opposites)
		checkNumbers(c, report)
		checkRelations(c, report, byKey, #citizens)
		for _, entry in
			{
				{ "name", if type(c.name) == "string" then c.name else nil, names },
				{ "key role", c.keyRole, roles },
				{ "look", if type(c.look) == "table" then lookKey(c.look) else nil, looks },
			}
		do
			local what, value, seen = entry[1], entry[2], entry[3]
			if value ~= nil and seen[value] then
				report(`{what} '{value}' is not unique`)
			elseif value ~= nil then
				seen[value] = true
			end
		end
	end
	checkHouseholds(citizens, reportFor)
	return problems
end

return table.freeze(Population)
