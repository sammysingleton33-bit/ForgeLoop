--[[
	Layout.arena and the world's Crown Arena (FL-0072, FORGE-02; CONTRACTS G12.6, D-053, D-047): the schema
	{ cframe, duelRadius, spawnA, spawnB } (+ footprint, regionId), its agreement with Kit.arena, its site (inside the heartland,
	flat ground, at least 20 studs from the watchtower zone, the hub plaza, every road and resource node, measured against the
	live Layout and the arena's real part bounds), the decor keep-out and trim protection in WorldPlan, and WorldService's one
	neutral CrownArena model. Where the arena may stand was solved over the live geometry (world/Layout.luau, the arena
	block); this spec re-measures it, so moving anything near it fails here.
]]

local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local MockEnv = require("../../../../roblox/tests/mocks/MockEnv")
local Def = require("@game/ServerScriptService/Game/Services/WorldService")
local Kit = require("@game/ReplicatedStorage/Game/Kit/Kit")
local Terrain = require("@game/ReplicatedStorage/Game/Kit/Terrain")
local WorldPlan = require("@game/ReplicatedStorage/Game/Kit/WorldPlan")
local Layout = require("@game/ReplicatedStorage/Game/World/Layout")

local ARENA = Layout.arena
local FEATURES = Layout.features
local MIN_CLEAR = 20 -- studs from the watchtower zone, the plaza, roads and nodes (the mission's rule)
local HUB_PLAZA = 14 -- WorldPlan's cobbled plaza at the hub (terrainOps)
local NODE_KEEP_OUT = 9 -- WorldPlan's keep-out disc round every resource node

local function halfExtents(p: BasePart): Vector3
	local s = p.Size
	local rv, uv, lv = p.CFrame.RightVector, p.CFrame.UpVector, p.CFrame.LookVector
	return Vector3.new(
		math.abs(rv.X) * s.X / 2 + math.abs(uv.X) * s.Y / 2 + math.abs(lv.X) * s.Z / 2,
		math.abs(rv.Y) * s.X / 2 + math.abs(uv.Y) * s.Y / 2 + math.abs(lv.Y) * s.Z / 2,
		math.abs(rv.Z) * s.X / 2 + math.abs(uv.Z) * s.Y / 2 + math.abs(lv.Z) * s.Z / 2
	)
end

-- the ground blend (a sloped skirt and a sand path at each gate, never above the apron) reaches 4 studs past the structure
local GROUND = { Skirt = true, PathRamp = true, PathSlab = true }

-- the arena's real extents on the ground plane, from the built model (not the Root plate); the structure alone, or with the blend
local function realHalf(withGround: boolean): Vector2
	local m = Kit.arena()
	local hx, hz = 0, 0
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") and d ~= m.PrimaryPart and (withGround or not GROUND[d.Name]) then
			local e, c = halfExtents(d), d.CFrame.Position
			hx = math.max(hx, math.abs(c.X) + e.X)
			hz = math.max(hz, math.abs(c.Z) + e.Z)
		end
	end
	return Vector2.new(hx, hz)
end

local REAL = realHalf(false)
local REAL_GROUND = realHalf(true)
local ARENA_RECT = { cf = ARENA.cframe, half = REAL, kind = "arena" }
local GROUND_RECT = { cf = ARENA.cframe, half = REAL_GROUND, kind = "arena" }

local function rectDist(x: number, z: number): number
	return WorldPlan.rectDistance(ARENA_RECT, x, z)
end

-- distance from the arena's rectangle to a polyline (sampled every stud)
local function polylineDist(points: { Vector2 }): number
	local best = math.huge
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local n = math.max(1, math.ceil((b - a).Magnitude))
		for k = 0, n do
			local p = a:Lerp(b, k / n)
			best = math.min(best, rectDist(p.X, p.Y))
		end
	end
	return best
end

local function inPolygon(polygon: { Vector2 }, x: number, z: number): boolean
	local inside = false
	local j = #polygon
	for i = 1, #polygon do
		local a, b = polygon[i], polygon[j]
		if (a.Y > z) ~= (b.Y > z) and x < (b.X - a.X) * (z - a.Y) / (b.Y - a.Y) + a.X then
			inside = not inside
		end
		j = i
	end
	return inside
end

local function boot()
	local env = MockEnv.new({ seed = 1 })
	local svc = Def.new(env, nil)
	svc.terrain = Terrain.recorder()
	return env, svc
end

describe("Layout.arena schema (CONTRACTS G12.6)", function()
	it("has { cframe, duelRadius, spawnA, spawnB } of the right types, plus the footprint and region", function()
		expect(typeof(ARENA)).toBe("table")
		expect(typeof(ARENA.cframe)).toBe("CFrame")
		expect(typeof(ARENA.spawnA)).toBe("CFrame")
		expect(typeof(ARENA.spawnB)).toBe("CFrame")
		expect(typeof(ARENA.duelRadius)).toBe("number")
		expect(typeof(ARENA.footprint)).toBe("Vector2")
		expect(ARENA.regionId).toBe("heartland")
		expect(ARENA.duelRadius).toBeGreaterThan(10)
		expect(ARENA.duelRadius).toBeLessThan(60)
		expect(typeof(Layout.regions[ARENA.regionId])).toBe("table")
	end)

	it("stands inside ±4,000 studs and inside the map, yaw-only on level ground", function()
		local p = ARENA.cframe.Position
		expect(math.abs(p.X)).toBeLessThan(4000)
		expect(math.abs(p.Z)).toBeLessThan(4000)
		expect(p.X - REAL.X).toBeGreaterThan(FEATURES.bounds.min.X + 100)
		expect(p.X + REAL.X).toBeLessThan(FEATURES.bounds.max.X - 100)
		expect(p.Z - REAL.Y).toBeGreaterThan(FEATURES.bounds.min.Y + 100)
		expect(p.Z + REAL.Y).toBeLessThan(FEATURES.bounds.max.Y - 100)
		expect(ARENA.cframe.UpVector.Y).toBeNear(1, 1e-6)
		expect(p.Y).toBe(WorldPlan.groundHeight(Layout, p.X, p.Z))
	end)

	it("is at the neutral centre: its centre inside the heartland region, near the valley centre", function()
		local polygon = Layout.regions.heartland.polygon
		local p = ARENA.cframe.Position
		expect(inPolygon(polygon, p.X, p.Z)).toBe(true)
		-- The centre of the valley is taken (the hub, the roads and the watchtower zone meet there), so the arena stands on the nearest
		-- ground that clears them by 20 studs: about 100 studs east. The 220 x 220 heartland square is too small to hold the arena
		-- and the 20-stud clearance both: the east gate and spawn B stand outside its east edge by at most 30 studs.
		local maxX = -math.huge
		for _, v in polygon do
			maxX = math.max(maxX, v.X)
		end
		expect(p.X + REAL.X - maxX).toBeLessThan(30)
		expect((Vector2.new(p.X, p.Z) - Vector2.new(40, 0)).Magnitude).toBeLessThan(115)
		expect(#Layout.objectives).toBeGreaterThanOrEqual(1)
	end)

	it("agrees with Kit.arena: radius, footprint and the two spawn marks", function()
		local m = Kit.arena()
		expect(ARENA.duelRadius).toBe(Kit.ARENA.DUEL_RADIUS)
		expect(ARENA.footprint).toBe(Kit.ARENA.FOOTPRINT)
		local root = m.PrimaryPart :: BasePart
		for side, want in { A = ARENA.spawnA, B = ARENA.spawnB } do
			local att = root:FindFirstChild(`Spawn{side}`) :: Attachment
			local local_ = root.CFrame * att.CFrame
			local world = ARENA.cframe * local_
			expect((world.Position - want.Position).Magnitude).toBeLessThan(1e-2)
			expect(world.LookVector:Dot(want.LookVector)).toBeNear(1, 1e-4)
		end
	end)

	it("puts the spawns inside the ring, 3 studs above the floor, facing each other", function()
		local a, b = ARENA.spawnA, ARENA.spawnB
		local c = ARENA.cframe.Position
		for _, cf in { a, b } do
			local flat = Vector3.new(cf.Position.X - c.X, 0, cf.Position.Z - c.Z)
			expect(flat.Magnitude).toBeLessThan(ARENA.duelRadius - 5)
			expect(cf.Position.Y - c.Y).toBeNear(Kit.ARENA.FLOOR_TOP + 3, 1e-3)
		end
		local ab = (b.Position - a.Position) * Vector3.new(1, 0, 1)
		expect(a.LookVector:Dot(ab.Unit)).toBeNear(1, 1e-4)
		expect(b.LookVector:Dot(-ab.Unit)).toBeNear(1, 1e-4)
		expect(ab.Magnitude).toBeNear(26, 1e-3)
	end)
end)

describe("Layout.arena site (clear of the watchtower zone, plaza, roads, nodes, plots; flat)", function()
	it("keeps at least 20 studs between the arena's real extents and every objective zone", function()
		for _, o in Layout.objectives do
			local p = o.cframe.Position
			expect(rectDist(p.X, p.Z) - o.radius).toBeGreaterThanOrEqual(MIN_CLEAR)
		end
	end)

	it("keeps at least 20 studs from the hub plaza and from every road, whatever its width", function()
		local roads = FEATURES.roads
		local last = roads[1].points[#roads[1].points]
		expect(rectDist(last.X, last.Y) - HUB_PLAZA).toBeGreaterThanOrEqual(MIN_CLEAR)
		for i, road in roads do
			local d = polylineDist(road.points) - road.width / 2
			if d < MIN_CLEAR then
				error(`road {i} comes within {d} studs of the arena`)
			end
		end
	end)

	it("keeps at least 20 studs from every resource node and 100 from the river", function()
		for _, node in Layout.resourceNodes do
			local p = node.cframe.Position
			expect(rectDist(p.X, p.Z) - NODE_KEEP_OUT).toBeGreaterThanOrEqual(MIN_CLEAR)
		end
		expect(polylineDist(FEATURES.river.points) - FEATURES.river.width / 2).toBeGreaterThan(100)
		for _, bridge in FEATURES.river.bridges do
			expect(rectDist(bridge.at.X, bridge.at.Y)).toBeGreaterThan(100)
		end
	end)

	it("keeps at least 20 studs from every plot rectangle (fields, buildings, slots, zones) and plot spawn", function()
		for _, rect in WorldPlan.reservedRects(Layout) do
			local c = rect.cf.Position
			-- a rectangle is far when its centre is further than both half-diagonals and the clearance
			local reach = REAL.Magnitude + rect.half.Magnitude + MIN_CLEAR
			expect((Vector2.new(c.X, c.Z) - Vector2.new(ARENA.cframe.Position.X, ARENA.cframe.Position.Z)).Magnitude).toBeGreaterThan(
				reach
			)
		end
		for _, kingdom in { "crimson", "azure", "emerald", "gold" } do
			local s = Layout.plots[kingdom].spawn.Position
			expect(rectDist(s.X, s.Z)).toBeGreaterThan(200)
		end
	end)

	it("keeps the nav graph's edges clear of the arena by 15 studs: no unit walks through the stands", function()
		local nodes = Layout.nav.nodes
		for _, e in Layout.nav.edges do
			local a, b = nodes[e[1]], nodes[e[2]]
			local n = math.max(1, math.ceil((b - a).Magnitude))
			for k = 0, n do
				local p = a:Lerp(b, k / n)
				expect(rectDist(p.X, p.Z)).toBeGreaterThan(15) -- the hub-azure edge passes 19.9 studs off the north-west corner
			end
		end
	end)

	it(
		"keeps the ground blend (skirt and gate paths) 14 studs off the plaza, roads, nodes and objectives, and on flat ground",
		function()
			expect(REAL_GROUND.X).toBeLessThanOrEqual(ARENA.footprint.X / 2 + Kit.ARENA.GROUND_REACH + 1e-3) -- 4 studs past the plate
			expect(REAL_GROUND.Y).toBeLessThanOrEqual(ARENA.footprint.Y / 2 + Kit.ARENA.GROUND_REACH + 1e-3)
			expect(REAL_GROUND.X).toBeGreaterThan(REAL.X + 3) -- and the paths do reach out
			local function ground(x: number, z: number): number
				return WorldPlan.rectDistance(GROUND_RECT, x, z)
			end
			for _, o in Layout.objectives do
				local p = o.cframe.Position
				expect(ground(p.X, p.Z) - o.radius).toBeGreaterThanOrEqual(14)
			end
			local roads = FEATURES.roads
			local last = roads[1].points[#roads[1].points]
			expect(ground(last.X, last.Y) - HUB_PLAZA).toBeGreaterThanOrEqual(14)
			for i, road in roads do
				local best = math.huge
				for j = 1, #road.points - 1 do
					local a, b = road.points[j], road.points[j + 1]
					local n = math.max(1, math.ceil((b - a).Magnitude))
					for k = 0, n do
						local p = a:Lerp(b, k / n)
						best = math.min(best, ground(p.X, p.Y))
					end
				end
				if best - road.width / 2 < 14 then
					error(`road {i} comes within {best - road.width / 2} studs of the arena's ground blend`)
				end
			end
			for _, node in Layout.resourceNodes do
				local p = node.cframe.Position
				expect(ground(p.X, p.Z) - NODE_KEEP_OUT).toBeGreaterThanOrEqual(10)
			end
			for _, e in Layout.nav.edges do
				local a, b = Layout.nav.nodes[e[1]], Layout.nav.nodes[e[2]]
				for k = 0, math.max(1, math.ceil((b - a).Magnitude)) do
					local p = a:Lerp(b, k / math.max(1, math.ceil((b - a).Magnitude)))
					expect(ground(p.X, p.Z)).toBeGreaterThan(10) -- no unit path crosses the sand
				end
			end
			-- the ground under the whole blend is level (the skirt and path lie on the grass at y = 0)
			for ix = -1, 1, 0.25 do
				for iz = -1, 1, 0.25 do
					local w = ARENA.cframe * Vector3.new(ix * REAL_GROUND.X, 0, iz * REAL_GROUND.Y)
					expect(WorldPlan.groundHeight(Layout, w.X, w.Z)).toBe(FEATURES.groundY)
				end
			end
		end
	)

	it(
		"stands on flat ground at y = 0 with level ground 8 studs all round (no hill under or beside the stands)",
		function()
			local gy = FEATURES.groundY
			for ix = -1, 1, 0.25 do
				for iz = -1, 1, 0.25 do
					local local_ = Vector3.new(ix * (REAL.X + 8), 0, iz * (REAL.Y + 8))
					local w = ARENA.cframe * local_
					expect(WorldPlan.groundHeight(Layout, w.X, w.Z)).toBe(gy)
				end
			end
		end
	)
end)

describe("WorldPlan keeps decor out of the arena and its surroundings are never thinned", function()
	local ALL = { crimson = true, azure = true, emerald = true, gold = true }
	local NATURAL = { forest = true, lone_tree = true, bush = true, rocks = true, flowers = true }

	it("reserves the footprint as a rectangle", function()
		local rect = WorldPlan.arenaRect(Layout)
		expect(rect).never.toBeNil()
		expect((rect :: any).half).toBe(ARENA.footprint / 2)
		expect((rect :: any).cf).toBe(ARENA.cframe)
		local none = table.clone(Layout)
		none.arena = nil
		expect(WorldPlan.arenaRect(none)).toBeNil()
	end)

	it("keeps every natural prop CLEAR.margin plus its own radius off the footprint, trimmed or not", function()
		local rect = WorldPlan.arenaRect(Layout) :: any
		for _, density in { WorldPlan.FULL_DENSITY, nil } do
			for _, p in WorldPlan.props(Layout, ALL, density) do
				if NATURAL[p.feature] then
					local q = p.cframe.Position
					local need = WorldPlan.footprintRadius(p.assetId) + WorldPlan.CLEAR.margin
					if WorldPlan.rectDistance(rect, q.X, q.Z) < need - 1e-6 then
						error(
							`{p.assetId} ({p.feature}) at ({q.X}, {q.Z}) is {WorldPlan.rectDistance(rect, q.X, q.Z)} from the arena, needs {need}`
						)
					end
					-- and never stands on the ground blend (the skirt and sand paths reach 4 studs past the plate)
					if WorldPlan.rectDistance(GROUND_RECT, q.X, q.Z) < WorldPlan.footprintRadius(p.assetId) - 1e-6 then
						error(`{p.assetId} at ({q.X}, {q.Z}) stands on the arena's ground blend`)
					end
				end
			end
		end
	end)

	it("clears decor off the arena: a tree, a bush and a boulder near the edge move or go, a far tree stays", function()
		local rect = WorldPlan.arenaRect(Layout) :: any
		local function at(local_: Vector3): CFrame
			local w = ARENA.cframe * local_
			return CFrame.new(w.X, 0, w.Z)
		end
		local hx, hz = rect.half.X, rect.half.Y
		local tree = { assetId = "tree_oak_01", cframe = at(Vector3.new(hx + 8, 0, 0)), feature = "lone_tree" }
		local bush = { assetId = "bush_01", cframe = at(Vector3.new(0, 0, hz + 6)), feature = "bush" }
		local rock = { assetId = "rock_boulder_m_01", cframe = at(Vector3.new(-hx - 5, 0, 10)), feature = "rocks" }
		local far = { assetId = "tree_oak_02", cframe = at(Vector3.new(hx + 90, 0, 0)), feature = "lone_tree" }
		local out = WorldPlan.clear(Layout, { tree, bush, rock, far })
		local kept = {}
		for _, p in out do
			kept[p.assetId] = p
			if p.assetId ~= "tree_oak_02" then
				local q = p.cframe.Position
				local need = WorldPlan.footprintRadius(p.assetId) + WorldPlan.CLEAR.margin
				expect(WorldPlan.rectDistance(rect, q.X, q.Z)).toBeGreaterThanOrEqual(need - 1e-6)
			end
		end
		expect(kept.rock_boulder_m_01).toBeNil() -- boulders are removed, not moved
		expect(kept.tree_oak_02).never.toBeNil()
		expect((kept.tree_oak_02.cframe.Position - far.cframe.Position).Magnitude).toBeLessThan(1e-6)
	end)

	it(
		"is not vacuous: the generator plants decor where a footprint would be, and the reservation keeps it off",
		function()
			-- the real arena sits in the open heartland, where the clumped generator (FORGE-02's nature pass) plants little, so the same
			-- footprint is laid over a forest stand: without the reservation decor stands on it, with it nothing does
			local c = Layout.features.forests[3].center
			local over = table.clone(Layout)
			over.arena = table.clone(ARENA)
			over.arena.cframe = CFrame.new(c.X, 0, c.Y)
			local none = table.clone(Layout)
			none.arena = nil
			local rect = WorldPlan.arenaRect(over) :: any
			local function hits(layout: any): number
				local n = 0
				for _, p in WorldPlan.clear(layout, WorldPlan.plan(layout, ALL)) do
					if NATURAL[p.feature] then
						local q = p.cframe.Position
						if
							WorldPlan.rectDistance(rect, q.X, q.Z)
							< WorldPlan.footprintRadius(p.assetId) * (p.scale or 1) + WorldPlan.CLEAR.margin
						then
							n += 1
						end
					end
				end
				return n
			end
			expect(hits(none)).toBeGreaterThan(0)
			expect(hits(over)).toBe(0)
		end
	)

	it("never thins within TRIM.arenaReach of the footprint, with every other protection taken away", function()
		-- an isolated layout: the plots, roads and objectives moved out of the way, so only the arena can protect
		local fake = table.clone(Layout)
		fake.objectives = {}
		fake.features = table.clone(Layout.features)
		fake.features.roads = {}
		fake.features.fields = {}
		fake.plots = {}
		for _, k in { "crimson", "azure", "emerald", "gold" } do
			fake.plots[k] = { anchors = { keep = CFrame.new(9000, 0, 9000) }, buildZones = {}, buildSlots = {} }
		end
		local rect = WorldPlan.arenaRect(fake) :: any
		expect(WorldPlan.TRIM.arenaReach).toBeGreaterThanOrEqual(50)
		local c = ARENA.cframe.Position
		expect(WorldPlan.unseen(fake, c.X, c.Z)).toBe(0)
		for _, off in { Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(0, 0, -1) } do
			-- 50 studs outside the footprint edge along an axis of the arena: still protected
			local reach = if off.X ~= 0 then rect.half.X else rect.half.Y
			local w = ARENA.cframe * (off * (reach + 50))
			expect(WorldPlan.unseen(fake, w.X, w.Z)).toBe(0)
			-- 90 studs out: thinnable again
			local far = ARENA.cframe * (off * (reach + 90))
			expect(WorldPlan.unseen(fake, far.X, far.Z)).toBeGreaterThan(0)
		end
		-- without the arena the same spot is unprotected
		local none = table.clone(fake)
		none.arena = nil
		expect(WorldPlan.unseen(none, c.X, c.Z)).toBeGreaterThan(0)
	end)
end)

describe("WorldService places the Crown Arena (G12.6, D-047)", function()
	it("builds exactly one neutral CrownArena at Layout.arena, tagged, with the spawn marks in place", function()
		local env, svc = boot()
		svc:start()
		env.mock:advance(30)
		expect(svc.stats.error).toBeNil()
		local tagged = env.CollectionService:GetTagged("CrownArena")
		expect(#tagged).toBe(1)
		local model = tagged[1]
		expect(model.Name).toBe("CrownArena")
		expect(model.Parent.Name).toBe("Arena")
		expect(model:GetAttribute("RegionId")).toBe("heartland")
		expect(model:GetAttribute("KitColorA")).toBe(Kit.NEUTRAL_COLOR) -- neutral until ArenaService dresses it
		expect(model:GetAttribute("KitColorB")).toBe(Kit.NEUTRAL_COLOR)
		local root = model.PrimaryPart :: BasePart
		local pivot = root.CFrame * root.PivotOffset
		expect((pivot.Position - ARENA.cframe.Position).Magnitude).toBeLessThan(1e-3)
		expect(pivot.LookVector:Dot(ARENA.cframe.LookVector)).toBeNear(1, 1e-4)
		for side, want in { A = ARENA.spawnA, B = ARENA.spawnB } do
			local att = root:FindFirstChild(`Spawn{side}`) :: Attachment
			local world = root.CFrame * att.CFrame
			expect((world.Position - want.Position).Magnitude).toBeLessThan(1e-2)
			expect(world.LookVector:Dot(want.LookVector)).toBeNear(1, 1e-4)
		end
		-- the seats are where the crowd director will find them: 72 a stand, in world space inside the footprint
		local seats = 0
		for _, a in root:GetChildren() do
			if a:IsA("Attachment") and string.match(a.Name, "^Stand%a_Row%d_Seat%d+$") then
				seats += 1
				local w = root.CFrame * a.CFrame
				expect(ARENA.cframe:PointToObjectSpace(w.Position).Y).toBeGreaterThan(1)
				expect(math.abs(ARENA.cframe:PointToObjectSpace(w.Position).X)).toBeLessThan(ARENA.footprint.X / 2)
			end
		end
		expect(seats).toBe(144)
		svc:destroy()
	end)

	it("counts the arena apart: its parts are within the cap, and the dressing's count excludes them", function()
		local env, svc = boot()
		svc:start()
		env.mock:advance(30)
		expect(svc.stats.arenaParts).toBe(Kit.partCount(Kit.arena()))
		expect(svc.stats.arenaParts).toBeLessThanOrEqual(Kit.ARENA.PART_BUDGET.cap)
		expect(svc.stats.arenaParts).toBeLessThanOrEqual(Kit.ARENA.PART_BUDGET.target)
		expect(svc.stats.parts).toBeGreaterThan(svc.stats.arenaParts)
		-- D-047: the arena in the world, at its worst dressed (two emerald dresses), still leaves the 27k ceiling's headroom: the
		-- delta of the worst dressing over the neutral build is what ArenaService adds at the Arena phase
		local emerald = Color3.fromRGB(35, 128, 95)
		local worstDelta = Kit.partCount(Kit.arena(emerald, emerald)) - svc.stats.arenaParts
		expect(worstDelta).toBeLessThan(200)
		svc:destroy()
	end)

	it(
		"makes the low parts solid and the high ones (caps, banners, the royal roof) walk-through, none touchable",
		function()
			local env, svc = boot()
			svc:start()
			env.mock:advance(30)
			local model = env.CollectionService:GetTagged("CrownArena")[1]
			local solid, through = 0, 0
			for _, d in model:GetDescendants() do
				if d:IsA("BasePart") then
					expect(d.CanTouch).toBe(false)
					if d.Name == "Row" then
						expect(d.CanCollide).toBe(true)
						solid += 1
					end
					if d.Name == "RoyalRoof" then
						expect(d.CanCollide).toBe(false)
						through += 1
					end
				end
			end
			expect(solid).toBe(8)
			expect(through).toBe(2)
			svc:destroy()
		end
	)

	it("Kit.arenaDress keeps the new dress where the arena stands (not at the world origin)", function()
		local env, svc = boot()
		svc:start()
		env.mock:advance(30)
		local model = env.CollectionService:GetTagged("CrownArena")[1]
		local root = model.PrimaryPart :: BasePart
		local pivot = root.CFrame * root.PivotOffset
		local function centreOf(dress: Instance): Vector3
			local lo, hi = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
			for _, d in dress:GetDescendants() do
				if d:IsA("BasePart") then
					local h = halfExtents(d)
					local c = d.CFrame.Position
					lo = Vector3.new(math.min(lo.X, c.X - h.X), math.min(lo.Y, c.Y - h.Y), math.min(lo.Z, c.Z - h.Z))
					hi = Vector3.new(math.max(hi.X, c.X + h.X), math.max(hi.Y, c.Y + h.Y), math.max(hi.Z, c.Z + h.Z))
				end
			end
			return (lo + hi) / 2
		end
		local before = {
			A = centreOf(model:FindFirstChild("DressA") :: Instance),
			B = centreOf(model:FindFirstChild("DressB") :: Instance),
		}
		Kit.arenaDress(model, Color3.fromRGB(190, 40, 50), Color3.fromRGB(40, 110, 210))
		for _, side in { "A", "B" } do
			local dress = model:FindFirstChild(`Dress{side}`) :: Instance
			local after = centreOf(dress)
			-- the verifier's repro moved DressA's centre from (140.8, 13.7, -40.2) to (0, 15.5, -13.7): about 141 studs
			expect(Vector2.new(after.X - before[side].X, after.Z - before[side].Z).Magnitude).toBeLessThan(1.5)
			expect(math.abs(after.Y - before[side].Y)).toBeLessThan(3)
			for _, d in dress:GetDescendants() do
				if d:IsA("BasePart") then
					local local_ = pivot:PointToObjectSpace(d.CFrame.Position) -- inside the venue's footprint round its pivot
					expect(math.abs(local_.X)).toBeLessThan(ARENA.footprint.X / 2 + 8)
					expect(math.abs(local_.Z)).toBeLessThan(ARENA.footprint.Y / 2 + 8)
				end
			end
		end
		expect((root.CFrame * root.PivotOffset).Position.X).toBeNear(pivot.Position.X, 1e-6) -- the venue itself did not move
		svc:destroy()
	end)

	it(
		"Kit.arenaDress gives the rebuilt dress the decoration physics WorldService gave the rest (nothing touchable, the high parts walk-through)",
		function()
			local env, svc = boot()
			svc:start()
			env.mock:advance(30)
			local model = env.CollectionService:GetTagged("CrownArena")[1]
			Kit.arenaDress(model, Color3.fromRGB(35, 128, 95), Color3.fromRGB(235, 185, 16))
			local function states(): { [Instance]: string }
				local out = {}
				for _, d in model:GetDescendants() do
					if d:IsA("BasePart") then
						out[d] = `{d.CanTouch}/{d.CanCollide}/{d.CanQuery}`
					end
				end
				return out
			end
			local dressParts, solid, through = 0, 0, 0
			for _, side in { "A", "B" } do
				for _, d in (model:FindFirstChild(`Dress{side}`) :: Instance):GetDescendants() do
					if d:IsA("BasePart") then
						dressParts += 1
						expect(d.CanTouch).toBe(false)
						if
							d.CFrame.Position.Y - d.Size.Y / 2
							> (model:GetAttribute("KitDecorBase") :: number) + svc.COLLIDE_HEIGHT
						then
							expect(d.CanCollide).toBe(false)
							through += 1
						else
							solid += 1
						end
					end
				end
			end
			expect(dressParts).toBeGreaterThan(150)
			expect(through).toBeGreaterThan(0)
			expect(solid).toBeGreaterThan(0)
			-- WorldService's own decorate step changes nothing on the dressed model: the dress already follows its rules
			local before = states()
			svc._decorate(model, model:GetAttribute("KitDecorBase") :: number)
			local after = states()
			for d, was in before do
				expect(after[d]).toBe(was)
			end
			svc:destroy()
		end
	)

	it("builds one arena when start() is called twice", function()
		local env, svc = boot()
		svc:start()
		svc:start()
		env.mock:advance(30)
		expect(#env.CollectionService:GetTagged("CrownArena")).toBe(1)
		svc:destroy()
	end)
end)
