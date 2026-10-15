--[[
	MoveBuilding (FL-0119, CONTRACTS G13.9 v0.4-g9j): a ruler picks up one of its own buildings and puts it down
	elsewhere. One Sim command, in place: the same record (id, level, hit points, construction progress, paid
	cost, placedBy, queue, claims), nothing charged, refunded, completed or re-placed. Refused under attack,
	during the alarm, after a war or a peace, inside the cooldown and anywhere Build.Place would refuse (plus
	the keep's own circle only, the no-build areas and the clearance around soldiers and rulers).
]]

local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local F = require("./KingdomFixtures")
local Catalog = require("@game/ReplicatedStorage/Game/Sim/Catalog")
local Commands = require("@game/ReplicatedStorage/Game/Sim/Commands")
local Diplomacy = require("@game/ReplicatedStorage/Game/Sim/Diplomacy")
local Footprint = require("@game/ReplicatedStorage/Game/Sim/Footprint")
local Military = require("@game/ReplicatedStorage/Game/Sim/Military")
local Simulation = require("@game/ReplicatedStorage/Game/Sim/Simulation")

local RULER, RIVAL = 101, 201

-- crimson at the origin (keep territory 130) and azure 300 studs east, no citizens, Military and Diplomacy
-- installed (no war grace), 5000 of everything each. The real catalog: placement rectangles from the Kit.
local function world()
	local sim = Simulation.new({ random = Random.new(11), catalog = Catalog.default() })
	local k1 = sim:addKingdom({ id = "crimson", name = "Crimson", x = 0, z = 0, populate = false })
	local k2 = sim:addKingdom({ id = "azure", name = "Azure", x = 300, z = 0, populate = false })
	Military.install(sim)
	Diplomacy.install(sim, { graceSeconds = 0 })
	assert(sim:addRuler("crimson", RULER))
	assert(sim:addRuler("azure", RIVAL))
	for _, id in { "crimson", "azure" } do
		for _, res in { "wood", "stone", "gold", "food" } do
			sim:deposit(id, res, 5000, `spec:move:{id}:{res}`, "spec")
		end
	end
	sim:_recompute(k1)
	sim:_recompute(k2)
	F.events(sim)
	return sim, k1, k2
end

-- the first spot (a ring around the keep) where `kind` fits now (the placement geometry: limits and cost
-- aside), also turned to each of `more` yaws and with `reach` studs more room along +X; `skip` spots are
-- passed over
local function free(
	sim,
	k,
	kind: string,
	yaw: number,
	skip: number?,
	more: { number }?,
	reach: number?
): (number, number)
	local keep = sim.buildings[k.keepId]
	local left = skip or 0
	for radius = 40, 110, 10 do
		for step = 0, 23 do
			local a = step / 24 * 2 * math.pi
			local x, z = keep.x + math.cos(a) * radius, keep.z + math.sin(a) * radius
			local fits = sim:_geometry(k, kind, x, z, yaw, nil)
			for _, other in more or {} do
				fits = fits and sim:_geometry(k, kind, x, z, other, nil)
			end
			if fits and (reach == nil or sim:_geometry(k, kind, x + reach, z, yaw, nil)) then
				if left == 0 then
					return x, z
				end
				left -= 1
			end
		end
	end
	error(`no free spot for {kind}`)
end

-- a finished building, paid for like any other
local function built(sim, k, kind: string, x: number, z: number, yaw: number?)
	local b = assert(sim:placeBuilding(k, kind, x, z, RULER, yaw or 0))
	sim:_completeInstantly(b)
	sim:_recompute(k)
	return b
end

local function move(sim, userId: number, b, x: number, z: number, yaw: number?)
	return Commands.execute(sim, userId, "MoveBuilding", b.id, x, z, yaw or b.yaw)
end

-- the cooldown and the lockout run on sim time
local function wait(sim, seconds: number)
	sim:advance(seconds)
	F.events(sim)
end

local function war(sim)
	Diplomacy.setRelation(sim, "crimson", "azure", "War")
end

local function enemy(sim, k2, kind: string, x: number, z: number, order: { [string]: any }?)
	local u = Military.spawnUnit(sim, k2, kind, x, z)
	u.order = order or { kind = "Hold" }
	return u
end

describe("MoveBuilding: one atomic, in-place move", function()
	it("moves a finished house to free ground: same record, one event, nothing charged", function()
		local sim, k1 = world()
		local sx, sz = free(sim, k1, "house", 0)
		local house = built(sim, k1, "house", sx, sz)
		house.hp -= 7 -- hit points are carried over exactly
		local dx, dz = free(sim, k1, "house", math.pi / 2)
		local before = table.clone(sim.treasury:get("crimson"))
		local ledger, built0, crown = #sim.treasury:ledger("crimson"), k1.stats.built, k1.crownPoints
		local level, hp, placedBy = house.level, house.hp, house.placedBy
		F.events(sim)

		local ok, err = move(sim, RULER, house, dx, dz, math.pi / 2)
		expect(err).toBe(nil)
		expect(ok).toBe(true)
		expect(rawequal(sim.buildings[house.id], house)).toBe(true) -- the very same record
		expect(house.level).toBe(level)
		expect(house.hp).toBe(hp)
		expect(house.placedBy).toBe(placedBy)
		expect(house.x).toBe(dx)
		expect(house.z).toBe(dz)
		expect(house.yaw).toBe(math.pi / 2)
		expect(house.shape).toEqual(sim:shapeOf("house", dx, dz, math.pi / 2))
		local events = F.events(sim)
		expect(F.count(events, function(e)
			return e.name == "BuildingMoved"
		end)).toBe(1)
		expect(F.count(events, function(e)
			return e.name == "BuildingPlaced" or e.name == "BuildingCompleted"
		end)).toBe(0)
		local moved = events[1]
		expect(moved.buildingId).toBe(house.id)
		expect(moved.kingdomId).toBe("crimson")
		expect(moved.kind).toBe("house")
		expect(moved.from).toEqual({ x = sx, z = sz, yaw = 0 })
		expect(moved.to).toEqual({ x = dx, z = dz, yaw = math.pi / 2 })
		expect(moved.by).toBe(RULER)
		expect(sim.treasury:get("crimson")).toEqual(before)
		expect(#sim.treasury:ledger("crimson")).toBe(ledger)
		expect(k1.stats.built).toBe(built0)
		expect(k1.crownPoints).toBe(crown)
		F.assertInvariants(sim)
	end)

	it("a move to the same spot and facing succeeds and changes nothing: no event, no cooldown", function()
		local sim, k1 = world()
		local x, z = free(sim, k1, "house", 0)
		local house = built(sim, k1, "house", x, z)
		F.events(sim)
		expect(move(sim, RULER, house, x, z, 0)).toBe(true)
		expect(#F.events(sim)).toBe(0)
		expect(house.movedAt).toBe(nil)
		-- so a real move right after is not on cooldown
		local dx, dz = free(sim, k1, "house", 0)
		expect(move(sim, RULER, house, dx, dz, 0)).toBe(true)
	end)

	it("a building does not block itself: a nudge into its own old footprint and a turn in place work", function()
		local sim, k1 = world()
		local x, z = free(sim, k1, "barracks", 0, nil, { math.pi, math.pi / 2 }, 2)
		local barracks = built(sim, k1, "barracks", x, z)
		expect(move(sim, RULER, barracks, x + 2, z, 0)).toBe(true) -- most of the new shape is the old one
		wait(sim, 11)
		expect(move(sim, RULER, barracks, x + 2, z, math.pi)).toBe(true) -- a half turn on the spot
		wait(sim, 11)
		expect(move(sim, RULER, barracks, x + 2, z, math.pi / 2)).toBe(true) -- a quarter turn
		expect(barracks.yaw).toBe(math.pi / 2)
		expect(barracks.shape).toEqual(sim:shapeOf("barracks", x + 2, z, math.pi / 2))
	end)

	it("refuses what Build.Place would refuse: another building, a resource node, an objective zone", function()
		local sim, k1 = world()
		local ax, az = free(sim, k1, "house", 0)
		local house = built(sim, k1, "house", ax, az)
		local bx, bz = free(sim, k1, "house", 0)
		local other = built(sim, k1, "house", bx, bz)
		local ok, err = move(sim, RULER, house, bx, bz, 0) -- on top of the other house
		expect(ok).toBe(false)
		expect(err).toBe("blocked")
		expect(house.x).toBe(ax) -- nothing changed
		local nx, nz = free(sim, k1, "house", 0)
		sim:addNode("tree", nx, nz)
		ok, err = move(sim, RULER, house, nx, nz, 0)
		expect(ok).toBe(false)
		expect(err).toBe("blocked")
		-- a depleted tree still blocks: it grows back
		local tree = sim.nodes[sim.nodeOrder[#sim.nodeOrder]]
		tree.amount, tree.regrow = 0, 60
		expect(sim:canMoveBuilding(k1, house.id, nx, nz, 0)).toBe(false)
		-- an objective's zone, radius plus the placement gap
		local ox, oz = free(sim, k1, "house", 0, 4)
		sim.objectives = { list = { { id = "tower", x = ox, z = oz, radius = 12 } } }
		ok, err = move(sim, RULER, house, ox, oz, 0)
		expect(ok).toBe(false)
		expect(err).toBe("blocked")
		expect(other.x).toBe(bx)
	end)

	it("destinations stay inside the keep's own circle and the map; a claimed region does not count", function()
		local sim, k1 = world()
		local x, z = free(sim, k1, "house", 0)
		local house = built(sim, k1, "house", x, z)
		-- 300 studs from the keep: far outside the 130 circle
		local ok, err = move(sim, RULER, house, 300 - 150, 150, 0)
		expect(ok).toBe(false)
		expect(err).toBe("out_of_territory")
		-- a region claimed far away: Build.Place may use it (own territory), a move may not (frontier teleport)
		sim:claimRegion("crimson", "frontier", 150, -250, 100, "spec")
		expect(sim:canPlace(k1, "house", 150, -250, 0)).toBe(true)
		ok, err = move(sim, RULER, house, 150, -250, 0)
		expect(ok).toBe(false)
		expect(err).toBe("out_of_territory")
		-- outside the map (the keep circle reaches past a small map)
		sim.bounds = { minX = -50, maxX = 50, minZ = -50, maxZ = 50 }
		ok, err = move(sim, RULER, house, 120, 0, 0)
		expect(ok).toBe(false)
		expect(err).toBe("out_of_bounds")
	end)

	it("does not check limits, keep level or cost: a move adds no building", function()
		local sim, k1 = world()
		local first = built(sim, k1, "barracks", free(sim, k1, "barracks", 0))
		local sx, sz = free(sim, k1, "barracks", 0)
		built(sim, k1, "barracks", sx, sz)
		local ex, ez = free(sim, k1, "barracks", 0)
		local placeable, why = sim:canPlace(k1, "barracks", ex, ez, 0)
		expect(placeable).toBe(false)
		expect(why).toBe("limit_reached") -- the limit of two is reached
		-- an empty treasury too
		for _, res in { "wood", "stone", "gold", "food" } do
			assert(sim:spend("crimson", { [res] = sim:balance("crimson", res) }, `spec:drain:{res}`, "spec"))
		end
		local dx, dz = free(sim, k1, "barracks", 0)
		expect(move(sim, RULER, first, dx, dz, 0)).toBe(true)
		expect(first.x).toBe(dx)
	end)

	it("canMoveBuilding answers the same as the command and changes nothing", function()
		local sim, k1 = world()
		local x, z = free(sim, k1, "house", 0)
		local house = built(sim, k1, "house", x, z)
		local dx, dz = free(sim, k1, "house", 0)
		F.events(sim)
		expect(sim:canMoveBuilding(k1, house.id, dx, dz, 0)).toBe(true)
		expect(house.x).toBe(x)
		expect(house.movedAt).toBe(nil)
		expect(#F.events(sim)).toBe(0)
		local ok, err = sim:canMoveBuilding(k1, house.id, 9999, 9999, 0)
		expect(ok).toBe(false)
		expect(err).toBe("out_of_bounds")
	end)

	it("a wall moves one section at a time and still joins its neighbour end to end", function()
		local sim, k1 = world()
		local width = sim:shapeOf("wall", 0, 0, 0).hx * 2
		local x, z = free(sim, k1, "wall", 0, nil, nil, width) -- room for a second one end to end
		local first = built(sim, k1, "wall", x, z)
		local fx, fz = free(sim, k1, "wall", 0, 12)
		local second = built(sim, k1, "wall", fx, fz)
		-- end to end with the first wall (wallGap 0): fine; half a stud inside it: blocked
		expect(sim:canMoveBuilding(k1, second.id, x + width, z, 0)).toBe(true)
		expect(sim:canMoveBuilding(k1, second.id, x + width - 0.5, z, 0)).toBe(false)
		expect(move(sim, RULER, second, x + width, z, 0)).toBe(true)
		expect(first.x).toBe(x)
	end)
end)

describe("MoveBuilding: who may move, and when", function()
	it("refuses the keep, a stranger's building, a missing one and a destroyed one", function()
		local sim, k1, k2 = world()
		local keep = sim.buildings[k1.keepId]
		local ok, err = move(sim, RULER, keep, keep.x + 5, keep.z, 0)
		expect(ok).toBe(false)
		expect(err).toBe("not_movable")
		local theirs = built(sim, k2, "house", free(sim, k2, "house", 0))
		ok, err = move(sim, RULER, theirs, theirs.x + 1, theirs.z, 0)
		expect(ok).toBe(false)
		expect(err).toBe("not_owner")
		ok, err = Commands.execute(sim, RULER, "MoveBuilding", 987654, 0, 0, 0)
		expect(ok).toBe(false)
		expect(err).toBe("not_found")
		local mine = built(sim, k1, "house", free(sim, k1, "house", 0))
		mine.destroyed = true
		ok, err = move(sim, RULER, mine, mine.x + 1, mine.z, 0)
		expect(ok).toBe(false)
		expect(err).toBe("not_found")
	end)

	it("refuses bad arguments, a frozen match and an eliminated kingdom", function()
		local sim, k1 = world()
		local house = built(sim, k1, "house", free(sim, k1, "house", 0))
		for _, args in
			{
				{ "1", 0, 0, 0 },
				{ house.id, "x", 0, 0 },
				{ house.id, 0 / 0, 0, 0 },
				{ house.id, 0, math.huge, 0 },
				{ house.id, 0, 0, 0 / 0 },
				{ house.id, 0, 0, "up" },
				{ -3, 0, 0, 0 },
				{ house.id, 0, 0, 0, 5 }, -- the slot id must be a string: no room for a fifth number
			}
		do
			local ok, err = Commands.execute(sim, RULER, "MoveBuilding", table.unpack(args))
			expect(ok).toBe(false)
			expect(err).toBe("invalid_args")
		end
		sim.active = false
		local ok, err = move(sim, RULER, house, house.x + 20, house.z, 0)
		expect(ok).toBe(false)
		expect(err).toBe("match_not_active")
		sim.active = true
		k1.alive = false
		ok, err = move(sim, RULER, house, house.x + 20, house.z, 0)
		expect(ok).toBe(false)
		expect(err).toBe("kingdom_eliminated")
	end)

	it("waits the cooldown between moves of one building (10 s of sim time), not between buildings", function()
		local sim, k1 = world()
		local house = built(sim, k1, "house", free(sim, k1, "house", 0))
		local other = built(sim, k1, "house", free(sim, k1, "house", 0))
		local x, z = free(sim, k1, "house", 0)
		expect(move(sim, RULER, house, x, z, 0)).toBe(true)
		local ok, err = move(sim, RULER, house, house.x, house.z, math.pi) -- turn it right away
		expect(ok).toBe(false)
		expect(err).toBe("cooldown")
		wait(sim, 9)
		ok, err = move(sim, RULER, house, house.x, house.z, math.pi)
		expect(err).toBe("cooldown")
		-- another building is not held by it
		local ox, oz = free(sim, k1, "house", 0)
		expect(move(sim, RULER, other, ox, oz, 0)).toBe(true)
		wait(sim, 2)
		expect(move(sim, RULER, house, house.x, house.z, math.pi)).toBe(true)
		expect(sim.catalog.tuning.moveCooldown).toBe(10)
	end)

	it("refuses while the alarm rings", function()
		local sim, k1 = world()
		local house = built(sim, k1, "house", free(sim, k1, "house", 0))
		local x, z = free(sim, k1, "house", 0)
		k1.alarm = true
		local ok, err = move(sim, RULER, house, x, z, 0)
		expect(ok).toBe(false)
		expect(err).toBe("alarm")
		k1.alarm = false
		expect(move(sim, RULER, house, x, z, 0)).toBe(true)
	end)

	it("any ruler of the kingdom may move, and only a ruler of it", function()
		local sim, k1 = world()
		assert(sim:addRuler("crimson", 102))
		assert(sim:addRuler("azure", 202))
		local house = built(sim, k1, "house", free(sim, k1, "house", 0))
		local x, z = free(sim, k1, "house", 0)
		local ok, err = move(sim, 202, house, x, z, 0) -- azure's ruler
		expect(ok).toBe(false)
		expect(err).toBe("not_owner")
		expect(move(sim, 102, house, x, z, 0)).toBe(true) -- a co-ruler of crimson
		expect(F.events(sim, "BuildingMoved")[1].by).toBe(102)
	end)
end)

describe("MoveBuilding: not while the building is under attack (g9j)", function()
	-- at war; a house, and its mirror image through the keep as the destination (far from the house)
	local function arrangement()
		local sim, k1, k2 = world()
		war(sim)
		local x, z = free(sim, k1, "house", 0)
		local house = built(sim, k1, "house", x, z)
		assert(sim:canPlace(k1, "house", -x, -z, 0), "the mirror spot is free")
		return sim, k1, k2, house, -x, -z
	end
	-- a soldier `gap` studs off the edge of the `kind` shape at (x, z), on the side away from the keep
	local function beside(sim, x: number, z: number, gap: number): (number, number)
		local hx = sim:shapeOf("house", x, z, 0).hx
		return x + (if x >= 0 then 1 else -1) * (hx + gap), z
	end

	it("an at-war unit that targets or focuses the building", function()
		local sim, k1, k2, house, x, z = arrangement()
		local u = enemy(sim, k2, "soldier", 2000, 2000)
		expect(sim:canMoveBuilding(k1, house.id, x, z, 0)).toBe(true) -- far away: fine
		u.target = { kind = "building", id = house.id }
		local ok, err = sim:canMoveBuilding(k1, house.id, x, z, 0)
		expect(ok).toBe(false)
		expect(err).toBe("under_attack")
		u.target = nil
		u.order = { kind = "Attack", focus = { kind = "building", id = house.id } }
		ok, err = sim:canMoveBuilding(k1, house.id, x, z, 0)
		expect(ok).toBe(false)
		expect(err).toBe("under_attack")
	end)

	it("an at-war unit within its range plus 30 of where the building stands", function()
		local sim, k1, k2, house, x, z = arrangement()
		local reach = sim.catalog.units.soldier.range + sim.catalog.tuning.moveThreatReach
		local ux, uz = beside(sim, house.x, house.z, reach - 1)
		local u = enemy(sim, k2, "soldier", ux, uz)
		local ok, err = sim:canMoveBuilding(k1, house.id, x, z, 0)
		expect(ok).toBe(false)
		expect(err).toBe("under_attack")
		-- one stud past the reach: allowed
		u.x, u.z = beside(sim, house.x, house.z, reach + 1)
		ok, err = sim:canMoveBuilding(k1, house.id, x, z, 0)
		expect(err).toBe(nil)
		expect(ok).toBe(true)
	end)

	it("and of where it would stand: no sliding a building onto attackers", function()
		local sim, k1, k2, house, x, z = arrangement()
		local reach = sim.catalog.units.soldier.range + sim.catalog.tuning.moveThreatReach
		local u = enemy(sim, k2, "soldier", beside(sim, x, z, reach - 1))
		local ok, err = sim:canMoveBuilding(k1, house.id, x, z, 0)
		expect(ok).toBe(false)
		expect(err).toBe("under_attack")
		u.x, u.z = beside(sim, x, z, reach + 1)
		expect(sim:canMoveBuilding(k1, house.id, x, z, 0)).toBe(true)
	end)

	it("a kingdom at peace is no threat", function()
		local sim, k1, k2, house, x, z = arrangement()
		Diplomacy.setRelation(sim, "crimson", "azure", "Peace")
		local u = enemy(sim, k2, "archer", house.x, house.z)
		u.target = { kind = "building", id = house.id }
		expect(sim:canMoveBuilding(k1, house.id, x, z, 0)).toBe(true)
	end)

	it("a building damaged in the last 10 seconds, and a burning one", function()
		local sim, k1, _, house, x, z = arrangement()
		Diplomacy.setRelation(sim, "crimson", "azure", "Peace")
		house.damagedAt = sim.time
		local ok, err = sim:canMoveBuilding(k1, house.id, x, z, 0)
		expect(ok).toBe(false)
		expect(err).toBe("under_attack")
		wait(sim, 9)
		expect(sim:canMoveBuilding(k1, house.id, x, z, 0)).toBe(false)
		wait(sim, 2)
		expect(sim:canMoveBuilding(k1, house.id, x, z, 0)).toBe(true)
		house.burning = true -- a riot's fire (FL-0082)
		ok, err = sim:canMoveBuilding(k1, house.id, x, z, 0)
		expect(ok).toBe(false)
		expect(err).toBe("under_attack")
		house.burning = nil
		expect(sim:canMoveBuilding(k1, house.id, x, z, 0)).toBe(true)
	end)

	it("a siege hit stamps the building, so a damaged wall can't dodge the ram", function()
		local sim, _, k2, house = arrangement()
		local ram = enemy(sim, k2, "ram", house.x, house.z + 4)
		ram.order = { kind = "Attack", kingdomId = "crimson" }
		local before = house.hp
		for _ = 1, 40 do
			sim:step()
			if house.damagedAt ~= nil then
				break
			end
		end
		expect(house.hp < before).toBe(true)
		expect(house.damagedAt ~= nil).toBe(true)
	end)

	it("after a war declaration or a peace nothing of either kingdom moves for 30 seconds", function()
		local sim, k1, k2 = world()
		local house = built(sim, k1, "house", free(sim, k1, "house", 0))
		local theirs = built(sim, k2, "house", free(sim, k2, "house", 0))
		local x, z = free(sim, k1, "house", 0)
		local tx, tz = free(sim, k2, "house", 0)
		assert(Commands.execute(sim, RULER, "DeclareWar", "azure"))
		for _, case in { { RULER, house, x, z }, { RIVAL, theirs, tx, tz } } do
			local ok, err = move(sim, case[1], case[2], case[3], case[4], 0)
			expect(ok).toBe(false)
			expect(err).toBe("under_attack")
		end
		wait(sim, 29)
		expect(sim:canMoveBuilding(k1, house.id, x, z, 0)).toBe(false)
		wait(sim, 2)
		expect(move(sim, RULER, house, x, z, 0)).toBe(true)
		-- and a peace starts it again
		assert(Commands.execute(sim, RULER, "ProposePeace", "azure"))
		assert(Commands.execute(sim, RIVAL, "AcceptPeace", "crimson"))
		local nx, nz = free(sim, k2, "house", 0)
		local ok, err = move(sim, RIVAL, theirs, nx, nz, 0)
		expect(ok).toBe(false)
		expect(err).toBe("under_attack")
		wait(sim, 31)
		expect(move(sim, RIVAL, theirs, nx, nz, 0)).toBe(true)
	end)
end)

describe("MoveBuilding: no building is put on a person (g9j)", function()
	it("placing or moving onto a soldier of any kingdom, at war or not, is blocked", function()
		local sim, k1, k2 = world()
		local x, z = free(sim, k1, "house", 0)
		local house = built(sim, k1, "house", x, z)
		local dx, dz = free(sim, k1, "house", 0)
		local u = enemy(sim, k2, "soldier", dx, dz) -- at peace
		expect(sim:canPlace(k1, "house", dx, dz, 0)).toBe(false)
		local ok, err = move(sim, RULER, house, dx, dz, 0)
		expect(ok).toBe(false)
		expect(err).toBe("blocked")
		-- a soldier standing well outside the shape does not block
		u.x, u.z = dx + sim:shapeOf("house", dx, dz, 0).hx + 4, dz
		expect(sim:canPlace(k1, "house", dx, dz, 0)).toBe(true)
		expect(move(sim, RULER, house, dx, dz, 0)).toBe(true)
	end)

	it("a ruler's character keeps 3 studs clear; any ruler's, the placer's own included", function()
		local sim, k1 = world()
		local x, z = free(sim, k1, "house", 0)
		local house = built(sim, k1, "house", x, z)
		local dx, dz = free(sim, k1, "house", 0)
		local hx = sim:shapeOf("house", dx, dz, 0).hx
		sim:setRulerPosition(RIVAL, dx + hx + 2, dz) -- 2 studs outside the edge: inside the 3-stud clearance
		expect(sim:canPlace(k1, "house", dx, dz, 0)).toBe(false)
		local ok, err = move(sim, RULER, house, dx, dz, 0)
		expect(ok).toBe(false)
		expect(err).toBe("blocked")
		sim:setRulerPosition(RIVAL, dx + hx + 4, dz) -- 4 outside: clear
		expect(sim:canPlace(k1, "house", dx, dz, 0)).toBe(true)
		sim:setRulerPosition(RIVAL, nil, nil)
		sim:setRulerPosition(RULER, dx, dz)
		expect(sim:canPlace(k1, "house", dx, dz, 0)).toBe(false)
		expect(sim.catalog.tuning.rulerClearance).toBe(3)
	end)

	it("the no-build areas (crop fields, plot roads, spawn pads) refuse Place and Move", function()
		local sim, k1 = world()
		local x, z = free(sim, k1, "house", 0)
		local house = built(sim, k1, "house", x, z)
		local dx, dz = free(sim, k1, "house", 0)
		sim.noBuild = { Footprint.rect(Vector2.new(20, 20), dx, dz, 0) }
		expect(sim:canPlace(k1, "house", dx, dz, 0)).toBe(false)
		local ok, err = move(sim, RULER, house, dx, dz, 0)
		expect(ok).toBe(false)
		expect(err).toBe("blocked")
		-- an area elsewhere does not matter
		sim.noBuild = { Footprint.rect(Vector2.new(20, 20), dx + 300, dz, 0) }
		expect(sim:canPlace(k1, "house", dx, dz, 0)).toBe(true)
		expect(move(sim, RULER, house, dx, dz, 0)).toBe(true)
	end)
end)

-- ------------------------------------------------------------------------------------ what stays with it
local function pose(b)
	return {
		id = b.id,
		kind = b.kind,
		level = b.level,
		pendingLevel = b.pendingLevel,
		pendingCost = b.pendingCost and table.clone(b.pendingCost) or nil,
		progress = b.progress,
		hp = b.hp,
		maxHp = b.maxHp,
		placedBy = b.placedBy,
	}
end

describe("MoveBuilding: construction, workers and queues travel with the building", function()
	it("a site keeps its progress, paid cost and hit points, and completes after the same total work", function()
		local function run(moveIt: boolean)
			local sim, k1 = world()
			local x, z = free(sim, k1, "house", 0)
			local site = assert(sim:placeBuilding(k1, "house", x, z, RULER, 0))
			local work = sim:workFor("house", 1)
			sim:addWork(site, work * 0.4)
			local before = pose(site)
			if moveIt then
				local dx, dz = free(sim, k1, "house", math.pi / 2)
				expect(move(sim, RULER, site, dx, dz, math.pi / 2)).toBe(true)
				expect(pose(site)).toEqual(before) -- nothing about the site changed but where it stands
				expect(site.level).toBe(0)
			end
			expect(sim:addWork(site, work * 0.6)).toBe(true) -- exactly the rest of the work
			return pose(site), table.clone(sim.treasury:get("crimson")), k1.stats.built, k1.crownPoints
		end
		local movedPose, movedStock, movedBuilt, movedCrown = run(true)
		local plainPose, plainStock, plainBuilt, plainCrown = run(false)
		expect(movedPose).toEqual(plainPose)
		expect(movedStock).toEqual(plainStock)
		expect(movedBuilt).toBe(plainBuilt)
		expect(movedCrown).toBe(plainCrown)
	end)

	it("an upgrade in progress keeps its level, progress and paid cost", function()
		local sim, k1 = world()
		local x, z = free(sim, k1, "house", 0)
		local house = built(sim, k1, "house", x, z)
		assert(sim:startUpgrade(k1, house.id, RULER))
		sim:addWork(house, 3)
		local before = pose(house)
		expect(before.pendingLevel).toBe(2)
		local stock, ledger = table.clone(sim.treasury:get("crimson")), #sim.treasury:ledger("crimson")
		local dx, dz = free(sim, k1, "house", 0)
		expect(move(sim, RULER, house, dx, dz, 0)).toBe(true)
		expect(pose(house)).toEqual(before)
		expect(sim.treasury:get("crimson")).toEqual(stock)
		expect(#sim.treasury:ledger("crimson")).toBe(ledger)
	end)

	it("farm workers, builders and sleepers walk to the new place; their claims and homes stay", function()
		local sim, k1 = world()
		local farm = built(sim, k1, "farm", free(sim, k1, "farm", 0))
		local house = built(sim, k1, "house", free(sim, k1, "house", 0))
		local px, pz = free(sim, k1, "house", 0)
		local site = assert(sim:placeBuilding(k1, "house", px, pz, RULER, 0))
		local farmer = sim:_spawnCitizen(k1, "farmer", farm.x, farm.z)
		local builder = sim:_spawnCitizen(k1, "builder", site.x, site.z)
		local sleeper = sim:_spawnCitizen(k1, "farmer", house.x, house.z)
		local carrier = sim:_spawnCitizen(k1, "woodcutter", farm.x, farm.z)
		farmer.activity, farmer.target, farmer.phase, farmer._route = "Farm", farm.id, "Work", { 1 }
		sim:_claim(farmer, "farm", farm.id)
		builder.activity, builder.target, builder.phase, builder._route = "Build", site.id, "Work", { 1 }
		sim:_claim(builder, "site", site.id)
		sleeper.activity, sleeper.target, sleeper.phase, sleeper.home = "Sleep", house.id, "Rest", house.id
		carrier.activity, carrier.target, carrier.phase = "Gather", "n1", "Return"
		local workers, builders = table.clone(farm.workers), table.clone(site.builders)

		local fx, fz = free(sim, k1, "farm", 0)
		expect(move(sim, RULER, farm, fx, fz, 0)).toBe(true)
		local sx, sz = free(sim, k1, "house", 0)
		expect(move(sim, RULER, site, sx, sz, 0)).toBe(true)
		local hx, hz = free(sim, k1, "house", 0)
		expect(move(sim, RULER, house, hx, hz, 0)).toBe(true)

		expect(farmer.phase).toBe("Go")
		expect(farmer._route).toBe(nil)
		expect(farmer.claim).toEqual({ kind = "farm", id = farm.id }) -- the claim stays
		expect(farm.workers).toEqual(workers)
		expect(builder.phase).toBe("Go")
		expect(builder.claim).toEqual({ kind = "site", id = site.id })
		expect(site.builders).toEqual(builders)
		expect(sleeper.phase).toBe("Go")
		expect(sleeper.home).toBe(house.id) -- homes are assigned by id
		expect(carrier.phase).toBe("Return") -- a carrier re-picks its drop-off by itself
		F.assertInvariants(sim)
	end)

	it("a barracks keeps its queue and bunks; the soldiers it trains afterwards appear at the new Rally", function()
		local sim, k1 = world()
		local bx, bz = free(sim, k1, "barracks", 0)
		local barracks = built(sim, k1, "barracks", bx, bz)
		assert(Commands.execute(sim, RULER, "Recruit", "soldier", 2))
		local queue = {}
		for _, entry in barracks.queue do
			table.insert(queue, table.clone(entry))
		end
		expect(#queue > 0).toBe(true)
		local stock = table.clone(sim.treasury:get("crimson"))
		local bunks = sim:population(k1) -- popCap, soldiers and queued units count against it

		local dx, dz = free(sim, k1, "barracks", math.pi)
		expect(move(sim, RULER, barracks, dx, dz, math.pi)).toBe(true)
		expect(barracks.queue).toEqual(queue)
		expect(sim.treasury:get("crimson")).toEqual(stock) -- no recruit_refund, no second charge
		expect(sim:population(k1)).toEqual(bunks)

		local rx, rz = Military.rallyPoint(barracks, 0)
		local spawned
		for _ = 1, 4000 do
			sim:step()
			spawned = F.events(sim, "UnitRecruited")[1]
			if spawned then
				break
			end
		end
		expect(spawned ~= nil).toBe(true)
		local unit = sim.units[spawned.unitId]
		expect((unit.x - rx) ^ 2 + (unit.z - rz) ^ 2 < 6 ^ 2).toBe(true) -- at the new Rally, not the old
	end)

	it("a moved lumber camp settles: no deliveries and no gather bonus for 30 seconds, then both again", function()
		local sim, k1 = world()
		local camp = built(sim, k1, "lumbercamp", free(sim, k1, "lumbercamp", 0))
		camp.level = 2 -- a level that speeds gathering up
		camp.maxHp, camp.hp =
			sim.catalog.buildings.lumbercamp.levels[2].hp, sim.catalog.buildings.lumbercamp.levels[2].hp
		sim:_recompute(k1)
		expect(k1.gatherBonus.wood).toBe(0.2)
		local dx, dz = free(sim, k1, "lumbercamp", 0)
		expect(sim:nearestDropoff(k1, dx, dz, "wood")).toBe(camp) -- would be the nearest once it stands there
		expect(move(sim, RULER, camp, dx, dz, 0)).toBe(true)
		expect((k1.gatherBonus.wood or 0)).toBe(0)
		expect(sim:nearestDropoff(k1, dx, dz, "wood")).toBe(sim.buildings[k1.keepId]) -- carriers go elsewhere
		wait(sim, 29)
		expect(sim:nearestDropoff(k1, dx, dz, "wood")).toBe(sim.buildings[k1.keepId])
		wait(sim, 2)
		expect(sim:nearestDropoff(k1, dx, dz, "wood")).toBe(camp)
		expect(k1.gatherBonus.wood).toBe(0.2)
		expect(camp.settleUntil).toBe(nil)
		-- a house has nothing to settle
		local house = built(sim, k1, "house", free(sim, k1, "house", 0))
		expect(move(sim, RULER, house, free(sim, k1, "house", 0, 3))).toBe(true)
		expect(house.settleUntil).toBe(nil)
	end)

	it("a move frees the slot id: Build.Move on a slot building clears it", function()
		local sim, k1 = world()
		local house = built(sim, k1, "house", free(sim, k1, "house", 0))
		house.slotId = "crimson_slot1"
		local dx, dz = free(sim, k1, "house", 0)
		assert(Commands.execute(sim, RULER, "MoveBuilding", house.id, dx, dz, 0))
		expect(house.slotId).toBe(nil)
		wait(sim, 11)
		local ex, ez = free(sim, k1, "house", 0)
		assert(Commands.execute(sim, RULER, "MoveBuilding", house.id, ex, ez, 0, "crimson_slot2"))
		expect(house.slotId).toBe("crimson_slot2") -- set in the same command
	end)

	it("is deterministic: the same seed and the same commands give the same buildings", function()
		local function run()
			local sim, k1 = world()
			local a = built(sim, k1, "house", free(sim, k1, "house", 0))
			local b = built(sim, k1, "barracks", free(sim, k1, "barracks", 0))
			move(sim, RULER, a, free(sim, k1, "house", 0))
			wait(sim, 12)
			move(sim, RULER, b, free(sim, k1, "barracks", math.pi / 2))
			move(sim, RULER, a, a.x, a.z, math.pi)
			wait(sim, 40)
			return sim:buildingViews()
		end
		expect(run()).toEqual(run())
	end)
end)
