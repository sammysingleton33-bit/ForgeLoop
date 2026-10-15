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
	Farm zones and build areas stay free too (the user's playtest: trees and rocks stood in the crop fields):
	a generated node keeps the same distance from every crop field (world features.fields, the farm zones)
	and every plot build zone (plot.buildZones: the front yard and the two flanks) as from a slot.
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
		Layout.keepOutAreas(): { Shape }           -- slots, build zones and crop fields: where generated nodes keep out
		Layout.reservedAreas(): { Shape }          -- no-build areas: crop fields, plot roads, spawn pads (G13.9 v0.4-g9j);
		                                           generate() sets them as sim.noBuild on the world layout
		Layout.SLOT_MARGIN: number                 -- extra studs between a generated node's clearance and a slot
		Layout.groundY(x, z): number               -- world surface height where entities stand: the bridge
		                                           deck on a bridge, else Kit/WorldPlan.groundHeight (hills,
		                                           river bed). World plots only; not for the square layout.
]]

local KingdomsConfig = require("@game/ReplicatedStorage/Forge/Config/Kingdoms")
local ObjectivesConfig = require("@game/ReplicatedStorage/Forge/Config/Objectives")
local WorldLayout = require("@game/ReplicatedStorage/Game/World/Layout")
local WorldPlan = require("../Kit/WorldPlan")
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
local NUDGE, TURN, NUDGES = 6, 0.1, 12

-- Every area a generated node keeps out of, as placement rectangles: each plot's build slots, its build
-- zones (front yard and flanks, in the keep's frame) and the world's crop fields (the farm zones).
local SLOTS = {}
for _, identity in KingdomsConfig.identities do
	local plot = WorldLayout.plots[identity.id]
	for _, slot in plot.buildSlots do
		local size = WorldLayout.slotSizes[slot.size]
		table.insert(SLOTS, Footprint.rect(size, slot.center.X, slot.center.Z, slot.rot))
	end
	local look = plot.anchors.keep.LookVector
	local keepYaw = math.atan2(-look.X, -look.Z) -- Layout.yawOf, which is defined further down
	for _, zone in plot.buildZones do
		table.insert(SLOTS, Footprint.rect(zone.size, zone.center.X, zone.center.Z, keepYaw))
	end
end
for _, field in WorldLayout.features.fields do
	table.insert(SLOTS, Footprint.rect(field.size, field.center.X, field.center.Y, field.yaw))
end

-- No-build areas (CONTRACTS G13.9 v0.4-g9j; Place, PlaceSlot and Move refuse a placement shape that overlaps
-- one, reason blocked): each plot's crop fields, its plot roads (the avenue from the keep door to the gate
-- and the cross street, a rectangle per road segment, as wide as the drawn road) and the spawn pad (a square
-- of SPAWN_PAD studs around the ruler spawn point, turned with the plot). A road segment is a plot road when
-- both its ends lie within PLOT_ROAD_REACH of a keep; the valley roads beyond the gate are not.
local SPAWN_PAD, PLOT_ROAD_REACH = 16, 130
local RESERVED = {}
for _, field in WorldLayout.features.fields do
	table.insert(RESERVED, Footprint.rect(field.size, field.center.X, field.center.Y, field.yaw))
end
for _, identity in KingdomsConfig.identities do
	local plot = WorldLayout.plots[identity.id]
	local look = plot.anchors.keep.LookVector
	local pad = plot.spawn.Position
	table.insert(
		RESERVED,
		Footprint.rect(Vector2.new(SPAWN_PAD, SPAWN_PAD), pad.X, pad.Z, math.atan2(-look.X, -look.Z))
	)
end
for _, road in WorldLayout.features.roads do
	for i = 1, #road.points - 1 do
		local a, b = road.points[i], road.points[i + 1]
		for _, identity in KingdomsConfig.identities do
			local keep = WorldLayout.plots[identity.id].anchors.keep.Position
			if
				(a.X - keep.X) ^ 2 + (a.Y - keep.Z) ^ 2 <= PLOT_ROAD_REACH ^ 2
				and (b.X - keep.X) ^ 2 + (b.Y - keep.Z) ^ 2 <= PLOT_ROAD_REACH ^ 2
			then
				local d = b - a
				table.insert(
					RESERVED,
					Footprint.rect(
						Vector2.new(road.width, d.Magnitude),
						(a.X + b.X) / 2,
						(a.Y + b.Y) / 2,
						math.atan2(d.X, d.Y)
					)
				)
				break
			end
		end
	end
