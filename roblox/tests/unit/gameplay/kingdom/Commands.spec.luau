local T = require("../../../harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local F = require("./KingdomFixtures")
local Commands = require("@game/ReplicatedStorage/Forge/Gameplay/Kingdom/Commands")
local Military = require("@game/ReplicatedStorage/Forge/Gameplay/Kingdom/Military")

local A, B, RIVAL = 101, 102, 201 -- A and B both rule k1; RIVAL rules k2

-- k1 at the origin (rulers A and B), k2 at (400, 0) (ruler RIVAL). Events drained.
local function setup()
	local sim, k1 = F.kingdom({ tuning = { birthInterval = 1e6 } })
	local k2 = sim:addKingdom({ id = "k2", name = "Rival", x = 400, z = 0 })
	assert(sim:addRuler("k1", A))
	assert(sim:addRuler("k1", B))
	assert(sim:addRuler("k2", RIVAL))
	F.events(sim)
	return sim, k1, k2
end

-- Runs a command expected to fail and checks it left no trace (stock, buildings, quotas, events).
local function rejects(sim, k, userId, expectedError: string, name: any, ...: any)
	local stock = k.stock:snapshot()
	local buildings = #sim.buildingOrder
	local quotas = table.clone(k.quotas)
	local priorities = table.clone(k.priorities)
	local alarm = k.alarm
	local ok, err, result = Commands.execute(sim, userId, name, ...)
	expect(ok).toBe(false)
	expect(err).toBe(expectedError)
	expect(result).toBeNil()
	expect(k.stock:snapshot()).toEqual(stock)
	expect(#sim.buildingOrder).toBe(buildings)
	expect(k.quotas).toEqual(quotas)
	expect(k.priorities).toEqual(priorities)
	expect(k.alarm).toBe(alarm)
	expect(F.events(sim)).toEqual({})
end

describe("Kingdom/Commands: who may command", function()
	it("rejects a user who rules no kingdom (not_ruler), also after leaving", function()
		local sim, k1 = setup()
		rejects(sim, k1, 999, "not_ruler", "SetAlarm", true)
		sim:removeRuler(B)
		F.events(sim)
		rejects(sim, k1, B, "not_ruler", "SetAlarm", true)
		expect((Commands.execute(sim, A, "SetAlarm", true))).toBe(true)
	end)

	it("rejects everything while the match is not active (match_not_active)", function()
		local sim, k1 = setup()
		sim.active = false
		rejects(sim, k1, A, "match_not_active", "SetAlarm", true)
		rejects(sim, k1, A, "match_not_active", "PlaceBuilding", "House", 0, -35)
		rejects(sim, k1, A, "match_not_active", "NoSuchCommand")
	end)

	it("rejects commands for an eliminated kingdom (kingdom_eliminated)", function()
		local sim, k1, k2 = setup()
		Military.eliminate(sim, k2, "k1")
		F.events(sim)
		rejects(sim, k2, RIVAL, "kingdom_eliminated", "SetAlarm", true)
		rejects(sim, k2, RIVAL, "kingdom_eliminated", "PlaceBuilding", "House", 400, -35)
		expect((Commands.execute(sim, A, "SetAlarm", true))).toBe(true)
		expect(k1.alive).toBe(true)
	end)

	it("rejects unknown and non-string command names (unknown_command)", function()
		local sim, k1 = setup()
		for _, name in { "Nope", "", "placebuilding", "PlaceBuilding ", "__index", "Recruit", "DeclareWar" } do
			rejects(sim, k1, A, "unknown_command", name, "House", 0, -35)
		end
		for _, name in { 42, true, {}, function() end } do
			rejects(sim, k1, A, "unknown_command", name)
		end
		rejects(sim, k1, A, "unknown_command", nil)
	end)
end)

describe("Kingdom/Commands: argument validation (invalid_args, no side effects)", function()
	it("PlaceBuilding needs a short string kind and finite coordinates inside +-100000", function()
		local sim, k1 = setup()
		local nan, inf = 0 / 0, math.huge
		local bad = {
			{ "House", nan, -35 },
			{ "House", 0, nan },
			{ "House", inf, -35 },
			{ "House", -inf, -35 },
			{ "House", 0, inf },
			{ "House", 1e9, -35 },
			{ "House", 100000, 0 },
			{ "House", 0, -100000 },
			{ "House", "0", -35 },
			{ "House", 0 },
			{ "House", nil, nil },
			{ "House", {}, -35 },
			{ 42, 0, -35 },
			{ nil, 0, -35 },
			{ "", 0, -35 },
			{ string.rep("H", 17), 0, -35 },
		}
		for _, args in bad do
			rejects(sim, k1, A, "invalid_args", "PlaceBuilding", args[1], args[2], args[3])
		end
		-- just inside the coordinate limit the arguments are valid; the map bounds then reject it
		rejects(sim, k1, A, "out_of_bounds", "PlaceBuilding", "House", 99999, 0)
	end)

	it("UpgradeBuilding and CancelConstruction need a string id of 1..16 characters", function()
		local sim, k1 = setup()
		for _, name in { "UpgradeBuilding", "CancelConstruction" } do
			for _, id in { 7, nil, "", string.rep("b", 17), true, {} } do
				rejects(sim, k1, A, "invalid_args", name, id)
			end
			rejects(sim, k1, A, "not_found", name, string.rep("b", 16))
		end
	end)

	it("SetJobQuota needs an integer count in 0..200", function()
		local sim, k1 = setup()
		for _, count in { -1, 201, 1.5, 0 / 0, math.huge, -math.huge, "3", nil, true } do
			rejects(sim, k1, A, "invalid_args", "SetJobQuota", "Woodcutter", count)
		end
		rejects(sim, k1, A, "invalid_args", "SetJobQuota", 5, 3)
		rejects(sim, k1, A, "invalid_args", "SetJobQuota", string.rep("W", 17), 3)
		for _, count in { 0, 200 } do
			local ok, err = Commands.execute(sim, A, "SetJobQuota", "Woodcutter", count)
			expect(err).toBeNil()
			expect(ok).toBe(true)
			expect(k1.quotas.Woodcutter).toBe(count)
		end
	end)

	it("SetPriority needs an integer weight in 0..3", function()
		local sim, k1 = setup()
		for _, weight in { -1, 4, 0.5, 0 / 0, math.huge, "1", nil, false } do
			rejects(sim, k1, A, "invalid_args", "SetPriority", "wood", weight)
		end
		rejects(sim, k1, A, "invalid_args", "SetPriority", nil, 1)
		for _, weight in { 0, 3 } do
			expect((Commands.execute(sim, A, "SetPriority", "wood", weight))).toBe(true)
			expect(k1.priorities.wood).toBe(weight)
		end
	end)

	it("SetAlarm needs a boolean", function()
		local sim, k1 = setup()
		for _, on in { 1, 0, "true", nil, {} } do
			rejects(sim, k1, A, "invalid_args", "SetAlarm", on)
		end
	end)

	it("rejects unknown occupations (Laborer has no quota) and unknown resources", function()
		local sim, k1 = setup()
		for _, occupation in { "Laborer", "Wizard", "woodcutter", "Knight" } do
			rejects(sim, k1, A, "unknown_occupation", "SetJobQuota", occupation, 2)
		end
		for _, resource in { "mana", "Food", "food ", "Tree" } do
			rejects(sim, k1, A, "unknown_resource", "SetPriority", resource, 2)
		end
	end)
end)

describe("Kingdom/Commands: results", function()
	it("PlaceBuilding returns the new building's id and spends its cost", function()
		local sim, k1 = setup()
		local ok, err, result = Commands.execute(sim, A, "PlaceBuilding", "House", 0, -35)
		expect(err).toBeNil()
		expect(ok).toBe(true)
		local house = sim.buildings[result.buildingId]
		expect(house.kind).toBe("House")
		expect(house.kingdomId).toBe("k1")
		expect(house.pendingLevel).toBe(1)
		expect(k1.stock:get("wood")).toBe(60)
		local placed = F.events(sim, "BuildingPlaced")
		expect(#placed).toBe(1)
		expect(placed[1].buildingId).toBe(result.buildingId)
		expect(placed[1].by).toBe(A)
	end)

	it("UpgradeBuilding returns the pending level; CancelConstruction returns the id", function()
		local sim, k1 = setup()
		local farm = sim:buildingsOf(k1)[2]
		local ok, err, result = Commands.execute(sim, A, "UpgradeBuilding", farm.id)
		expect(err).toBeNil()
		expect(ok).toBe(true)
		expect(result).toEqual({ buildingId = farm.id, level = 2 })
		ok, err, result = Commands.execute(sim, A, "CancelConstruction", farm.id)
		expect(err).toBeNil()
		expect(result).toEqual({ buildingId = farm.id })
		expect(farm.pendingLevel).toBeNil()
	end)

	it("SetJobQuota, SetPriority and SetAlarm return what they set and take effect", function()
		local sim, k1 = setup()
		local _, _, quota = Commands.execute(sim, A, "SetJobQuota", "Woodcutter", 5)
		expect(quota).toEqual({ occupation = "Woodcutter", count = 5 })
		local _, _, priority = Commands.execute(sim, A, "SetPriority", "stone", 3)
		expect(priority).toEqual({ resource = "stone", weight = 3 })
		expect(k1.priorities.stone).toBe(3)
		local _, _, alarm = Commands.execute(sim, A, "SetAlarm", true)
		expect(alarm).toEqual({ on = true })
		expect(k1.alarm).toBe(true)
		local changed = F.events(sim, "AlarmChanged")
		expect(#changed).toBe(1)
		expect(changed[1].kingdomId).toBe("k1")
		expect(changed[1].on).toBe(true)
		-- ringing a bell that already rings succeeds without a second announcement
		expect((Commands.execute(sim, A, "SetAlarm", true))).toBe(true)
		expect(#F.events(sim, "AlarmChanged")).toBe(0)
		-- quotas move citizens through the Laborer pool: freeing two farmers lets woodcutters reach 5
		assert(Commands.execute(sim, B, "SetJobQuota", "Farmer", 1))
		sim:advance(1) -- the quota rebalance runs every second
		expect(F.occupations(sim, k1).Woodcutter).toBe(5)
		expect(F.occupations(sim, k1).Farmer).toBe(1)
	end)

	it("passes the simulation's own rejections through unchanged, without side effects", function()
		local sim, k1 = setup()
		rejects(sim, k1, A, "unknown_building", "PlaceBuilding", "Castle", 0, -35)
		rejects(sim, k1, A, "not_placeable", "PlaceBuilding", "Keep", 0, -35)
		rejects(sim, k1, A, "requires_keep_level", "PlaceBuilding", "Tower", 0, -35)
		rejects(sim, k1, A, "out_of_territory", "PlaceBuilding", "House", 0, -200)
		rejects(sim, k1, A, "blocked", "PlaceBuilding", "House", 0, 0)
		rejects(sim, k1, A, "cannot_afford", "PlaceBuilding", "Barracks", 0, -40)
		rejects(sim, k1, A, "cannot_afford", "UpgradeBuilding", k1.keepId)
		rejects(sim, k1, A, "nothing_to_cancel", "CancelConstruction", k1.keepId)
		rejects(sim, k1, A, "not_found", "UpgradeBuilding", "b999")
		local farm = sim:buildingsOf(k1)[2]
		assert(Commands.execute(sim, A, "UpgradeBuilding", farm.id))
		F.events(sim)
		rejects(sim, k1, A, "busy", "UpgradeBuilding", farm.id)
	end)
end)

describe("Kingdom/Commands: shared ownership", function()
	it("every ruler of a kingdom can command it, and events record who did what", function()
		local sim, k1 = setup()
		local _, _, placed = Commands.execute(sim, A, "PlaceBuilding", "House", 0, -35)
		local ok, err = Commands.execute(sim, B, "CancelConstruction", placed.buildingId)
		expect(err).toBeNil()
		expect(ok).toBe(true)
		assert(Commands.execute(sim, B, "SetAlarm", true))
		assert(Commands.execute(sim, A, "SetAlarm", false))
		local farm = sim:buildingsOf(k1)[2]
		assert(Commands.execute(sim, B, "UpgradeBuilding", farm.id))
		local by = {}
		for _, e in F.events(sim) do
			table.insert(by, { e.name, e.by })
		end
		expect(by).toEqual({
			{ "BuildingPlaced", A },
			{ "ConstructionCancelled", B },
			{ "AlarmChanged", B },
			{ "AlarmChanged", A },
			{ "UpgradeStarted", B },
		})
	end)

	it("a ruler cannot upgrade, cancel or build on behalf of another kingdom", function()
		local sim, k1, k2 = setup()
		local _, _, site = Commands.execute(sim, RIVAL, "PlaceBuilding", "House", 400, -35)
		F.events(sim)
		local siteBefore = table.clone(sim.buildings[site.buildingId])
		rejects(sim, k1, A, "not_owner", "UpgradeBuilding", k2.keepId)
		rejects(sim, k1, A, "not_owner", "CancelConstruction", site.buildingId)
		rejects(sim, k1, B, "not_owner", "UpgradeBuilding", sim:buildingsOf(k2)[2].id)
		-- territory is measured from the commander's own keep
		rejects(sim, k1, A, "out_of_territory", "PlaceBuilding", "House", 400, 35)
		expect(sim.buildings[site.buildingId].pendingLevel).toBe(siteBefore.pendingLevel)
		expect(k2.stock:get("wood")).toBe(60)
		-- and the rival's own commands touch only k2
		assert(Commands.execute(sim, RIVAL, "SetAlarm", true))
		expect(k2.alarm).toBe(true)
		expect(k1.alarm).toBe(false)
	end)
end)

describe("Kingdom/Commands: install and namesFor", function()
	it("lists the six built-in commands", function()
		expect(table.clone(Commands.NAMES)).toEqual({
			"PlaceBuilding",
			"UpgradeBuilding",
			"CancelConstruction",
			"SetJobQuota",
			"SetPriority",
			"SetAlarm",
		})
	end)

	it("installs per-simulation commands, refuses duplicates and lists installed names sorted", function()
		local sim, k1 = setup()
		local other = F.kingdom()
		local seen
		Commands.install(sim, "Wave", function(s, kingdom, by, a, b)
			seen = { s = s, kingdom = kingdom.id, by = by, a = a, b = b }
			return true, nil, { waved = true }
		end)
		local ok, err, result = Commands.execute(sim, A, "Wave", 1, "x")
		expect(err).toBeNil()
		expect(ok).toBe(true)
		expect(result).toEqual({ waved = true })
		expect(seen).toEqual({ s = sim, kingdom = "k1", by = A, a = 1, b = "x" })
		-- executeFor reaches it too (AI rulers pass by = nil)
		expect((Commands.executeFor(sim, k1, nil, "Wave"))).toBe(true)
		expect(seen.by).toBeNil()

		expect(function()
			Commands.install(sim, "Wave", function()
				return true
			end)
		end).toThrow("already exists")
		expect(function()
			Commands.install(sim, "PlaceBuilding", function()
				return true
			end)
		end).toThrow("already exists")
		expect(function()
			Commands.install(sim, 5 :: any, function()
				return true
			end)
		end).toThrow()
		expect(function()
			Commands.install(sim, "Nothing", nil :: any)
		end).toThrow()

		-- another simulation does not see it
		local otherK = other.kingdoms.k1
		expect(select(2, Commands.executeFor(other, otherK, nil, "Wave"))).toBe("unknown_command")

		Military.install(sim)
		expect(Commands.namesFor(sim)).toEqual({
			"ArmyOrder",
			"CancelConstruction",
			"PlaceBuilding",
			"Recruit",
			"SetAlarm",
			"SetJobQuota",
			"SetPriority",
			"UpgradeBuilding",
			"Wave",
		})
		expect(#Commands.namesFor(other)).toBe(6)
		expect(#Commands.NAMES).toBe(6) -- namesFor returns a copy
	end)
end)
