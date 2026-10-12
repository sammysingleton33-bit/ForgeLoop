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
	nodes "<kingdom>_<resource><n>" and "heart_<resource><n>"; objective "watchtower".
	Visual features (`features`) are FORGE-02's own shape, read only by WorldService.
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

local plots = {}
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

	-- plot nav: keep door, yard, storehouse, farm, lumber camp, quarry, gate (towards the valley)
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
	plotNav[k.id] = n

	plots[k.id] = {
		spawn = spawn,
		regionId = `{k.id}_home`,
		anchors = anchors,
		buildZones = buildZones,
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
	-- 1 gold (ore), 2 food (berry bushes near the farm)
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
		addNode("wood", t, Vector3.new(-80 + (i - 1) * 14, 0, 58 + (i % 2) * 10), 120, 90, n.lumbercamp)
	end
	addNode("stone", "resource_stone_01", Vector3.new(70, 0, 66), 200, 0, n.quarry)
	addNode("stone", "resource_stone_02", Vector3.new(40, 0, 72), 200, 0, n.quarry)
	addNode("gold", "resource_ore_03", Vector3.new(90, 0, 40), 80, 0, n.quarry)
	addNode("food", "bush_03", Vector3.new(80, 0, -40), 60, 45, n.farm)
	addNode("food", "bush_03", Vector3.new(92, 0, -28), 60, 45, n.farm)
end

-- ---------------------------------------------------------------- valley roads, bridges, heartland
local hub = node(CENTRE.X - 20, CENTRE.Z) -- crossroads below the watchtower hill
local tower = node(CENTRE.X + 10, CENTRE.Z - 6)
link(hub, tower)
local bridgeN = node(-100, -150) -- bridge on the north-west road
local bridgeS = node(-92, 170) -- bridge on the south-west road
local westN = node(-190, -230)
local westS = node(-190, 245)
local eastN = node(230, -220)
local eastS = node(240, 230)
chain({ plotNav.crimson.gate, westN, bridgeN, hub })
chain({ plotNav.emerald.gate, westS, bridgeS, hub })
chain({ plotNav.azure.gate, eastN, hub })
chain({ plotNav.gold.gate, eastS, hub })
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

local objectives = {
	{
		id = "watchtower",
		kind = "capture",
		cframe = facing(CENTRE + Vector3.new(10, 0, -6), v(-330, -320)),
		radius = 26,
		regionId = "heartland",
		navNode = tower,
	},
}

-- ---------------------------------------------------------------- visual features (WorldService only)
local features = {
	groundY = 0,
	bounds = { min = Vector2.new(-660, -640), max = Vector2.new(700, 680) },
	river = {
		width = 34,
		depth = 9,
		points = {
			Vector2.new(-60, -660),
			Vector2.new(-80, -420),
			Vector2.new(-118, -210),
			Vector2.new(-100, -40),
			Vector2.new(-70, 90),
			Vector2.new(-108, 230),
			Vector2.new(-60, 420),
			Vector2.new(-30, 680),
		},
		bridges = { { at = Vector2.new(-100, -150), yaw = 75 }, { at = Vector2.new(-92, 170), yaw = 100 } },
	},
	roads = {
		{
			width = 12,
			points = { Vector2.new(-330, -390), Vector2.new(-190, -230), Vector2.new(-100, -150), Vector2.new(20, 0) },
		},
		{
			width = 12,
			points = { Vector2.new(-330, 410), Vector2.new(-190, 245), Vector2.new(-92, 170), Vector2.new(20, 0) },
		},
		{ width = 12, points = { Vector2.new(380, -390), Vector2.new(230, -220), Vector2.new(20, 0) } },
		{ width = 12, points = { Vector2.new(380, 410), Vector2.new(240, 230), Vector2.new(20, 0) } },
	},
	hills = {
		{ center = Vector2.new(50, -6), radius = 70, height = 14 }, -- watchtower hill
		{ center = Vector2.new(560, 0), radius = 200, height = 60 }, -- eastern ridge (valley wall)
		{ center = Vector2.new(-560, 0), radius = 200, height = 55 }, -- western ridge
		{ center = Vector2.new(0, -620), radius = 220, height = 70 }, -- northern mountains
		{ center = Vector2.new(0, 640), radius = 220, height = 65 }, -- southern hills
	},
	forests = {
		{ center = Vector2.new(-460, -180), radius = 90, count = 26, species = { "tree_pine", "tree_oak" } },
		{ center = Vector2.new(-250, 40), radius = 80, count = 22, species = { "tree_oak", "tree_birch" } },
		{ center = Vector2.new(250, 60), radius = 90, count = 24, species = { "tree_oak", "tree_birch" } },
		{ center = Vector2.new(520, -200), radius = 90, count = 24, species = { "tree_pine", "tree_oak" } },
		{ center = Vector2.new(-430, 520), radius = 100, count = 22, species = { "tree_pine" } },
		{ center = Vector2.new(470, 540), radius = 100, count = 22, species = { "tree_pine", "tree_oak" } },
	},
	fields = {
		{ center = Vector2.new(-170, -330), size = Vector2.new(40, 30), crop = "wheat" },
		{ center = Vector2.new(250, 380), size = Vector2.new(40, 30), crop = "wheat" },
	},
}

return {
	version = 1,
	plots = plots,
	nav = { nodes = nodes, edges = edges },
	resourceNodes = resourceNodes,
	objectives = objectives,
	regions = regions,
	features = features,
}
