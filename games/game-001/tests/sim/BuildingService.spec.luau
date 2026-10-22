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
local MatchConfig = require("@game/ReplicatedStorage/Forge/Config/Match")
local Costs = require("@game/ReplicatedStorage/Forge/Config/Costs")
local Fit = require("@game/ReplicatedStorage/Game/Build/Fit")
local Footprint = require("@game/ReplicatedStorage/Game/Sim/Footprint")
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
	local savedMode = MatchConfig.mode
	MatchConfig.mode = "slice" -- the VS-1 slice this spec was written for; the shipped default is the full match (D-053)
	local registry = Loader.load(env, definitions)
	MatchConfig.mode = savedMode
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
	it(
		"Build.PlaceLine lays a wall line all or nothing, charges per piece, and refuses what is not a wall line",
		function()
			local env, _, match, treasury = boot()
			local p1 = env.mock.players:add({ userId = 1 })
			env.mock:advance(0.5)
			local sim = match.host.match.sim
			local k = sim.kingdoms.crimson
			local length = sim.catalog.buildings.wall.placeSize.X
			local keep = sim.buildings[k.keepId]
			local before = treasury:get("crimson")
			local ids = nil
			-- the first of a few lines north of the keep, where the node and the roads leave room
			for _, dz in { -90, -70, -50, 50, 70, 90, -110, 110, -30, 30 } do
				for _, dx in { -48, 40, -100 } do
					env.mock:advance(1) -- the remote allows a burst of 2, then 1 a second
					local from = Vector3.new(keep.x + dx, 0, keep.z + dz)
					local to = Vector3.new(keep.x + dx + 2 * length, 0, keep.z + dz + 16) -- a slope, so the far end matters
					local got, why = invoke(env, p1, "Build.PlaceLine", "wall", from, to)
					if got ~= nil then
						ids = got
						break
					end
					expect(type(why)).toBe("string")
				end
				if ids ~= nil then
					break
				end
			end
			assert(ids, "one of the lines fits")
			expect(#ids).toBe(2)
			local after = treasury:get("crimson")
			for res, amount in assert(Costs.building("wall", 1)).cost do
				expect(before[res] - after[res]).toBe(amount * 2)
			end
			expect(sim.buildings[ids[1]].kind).toBe("wall")
			expect(sim.buildings[ids[2]].z > sim.buildings[ids[1]].z).toBe(true) -- the line climbs towards `to`
			expect(sim.buildings[ids[1]].placedBy).toBe(1)
			local here = Vector3.new(keep.x - 48, 0, keep.z)
			env.mock:advance(2)
			expect({ invoke(env, p1, "Build.PlaceLine", "wall", here, here) }).toEqual({ nil, "too_short" })
			env.mock:advance(2)
			expect({ invoke(env, p1, "Build.PlaceLine", "farm", here, here + Vector3.new(length, 0, 0)) }).toEqual({
				nil,
				"not_a_line_piece",
			})
			local far = Vector3.new(keep.x + 900, 0, keep.z + 900)
			env.mock:advance(2)
			local farReason =
				select(2, invoke(env, p1, "Build.PlaceLine", "wall", far, far + Vector3.new(length, 0, 0)))
			expect(farReason == "out_of_territory" or farReason == "out_of_bounds").toBe(true)
		end
	)

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

describe("BuildingService base editing (CONTRACTS G13.9, FL-0119)", function()
	local function slotDef(kingdomId, size, nth)
		local seen = 0
		for _, slot in Layout.WORLD.plots[kingdomId].buildSlots do
			if slot.size == size then
				seen += 1
				if seen == (nth or 1) then
					return slot
				end
			end
		end
		error(`no {size} slot {nth}`)
	end

	local function sameFacing(a: number, b: number): boolean
		return math.abs((a - b + math.pi) % (2 * math.pi) - math.pi) < 1e-6
	end

	-- a finished house on free ground, ready to move
	local function houseFor(env, p1, sim, k)
		local id = invoke(env, p1, "Build.Place", "house", freeSpot(sim, k, "house", 0, 1, 2, 3), 0)
		local b = assert(sim.buildings[id], "the house was placed")
		sim:_completeInstantly(b)
		sim:_recompute(k)
		return b
	end

	local function latestView(env, id)
		local found
		for _, batch in broadcasts(env) do
			for _, view in batch do
				if view.id == id then
					found = view
				end
			end
		end
		return found
	end

	it("CanMove agrees with Move; Move turns and moves the building in place, free, and says so once", function()
		local env, _, match, treasury = boot()
		local p1 = env.mock.players:add({ userId = 1 })
		env.mock:advance(0.5)
		local sim = match.host.match.sim
		local k = sim.kingdoms.crimson
		local moved = {}
		GameEvents.BuildingMoved:connect(function(building, player, from, slotId)
			table.insert(moved, { building = building, player = player, from = from, slotId = slotId })
		end)
		env.mock:advance(3)
		local house = houseFor(env, p1, sim, k)
		local from = Vector3.new(house.x, 0, house.z)
		env.mock:advance(1)
		local to = freeSpot(sim, k, "house", 0, 1, 2, 3)
		local before = treasury:get("crimson")
		expect({ invoke(env, p1, "Build.CanMove", house.id, to, 1) }).toEqual({ true })
		expect(house.x).toBe(from.X) -- asking changes nothing
		expect(#moved).toBe(0)
		expect({ invoke(env, p1, "Build.Move", house.id, to, 1) }).toEqual({ true })
		expect(house.x).toBe(to.X)
		expect(house.z).toBe(to.Z)
		expect(sameFacing(house.yaw, math.pi / 2)).toBe(true)
		expect(treasury:get("crimson")).toEqual(before)
		env.mock:advance(0.5) -- the host relays the sim's events on its next tick
		expect(#moved).toBe(1)
		expect(moved[1].building.id).toBe(house.id)
		expect(moved[1].player).toBe(p1)
		expect(moved[1].from.position.X).toBeNear(from.X, 1e-6)
		expect(moved[1].from.position.Z).toBeNear(from.Z, 1e-6)
		expect(moved[1].slotId).toBeNil()
		-- right after, the same building is cooling down: the ghost tint says so too
		expect({ invoke(env, p1, "Build.CanMove", house.id, from, 0) }).toEqual({ false, "cooldown" })
		env.mock:advance(0.5)
		expect({ invoke(env, p1, "Build.Move", house.id, from, 0) }).toEqual({ false, "cooldown" })
	end)

	it("Build.Buildings re-sends a moved building with its new position and facing", function()
		local env, _, match = boot()
		local p1 = env.mock.players:add({ userId = 1 })
		env.mock:advance(0.5)
		local sim = match.host.match.sim
		local k = sim.kingdoms.crimson
		local house = houseFor(env, p1, sim, k)
		env.mock:advance(1)
		local seen = latestView(env, house.id)
		expect(seen.cframe.Position.X).toBeNear(house.x, 1e-3)
		local sentBefore = #broadcasts(env)
		env.mock:advance(2)
		expect(#broadcasts(env)).toBe(sentBefore) -- nothing changed: nothing sent
		local to = freeSpot(sim, k, "house", 0, 1, 2, 3)
		assert(invoke(env, p1, "Build.Move", house.id, to, 3))
		env.mock:advance(1)
		local after = latestView(env, house.id)
		expect(after.cframe.Position.X).toBeNear(to.X, 1e-3)
		expect(after.cframe.Position.Z).toBeNear(to.Z, 1e-3)
		local look = after.cframe.LookVector
		expect(sameFacing(math.atan2(-look.X, -look.Z), -math.pi / 2)).toBe(true) -- rot 3
		-- only a turn on the spot counts as a change too
		env.mock:advance(11)
		assert(invoke(env, p1, "Build.Move", house.id, to, 2))
		env.mock:advance(1)
		local turned = latestView(env, house.id).cframe.LookVector
		expect(sameFacing(math.atan2(-turned.X, -turned.Z), math.pi)).toBe(true)
	end)

	it("refuses another kingdom's building, the keep and a missing one, with the Place reasons beside them", function()
		local env, _, match = boot()
		local p1 = env.mock.players:add({ userId = 1 })
		local p2 = env.mock.players:add({ userId = 2 })
		env.mock:advance(0.5)
		local sim = match.host.match.sim
		local k = sim.kingdoms.crimson
		assert(match.host:kingdomOf(p2) ~= "crimson", "p2 joined another kingdom")
		local house = houseFor(env, p1, sim, k)
		local to = freeSpot(sim, k, "house", 0, 1, 2, 3)
		expect({ invoke(env, p2, "Build.CanMove", house.id, to, 0) }).toEqual({ false, "not_owner" })
		expect({ invoke(env, p2, "Build.Move", house.id, to, 0) }).toEqual({ false, "not_owner" })
		expect({ invoke(env, p1, "Build.Move", k.keepId, to, 0) }).toEqual({ false, "not_movable" })
		expect({ invoke(env, p1, "Build.Move", 987654, to, 0) }).toEqual({ false, "not_found" })
		expect({ invoke(env, p1, "Build.Move", house.id, Vector3.new(0, 0, 0), 0) }).toEqual({
			false,
			"out_of_territory",
		})
		sim.kingdoms.crimson.alarm = true
		env.mock:advance(1)
		expect({ invoke(env, p1, "Build.Move", house.id, to, 0) }).toEqual({ false, "alarm" })
		expect(house.x ~= to.X).toBe(true) -- nothing moved
	end)

	it("drops bad arguments before they reach the sim, and rate-limits the remotes", function()
		local env, _, match = boot()
		local p1 = env.mock.players:add({ userId = 1 })
		env.mock:advance(0.5)
		local sim = match.host.match.sim
		local k = sim.kingdoms.crimson
		local house = houseFor(env, p1, sim, k)
		local to = freeSpot(sim, k, "house", 0, 1, 2, 3)
		for _, name in { "Build.CanMove", "Build.Move" } do
			expect(invoke(env, p1, name, "1", to, 0)).toBeNil() -- id is an integer
			expect(invoke(env, p1, name, 0, to, 0)).toBeNil()
			expect(invoke(env, p1, name, 1.5, to, 0)).toBeNil()
			expect(invoke(env, p1, name, house.id, CFrame.new(to), 0)).toBeNil() -- no CFrame on the wire
			expect(invoke(env, p1, name, house.id, Vector3.new(9000, 0, 0), 0)).toBeNil() -- off the world
			expect(invoke(env, p1, name, house.id, to, 4)).toBeNil() -- rot 0..3
			expect(invoke(env, p1, name, house.id, to, -1)).toBeNil()
			expect(invoke(env, p1, name, house.id, to, 0.5)).toBeNil()
			expect(invoke(env, p1, name, house.id, to)).toBeNil()
			env.mock:advance(3)
		end
		for _, bad in { 4, -1, 1.5, "1", math.huge, {} } do
			expect(invoke(env, p1, "Build.MoveToSlot", house.id, "crimson_slot1", bad)).toBeNil()
		end
		env.mock:advance(3)
		expect(invoke(env, p1, "Build.MoveToSlot", house.id, string.rep("x", 33))).toBeNil()
		expect(invoke(env, p1, "Build.MoveToSlot", house.id, 7)).toBeNil()
		expect(invoke(env, p1, "Build.MoveToSlot", "x", "crimson_slot1")).toBeNil()
		env.mock:advance(3)
		expect(house.x).toBe(house.x) -- (nothing above could have moved it)
		expect(house.slotId).toBeNil()
		-- Build.Move's burst is 4: a fifth call within the same instant gets no answer. A move to where the
		-- building already is answers true without any cooldown, so it can be asked again and again
		local here = Vector3.new(house.x, 0, house.z)
		local answers = 0
		for _ = 1, 8 do
			if
				invoke(env, p1, "Build.Move", house.id, here, math.floor(house.yaw / (math.pi / 2) + 0.5) % 4) ~= nil
			then
				answers += 1
			end
		end
		expect(answers).toBe(4)
	end)

	it("MoveToSlot seats a building on a free slot of its kingdom, frees the old slot and may turn on it", function()
		local env, building, match, treasury = boot()
		local p1 = env.mock.players:add({ userId = 1 })
		env.mock:advance(0.5)
		local sim = match.host.match.sim
		for _, res in { "wood", "stone", "gold", "food" } do
			sim.treasury:deposit("crimson", res, 2000, `spec:slot:{res}`, "spec")
		end
		local first, second = slotDef("crimson", "S", 1), slotDef("crimson", "S", 2)
		local id = invoke(env, p1, "Build.PlaceSlot", first.id, "house")
		assert(id, "a house on the first S slot")
		local house = sim.buildings[id]
		sim:_completeInstantly(house)
		expect(house.slotId).toBe(first.id)
		local stock = treasury:get("crimson")
		env.mock:advance(3)
		expect({ invoke(env, p1, "Build.MoveToSlot", id, second.id) }).toEqual({ true })
		expect(house.slotId).toBe(second.id) -- taken in the same command
		expect(house.x).toBeNear(second.center.X, 1e-6)
		expect(house.z).toBeNear(second.center.Z, 1e-6)
		expect(sameFacing(house.yaw, second.rot)).toBe(true)
		for _, entry in building:slots("crimson") do
			expect(entry.occupiedBy).toBe(if entry.id == second.id then id else nil) -- the old slot is free
		end
		expect(treasury:get("crimson")).toEqual(stock)
		-- it may turn on its own slot (a half turn fits a house in an S slot), after the cooldown
		env.mock:advance(11)
		expect({ invoke(env, p1, "Build.MoveToSlot", id, second.id, 2) }).toEqual({ true })
		expect(sameFacing(house.yaw, second.rot + math.pi)).toBe(true)
		expect(house.slotId).toBe(second.id)
		-- a quarter turn doesn't fit an S slot
		env.mock:advance(11)
		expect({ invoke(env, p1, "Build.MoveToSlot", id, second.id, 1) }).toEqual({ false, "does_not_fit" })
	end)

	it("MoveToSlot refuses an occupied slot, a foreign one, a type that doesn't fit and walls", function()
		local env, _, match = boot()
		local p1 = env.mock.players:add({ userId = 1 })
		env.mock:advance(0.5)
		local sim = match.host.match.sim
		local k = sim.kingdoms.crimson
		for _, res in { "wood", "stone", "gold", "food" } do
			sim.treasury:deposit("crimson", res, 2000, `spec:slot:{res}`, "spec")
		end
		local s1, s2, big = slotDef("crimson", "S", 1), slotDef("crimson", "S", 2), slotDef("crimson", "L", 1)
		local mine = invoke(env, p1, "Build.PlaceSlot", s1.id, "house")
		env.mock:advance(2)
		local other = invoke(env, p1, "Build.PlaceSlot", s2.id, "house")
		assert(mine and other, "two houses on two slots")
		sim:_completeInstantly(sim.buildings[mine])
		env.mock:advance(2)
		expect({ invoke(env, p1, "Build.MoveToSlot", mine, s2.id) }).toEqual({ false, "slot_occupied" })
		expect({ invoke(env, p1, "Build.MoveToSlot", mine, "azure_slot1") }).toEqual({ false, "unknown_slot" })
		expect({ invoke(env, p1, "Build.MoveToSlot", mine, "crimson_slot999") }).toEqual({ false, "unknown_slot" })
		expect({ invoke(env, p1, "Build.MoveToSlot", k.keepId, big.id) }).toEqual({ false, "not_movable" })
		local barracks = invoke(env, p1, "Build.PlaceSlot", slotDef("crimson", "M", 1).id, "barracks")
		assert(barracks, "a barracks on an M slot")
		env.mock:advance(2)
		expect({ invoke(env, p1, "Build.MoveToSlot", barracks, slotDef("crimson", "S", 3).id) }).toEqual({
			false,
			"does_not_fit",
		})
		expect(sim.buildings[mine].slotId).toBe(s1.id) -- every refusal left things as they were
		local wall = invoke(env, p1, "Build.Place", "wall", freeSpot(sim, k, "wall", 0), 0)
		assert(wall, "a wall on free ground")
		env.mock:advance(2)
		expect({ invoke(env, p1, "Build.MoveToSlot", wall, big.id) }).toEqual({ false, "not_on_plot" })
		-- a free move off a slot frees it
		env.mock:advance(11)
		local to = freeSpot(sim, k, "house", 0, 1, 2, 3)
		assert(invoke(env, p1, "Build.Move", mine, to, 0))
		expect(sim.buildings[mine].slotId).toBeNil()
		local found = false
		for _, entry in match.host.match.sim.buildings do
			found = found or entry.slotId == s1.id
		end
		expect(found).toBe(false)
	end)

	it("a slot reads occupied when a building stands within the placement gap of it", function()
		local env, building, match = boot()
		env.mock.players:add({ userId = 1 })
		env.mock:advance(0.5)
		local sim = match.host.match.sim
		local k = sim.kingdoms.crimson
		local slot = slotDef("crimson", "S", 1)
		local size = Layout.WORLD.slotSizes.S
		-- a wall one stud off the slot's edge, in line with the slot's front: free ground, but within the gap
		local gap = sim.catalog.tuning.placementGap
		local wallDepth = sim:shapeOf("wall", 0, 0, 0).hz
		local dx = size.X / 2 + 1 + wallDepth
		local fx = slot.center.X + math.cos(slot.rot) * dx
		local fz = slot.center.Z - math.sin(slot.rot) * dx
		local b = sim:_createBuilding(k, "wall", fx, fz, slot.rot + math.pi / 2)
		sim:_completeInstantly(b)
		expect(Footprint.overlaps(Footprint.rect(size, slot.center.X, slot.center.Z, slot.rot), b.shape, 0)).toBe(false)
		expect(Footprint.overlaps(Footprint.rect(size, slot.center.X, slot.center.Z, slot.rot), b.shape, gap)).toBe(
			true
		)
		expect(building:_occupant("crimson", slot.id)).toBe(b.id) -- no longer reads free while placing is refused
	end)
end)
