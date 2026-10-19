--!strict
--[[
	Layout — the AI Kingdoms valley (CONTRACTS G10.1). Owner: FORGE-02. Pure data: no requires, no
	side effects; the helpers below only compute values once at require time.

	World frame (Roblox): +X east, +Z south, Y up; ground level is y = 0 (WorldService terrain top).
	Valley ≈ 1,300 × 1,300 studs; every position is within ±700 (contract limit ±4,000).
	Four kingdom plots sit in the corners and face the valley centre; a river runs north→south
	west of the central hill, where the neutral watchtower objective stands. Building models
	face -Z (Kit), so each anchor CFrame turns that front towards the valley centre.

	Ids: plots by KingdomId (crimson, azure, emerald, gold); regions "<kingdom>_home", "heartland";
	nodes "<kingdom>_<resource><n>" and "heart_<resource><n>"; objectives "watchtower", "outpost_n", "outpost_s", "outpost_w";
	build slots "<kingdom>_slot<n>" (G13.5: 10 per kingdom, 4 S + 4 M + 2 L, sizes in `slotSizes`).
	Each plot is a small town: the keep at the back, an avenue from the keep door through the yard to the
	gate, a cross street through the yard with the slots on it, the starting buildings on the flanks.
	`arena` (G12.6, FL-0072): the Crown Arena's frame, duel radius, the champions' marks and its footprint, inside the heartland.
	Visual features (`features`) are FORGE-02's own shape, read only by WorldService.
	The dressing density knob (D-047) lives here: `features.density` (forest, props), see below.
]]

local CENTRE = Vector3.new(40, 0, 0)

-- CFrame at `pos` whose -Z (Kit front) faces `target` on the XZ plane.
local function facing(pos: Vector3, target: Vector3): CFrame
	local d = target - pos
	local yaw = math.atan2(-d.X, -d.Z)
	return CFrame.new(pos) * CFrame.Angles(0, yaw, 0)
end

local function v(x: number, z: number): Vector3
	return Vector3.new(x, 0, z)
end

-- ---------------------------------------------------------------- river and bridges (shared by nav + features)
local RIVER = {
	Vector2.new(-60, -660),
	Vector2.new(-80, -420),
	Vector2.new(-118, -210),
	Vector2.new(-100, -40),
	Vector2.new(-70, 90),
	Vector2.new(-108, 230),
	Vector2.new(-60, 420),
	Vector2.new(-30, 680),
}
local BRIDGE_HALF = 30 -- Kit bridge_stone stand-in: ramps reach the ground 30 studs from the centre
local BRIDGE_DECK_Y = 3.8 -- deck top of the bridge stand-in (units walk over it)

-- Bridge across the river at latitude z: centre on the river line, axis perpendicular to the flow.
local function bridgeAt(z: number)
	for i = 1, #RIVER - 1 do
		local a, b = RIVER[i], RIVER[i + 1]
		if z >= a.Y and z <= b.Y then
			local t = (z - a.Y) / (b.Y - a.Y)
			local centre = a:Lerp(b, t)
			local flow = (b - a).Unit
			local across = Vector2.new(flow.Y, -flow.X) -- perpendicular, pointing roughly +X (east)
			if across.X < 0 then
				across = -across
			end
			return {
				at = centre,
				yaw = math.deg(math.atan2(across.X, across.Y)),
				west = centre - across * BRIDGE_HALF,
				east = centre + across * BRIDGE_HALF,
			}
		end
	end
	error(`Layout: no river segment at z = {z}`)
end
local BRIDGE_N = bridgeAt(-150)
local BRIDGE_S = bridgeAt(170)

-- ---------------------------------------------------------------- nav graph
-- Nodes are added in order; edges reference node indices. Roads follow the same polylines.
local nodes: { Vector3 } = {}
local edges: { { number } } = {}
local function node(x: number, z: number): number
	table.insert(nodes, v(x, z))
	return #nodes
end
local function link(a: number, b: number)
	table.insert(edges, { a, b })
end
local function chain(list: { number })
	for i = 1, #list - 1 do
		link(list[i], list[i + 1])
	end
end

-- Kingdom plot definitions: corner centre and the direction its keep faces (valley centre).
local KINGDOMS = {
	{ id = "crimson", centre = v(-330, -320) },
	{ id = "azure", centre = v(380, -320) },
	{ id = "emerald", centre = v(-330, 340) },
	{ id = "gold", centre = v(380, 340) },
}

