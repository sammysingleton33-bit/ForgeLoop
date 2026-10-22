local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local F = require("./KingdomFixtures")
local Commands = require("@game/ReplicatedStorage/Game/Sim/Commands")
local Military = require("@game/ReplicatedStorage/Game/Sim/Military")

-- (i, value) for every argument, nil ones included: a list literal drops its nil entries from `for in`
local function each(...)
	local cases = table.pack(...)
	local i = 0
	return function()
		i += 1
		if i <= cases.n then
			return i, cases[i]
		end
		return nil
	end
end

local A, B, RIVAL = 101, 102, 201 -- A and B both rule crimson; RIVAL rules azure

-- crimson at the origin (rulers A and B), azure at (400, 0) (ruler RIVAL). Events drained.
local function setup()
	local sim, crimson = F.kingdom({ tuning = { birthInterval = 1e6 } })
	local azure = sim:addKingdom({ id = "azure", name = "Rival", x = 400, z = 0 })
	assert(sim:addRuler("crimson", A))
	assert(sim:addRuler("crimson", B))
	assert(sim:addRuler("azure", RIVAL))
	F.events(sim)
	return sim, crimson, azure
end

-- Runs a command expected to fail and checks it left no trace (treasury and its ledger, buildings,
-- quotas, priorities, alarm, events).
local function rejects(sim, k, userId, expectedError: string, name: any, ...: any)
	local balances = sim.treasury:get(k.id)
	local ledger = #sim.treasury:ledger(k.id)
	local buildings = #sim.buildingOrder
	local quotas = table.clone(k.quotas)
	local priorities = table.clone(k.priorities)
	local alarm = k.alarm
	local ok, err, result = Commands.execute(sim, userId, name, ...)
	expect(ok).toBe(false)
	expect(err).toBe(expectedError)
	expect(result).toBeNil()
	expect(sim.treasury:get(k.id)).toEqual(balances)
	expect(#sim.treasury:ledger(k.id)).toBe(ledger)
	expect(#sim.buildingOrder).toBe(buildings)
	expect(k.quotas).toEqual(quotas)
	expect(k.priorities).toEqual(priorities)
	expect(k.alarm).toBe(alarm)
	expect(F.events(sim)).toEqual({})
end

describe("Kingdom/Commands: who may command", function()
	it("rejects a user who rules no kingdom (not_ruler), also after leaving", function()
		local sim, crimson = setup()
		rejects(sim, crimson, 999, "not_ruler", "SetAlarm", true)
		sim:removeRuler(B)
		F.events(sim)
		rejects(sim, crimson, B, "not_ruler", "SetAlarm", true)
		expect((Commands.execute(sim, A, "SetAlarm", true))).toBe(true)
	end)

	it("rejects everything while the match is not active (match_not_active)", function()
		local sim, crimson = setup()
		sim.active = false
		rejects(sim, crimson, A, "match_not_active", "SetAlarm", true)
		rejects(sim, crimson, A, "match_not_active", "PlaceBuilding", "house", 0, -35)
		rejects(sim, crimson, A, "match_not_active", "NoSuchCommand")
	end)

	it("rejects commands for an eliminated kingdom (kingdom_eliminated)", function()
		local sim, crimson, azure = setup()
		Military.eliminate(sim, azure, "crimson")
		F.events(sim)
		rejects(sim, azure, RIVAL, "kingdom_eliminated", "SetAlarm", true)
		rejects(sim, azure, RIVAL, "kingdom_eliminated", "PlaceBuilding", "house", 400, -35)
		expect((Commands.execute(sim, A, "SetAlarm", true))).toBe(true)
		expect(crimson.alive).toBe(true)
	end)

	it("rejects unknown and non-string command names (unknown_command)", function()
		local sim, crimson = setup()
		for _, name in { "Nope", "", "placebuilding", "PlaceBuilding ", "__index", "Recruit", "DeclareWar" } do
			rejects(sim, crimson, A, "unknown_command", name, "house", 0, -35)
		end
		for _, name in { 42, true, {}, function() end } do
			rejects(sim, crimson, A, "unknown_command", name)
		end
		rejects(sim, crimson, A, "unknown_command", nil)
	end)
end)

describe("Kingdom/Commands: argument validation (invalid_args, no side effects)", function()
	it("PlaceBuilding needs a short string kind and finite coordinates inside +-100000", function()
		local sim, crimson = setup()
		local nan, inf = 0 / 0, math.huge
		local bad = {
			{ "house", nan, -35 },
			{ "house", 0, nan },
			{ "house", inf, -35 },
			{ "house", -inf, -35 },
			{ "house", 0, inf },
			{ "house", 1e9, -35 },
			{ "house", 100000, 0 },
			{ "house", 0, -100000 },
			{ "house", "0", -35 },
			{ "house", 0 },
			{ "house", nil, nil },
			{ "house", {}, -35 },
			{ 42, 0, -35 },
			{ nil, 0, -35 },
			{ "", 0, -35 },
			{ string.rep("h", 17), 0, -35 },
		}
		for _, args in bad do
			rejects(sim, crimson, A, "invalid_args", "PlaceBuilding", args[1], args[2], args[3])
		end
		-- just inside the coordinate limit the arguments are valid; the map bounds then reject it
		rejects(sim, crimson, A, "out_of_bounds", "PlaceBuilding", "house", 99999, 0)
	end)

	it("UpgradeBuilding and CancelConstruction need an integer building id in 1..1e9", function()
		local sim, crimson = setup()
		local keepId = crimson.keepId
		expect(keepId).toBeA("number")
		for _, name in { "UpgradeBuilding", "CancelConstruction" } do
			for _, id in each(tostring(keepId), "b1", 0, -1, 1.5, 0 / 0, math.huge, 1e9 + 1, nil, true, {}) do
				rejects(sim, crimson, A, "invalid_args", name, id)
			end
			rejects(sim, crimson, A, "not_found", name, 1e9)
			rejects(sim, crimson, A, "not_found", name, 999)
		end
	end)

	it("SetJobQuota needs an integer count in 0..200", function()
		local sim, crimson = setup()
		for _, count in each(-1, 201, 1.5, 0 / 0, math.huge, -math.huge, "3", nil, true) do
			rejects(sim, crimson, A, "invalid_args", "SetJobQuota", "woodcutter", count)
		end
		rejects(sim, crimson, A, "invalid_args", "SetJobQuota", 5, 3)
		rejects(sim, crimson, A, "invalid_args", "SetJobQuota", string.rep("w", 17), 3)
		for _, count in { 0, 200 } do
			local ok, err = Commands.execute(sim, A, "SetJobQuota", "woodcutter", count)
			expect(err).toBeNil()
			expect(ok).toBe(true)
			expect(crimson.quotas.woodcutter).toBe(count)
		end
	end)

	it("SetPriority needs an integer weight in 0..3", function()
		local sim, crimson = setup()
		for _, weight in each(-1, 4, 0.5, 0 / 0, math.huge, "1", nil, false) do
			rejects(sim, crimson, A, "invalid_args", "SetPriority", "wood", weight)
		end
		rejects(sim, crimson, A, "invalid_args", "SetPriority", nil, 1)
		for _, weight in { 0, 3 } do
			expect((Commands.execute(sim, A, "SetPriority", "wood", weight))).toBe(true)
			expect(crimson.priorities.wood).toBe(weight)
		end
	end)

	it("SetAlarm needs a boolean", function()
		local sim, crimson = setup()
		for _, on in each(1, 0, "true", nil, {}) do
			rejects(sim, crimson, A, "invalid_args", "SetAlarm", on)
		end
	end)

	it("rejects unknown jobs (hauler is the pool and has no quota) and unknown resources", function()
		local sim, crimson = setup()
		for _, job in { "hauler", "Woodcutter", "wizard", "soldier", "Laborer", "Quarrier" } do
			rejects(sim, crimson, A, "unknown_job", "SetJobQuota", job, 2)
		end
		for _, resource in { "mana", "Food", "food ", "tree" } do
			rejects(sim, crimson, A, "unknown_resource", "SetPriority", resource, 2)
		end
	end)
end)

describe("Kingdom/Commands: results", function()
	it("PlaceBuilding returns the new building's integer id and spends its cost from the treasury", function()
		local sim, crimson = setup()
		local ok, err, result = Commands.execute(sim, A, "PlaceBuilding", "house", 0, -35)
		expect(err).toBeNil()
		expect(ok).toBe(true)
		expect(result.buildingId).toBeA("number")
		local house = sim.buildings[result.buildingId]
		expect(house.kind).toBe("house")
		expect(house.kingdomId).toBe("crimson")
		expect(house.pendingLevel).toBe(1)
		expect(sim:balance("crimson", "wood")).toBe(60)
		expect(F.stock(sim, crimson):flows().expense.construction).toEqual({ wood = 40 })
		local placed = F.events(sim, "BuildingPlaced")
		expect(#placed).toBe(1)
		expect(placed[1].buildingId).toBe(result.buildingId)
		expect(placed[1].by).toBe(A)
	end)

	it("UpgradeBuilding returns the pending level; CancelConstruction returns the id", function()
		local sim, crimson = setup()
		local farm = sim:buildingsOf(crimson)[2]
		local ok, err, result = Commands.execute(sim, A, "UpgradeBuilding", farm.id)
		expect(err).toBeNil()
		expect(ok).toBe(true)
		expect(result).toEqual({ buildingId = farm.id, level = 2 })
		expect(F.stock(sim, crimson):flows().expense.upgrade).toEqual({ wood = 60, stone = 20 })
		ok, err, result = Commands.execute(sim, A, "CancelConstruction", farm.id)
		expect(err).toBeNil()
		expect(result).toEqual({ buildingId = farm.id })
		expect(farm.pendingLevel).toBeNil()
		expect(F.stock(sim, crimson):flows().income.refund).toEqual({ wood = 30, stone = 10 })
	end)

	it("SetJobQuota, SetPriority and SetAlarm return what they set and take effect", function()
		local sim, crimson = setup()
		local _, _, quota = Commands.execute(sim, A, "SetJobQuota", "woodcutter", 5)
		expect(quota).toEqual({ job = "woodcutter", count = 5 })
		local _, _, priority = Commands.execute(sim, A, "SetPriority", "stone", 3)
		expect(priority).toEqual({ resource = "stone", weight = 3 })
		expect(crimson.priorities.stone).toBe(3)
		local _, _, alarm = Commands.execute(sim, A, "SetAlarm", true)
		expect(alarm).toEqual({ on = true })
		expect(crimson.alarm).toBe(true)
		local changed = F.events(sim, "AlarmChanged")
		expect(#changed).toBe(1)
		expect(changed[1].kingdomId).toBe("crimson")
		expect(changed[1].on).toBe(true)
		-- ringing a bell that already rings succeeds without a second announcement
		expect((Commands.execute(sim, A, "SetAlarm", true))).toBe(true)
		expect(#F.events(sim, "AlarmChanged")).toBe(0)
		-- quotas draw on the hauler pool: the two haulers become woodcutters (3 + 2 = 5)
		expect(F.jobs(sim, crimson).hauler).toBe(2)
		sim:advance(1) -- the quota rebalance runs every second
		expect(F.jobs(sim, crimson).woodcutter).toBe(5)
		expect(F.jobs(sim, crimson).hauler).toBeNil()
		-- lowering a quota sends the surplus back to the pool
		assert(Commands.execute(sim, B, "SetJobQuota", "farmer", 1))
		sim:advance(1)
		expect(F.jobs(sim, crimson).farmer).toBe(1)
		expect(F.jobs(sim, crimson).hauler).toBe(2)
	end)

	it("passes the simulation's own rejections through unchanged, without side effects", function()
		local sim, crimson = setup()
		rejects(sim, crimson, A, "unknown_building", "PlaceBuilding", "castle", 0, -35)
		rejects(sim, crimson, A, "unknown_building", "PlaceBuilding", "House", 0, -35) -- ids are lowercase
		rejects(sim, crimson, A, "not_placeable", "PlaceBuilding", "keep", 0, -35)
		rejects(sim, crimson, A, "requires_keep_level", "PlaceBuilding", "watchtower", 0, -35)
		rejects(sim, crimson, A, "out_of_territory", "PlaceBuilding", "house", 0, -200)
		rejects(sim, crimson, A, "blocked", "PlaceBuilding", "house", 0, 0)
		rejects(sim, crimson, A, "cannot_afford", "PlaceBuilding", "barracks", 0, -40)
		rejects(sim, crimson, A, "cannot_afford", "UpgradeBuilding", crimson.keepId)
		rejects(sim, crimson, A, "nothing_to_cancel", "CancelConstruction", crimson.keepId)
		local farm = sim:buildingsOf(crimson)[2]
		assert(Commands.execute(sim, A, "UpgradeBuilding", farm.id))
		F.events(sim)
		rejects(sim, crimson, A, "busy", "UpgradeBuilding", farm.id)
	end)
end)

describe("Kingdom/Commands: shared ownership", function()
	it("every ruler of a kingdom can command it, and events record who did what", function()
		local sim, crimson = setup()
		local _, _, placed = Commands.execute(sim, A, "PlaceBuilding", "house", 0, -35)
		local ok, err = Commands.execute(sim, B, "CancelConstruction", placed.buildingId)
		expect(err).toBeNil()
		expect(ok).toBe(true)
		assert(Commands.execute(sim, B, "SetAlarm", true))
		assert(Commands.execute(sim, A, "SetAlarm", false))
		local farm = sim:buildingsOf(crimson)[2]
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
		local sim, crimson, azure = setup()
		local _, _, site = Commands.execute(sim, RIVAL, "PlaceBuilding", "house", 400, -35)
		F.events(sim)
		local siteBefore = table.clone(sim.buildings[site.buildingId])
		rejects(sim, crimson, A, "not_owner", "UpgradeBuilding", azure.keepId)
		rejects(sim, crimson, A, "not_owner", "CancelConstruction", site.buildingId)
		rejects(sim, crimson, B, "not_owner", "UpgradeBuilding", sim:buildingsOf(azure)[2].id)
		-- territory is measured from the commander's own keep
		rejects(sim, crimson, A, "out_of_territory", "PlaceBuilding", "house", 400, 35)
		expect(sim.buildings[site.buildingId].pendingLevel).toBe(siteBefore.pendingLevel)
		expect(sim:balance("azure", "wood")).toBe(60)
		-- and the rival's own commands touch only azure
		assert(Commands.execute(sim, RIVAL, "SetAlarm", true))
		expect(azure.alarm).toBe(true)
		expect(crimson.alarm).toBe(false)
	end)
end)

describe("Kingdom/Commands: install and namesFor", function()
	it("lists the eight built-in commands", function()
		expect(table.clone(Commands.NAMES)).toEqual({
			"PlaceBuilding",
			"PlaceBuildingLine",
			"MoveBuilding",
			"UpgradeBuilding",
			"CancelConstruction",
			"SetJobQuota",
			"SetPriority",
			"SetAlarm",
		})
	end)

	it("installs per-simulation commands, refuses duplicates and lists installed names sorted", function()
		local sim, crimson = setup()
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
		expect(seen).toEqual({ s = sim, kingdom = "crimson", by = A, a = 1, b = "x" })
		-- executeFor reaches it too (AI rulers pass by = nil)
		expect((Commands.executeFor(sim, crimson, nil, "Wave"))).toBe(true)
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
		local otherK = other.kingdoms.crimson
		expect(select(2, Commands.executeFor(other, otherK, nil, "Wave"))).toBe("unknown_command")

		Military.install(sim)
		expect(Commands.namesFor(sim)).toEqual({
			"ArmyOrder",
			"CancelConstruction",
			"MoveBuilding",
			"PlaceBuilding",
			"PlaceBuildingLine",
			"Recruit",
			"SetAlarm",
			"SetJobQuota",
			"SetPriority",
			"UnitOrder",
			"UpgradeBuilding",
			"Wave",
		})
		expect(#Commands.namesFor(other)).toBe(8)
		expect(#Commands.NAMES).toBe(8) -- namesFor returns a copy
	end)
end)
