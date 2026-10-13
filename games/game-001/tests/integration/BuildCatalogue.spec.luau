-- G13.5 "one source per number" (CONTRACTS, FORGE-05 finding L4; FL-0093): Costs.luau (FORGE-03) is
-- canonical for cost, build time and the number of levels; Buildings.luau (FORGE-01) holds only the
-- gameplay stats, for exactly levels 1..Costs.maxLevel(type). When the two files drift, this spec
-- fails with the full list of mismatches, so the owner gets a to-do list rather than the first diff.
local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local Buildings = require("@game/ReplicatedStorage/Forge/Config/Buildings")
local Costs = require("@game/ReplicatedStorage/Forge/Config/Costs")

-- Per-level field names that mean a Costs number under another name. `work` is Buildings' former
-- local double of `buildSeconds` (its own header said so); a cost or a time never lives in both files.
local ALIASES: { [string]: string } = { work = "buildSeconds" }

type Catalogue = { [string]: { [number]: { [string]: any } } }

local function sortedKeys(t: { [any]: any }): { any }
	local keys = {}
	for k in t do
		table.insert(keys, k)
	end
	table.sort(keys, function(a, b)
		return tostring(a) < tostring(b)
	end)
	return keys
end

-- Levels must be exactly 1..n with no holes; returns n, or nil plus the offending keys.
local function levelCount(levels: { [any]: any }): (number?, string?)
	local n = 0
	for _ in levels do
		n += 1
	end
	for i = 1, n do
		if levels[i] == nil then
			return nil, table.concat(sortedKeys(levels) :: { any }, ",")
		end
	end
	return n, nil
end

-- costs: Costs.catalogue().buildings ({ [type] = { [level] = { cost, buildSeconds } } });
-- stats: Buildings.buildings ({ [type] = { levels = { [level] = stats } } }).
local function problems(costs: Catalogue, stats: { [string]: any }): { string }
	local out = {}
	local costFields: { [string]: boolean } = {}
	for _, levels in costs do
		for _, entry in levels do
			for field in entry do
				costFields[field] = true
			end
		end
	end

	local types: { [string]: boolean } = {}
	for buildingType in costs do
		types[buildingType] = true
	end
	for buildingType in stats do
		types[buildingType] = true
	end

	for _, buildingType in sortedKeys(types) do
		local costLevels = costs[buildingType]
		local def = stats[buildingType]
		local statLevels = if type(def) == "table" then def.levels else nil
		if costLevels == nil then
			table.insert(out, `{buildingType}: in Buildings, not in Costs`)
			continue
		end
		if type(statLevels) ~= "table" then
			table.insert(out, `{buildingType}: in Costs (levels 1..{#costLevels}), not in Buildings`)
			continue
		end
		local nCost, badCost = levelCount(costLevels)
		local nStat, badStat = levelCount(statLevels)
		if nCost == nil then
			table.insert(out, `{buildingType}: Costs levels are not 1..n (keys {badCost})`)
		end
		if nStat == nil then
			table.insert(out, `{buildingType}: Buildings levels are not 1..n (keys {badStat})`)
		end
		if nCost and nStat then
			for level = nStat + 1, nCost do
				table.insert(out, `{buildingType} L{level}: in Costs, not in Buildings`)
			end
			for level = nCost + 1, nStat do
				table.insert(out, `{buildingType} L{level}: in Buildings, not in Costs`)
			end
		end
		for _, level in sortedKeys(statLevels) do
			local entry = statLevels[level]
			if type(entry) ~= "table" then
				continue
			end
			for _, field in sortedKeys(entry) do
				if costFields[field] then
					table.insert(out, `{buildingType} L{level}: Buildings repeats \`{field}\` (Costs owns it)`)
				elseif ALIASES[field] then
					table.insert(
						out,
						`{buildingType} L{level}: Buildings has \`{field}\`, a copy of Costs \`{ALIASES[field]}\``
					)
				end
			end
		end
	end
	return out
end

describe("G13.5 one source per number: Costs vs Buildings", function()
	it("the checker reports every kind of drift (self-test on synthetic data)", function()
		local costs: Catalogue = {
			hut = { { cost = { wood = 1 }, buildSeconds = 5 }, { cost = { wood = 2 }, buildSeconds = 6 } },
			gate = { { cost = { stone = 1 }, buildSeconds = 5 } },
			tower = { { cost = {}, buildSeconds = 1 } },
			pit = { [1] = { cost = {}, buildSeconds = 1 }, [3] = { cost = {}, buildSeconds = 1 } },
		}
		local stats = {
			hut = { levels = { { hp = 1, cost = { wood = 1 } }, { hp = 2, work = 6 }, { hp = 3 } } },
			tower = { levels = { { hp = 1, buildSeconds = 1 } } },
			pit = { levels = { { hp = 1 } } },
			moat = { levels = { { hp = 1 } } },
		}
		expect(problems(costs, stats)).toEqual({
			"gate: in Costs (levels 1..1), not in Buildings",
			"hut L3: in Buildings, not in Costs",
			"hut L1: Buildings repeats `cost` (Costs owns it)",
			"hut L2: Buildings has `work`, a copy of Costs `buildSeconds`",
			"moat: in Buildings, not in Costs",
			"pit: Costs levels are not 1..n (keys 1,3)",
			"tower L1: Buildings repeats `buildSeconds` (Costs owns it)",
		})
		-- And stays quiet when the files agree.
		expect(problems({ hut = { { cost = {}, buildSeconds = 1 } } }, { hut = { levels = { { hp = 1 } } } })).toEqual({})
	end)

	it("every (type, level) is in both files and no field is in both (game config)", function()
		local found = problems(Costs.catalogue().buildings, Buildings.buildings)
		if #found > 0 then
			-- The whole list, not the matcher's truncated diff: it is the owner's to-do list.
			error(
				`{#found} G13.5 mismatch(es) between Costs.luau and Buildings.luau:\n      {table.concat(
					found,
					"\n      "
				)}`,
				0
			)
		end
	end)

	it("Costs.maxLevel agrees with the catalogue it serves", function()
		local mismatches = {}
		for buildingType, levels in Costs.catalogue().buildings do
			if Costs.maxLevel(buildingType) ~= #levels then
				table.insert(mismatches, `{buildingType}: maxLevel {Costs.maxLevel(buildingType)} vs {#levels}`)
			end
		end
		expect(mismatches).toEqual({})
	end)
end)
