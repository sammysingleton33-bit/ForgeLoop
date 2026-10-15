--[[
	BuildingService (CONTRACTS G6, G8 Build area; FL-0051) booted with the match services and FORGE-03's
	real TreasuryService and Costs: CanPlace and Place agree (facing included: the placement rectangle
	turns with rot), Place charges exactly once and sets placedBy, the facing comes from rot, Upgrade,
	Build.Buildings / Build.GetBuildings, and the G13.5 build slots (Build.PlaceSlot, GetSlots, Slots).
]]

local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect, afterEach = T.describe, T.it, T.expect, T.afterEach

local MockEnv = require("../../../../roblox/tests/mocks/MockEnv")
local GameEvents = require("@game/ReplicatedStorage/Forge/Contracts/GameEvents")
local Loader = require("@game/ReplicatedStorage/Forge/Contracts/Loader")
local Costs = require("@game/ReplicatedStorage/Forge/Config/Costs")
local Fit = require("@game/ReplicatedStorage/Game/Build/Fit")
local Layout = require("@game/ReplicatedStorage/Game/Kingdom/Layout")
local BuildRemotes = require("@game/ReplicatedStorage/Game/Build/Remotes")
local KingdomRemotes = require("@game/ReplicatedStorage/Game/Kingdom/Remotes")
local MatchRemotes = require("@game/ReplicatedStorage/Game/Match/Remotes")
local TreasuryRemotes = require("@game/ReplicatedStorage/Game/Treasury/Remotes")

local function service(name)
	return require(`@game/ServerScriptService/{if name == "RemoteService" then "Forge" else "Game"}/Services/{name}`)
end

local booted = {}

local function boot()
	local env = MockEnv.new({
		seed = 8,
		sharedModules = {
			Remotes = {
				Kingdom = KingdomRemotes,
				Match = MatchRemotes,
				Build = BuildRemotes,
				Treasury = TreasuryRemotes,
			},
		},
	})
	local definitions = {}
	for _, name in { "RemoteService", "MatchService", "KingdomService", "BuildingService", "TreasuryService" } do
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
	return env, registry:get("BuildingService"), registry:get("MatchService"), registry:get("TreasuryService")
end

local function remote(env, name)
	local area, action = string.match(name, "^(%w+)%.(%w+)$")
	return env.ReplicatedStorage.ForgeRemotes:FindFirstChild(area):FindFirstChild(action)
end

local function invoke(env, player, name, ...)
	local args = table.pack(...)
	local results
	env.mock.remotes:asClient(player, function()
		results = table.pack(remote(env, name):InvokeServer(table.unpack(args, 1, args.n)))
	end)
	return table.unpack(results, 1, results.n)
end

local function broadcasts(env)
	local out = {}
	for _, entry in env.mock.remotes:sent(remote(env, "Build.Buildings")) do
		table.insert(out, entry.args[1])
	end
	return out
end

-- the first spot around the keep where `kind` may stand at every one of the given rots (0..3)
local function freeSpot(sim, k, kind, ...)
	local rots = { ... }
	local keep = sim.buildings[k.keepId]
	for radius = 40, 140, 10 do
		for step = 0, 23 do
			local a = step / 24 * 2 * math.pi
			local x, z = keep.x + math.cos(a) * radius, keep.z + math.sin(a) * radius
			local free = true
			for _, rot in rots do
				free = free and sim:canPlace(k, kind, x, z, rot * math.pi / 2)
			end
			if free then
				return Vector3.new(x, 0, z)
			end
		end
	end
	error("no free spot")
end

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