end

-- world layout: a `kind` node at (x, z) clears the standing buildings, every build slot, build zone and crop
-- field, and the other nodes
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

-- Kit/Props bridge stand-in (bridge_stone), in its local frame (deck along local Z): flat deck top over
-- |z| <= 12, ramps down to its base at |z| = 30, 14 studs wide. WorldPlan.props seats it at the ground
-- height 30 studs east of its centre.
local BRIDGE_DECK_HALF = 12
local BRIDGE_HALF = 30
local BRIDGE_HALF_WIDTH = 7

local bridgeSpans = {}
for _, br in WorldLayout.features.river.bridges do
	local yaw = math.rad(br.yaw)
	table.insert(bridgeSpans, {
		x = br.at.X,
		z = br.at.Y,
		sin = math.sin(yaw),
		cos = math.cos(yaw),
		base = WorldPlan.groundHeight(WorldLayout, br.at.X + 30, br.at.Y),
		deck = br.deckY,
	})
end

-- WorldPlan.groundHeight tests every hill ball (~110), so the surface is sampled once per corner of a
-- 2-stud lattice and interpolated: under 0.3 studs off (the most at a hill foot, where the slope
-- breaks); river banks blend over one cell. The cache only holds corners entities have stood near and
-- is cleared if it ever grows huge.
local CELL = 2
local MAX_CORNERS = 200000
local corners: { [number]: number } = {}
local cornerCount = 0

local function corner(ix: number, iz: number): number
	local key = (ix + 32768) * 65536 + (iz + 32768)
	local h = corners[key]
	if h == nil then
		if cornerCount >= MAX_CORNERS then
			table.clear(corners)
			cornerCount = 0
		end
		h = WorldPlan.groundHeight(WorldLayout, ix * CELL, iz * CELL)
		corners[key] = h
		cornerCount += 1
	end
	return h :: number
end

local function terrainY(x: number, z: number): number
	local fx, fz = x / CELL, z / CELL
	local ix, iz = math.floor(fx), math.floor(fz)
	local tx, tz = fx - ix, fz - iz
	local h00, h10 = corner(ix, iz), corner(ix + 1, iz)
	local h01, h11 = corner(ix, iz + 1), corner(ix + 1, iz + 1)
	return (h00 * (1 - tx) + h10 * tx) * (1 - tz) + (h01 * (1 - tx) + h11 * tx) * tz
end

function Layout.groundY(x: number, z: number): number
	local y = terrainY(x, z)
	for _, span in bridgeSpans do
		local dx, dz = x - span.x, z - span.z
		local along = math.abs(dx * span.sin + dz * span.cos) -- the deck's local Z
		local side = math.abs(dx * span.cos - dz * span.sin) -- its local X
		if along <= BRIDGE_HALF and side <= BRIDGE_HALF_WIDTH then
			local rise = if along <= BRIDGE_DECK_HALF
				then span.deck
				else span.deck * (BRIDGE_HALF - along) / (BRIDGE_HALF - BRIDGE_DECK_HALF)
			y = math.max(y, span.base + rise)
		end
	end
	return y
end

-- Every area a generated node keeps out of (clearSpot's list): each plot's build slots and build zones and the
-- world's crop fields, as placement shapes (read-only). FORGE-02's dressing-clearance spec reads this one list
-- instead of keeping a copy.
function Layout.keepOutAreas(): { Footprint.Shape }
	return table.clone(SLOTS)
end

-- The no-build areas above as placement shapes (read-only). Layout.generate hands them to the simulation on
-- the world layout (sim.noBuild); specs and FORGE-02's checks read them here.
function Layout.reservedAreas(): { Footprint.Shape }
	return table.clone(RESERVED)
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
	if not spacing then
		sim.noBuild = Layout.reservedAreas() -- the square layout (compact specs) has no roads or fields
	end

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