-- Plot-local offsets (studs) in the keep's frame: x right, z towards the back (keep front is -Z).
local ANCHOR_OFFSETS = {
	keep = Vector3.new(0, 0, 0),
	storehouse = Vector3.new(-46, 0, -18),
	farm = Vector3.new(58, 0, -6),
	lumbercamp = Vector3.new(-64, 0, 40),
	quarry = Vector3.new(52, 0, 50),
}

-- Build slots (CONTRACTS G13.5): predefined plots for Build.PlaceSlot. Sizes in studs, slot-local
-- (X = width across the slot's front, Y = depth); a building placed on a slot uses
-- CFrame.new(center) * CFrame.Angles(0, rot, 0), so its -Z front faces the street.
local SLOT_SIZES = {
	S = Vector2.new(24, 20), -- house (all levels)
	M = Vector2.new(36, 30), -- barracks, storehouse, market, granary, infirmary, blacksmith, shrine
	L = Vector2.new(46, 40), -- farm, lumber camp, quarry, mine
}
-- Plot-local slot plan in the keep frame: { x, z, size, yaw }. Yaw pi faces the cross street (+Z, towards
-- the keep); +-pi/2 faces the avenue or the lumber camp and quarry lanes; 0 faces the valley.
local SLOT_PLAN = {
	{ -20, -82, "S", math.pi },
	{ 20, -82, "S", math.pi },
	{ -24, -107, "S", -math.pi / 2 },
	{ 24, -107, "S", math.pi / 2 },
	{ -58, -85, "M", math.pi },
	{ 58, -85, "M", math.pi },
	{ -100, -40, "M", 0 },
	{ 100, -40, "M", 0 },
	{ -106, 12, "L", -math.pi / 2 },
	{ 106, 10, "L", math.pi / 2 },
}

local plots = {}
local plotRoads: { [string]: { Vector2 } } = {}
local plotPaths: { { kingdom: string, name: string, width: number, points: { Vector2 } } } = {}
local plotFields = {}
local resourceNodes = {}
local regions: { [string]: { kingdom: string?, polygon: { Vector2 } } } = {}
local plotNav: { [string]: { [string]: number } } = {}

local function toWorld(frame: CFrame, offset: Vector3): Vector3
	return (frame * CFrame.new(offset)).Position
end

for _, k in KINGDOMS do
	local keepCF = facing(k.centre, CENTRE)
	local anchors = {}
	for name, off in ANCHOR_OFFSETS do
		local p = toWorld(keepCF, off)
		anchors[name] = facing(p, toWorld(keepCF, Vector3.new(0, 0, -60))) -- face the plot's front yard
	end
	anchors.keep = keepCF
	local spawn = keepCF * CFrame.new(0, 3, -34) -- in front of the keep door, standing height above ground

	-- build zones: the front yard and the two flanks of the plot
	local buildZones = {
		{ id = `{k.id}_yard`, center = toWorld(keepCF, Vector3.new(0, 0, -70)), size = Vector2.new(90, 50) },
		{ id = `{k.id}_west`, center = toWorld(keepCF, Vector3.new(-80, 0, -40)), size = Vector2.new(50, 60) },
		{ id = `{k.id}_east`, center = toWorld(keepCF, Vector3.new(80, 0, -40)), size = Vector2.new(50, 60) },
	}

	-- build slots along the cross street, the avenue and the flanks (G13.5)
	local buildSlots = {}
	for i, s in SLOT_PLAN do
		local cf = keepCF * CFrame.new(s[1], 0, s[2]) * CFrame.Angles(0, s[4], 0)
		local look = cf.LookVector
		table.insert(buildSlots, {
			id = `{k.id}_slot{i}`,
			center = cf.Position,
			size = s[3],
			rot = math.atan2(-look.X, -look.Z),
		})
	end

	-- plot nav: keep door, yard, storehouse, farm, lumber camp, quarry, gate (towards the valley),
	-- and the cross street in front of the slots (west1/west2, east1/east2)
	local function at(x: number, z: number): number
		local p = toWorld(keepCF, Vector3.new(x, 0, z))
		return node(p.X, p.Z)
	end
	local n = {
		keep = node(toWorld(keepCF, Vector3.new(0, 0, -30)).X, toWorld(keepCF, Vector3.new(0, 0, -30)).Z),
		yard = node(toWorld(keepCF, Vector3.new(0, 0, -62)).X, toWorld(keepCF, Vector3.new(0, 0, -62)).Z),
		storehouse = node(toWorld(keepCF, Vector3.new(-46, 0, -34)).X, toWorld(keepCF, Vector3.new(-46, 0, -34)).Z),
		farm = node(toWorld(keepCF, Vector3.new(58, 0, -26)).X, toWorld(keepCF, Vector3.new(58, 0, -26)).Z),
		lumbercamp = node(toWorld(keepCF, Vector3.new(-64, 0, 18)).X, toWorld(keepCF, Vector3.new(-64, 0, 18)).Z),
		quarry = node(toWorld(keepCF, Vector3.new(52, 0, 26)).X, toWorld(keepCF, Vector3.new(52, 0, 26)).Z),
		gate = node(toWorld(keepCF, Vector3.new(0, 0, -110)).X, toWorld(keepCF, Vector3.new(0, 0, -110)).Z),
	}
	link(n.keep, n.yard)
	link(n.yard, n.storehouse)
	link(n.yard, n.farm)
	link(n.storehouse, n.lumbercamp)
	link(n.farm, n.quarry)
	link(n.yard, n.gate)
	n.west1, n.west2, n.east1, n.east2 = at(-58, -62), at(-100, -62), at(58, -62), at(100, -62)
	chain({ n.west2, n.west1, n.yard, n.east1, n.east2 })
	plotNav[k.id] = n

	-- plot roads: the avenue (keep door -> yard -> gate), continued into the valley below, and the cross street
	local function flat(x: number, z: number): Vector2
		local p = toWorld(keepCF, Vector3.new(x, 0, z))
		return Vector2.new(p.X, p.Z)
	end
	plotRoads[k.id] = { flat(0, -36), flat(0, -62), flat(0, -110) }
	plotRoads[`{k.id}_street`] = { flat(-110, -62), flat(0, -62), flat(110, -62) }
	-- Worn lanes between the plot's buildings (`features.paths`, drawn as dirt by Kit/WorldGround; the ground only). They are
	-- NOT features.roads on purpose: the sim reserves every road near a keep as no-build ground (Kingdom/Layout), and a lane
	-- must never take a slot's or a field's place. Points are in the keep's frame (x right, z back; the keep door is at
	-- z = -23, the yard crossroads at z = -62); each lane ends in front of a building door, a work area or a slot front.
	local function lane(name: string, width: number, pts: { { number } })
		local line = {}
		for _, p in pts do
			table.insert(line, flat(p[1], p[2]))
		end
		table.insert(plotPaths, { kingdom = k.id, name = name, width = width, points = line })
	end
	lane("keep", 8, { { 0, -26 }, { 0, -32 } })
	lane("storehouse", 7, { { -12, -40 }, { -24, -34 }, { -37, -28 } })
	lane("farm", 7, { { 12, -40 }, { 28, -32 }, { 44, -21 } })
	lane("fields", 6, { { 28, -32 }, { 27, -10 }, { 26, 14 }, { 24, 34 }, { 24, 64 } })
	lane("quarry", 7, { { 26, 14 }, { 30, 30 }, { 37, 38 }, { 43, 36 } })
	lane("quarry_slot", 6, { { 58, 33 }, { 72, 24 }, { 82, 19 } })
	lane("stone", 6, { { 66, 58 }, { 80, 60 } })
	lane("lumbercamp", 7, { { -70, -62 }, { -76, -36 }, { -74, -8 }, { -72, 16 }, { -60, 28 } })
	lane("lumber_slot", 6, { { -72, 14 }, { -82, 14 } })
	lane("timber", 6, { { -58, 58 }, { -62, 66 }, { -66, 73 } })

	-- farmland behind the keep, turned with the plot (clear of slots, wood nodes and the quarry)
	local look = keepCF.LookVector
	local keepYaw = math.atan2(-look.X, -look.Z)
	for i, off in { Vector2.new(0, 50), Vector2.new(0, 86), Vector2.new(44, 86) } do
		table.insert(plotFields, {
			center = flat(off.X, off.Y),
			size = Vector2.new(40, 30),
			yaw = keepYaw,
			crop = if i == 2 then "cabbage" else "wheat",
		})
	end
	-- lanes to the flank slots: west3 by the lumber camp, east3 between the farm and the quarry
	n.west3, n.east3 = at(-82, 14), at(82, 22)
	link(n.west3, n.lumbercamp)
	link(n.east3, n.quarry)

	plots[k.id] = {
		spawn = spawn,
		regionId = `{k.id}_home`,
		anchors = anchors,
		buildZones = buildZones,
		buildSlots = buildSlots,
	}

	-- home region: a square around the plot, clipped short of the river/centre
	local c = k.centre
	regions[`{k.id}_home`] = {
		kingdom = k.id,
		polygon = {
			Vector2.new(c.X - 150, c.Z - 140),
			Vector2.new(c.X + 150, c.Z - 140),
			Vector2.new(c.X + 150, c.Z + 140),
			Vector2.new(c.X - 150, c.Z + 140),
		},
	}

	-- resource nodes around the plot: 4 wood (forest edge behind the lumber camp), 2 stone (by the quarry),
	-- 1 gold (ore), 2 food (berry bushes near the farm). FL-0124 (D-052 (4)): every node stands clear of the crop
	-- fields, build zones and slots (8 studs), the starting buildings (5 studs from their footprints) and the walking
	-- paths by what its Kit model DRAWS (tests/world/NodeKeepOut.spec measures the live Kit.prop extent), so no rock or
	-- bush sits on or crowds a farm. The stone and ore form an arc around the quarry, the berries flank the farm
	-- building; the offsets are in the keep's frame, so the four plots stay rotated copies of each other (per-kingdom
	-- fairness, #94).
	local function addNode(
		resource: string,
		assetId: string,
		offset: Vector3,
		amount: number,
		regrow: number,
		nav: number
	)
		local p = toWorld(keepCF, offset)
		local cf = CFrame.new(p) * CFrame.Angles(0, (#resourceNodes * 1.7) % (2 * math.pi), 0)
		local spots = {}
		for i = 0, 2 do
			local a = i * 2.1 + 0.4
			table.insert(spots, p + Vector3.new(math.cos(a) * 5, 0, math.sin(a) * 5))
		end
		local count = 0
		for _, rn in resourceNodes do
			if string.sub(rn.id, 1, #k.id + 1 + #resource) == `{k.id}_{resource}` then
				count += 1
			end
		end
		table.insert(resourceNodes, {
			id = `{k.id}_{resource}{count + 1}`,
			resource = resource,
			assetId = assetId,
			cframe = cf,
			amount = amount,
			regrowSec = regrow,
			workSpots = spots,
			navNode = nav,
		})
	end
	local trees = { "tree_oak_01", "tree_oak_03", "tree_pine_02", "tree_oak_05" }
	for i, t in trees do
		-- the second tree's canopy used to cover the lumber camp (18 studs from it): it stands 34 studs back now;
		-- the fourth stands 4 studs further from the first crop field (its canopy was too close to it)
		local x = -80 + (i - 1) * 14 - (if i == 4 then 4 else 0)
		local z = if i == 2 then 74 else 58 + (i % 2) * 10
		addNode("wood", t, Vector3.new(x, 0, z), 120, 90, n.lumbercamp)
	end
	addNode("stone", "resource_stone_01", Vector3.new(40, 0, 28), 200, 0, n.quarry)
	addNode("stone", "resource_stone_02", Vector3.new(80, 0, 60), 200, 0, n.quarry)
	addNode("gold", "resource_ore_03", Vector3.new(70, 0, 34), 80, 0, n.quarry)
	addNode("food", "bush_03", Vector3.new(40, 0, -24), 60, 45, n.farm)
	addNode("food", "bush_03", Vector3.new(74, 0, 14), 60, 45, n.farm)
end

-- ---------------------------------------------------------------- valley roads, bridges, heartland
local function join(a: { Vector2 }, b: { Vector2 }): { Vector2 }
	local out = table.clone(a)
	for _, p in b do
		table.insert(out, p)
	end
	return out
end
local hub = node(CENTRE.X - 20, CENTRE.Z) -- crossroads in front of the watchtower
local tower = node(CENTRE.X + 10, CENTRE.Z - 6)
link(hub, tower)
local function bridgeNodes(b): { number }
	local w = node(b.west.X, b.west.Y)
	local deck = node(b.at.X, b.at.Y)
	nodes[deck] = Vector3.new(b.at.X, BRIDGE_DECK_Y, b.at.Y) -- on the deck, above the river
	local e = node(b.east.X, b.east.Y)
	b.navNodes = { w, deck, e }
	return { w, deck, e }
end
local bridgeN = bridgeNodes(BRIDGE_N)
local bridgeS = bridgeNodes(BRIDGE_S)
local westN = node(-190, -230)
local westS = node(-190, 245)
local eastN = node(230, -220)
local eastS = node(240, 230)
chain({ plotNav.crimson.gate, westN, bridgeN[1], bridgeN[2], bridgeN[3], hub })
chain({ plotNav.emerald.gate, westS, bridgeS[1], bridgeS[2], bridgeS[3], hub })
chain({ plotNav.azure.gate, eastN, hub })
chain({ plotNav.gold.gate, eastS, hub })

-- Neutral outposts (Operation Crownfall, FL-0127): three capture points besides the central watchtower, for FORGE-01's
-- FL-0126 (it gives them config rows: territory radius, Crown Points, capture time; the world only places them).
-- North and south stand on the valley's north and south edges between the two kingdoms of each side; the west outpost
-- stands on the west bank, to balance the river the two western kingdoms must cross to reach the watchtower.
-- Each is 330-365 studs from its nearest kingdoms and 80+ studs clear of every forest stand, hill and the river.
local OUTPOST_N, OUTPOST_S, OUTPOST_W = v(40, -330), v(30, 315), v(-430, 10)
local outN, outS, outW = node(OUTPOST_N.X, OUTPOST_N.Z), node(OUTPOST_S.X, OUTPOST_S.Z), node(OUTPOST_W.X, OUTPOST_W.Z)
link(eastN, outN) -- the north outpost hangs off the azure road, the south one off the gold road
link(eastS, outS)
link(westN, outW) -- the west outpost joins both west-bank roads
link(westS, outW)
-- heartland stone + gold nodes near the tower (contested)
table.insert(resourceNodes, {
	id = "heart_stone1",
	resource = "stone",
	assetId = "resource_stone_03",
	cframe = CFrame.new(CENTRE + Vector3.new(60, 0, 40)),
	amount = 400,
	regrowSec = 0,
	workSpots = { CENTRE + Vector3.new(54, 0, 36), CENTRE + Vector3.new(66, 0, 36), CENTRE + Vector3.new(60, 0, 47) },
	navNode = hub,
})
table.insert(resourceNodes, {
	id = "heart_gold1",
	resource = "gold",
	assetId = "resource_ore_04",
	cframe = CFrame.new(CENTRE + Vector3.new(-30, 0, -60)),
	amount = 200,
	regrowSec = 0,
	workSpots = {
		CENTRE + Vector3.new(-36, 0, -56),
		CENTRE + Vector3.new(-24, 0, -56),
		CENTRE + Vector3.new(-30, 0, -50),
	},
	navNode = hub,
})

regions.heartland = {
	kingdom = nil,
	polygon = {
		Vector2.new(CENTRE.X - 110, CENTRE.Z - 110),
		Vector2.new(CENTRE.X + 110, CENTRE.Z - 110),
		Vector2.new(CENTRE.X + 110, CENTRE.Z + 110),
		Vector2.new(CENTRE.X - 110, CENTRE.Z + 110),
	},
}

-- one small neutral region per outpost (the sim maps an objective to its region for ownership)
for id, at in { outpost_n = OUTPOST_N, outpost_s = OUTPOST_S, outpost_w = OUTPOST_W } do
	regions[id] = {
		kingdom = nil,
		polygon = {
			Vector2.new(at.X - 70, at.Z - 70),
			Vector2.new(at.X + 70, at.Z - 70),
			Vector2.new(at.X + 70, at.Z + 70),
			Vector2.new(at.X - 70, at.Z + 70),
		},
	}
end

local objectives = {
	{
		id = "watchtower",
		kind = "capture",
		cframe = facing(CENTRE + Vector3.new(10, 0, -6), v(-330, -320)),
		radius = 26,
		regionId = "heartland",
		navNode = tower,
	},
	-- the outposts face the watchtower (their neutral tower's front looks at the valley centre)
	{
		id = "outpost_n",
		kind = "capture",
		cframe = facing(OUTPOST_N, CENTRE),
		radius = 20,
		regionId = "outpost_n",
		navNode = outN,
	},
	{
		id = "outpost_s",
		kind = "capture",
		cframe = facing(OUTPOST_S, CENTRE),
		radius = 20,
		regionId = "outpost_s",
		navNode = outS,
	},
	{
		id = "outpost_w",
		kind = "capture",
		cframe = facing(OUTPOST_W, CENTRE),
		radius = 20,
		regionId = "outpost_w",
		navNode = outW,
	},
}

-- ---------------------------------------------------------------- Crown Arena (FL-0072, CONTRACTS G12.6, D-053)
-- The final duel's venue, at the neutral valley centre: inside the heartland region, east of the watchtower on the open ground between
-- the azure and gold roads and the east hill, with its Gate A turned to the hub and the watchtower. The centre itself is taken (the
-- four roads, the hub plaza and the watchtower zone converge there), so the site was solved over the live geometry: the largest
-- free disc in the heartland has a radius of about 62 studs from any road, node or zone; the arena's 75 x 74 plate fits with at least
-- 20 studs to the watchtower zone, the plaza, every road and every resource node, and flat ground (tests/world/ArenaLayout.spec
-- re-measures all of it against the live Layout and Kit.arena's real bounds, so moving anything near it fails there).
-- cframe: the arena's frame on the ground (Kit.arena's pivot is the ring centre; its X axis is the gate axis, Gate A at -X). spawnA and
-- spawnB are the champions' marks, 3 studs above the ring floor, 26 studs apart, each facing the other (Kit.arena has the same
-- attachments, SpawnA / SpawnB); duelRadius is the painted ring, from the ring centre. footprint: the plate (X = gate axis, Y = stand
-- axis) WorldPlan keeps decor off. The numbers below mirror Kit/Arena.luau (RING, SPAWN_X, FLOOR_TOP + SPAWN_HEIGHT, FOOTPRINT); the spec
-- pins them to each other.
local ARENA_AT = v(141, -27)
local ARENA_CF = CFrame.new(ARENA_AT)
local arena = {
	cframe = ARENA_CF,
	duelRadius = 21,
	spawnA = ARENA_CF * CFrame.new(-13, 4.12, 0) * CFrame.Angles(0, -math.pi / 2, 0),
	spawnB = ARENA_CF * CFrame.new(13, 4.12, 0) * CFrame.Angles(0, math.pi / 2, 0),
	footprint = Vector2.new(75, 74),
	regionId = "heartland",
}

-- ---------------------------------------------------------------- visual features (WorldService only)
local features = {
	groundY = 0,
	bounds = { min = Vector2.new(-660, -640), max = Vector2.new(700, 680) },
	river = {
		width = 34,
		depth = 9,
		points = RIVER,
		bridges = {
			{ at = BRIDGE_N.at, yaw = BRIDGE_N.yaw, navNodes = BRIDGE_N.navNodes, deckY = BRIDGE_DECK_Y },
			{ at = BRIDGE_S.at, yaw = BRIDGE_S.yaw, navNodes = BRIDGE_S.navNodes, deckY = BRIDGE_DECK_Y },
		},
	},
	roads = {
		{
			width = 12,
			points = join(plotRoads.crimson, {
				Vector2.new(-190, -230),
				Vector2.new(-160, -170),
				BRIDGE_N.west,
				BRIDGE_N.east,
				Vector2.new(-40, -90),
				Vector2.new(20, 0),
			}),
		},
		{
			width = 12,
			points = join(plotRoads.emerald, {
				Vector2.new(-190, 245),
				Vector2.new(-150, 190),
				BRIDGE_S.west,
				BRIDGE_S.east,
				Vector2.new(-20, 90),
				Vector2.new(20, 0),
			}),
		},
		{
			width = 12,
			points = join(plotRoads.azure, {
				Vector2.new(230, -220),
				Vector2.new(170, -150),
				Vector2.new(90, -90),
				Vector2.new(20, 0),
			}),
		},
		{
			width = 12,
			points = join(plotRoads.gold, {
				Vector2.new(240, 230),
				Vector2.new(180, 160),
				Vector2.new(100, 90),
				Vector2.new(20, 0),
			}),
		},
		-- spurs to the neutral outposts (FL-0127)
		{
			width = 10,
			spur = true, -- WorldPlan protects only a narrow band of a spur from the trim
			points = { Vector2.new(230, -220), Vector2.new(140, -285), Vector2.new(OUTPOST_N.X, OUTPOST_N.Z) },
		},
		{
			width = 10,
			spur = true, -- WorldPlan protects only a narrow band of a spur from the trim
			points = { Vector2.new(240, 230), Vector2.new(130, 280), Vector2.new(OUTPOST_S.X, OUTPOST_S.Z) },
		},
		{
			width = 10,
			spur = true, -- WorldPlan protects only a narrow band of a spur from the trim
			points = { Vector2.new(-190, -230), Vector2.new(-320, -110), Vector2.new(OUTPOST_W.X, OUTPOST_W.Z) },
		},
		{
			width = 10,
			spur = true, -- WorldPlan protects only a narrow band of a spur from the trim
			points = { Vector2.new(-190, 245), Vector2.new(-320, 130), Vector2.new(OUTPOST_W.X, OUTPOST_W.Z) },
		},
		{ width = 10, points = plotRoads.crimson_street },
		{ width = 10, points = plotRoads.azure_street },
		{ width = 10, points = plotRoads.emerald_street },
		{ width = 10, points = plotRoads.gold_street },
	},
	hills = (function()
		local h = {
			{ center = Vector2.new(-200, -20), radius = 60, height = 12 },
			{ center = Vector2.new(240, -40), radius = 70, height = 16 },
			{ center = Vector2.new(170, 420), radius = 60, height = 12 },
			{ center = Vector2.new(-160, -440), radius = 55, height = 10 },
		}
		-- mountain ring framing the valley (also hides the world edge)
		local ring = {}
		for x = -600, 640, 150 do
			table.insert(ring, { Vector2.new(x, -720), 1 })
			table.insert(ring, { Vector2.new(x + 40, 760), 1 })
		end
		for z = -560, 640, 150 do
			table.insert(ring, { Vector2.new(-740, z), 1 })
			table.insert(ring, { Vector2.new(780, z + 40), 1 })
		end
		for i, r in ring do
			local wobble = ((i * 37) % 11) / 10
			table.insert(h, { center = r[1], radius = 100 + wobble * 10, height = 70 + wobble * 38 })
		end
		return h
	end)(),
	forests = { -- ~220 trees: forest stand-ins were 6.4k of 11.5k world parts (FORGE-05 review of #28)
		{ center = Vector2.new(-480, -170), radius = 110, count = 28, species = { "tree_pine", "tree_oak" } },
		{ center = Vector2.new(-250, 40), radius = 90, count = 22, species = { "tree_oak", "tree_birch" } },
		{ center = Vector2.new(250, 60), radius = 100, count = 24, species = { "tree_oak", "tree_birch" } },
		{ center = Vector2.new(540, -180), radius = 110, count = 28, species = { "tree_pine", "tree_oak" } },
		{ center = Vector2.new(-460, 520), radius = 110, count = 24, species = { "tree_pine" } },
		{ center = Vector2.new(500, 540), radius = 110, count = 24, species = { "tree_pine", "tree_oak" } },
		{ center = Vector2.new(-60, -420), radius = 90, count = 20, species = { "tree_oak", "tree_pine" } },
		{ center = Vector2.new(60, 430), radius = 90, count = 20, species = { "tree_oak", "tree_birch" } },
		{ center = Vector2.new(-460, -480), radius = 80, count = 16, species = { "tree_pine" } },
		{ center = Vector2.new(560, -500), radius = 80, count = 16, species = { "tree_pine", "tree_birch" } },
	},
	fields = plotFields, -- { center: Vector2, size: Vector2, yaw: number, crop: string }
	-- worn lanes inside the plots, { kingdom, name, width, points } (terrain only: Kit/WorldGround; not roads, see `lane`)
	paths = plotPaths,
	-- Dressing density knob (D-047, FL-0116): the share of each dressing kind WorldPlan.props keeps, the least
	-- seen first to go (map edges, the ground between kingdoms). Never thinned: the plot showcase (fields,
	-- buildings, slots and the farm's view), plot framing and approach roads for scatter props, and any forest stand
	-- near the plots or in view. forest: trees in the forest stands; props: lone trees, bushes, rocks and flowers,
	-- each kind on its own. 1.0 for both rebuilds the untrimmed valley (WorldService spec pins it); restore here
	-- after a phone test.
	density = { forest = 0.75, props = 0.5 },
}

return {
	version = 1,
	plots = plots,
	slotSizes = SLOT_SIZES, -- G13.5 slot dimensions by size class (FORGE-02 shape)
	nav = { nodes = nodes, edges = edges },
	resourceNodes = resourceNodes,
	objectives = objectives,
	arena = arena, -- G12.6: { cframe, duelRadius, spawnA, spawnB } + footprint, regionId (additive)
	regions = regions,
	features = features,
}
