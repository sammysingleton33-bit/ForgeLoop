--!strict
--[[
	Kingdom/Layout — where the simulation's kingdoms, nodes and objectives sit.

	By default the four kingdoms sit on FORGE-02's world Layout (CONTRACTS G10.1, world/Layout.luau):
	each keep at `plots[k].anchors.keep` and the starting buildings (config Kingdoms.startAnchors:
	storehouse, farm, lumbercamp, quarry) at their anchors, facing as the anchors do; the neutral objectives at `objectives[i]` (gameplay numbers from
	config Objectives), and the contested centre nodes from the world's `heart_*` resource nodes. Each
	kingdom still gets a generated forest, quarry and gold vein around its keep until FL-0050/FL-0051
	move the economy onto `Layout.resourceNodes` and the starting buildings onto the plot anchors.
	On the world layout a generated node keeps clear of every building already standing (sim:nodeClear:
	the keep and starting buildings) and of every build slot (its circle stays placementGap +
	SLOT_MARGIN from the slot, so any type that fits the slot can be built there). A blocked spot tries
	a step inwards, outwards and towards the back of the plot, then a step further, a few times and without
	random draws; a node with no clear spot is left out. Same seed, same nodes.
	Passing `spacing` instead keeps the older square generator (specs that need compact maps).

	API
		Layout.KINGDOMS: { { id, name, color, teamColor } }  -- the four kingdoms, CONTRACTS G2 ids
		                                           (crimson, azure, emerald, gold; teamColor = unique BrickColor name)
		Layout.OBJECTIVES: { { id, x, z, radius, regionId?, captureSeconds, crownPoints, ... } }
		Layout.WORLD                               -- world/Layout.luau (plots[k].spawn, regionId, ...)
		Layout.generate(sim, options?): { kingdoms: { Kingdom } }
			options.kingdoms   number of kingdoms, 1..4 (default 4)
			options.spacing    square layout: distance from the centre to each keep on X and Z (default: world plots)
			options.trees      trees per forest (default 24)
			options.populate   false: kingdoms start without citizens (sim:populate later; slice mode)
		Layout.bounds(spacing?): Bounds            -- map bounds: the world's, or ones that fit the square layout
		Layout.boundsFor(spacing): Bounds          -- (square layout)
		Layout.SLOT_MARGIN: number                 -- extra studs between a generated node's clearance and a slot
]]

local KingdomsConfig = require("@game/ReplicatedStorage/Forge/Config/Kingdoms")
local ObjectivesConfig = require("@game/ReplicatedStorage/Forge/Config/Objectives")
local WorldLayout = require("@game/ReplicatedStorage/Game/World/Layout")
local Footprint = require("../Sim/Footprint")

local Layout = {}

-- identities and start layout come from config Kingdoms
Layout.KINGDOMS = KingdomsConfig.identities
Layout.WORLD = WorldLayout

-- corner signs in kingdom order: NW, NE, SE, SW (clockwise, so neighbours are adjacent indices)
local CORNERS = { { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } }

-- world resource -> simulation node kind
local NODE_KIND = { wood = "tree", stone = "rock", gold = "goldvein", food = "berries" }

Layout.SLOT_MARGIN = 2
-- a blocked generated node tries NUDGES steps: i * NUDGE studs in, then out, then i * TURN radians to the back
local NUDGE, TURN, NUDGES = 6, 0.1, 8

-- every build slot of every plot, as placement rectangles
local SLOTS = {}
for _, identity in KingdomsConfig.identities do
	for _, slot in WorldLayout.plots[identity.id].buildSlots do
		local size = WorldLayout.slotSizes[slot.size]
		table.insert(SLOTS, Footprint.rect(size, slot.center.X, slot.center.Z, slot.rot))
	end
end

-- world layout: a `kind` node at (x, z) clears the standing buildings, every build slot and the other nodes
local function clearSpot(sim: any, kind: string, x: number, z: number): boolean
	if not sim:nodeClear(kind, x, z) then
		return false
	end
	local radius = sim.catalog.nodes[kind].footprint
	local gap = sim.catalog.tuning.placementGap + Layout.SLOT_MARGIN
	for _, slot in SLOTS do
		if Footprint.overlapsCircle(slot, x, z, radius, gap) then
			return false
		end
	end
	for _, nid in sim.nodeOrder do
		local node = sim.nodes[nid]
		if (node.x - x) ^ 2 + (node.z - z) ^ 2 < (node.footprint + radius) ^ 2 then
			return false
		end
	end
	return true
end

