--!strict
--[[
	Kingdom/Layout — where the simulation's kingdoms, nodes and objectives sit.

	By default the four kingdoms sit on FORGE-02's world Layout (CONTRACTS G10.1, world/Layout.luau):
	each keep at `plots[k].anchors.keep`, the neutral objectives at `objectives[i]` (gameplay numbers from
	config Objectives), and the contested centre nodes from the world's `heart_*` resource nodes. Each
	kingdom still gets a generated forest, quarry and gold vein around its keep until FL-0050/FL-0051
	move the economy onto `Layout.resourceNodes` and the starting buildings onto the plot anchors.
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
]]

local KingdomsConfig = require("@game/ReplicatedStorage/Forge/Config/Kingdoms")
local ObjectivesConfig = require("@game/ReplicatedStorage/Forge/Config/Objectives")
local WorldLayout = require("@game/ReplicatedStorage/Game/World/Layout")

local Layout = {}

-- identities and start layout come from config Kingdoms
Layout.KINGDOMS = KingdomsConfig.identities
Layout.WORLD = WorldLayout

-- corner signs in kingdom order: NW, NE, SE, SW (clockwise, so neighbours are adjacent indices)
local CORNERS = { { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } }

-- world resource -> simulation node kind
local NODE_KIND = { wood = "tree", stone = "rock", gold = "goldvein", food = "berries" }

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
		local kx, kz
		if spacing then
			kx, kz = CORNERS[i][1] * spacing, CORNERS[i][2] * spacing
		else
			local keep = WorldLayout.plots[identity.id].anchors.keep.Position
			kx, kz = keep.X, keep.Z
		end
		table.insert(
			kingdoms,
			sim:addKingdom({
				id = identity.id,
				name = identity.name,
				color = identity.color,
				x = kx,
				z = kz,
				populate = opts.populate,
			})
		)

		-- forest behind the keep (away from the centre), spread on an arc
		local away = math.atan2(kz, kx)
		for t = 1, trees do
			local angle = away + (t / trees - 0.5) * 1.6 + (rng:NextNumber() - 0.5) * 0.15
			local radius = 70 + (t % 3) * 14 + rng:NextNumber() * 8
			sim:addNode("tree", kx + math.cos(angle) * radius, kz + math.sin(angle) * radius)
		end
		-- quarry on one flank, gold vein on the other
		local flank = away + math.pi / 2
		for r = 1, 3 do
			local angle = flank + (r - 2) * 0.22
			sim:addNode("rock", kx + math.cos(angle) * 85, kz + math.sin(angle) * 85)
		end
		sim:addNode("goldvein", kx + math.cos(away - math.pi / 2) * 105, kz + math.sin(away - math.pi / 2) * 105)
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