describe("BuildingService (G6, G8)", function()
	it("CanPlace and Place agree; Place charges Costs once, sets placedBy and faces by rot", function()
		local env, _, match, treasury = boot()
		local p1 = env.mock.players:add({ userId = 1 })
		env.mock:advance(0.5)
		local sim = match.host.match.sim
		local k = sim.kingdoms.crimson
		local spot = freeSpot(sim, k, "house", 1, 2)
		expect({ invoke(env, p1, "Build.CanPlace", "house", spot, 1) }).toEqual({ true })
		local keep = sim.buildings[k.keepId]
		expect({ invoke(env, p1, "Build.CanPlace", "house", Vector3.new(keep.x, 0, keep.z), 0) }).toEqual({
			false,
			"blocked",
		})
		local before = treasury:get("crimson")
		local id, reason = invoke(env, p1, "Build.Place", "house", spot, 2)
		expect(reason).toBeNil()
		expect(type(id)).toBe("number")
		local after = treasury:get("crimson")
		local cost = assert(Costs.building("house", 1)).cost
		for res, amount in cost do
			expect(after[res]).toBe(before[res] - amount)
		end
		local view = assert(sim:buildingView(id))
		expect(view.placedBy).toBe(1)
		local look = view.cframe.LookVector
		local yaw = math.atan2(-look.X, -look.Z) % (2 * math.pi)
		expect(math.abs(yaw - math.pi) < 1e-6).toBe(true) -- rot 2 = 180°, whatever way the keep lies
		expect({ invoke(env, p1, "Build.CanPlace", "house", spot, 0) }).toEqual({ false, "blocked" }) -- taken now
	end)

	it("CanPlace and Place agree on the facing: a barracks blocked at rot 0 fits turned at rot 1", function()
		local env, _, match = boot()
		local p1 = env.mock.players:add({ userId = 1 })
		env.mock:advance(0.5)
		local sim = match.host.match.sim
		local k = sim.kingdoms.crimson
		for _, res in { "food", "wood", "stone", "gold" } do
			sim.treasury:deposit(k.id, res, 2000, `spec:{res}`, "spec")
		end
		-- a spot where only the turned barracks (34 x 22, long side on Z at rot 1) fits
		local keep = sim.buildings[k.keepId]
		local spot
		for radius = 30, 140, 2 do
			for step = 0, 71 do
				local a = step / 72 * 2 * math.pi
				local x, z = keep.x + math.cos(a) * radius, keep.z + math.sin(a) * radius
				if spot == nil and sim:canPlace(k, "barracks", x, z, math.pi / 2) then
					local ok, reason = sim:canPlace(k, "barracks", x, z, 0)
					if not ok and reason == "blocked" then
						spot = Vector3.new(x, 0, z)
					end
				end
			end
		end
		assert(spot, "no spot where the facing decides")
		expect({ invoke(env, p1, "Build.CanPlace", "barracks", spot, 0) }).toEqual({ false, "blocked" })
		expect({ invoke(env, p1, "Build.CanPlace", "barracks", spot, 1) }).toEqual({ true })
		expect({ invoke(env, p1, "Build.Place", "barracks", spot, 0) }).toEqual({ nil, "blocked" })
		local id = invoke(env, p1, "Build.Place", "barracks", spot, 1)
		expect(type(id)).toBe("number")
		local look = assert(sim:buildingView(id)).cframe.LookVector
		expect(math.abs(math.atan2(-look.X, -look.Z) - math.pi / 2) < 1e-6).toBe(true)
	end)

	it("refuses bad input before it reaches the kingdom and charges nothing", function()
		local env, _, match, treasury = boot()
		local p1 = env.mock.players:add({ userId = 1 })
		env.mock:advance(0.5)
		local before = treasury:get("crimson")
		expect(invoke(env, p1, "Build.Place", "house", Vector3.new(0, 0, 0), 4)).toBeNil() -- rot 0..3
		expect(invoke(env, p1, "Build.Place", "castle", Vector3.new(0, 0, 0), 0)).toBeNil() -- not a G2 type
		expect(invoke(env, p1, "Build.Place", "house", Vector3.new(9000, 0, 0), 0)).toBeNil() -- off the world
		expect(invoke(env, p1, "Build.Place", "house", CFrame.new(), 0)).toBeNil() -- no CFrame on the wire
		env.mock:advance(3) -- those spent Build.Place's burst (4); let the bucket refill
		expect({ invoke(env, p1, "Build.Place", "keep", Vector3.new(0, 0, 0), 0) }).toEqual({ nil, "not_placeable" })
		expect({ invoke(env, p1, "Build.Place", "house", Vector3.new(0, 0, 0), 0) }).toEqual({
			nil,
			"out_of_territory",
		})
		expect(treasury:get("crimson")).toEqual(before)
		local spectator = env.mock.players:add({ userId = 99 })
		for userId = 2, 16 do
			env.mock.players:add({ userId = userId })
		end
		local extra = env.mock.players:add({ userId = 100 })
		expect({ invoke(env, extra, "Build.CanPlace", "house", Vector3.new(0, 0, 0), 0) }).toEqual({
			false,
			"not_in_match",
		})
		expect(spectator).toBeTruthy()
		expect(match).toBeTruthy()
	end)

	it("upgrades a building the player's kingdom owns, and nobody else's", function()
		local env, _, match = boot()
		local p1 = env.mock.players:add({ userId = 1 })
		local p2 = env.mock.players:add({ userId = 2 })
		env.mock:advance(0.5)
		local sim = match.host.match.sim
		local keep = sim.kingdoms.crimson.keepId
		expect({ invoke(env, p2, "Build.Upgrade", keep) }).toEqual({ false, "not_owner" })
		expect({ invoke(env, p1, "Build.Upgrade", keep) }).toEqual({ false, "cannot_afford" })
		sim.treasury:deposit("crimson", "wood", 500, "spec:wood", "spec")
		sim.treasury:deposit("crimson", "stone", 500, "spec:stone", "spec")
		expect({ invoke(env, p1, "Build.Upgrade", keep) }).toEqual({ true })
		expect(sim.buildings[keep].pendingLevel).toBe(2)
	end)

	it("broadcasts changed buildings at most twice a second and answers GetBuildings with all of them", function()
		local env, _, match = boot()
		local p1 = env.mock.players:add({ userId = 1 })
		env.mock:advance(1)
		local sim = match.host.match.sim
		local all = invoke(env, p1, "Build.GetBuildings")
		expect(#all).toBe(#sim:buildingViews())
		expect(#all).toBe(4 * 5) -- keep, storehouse, farm, lumber camp and quarry per kingdom
		local first = broadcasts(env)
		expect(#first >= 1).toBe(true)
		local seen = 0
		for _, list in first do
			seen += #list
		end
		expect(seen).toBe(#all) -- everything once at the start, nothing repeated while nothing changes
		env.mock:advance(5)
		expect(#broadcasts(env)).toBe(#first)
		local spot = freeSpot(sim, sim.kingdoms.crimson, "house", 0)
		local id = invoke(env, p1, "Build.Place", "house", spot, 0)
		env.mock:advance(2)
		local later = broadcasts(env)
		expect(#later > #first and #later <= #first + 4).toBe(true) -- ≤ 2 per second
		local found = false
		for i = #first + 1, #later do
			for _, view in later[i] do
				if view.id == id then
					found = true
				end
			end
		end
		expect(found).toBe(true)
	end)

	it("sends a removed building once as destroyed, and every old building when a new world starts", function()
		local env, _, match = boot()
		local p1 = env.mock.players:add({ userId = 1 })
		env.mock:advance(1)
		local sim = match.host.match.sim
		local k = sim.kingdoms.crimson
		local spot = freeSpot(sim, k, "house", 0)
		local id = invoke(env, p1, "Build.Place", "house", spot, 0)
		env.mock:advance(1)
		assert(sim:cancelConstruction(k, id, 1))
		env.mock:advance(1)
		local function statesOf(fromIndex)
			local out = {}
			local all = broadcasts(env)
			for i = fromIndex, #all do
				for _, view in all[i] do
					out[view.id] = out[view.id] or {}
					table.insert(out[view.id], view.state)
				end
			end
			return out
		end
		local states = statesOf(1)[id]
		expect(states[#states]).toBe("destroyed")
		local count = #broadcasts(env)
		env.mock:advance(3)
		expect(#broadcasts(env)).toBe(count) -- once
		-- a new world: every building of the old one goes out as destroyed, before the new world's
		local old = #sim.buildingOrder
		match.host.match:_newWorld()
		env.mock:advance(1)
		local batches = broadcasts(env)
		local gone = batches[count + 1]
		expect(#gone).toBe(old)
		for _, view in gone do
			expect(view.state).toBe("destroyed")
		end
	end)
end)

describe("BuildingService: walls turn like every free-placed building (CONTRACTS v0.4-g9h)", function()
	it("a wall faces rot quarter turns and its placement shape turns with it, so a turn changes what fits", function()
		local env, _, match, treasury = boot()
		local p1 = env.mock.players:add({ userId = 1 })
		env.mock:advance(0.5)
		local sim = match.host.match.sim
		local k = sim.kingdoms.crimson
		for _, res in { "wood", "stone", "gold", "food" } do
			sim.treasury:deposit("crimson", res, 4000, `spec:wall:{res}`, "spec")
		end
		local size = assert(Fit.largestFootprint("wall"), "walls have a Kit footprint")
		expect(size.X > size.Y + 2).toBe(true) -- a wall is a long thin piece: its turn matters
		local spot = freeSpot(sim, k, "wall", 0, 1, 2, 3)
		local gap = sim.catalog.tuning.placementGap
		-- 1) every rot builds and faces rot x 90 degrees; the shape's axis turns with the facing
		for rot = 0, 3 do
			env.mock:advance(3) -- refill Place's burst
			local at = spot + Vector3.new(0, 0, rot * 60) -- far enough apart not to meet each other
			if not sim:canPlace(k, "wall", at.X, at.Z, rot * math.pi / 2) then
				at = freeSpot(sim, k, "wall", rot)
			end
			local id, reason = invoke(env, p1, "Build.Place", "wall", at, rot)
			expect(`{rot}:{reason}`).toBe(`{rot}:nil`)
			local b = sim.buildings[id]
			local want = rot * math.pi / 2
			expect(b.yaw % (2 * math.pi)).toBeNear(want % (2 * math.pi), 1e-6)
			expect(b.shape.ux).toBeNear(math.cos(want), 1e-6)
			expect(b.shape.uz).toBeNear(-math.sin(want), 1e-6)
			expect(b.shape.hx).toBeNear(size.X / 2, 1e-6) -- width stays the local X axis
		end
		-- 2) a turn changes what fits: next to a wall's long side, a parallel wall fits and a crosswise one does not.
		-- Pick a base where, before the first wall stands, all three are free (so only the first wall can matter).
		local keep = sim.buildings[k.keepId]
		local base, beside
		for radius = 40, 140, 10 do
			for step = 0, 23 do
				local a = step / 24 * 2 * math.pi
				local x, z = keep.x + math.cos(a) * radius, keep.z + math.sin(a) * radius
				local b2 = Vector3.new(x, 0, z + size.Y + gap + 0.5) -- beside it, not past its end
				if
					base == nil
					and sim:canPlace(k, "wall", x, z, 0)
					and sim:canPlace(k, "wall", b2.X, b2.Z, 0)
					and sim:canPlace(k, "wall", b2.X, b2.Z, math.pi / 2)
					and sim:canPlace(k, "wall", b2.X, b2.Z, -math.pi / 2)
				then
					base, beside = Vector3.new(x, 0, z), b2
				end
			end
		end
		assert(base and beside, "a spot for the wall pair")
		env.mock:advance(3)
		local first, why = invoke(env, p1, "Build.Place", "wall", base, 0)
		expect(why).toBeNil()
		expect(type(first)).toBe("number")
		env.mock:advance(3)
		expect({ invoke(env, p1, "Build.CanPlace", "wall", beside, 0) }).toEqual({ true }) -- parallel: fits
		expect({ invoke(env, p1, "Build.CanPlace", "wall", beside, 1) }).toEqual({ false, "blocked" }) -- crosswise
		expect({ invoke(env, p1, "Build.CanPlace", "wall", beside, 3) }).toEqual({ false, "blocked" })
		expect(treasury:get("crimson").wood > 0).toBe(true)
	end)
end)

describe("BuildingService build slots (G13.5, FL-0081)", function()
	local function slotsSent(env, player)
		local out = {}
		for _, entry in env.mock.remotes:sent(remote(env, "Build.Slots")) do
			if entry.player == player then
				table.insert(out, entry.args[1])
			end
		end
		return out
	end

	local function firstSlot(kingdomId, size)
		for _, slot in Layout.WORLD.plots[kingdomId].buildSlots do
			if slot.size == size then
				return slot
			end
		end
		error(`no {size} slot`)
	end

	it("PlaceSlot builds on a free slot of the player's kingdom, facing its street, at the Place price", function()
		local env, _, match, treasury = boot()
		local p1 = env.mock.players:add({ userId = 1 })
		env.mock:advance(0.5)
		local sim = match.host.match.sim
		local defs = Layout.WORLD.plots.crimson.buildSlots
		expect(#defs >= 8).toBe(true)
		local listed = invoke(env, p1, "Build.GetSlots")
		expect(#listed).toBe(#defs)
		for i, slot in listed do
			expect(slot).toEqual({ id = defs[i].id, size = defs[i].size }) -- all free
		end
		local slot = firstSlot("crimson", "S")
		local before = treasury:get("crimson")
		local id, reason = invoke(env, p1, "Build.PlaceSlot", slot.id, "house")
		expect(reason).toBeNil()
		local b = sim.buildings[id]
		expect({ b.kind, b.slotId, b.placedBy }).toEqual({ "house", slot.id, 1 })
		expect(b.x).toBeNear(slot.center.X, 1e-6)
		expect(b.z).toBeNear(slot.center.Z, 1e-6)
		expect(b.yaw).toBeNear(slot.rot, 1e-6)
		local after = treasury:get("crimson")
		for res, amount in assert(Costs.building("house", 1)).cost do
			expect(after[res]).toBe(before[res] - amount)
		end
		for _, entry in invoke(env, p1, "Build.GetSlots") do
			expect(entry.occupiedBy).toBe(if entry.id == slot.id then id else nil)
		end
		-- every S slot fits a house; an L slot (farm) takes what fits it
		local large = firstSlot("crimson", "L")
		expect(Fit.fits("farm", "L")).toBe(true)
		local farm = invoke(env, p1, "Build.PlaceSlot", large.id, "farm")
		expect(sim.buildings[farm].slotId).toBe(large.id)
	end)

	it("refuses another kingdom's or an unknown slot, a taken slot, a type that does not fit, and the poor", function()
		local env, buildings, match, treasury = boot()
		local p1 = env.mock.players:add({ userId = 1 }) -- crimson
		local p2 = env.mock.players:add({ userId = 2 }) -- another kingdom
		env.mock:advance(0.5)
		local sim = match.host.match.sim
		local theirs = match.host:kingdomOf(p2)
		expect(theirs).never.toBe("crimson")
		local slot = firstSlot("crimson", "S")
		local before = treasury:get("crimson")
		expect({ invoke(env, p1, "Build.PlaceSlot", firstSlot(theirs, "S").id, "house") }).toEqual({
			nil,
			"unknown_slot",
		})
		expect({ invoke(env, p1, "Build.PlaceSlot", "crimson_slot999", "house") }).toEqual({ nil, "unknown_slot" })
		expect(Fit.fits("barracks", "S")).toBe(false)
		expect({ invoke(env, p1, "Build.PlaceSlot", slot.id, "barracks") }).toEqual({ nil, "does_not_fit" })
		env.mock:advance(3) -- refill PlaceSlot's burst
		expect(treasury:get("crimson")).toEqual(before) -- refusals cost nothing
		local id = invoke(env, p1, "Build.PlaceSlot", slot.id, "house")
		expect(type(id)).toBe("number")
		expect({ invoke(env, p1, "Build.PlaceSlot", slot.id, "house") }).toEqual({ nil, "slot_occupied" })
		expect({ invoke(env, p2, "Build.PlaceSlot", slot.id, "house") }).toEqual({ nil, "unknown_slot" })
		-- a building on the slot that is gone frees it
		assert(sim:cancelConstruction(sim.kingdoms.crimson, id, 1))
		env.mock:advance(3)
		local poor = treasury:get("crimson")
		sim:spend("crimson", { wood = poor.wood }, "spec:drain", "spec")
		expect({ invoke(env, p1, "Build.PlaceSlot", slot.id, "house") }).toEqual({ nil, "cannot_afford" })
		expect(buildings:slots("crimson")[1].occupiedBy).toBeNil()
		-- malformed calls never reach the kingdom; a spectator is not in the match
		expect(invoke(env, p1, "Build.PlaceSlot", string.rep("x", 33), "house")).toBeNil()
		expect(invoke(env, p1, "Build.PlaceSlot", slot.id, "castle")).toBeNil()
		expect(invoke(env, p1, "Build.PlaceSlot", 7, "house")).toBeNil()
		expect({ buildings:placeSlot({ UserId = 999 }, slot.id, "house") }).toEqual({ nil, "not_in_match" })
		expect(buildings:slots("violet")).toEqual({})
	end)

	-- two angles are the same facing (radians, modulo a full turn)
	local function sameFacing(a: number, b: number): boolean
		local d = (a - b) % (2 * math.pi)
		return math.min(d, 2 * math.pi - d) < 1e-6
	end

	it(
		"PlaceSlot turns the building `turn` quarter turns from the slot's street facing, charging once (CONTRACTS v0.4-g9h)",
		function()
			local env, _, match, treasury = boot()
			local p1 = env.mock.players:add({ userId = 1 })
			env.mock:advance(0.5)
			local sim = match.host.match.sim
			for _, res in { "wood", "stone", "gold", "food" } do
				sim.treasury:deposit("crimson", res, 2000, `spec:turn:{res}`, "spec") -- cancelled sites refund in part
			end
			local slot = firstSlot("crimson", "L")
			expect(Fit.turns("house", "S")).toEqual({ 0, 2 }) -- a house in an S slot turns half a turn only
			expect(Fit.turns("house", "L")).toEqual({ 0, 1, 2, 3 }) -- in an L slot every way
			local before = treasury:get("crimson")
			local id, reason = invoke(env, p1, "Build.PlaceSlot", slot.id, "house", 1)
			expect(reason).toBeNil()
			local b = sim.buildings[id]
			expect(sameFacing(b.yaw, slot.rot + math.pi / 2)).toBe(true)
			expect(b.slotId).toBe(slot.id)
			expect(b.x).toBeNear(slot.center.X, 1e-6) -- still centred on the slot
			expect(b.z).toBeNear(slot.center.Z, 1e-6)
			local after = treasury:get("crimson")
			for res, amount in assert(Costs.building("house", 1)).cost do
				expect(after[res]).toBe(before[res] - amount) -- the same price as unturned
			end
			-- every turn is its own facing, and the placement shape turns with it
			for rot = 0, 3 do
				local spare = firstSlot("crimson", "L")
				assert(sim:cancelConstruction(sim.kingdoms.crimson, id, 1))
				env.mock:advance(3)
				local again, why = invoke(env, p1, "Build.PlaceSlot", spare.id, "house", rot)
				expect(`{rot}:{why}`).toBe(`{rot}:nil`)
				expect(type(again)).toBe("number")
				local placed = sim.buildings[again]
				expect(sameFacing(placed.yaw, spare.rot + rot * math.pi / 2)).toBe(true)
				local want = spare.rot + rot * math.pi / 2
				expect(placed.shape.ux).toBeNear(math.cos(want), 1e-6) -- Footprint.rect's local X axis
				expect(placed.shape.uz).toBeNear(-math.sin(want), 1e-6)
				id = again
			end
		end
	)

	it(
		"PlaceSlot refuses a turn the type does not fit with does_not_fit, free; bad turns never arrive (CONTRACTS v0.4-g9h)",
		function()
			local env, _, match, treasury = boot()
			local p1 = env.mock.players:add({ userId = 1 })
			env.mock:advance(0.5)
			local sim = match.host.match.sim
			for _, res in { "wood", "stone", "gold", "food" } do
				sim.treasury:deposit("crimson", res, 2000, `spec:refuse:{res}`, "spec")
			end
			local slot = firstSlot("crimson", "M")
			expect(Fit.turns("barracks", "M")).toEqual({ 0, 2 }) -- 34 x 22 turned would be 22 x 34 in 36 x 30
			local before = treasury:get("crimson")
			expect({ invoke(env, p1, "Build.PlaceSlot", slot.id, "barracks", 1) }).toEqual({ nil, "does_not_fit" })
			env.mock:advance(3)
			expect({ invoke(env, p1, "Build.PlaceSlot", slot.id, "barracks", 3) }).toEqual({ nil, "does_not_fit" })
			env.mock:advance(3)
			local function notSpent()
				for res, amount in treasury:get("crimson") do
					expect(amount >= before[res]).toBe(true) -- citizens keep gathering meanwhile: it only grows
				end
			end
			notSpent() -- refusals cost nothing
			-- values outside 0..3 are dropped by the remote's validation, never reaching the service
			for _, bad in { 4, -1, 1.5, "1", math.huge, {} } do
				env.mock:advance(3)
				expect(invoke(env, p1, "Build.PlaceSlot", slot.id, "barracks", bad)).toBeNil()
			end
			notSpent()
			for _, entry in invoke(env, p1, "Build.GetSlots") do
				expect(entry.occupiedBy).toBeNil()
			end
			-- the half turn fits: facing the other way, still in the slot
			env.mock:advance(3)
			local id, reason = invoke(env, p1, "Build.PlaceSlot", slot.id, "barracks", 2)
			expect(reason).toBeNil()
			expect(sameFacing(sim.buildings[id].yaw, slot.rot + math.pi)).toBe(true)
		end
	)

	it("a building placed with Build.Place over a slot occupies it; the other slots stay free (#89 M1)", function()
		local env, buildings, match = boot()
		local p1 = env.mock.players:add({ userId = 1 })
		env.mock:advance(0.5)
		local sim = match.host.match.sim
		-- a house turned any way stays inside an L slot (46 x 40), so no neighbouring slot is touched
		local slot = firstSlot("crimson", "L")
		local id, reason = invoke(env, p1, "Build.Place", "house", Vector3.new(slot.center.X, 0, slot.center.Z), 0)
		expect(reason).toBeNil()
		expect(sim.buildings[id].slotId).toBeNil() -- placed on the rail, not on the slot
		for _, entry in invoke(env, p1, "Build.GetSlots") do
			expect(entry.occupiedBy).toBe(if entry.id == slot.id then id else nil)
		end
		expect({ invoke(env, p1, "Build.PlaceSlot", slot.id, "farm") }).toEqual({ nil, "slot_occupied" })
		-- gone: the slot is free again
		assert(sim:cancelConstruction(sim.kingdoms.crimson, id, 1))
		for _, entry in buildings:slots("crimson") do
			expect(entry.occupiedBy).toBeNil()
		end
	end)

	it("refuses wall and gate on any plot with not_on_plot, charging nothing (G13.5 v0.4-g9a)", function()
		local env, _, match, treasury = boot()
		local p1 = env.mock.players:add({ userId = 1 })
		env.mock:advance(0.5)
		local before = treasury:get("crimson")
		for _, kind in { "wall", "gate" } do
			for _, size in { "S", "L" } do
				expect({ invoke(env, p1, "Build.PlaceSlot", firstSlot("crimson", size).id, kind) }).toEqual({
					nil,
					"not_on_plot",
				})
				env.mock:advance(0.6) -- PlaceSlot's rate
			end
		end
		expect(treasury:get("crimson")).toEqual(before)
		for _, building in match.host.match.sim.buildings do
			expect(building.kind ~= "wall" and building.kind ~= "gate").toBe(true)
		end
	end)

	it("Build.Slots goes to the kingdom's members on arrival and when a slot is taken or freed", function()
		local env, _, match = boot()
		local p1 = env.mock.players:add({ userId = 1 })
		local p2 = env.mock.players:add({ userId = 2 })
		env.mock:advance(1)
		local sim = match.host.match.sim
		expect(#slotsSent(env, p1)).toBe(1) -- on arrival
		expect(#slotsSent(env, p2)).toBe(1)
		expect(slotsSent(env, p2)[1][1].id).toBe(Layout.WORLD.plots[match.host:kingdomOf(p2)].buildSlots[1].id)
		env.mock:advance(2)
		expect(#slotsSent(env, p1)).toBe(1) -- nothing changed: nothing sent
		local slot = firstSlot("crimson", "S")
		local id = invoke(env, p1, "Build.PlaceSlot", slot.id, "house")
		env.mock:advance(1)
		local mine = slotsSent(env, p1)
		expect(#mine).toBe(2)
		for _, entry in mine[2] do
			expect(entry.occupiedBy).toBe(if entry.id == slot.id then id else nil)
		end
		expect(#slotsSent(env, p2)).toBe(1) -- another kingdom's slot: not theirs to hear
		assert(sim:cancelConstruction(sim.kingdoms.crimson, id, 1))
		env.mock:advance(1)
		mine = slotsSent(env, p1)
		expect(#mine).toBe(3)
		for _, entry in mine[3] do
			expect(entry.occupiedBy).toBeNil()
		end
	end)
end)