-- Adds a generated node at `angle`/`radius` around (cx, cz). On the world layout (`back` set: the angle of
-- the plot's back) a blocked spot moves inwards, outwards or towards `back`; no clear spot: no node.
local function addGenerated(
	sim: any,
	kind: string,
	cx: number,
	cz: number,
	angle: number,
	radius: number,
	back: number?
)
	if back == nil then
		sim:addNode(kind, cx + math.cos(angle) * radius, cz + math.sin(angle) * radius)
		return
	end
	local delta = (back - angle + math.pi) % (2 * math.pi) - math.pi
	local toward = if delta > 0 then 1 elseif delta < 0 then -1 else 0
	for i = 0, NUDGES do
		local turned = angle + toward * math.min(i * TURN, math.abs(delta))
		for _, spot in { { angle, radius - i * NUDGE }, { angle, radius + i * NUDGE }, { turned, radius } } do
			local x, z = cx + math.cos(spot[1]) * spot[2], cz + math.sin(spot[1]) * spot[2]
			if clearSpot(sim, kind, x, z) then
				sim:addNode(kind, x, z)
				return
			end
		end
	end
end

-- config Objectives gameplay numbers, placed where the world Layout puts each objective
local function objectives(): { any }
	local out = {}
	for _, o in ObjectivesConfig do
		local entry = table.clone(o)
		for _, w in WorldLayout.objectives do
			if w.id == o.id then
				entry.x, entry.z = w.cframe.Position.X, w.cframe.Position.Z
				entry.radius = w.radius
				entry.regionId = w.regionId
			end
		end
		table.insert(out, entry)
	end
	return out
end
Layout.OBJECTIVES = objectives()

-- The yaw (CFrame.Angles(0, yaw, 0)) of a CFrame's facing: its LookVector projected on XZ.
function Layout.yawOf(cf: CFrame): number
	local look = cf.LookVector
	return math.atan2(-look.X, -look.Z)
end

function Layout.boundsFor(spacing: number)
	local half = spacing + 240
	return { minX = -half, maxX = half, minZ = -half, maxZ = half }
end

function Layout.bounds(spacing: number?)
	if spacing then
		return Layout.boundsFor(spacing)
	end
	local b = WorldLayout.features.bounds
	return { minX = b.min.X, maxX = b.max.X, minZ = b.min.Y, maxZ = b.max.Y }
end

function Layout.generate(sim: any, options: { [string]: any }?)
	local opts = options or {}
	local count = opts.kingdoms or 4
	assert(type(count) == "number" and count >= 1 and count <= 4, "Layout.generate: kingdoms must be 1..4")
	local spacing = opts.spacing
	local trees = opts.trees or KingdomsConfig.trees
	local rng = sim.rng

	local kingdoms = {}
	for i = 1, count do
		local identity = Layout.KINGDOMS[i]
		local kx, kz, keepYaw, startAt
		if spacing then
			kx, kz = CORNERS[i][1] * spacing, CORNERS[i][2] * spacing
		else
			local anchors = WorldLayout.plots[identity.id].anchors
			kx, kz, keepYaw = anchors.keep.Position.X, anchors.keep.Position.Z, Layout.yawOf(anchors.keep)
			startAt = {}
			for _, kind in KingdomsConfig.startAnchors do
				local cf = anchors[kind]
				if cf then
					table.insert(startAt, { kind = kind, x = cf.Position.X, z = cf.Position.Z, yaw = Layout.yawOf(cf) })
				end
			end
		end
		table.insert(
			kingdoms,
			sim:addKingdom({
				id = identity.id,
				name = identity.name,
				color = identity.color,
				x = kx,
				z = kz,
				yaw = keepYaw,
				startAt = startAt,
				populate = opts.populate,
			})
		)

		-- forest behind the keep (away from the centre), spread on an arc
		local away = math.atan2(kz, kx)
		local back = if spacing then nil else away
		for t = 1, trees do
			local angle = away + (t / trees - 0.5) * 1.6 + (rng:NextNumber() - 0.5) * 0.15
			local radius = 70 + (t % 3) * 14 + rng:NextNumber() * 8
			addGenerated(sim, "tree", kx, kz, angle, radius, back)
		end
		-- quarry on one flank, gold vein on the other
		local flank = away + math.pi / 2
		for r = 1, 3 do
			addGenerated(sim, "rock", kx, kz, flank + (r - 2) * 0.22, 85, back)
		end
		addGenerated(sim, "goldvein", kx, kz, away - math.pi / 2, 105, back)
	end

	if spacing then
		-- contested centre (gold veins and rocks, clear of the watchtower objective)
		sim:addNode("goldvein", 0, 0)
		sim:addNode("goldvein", 18, 12)
		sim:addNode("goldvein", -18, 12)
		sim:addNode("rock", 30, 25)
		sim:addNode("rock", -30, 25)
	else
		-- contested centre from the world (heart_* nodes, at their world ids)
		for _, node in WorldLayout.resourceNodes do
			local kind = NODE_KIND[node.resource]
			if kind and string.sub(node.id, 1, 6) == "heart_" then
				sim:addNode(kind, node.cframe.Position.X, node.cframe.Position.Z, node.id)
			end
		end
	end
	return { kingdoms = kingdoms }
end

return Layout
