--!strict
--[[
	Gameplay/Kingdom/Layout — deterministic placement of kingdoms and resource nodes.

	Until FORGE-05's kingdom map exists (tagged spawn points / resource markers), the simulation
	generates its own layout: kingdoms on the corners of a square, each with a forest behind it,
	a quarry and a gold vein to the side, and contested gold and stone in the centre. The server
	host renders whatever the simulation contains, so swapping this for map-driven placement later
	changes no other module.

	API
		Layout.KINGDOMS: { { id, name, color, teamColor } }  -- the four kingdoms, CONTRACTS G2 ids
		                                           (crimson, azure, emerald, gold; teamColor = unique BrickColor name)
		Layout.OBJECTIVES: { { id, x, z } }       -- neutral capture points (VS-1: the centre watchtower)
		Layout.generate(sim, options?): { kingdoms: { Kingdom } }
			options.kingdoms   number of kingdoms, 1..4 (default 4)
			options.spacing    distance from the map centre to each keep on X and Z (default 260)
			options.trees      trees per forest (default 24)
		Layout.boundsFor(spacing): Bounds          -- map bounds that fit the generated layout
]]

local Layout = {}

Layout.KINGDOMS = table.freeze({
	table.freeze({ id = "crimson", name = "Crimson Kingdom", color = { 190, 40, 50 }, teamColor = "Crimson" }),
	table.freeze({ id = "azure", name = "Azure Kingdom", color = { 40, 110, 210 }, teamColor = "Bright blue" }),
	table.freeze({ id = "emerald", name = "Emerald Kingdom", color = { 40, 160, 90 }, teamColor = "Bright green" }),
	table.freeze({ id = "gold", name = "Gold Kingdom", color = { 225, 175, 40 }, teamColor = "Bright yellow" }),
})

-- corner signs in kingdom order: NW, NE, SE, SW (clockwise, so neighbours are adjacent indices)
local CORNERS = { { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } }

-- the neutral watchtower sits just off the contested centre (VS-1 row 7)
Layout.OBJECTIVES = table.freeze({ table.freeze({ id = "watchtower", x = 0, z = -60 }) })

function Layout.boundsFor(spacing: number)
	local half = spacing + 240
	return { minX = -half, maxX = half, minZ = -half, maxZ = half }
end

function Layout.generate(sim: any, options: { [string]: any }?)
	local opts = options or {}
	local count = opts.kingdoms or 4
	assert(type(count) == "number" and count >= 1 and count <= 4, "Layout.generate: kingdoms must be 1..4")
	local spacing = opts.spacing or 260
	local trees = opts.trees or 24
	local rng = sim.rng

	local kingdoms = {}
	for i = 1, count do
		local identity = Layout.KINGDOMS[i]
		local sx, sz = CORNERS[i][1], CORNERS[i][2]
		local kx, kz = sx * spacing, sz * spacing
		table.insert(
			kingdoms,
			sim:addKingdom({ id = identity.id, name = identity.name, color = identity.color, x = kx, z = kz })
		)

		-- forest behind the keep (away from the centre), spread on an arc
		local away = math.atan2(sz, sx)
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

	-- contested centre (gold veins and rocks, clear of the watchtower objective)
	sim:addNode("goldvein", 0, 0)
	sim:addNode("goldvein", 18, 12)
	sim:addNode("goldvein", -18, 12)
	sim:addNode("rock", 30, 25)
	sim:addNode("rock", -30, 25)
	return { kingdoms = kingdoms }
end

return Layout
