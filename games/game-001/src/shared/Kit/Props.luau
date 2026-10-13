--!strict
--[[
	Kit/Props — props by asset id (CONTRACTS G10): the imported Blender mesh when an asset source is
	registered (Kit.setAssetSource(ReplicatedStorage.Forge.Assets)), otherwise a part-built stand-in
	with the same id, so imports swap in automatically (D-021). Also territory markers.

	Stand-ins follow the art bible (blender/ART_DIRECTION.md) as far as primitives allow: chunky,
	layered, colour-varied. They are deterministic per asset id (Park–Miller PRNG from WorldPlan,
	never Random) so Lune previews match Roblox. Ids follow blender/manifest.json:
	tree_oak_NN, tree_pine_NN, tree_birch_NN, bush_NN, plant_flowers_NN, rock_boulder_{s,m,l}_NN,
	rock_cliff_NN, resource_{stone,ore,wood}_NN, prop_banner_<colour>_NN, prop_well_NN, prop_cart_NN,
	prop_goods_NN, farm_haystack_NN, farm_fence_NN, bridge_stone_NN; anything else is a crate.
]]

local KingdomsConfig = require("@game/ReplicatedStorage/Forge/Config/Kingdoms")
local Parts = require("./Parts")
local Pieces = require("./Pieces")
local WorldPlan = require("./WorldPlan")

local C = Parts.C
local shade = Parts.shade
local newModel = Parts.newModel
local block = Parts.block
local wedge = Parts.wedge
local cornerWedge = Parts.cornerWedge
local column = Parts.column
local log = Parts.log
local ball = Parts.ball
local flagpole = Pieces.flagpole

local Props = {}

local EXTRA = {
	birch = Color3.fromRGB(232, 226, 210),
	birchMark = Color3.fromRGB(59, 53, 48),
	birchLeaf = Color3.fromRGB(156, 201, 74),
	birchLeafLight = Color3.fromRGB(196, 222, 106),
	pine = Color3.fromRGB(31, 82, 54),
	pineMid = Color3.fromRGB(45, 107, 67),
	pineLight = Color3.fromRGB(74, 138, 80),
	oakSun = Color3.fromRGB(166, 207, 74),
	hay = Color3.fromRGB(216, 184, 90),
	hayDark = Color3.fromRGB(184, 150, 62),
	ironOre = Color3.fromRGB(160, 86, 58),
	goldOre = Color3.fromRGB(242, 194, 48),
	crystal = Color3.fromRGB(111, 208, 224),
	berry = Color3.fromRGB(200, 50, 43),
	flowerRed = Color3.fromRGB(217, 52, 58),
	flowerYellow = Color3.fromRGB(244, 208, 63),
	flowerWhite = Color3.fromRGB(245, 243, 234),
	flowerPurple = Color3.fromRGB(142, 92, 194),
	sack = Color3.fromRGB(216, 196, 150),
	water = Color3.fromRGB(46, 120, 168),
}

-- Banner stand-ins in the canonical kingdom colours (config Kingdoms, D-033). Asset ids use the Blender
-- names (prop_banner_<red|blue|green|yellow>_NN), mapped here to the kingdom ids.
local BANNER_KINGDOM = { red = "crimson", blue = "azure", green = "emerald", yellow = "gold" }
local BANNER_COLORS: { [string]: Color3 } = {}
do
	local byId = {}
	for _, identity in KingdomsConfig.identities do
		byId[identity.id] = identity.color
	end
	for name, id in BANNER_KINGDOM do
		local c = byId[id] or { 208, 200, 184 }
		BANNER_COLORS[name] = Color3.fromRGB(c[1], c[2], c[3])
	end
end

local assetSource: Instance? = nil

function Props.setAssetSource(folder: Instance?)
	assetSource = folder
end

local function hash(s: string): number
	local h = 7
	for i = 1, #s do
		h = (h * 31 + string.byte(s, i)) % 2147483629
	end
	return h
end

local function variantOf(assetId: string): number
	return tonumber(string.match(assetId, "_(%d+)$")) or 1
end

-- ---------------------------------------------------------------- vegetation

local function oak(ctx, rng)
	local th = rng.range(9, 13)
	column(ctx, "TrunkBase", 2.0, 2.2, Vector3.new(0, 0, 0), C.bark, Enum.Material.Wood)
	column(ctx, "Trunk", 1.35, th, Vector3.new(0, 1.6, 0), C.bark, Enum.Material.Wood)
	for i = 1, 3 do
		local a = (i / 3) * 2 * math.pi + rng.range(-0.4, 0.4)
		local len = rng.range(5, 7)
		local tilt = math.rad(rng.range(35, 55))
		local base = Vector3.new(0, th * rng.range(0.6, 0.85), 0)
		local dir = Vector3.new(math.cos(a) * math.sin(tilt), math.cos(tilt), math.sin(a) * math.sin(tilt))
		local mid = base + dir * (len / 2)
		local cf = CFrame.lookAt(mid, mid + dir) * CFrame.Angles(math.rad(90), 0, 0)
		block(ctx, "Branch", Vector3.new(0.9, len, 0.9), cf, shade(C.bark, 0.95), Enum.Material.Wood)
	end
	local crown = th + 4
	local greens = { C.leafDark, C.leaf, C.leafLight, EXTRA.oakSun }
	ball(ctx, "Canopy", 14, Vector3.new(0, crown, 0), C.leaf, Enum.Material.Grass)
	local n = rng.int(8, 10)
	for i = 1, n do
		local a = (i / n) * 2 * math.pi + rng.range(-0.3, 0.3)
		local r = rng.range(4.5, 7)
		local y = crown + rng.range(-3, 4)
		local d = rng.range(7, 10)
		local tone = if y < crown - 1 then 1 elseif y > crown + 2 then 4 else rng.int(2, 3)
		ball(ctx, "Canopy", d, Vector3.new(math.cos(a) * r, y, math.sin(a) * r), greens[tone], Enum.Material.Grass)
	end
	ball(
		ctx,
		"Canopy",
		9,
		Vector3.new(rng.range(-1, 1), crown + 5.5, rng.range(-1, 1)),
		EXTRA.oakSun,
		Enum.Material.Grass
	)
end

local function pine(ctx, rng)
	local h = rng.range(26, 34)
	column(ctx, "Trunk", 1.0, h * 0.5, Vector3.new(0, 0, 0), C.bark, Enum.Material.Wood)
	local tiers = 5
	for i = 0, tiers - 1 do
		local t = i / tiers
		local w = 15 * (1 - t * 0.78) + rng.range(-0.6, 0.6)
		local th = h * 0.21
		local y = 5 + i * h * 0.16
		local color = if i == tiers - 1 then EXTRA.pineLight elseif i % 2 == 0 then EXTRA.pine else EXTRA.pineMid
		local half = w / 2
		local turn = rng.range(-0.25, 0.25)
		for q = 0, 3 do
			-- CornerWedge apex is at local (+X, +Y, -Z): a 90° turn puts each quarter's apex on the axis
			local cf = CFrame.new(0, y + th / 2, 0)
				* CFrame.Angles(0, math.rad(90 * q) + turn, 0)
				* CFrame.new(half / 2, 0, half / 2)
				* CFrame.Angles(0, math.rad(90), 0)
			cornerWedge(ctx, "Tier", Vector3.new(half, th, half), cf, color, Enum.Material.Grass)
		end
	end
end

local function birch(ctx, rng)
	local trunks = rng.int(1, 2)
	for k = 1, trunks do
		local ox = if trunks == 1 then 0 else (k - 1.5) * 2.2
		local h = rng.range(16, 22)
		column(ctx, "Trunk", 0.7, h, Vector3.new(ox, 0, 0), EXTRA.birch, Enum.Material.SmoothPlastic)
		for b = 1, 3 do
			column(ctx, "Bark", 0.72, 0.35, Vector3.new(ox, h * b / 4, 0), EXTRA.birchMark, Enum.Material.SmoothPlastic)
		end
		for i = 1, 4 do
			local a = i * 1.7 + rng.range(-0.3, 0.3)
			local r = rng.range(1.5, 3.5)
			local pos = Vector3.new(ox + math.cos(a) * r, h - 2 + rng.range(-2, 3), math.sin(a) * r)
			local tone = if i % 2 == 0 then EXTRA.birchLeaf else EXTRA.birchLeafLight
			ball(ctx, "Canopy", rng.range(5.5, 7.5), pos, tone, Enum.Material.Grass)
		end
	end
end

local function bush(ctx, rng, variant: number)
	local greens = { C.leafDark, C.leaf, C.leafLight }
	for i = 1, 4 do
		local a = i * 1.6 + rng.range(-0.3, 0.3)
		local r = if i == 1 then 0 else rng.range(1.2, 2.2)
		local pos = Vector3.new(math.cos(a) * r, 1.6, math.sin(a) * r)
		ball(ctx, "Bush", rng.range(3.2, 4.6), pos, greens[1 + (i % 3)], Enum.Material.Grass)
	end
	if variant % 3 ~= 1 then
		local c = if variant % 3 == 0 then EXTRA.berry else EXTRA.flowerWhite
		for i = 1, 5 do
			local a = i * 1.25
			local pos = Vector3.new(math.cos(a) * 1.9, 2.6 + (i % 2) * 0.6, math.sin(a) * 1.9)
			ball(ctx, "Berry", 0.7, pos, c, Enum.Material.SmoothPlastic)
		end
	end
end

local function flowers(ctx, rng)
	column(ctx, "Leaves", 2.4, 0.3, Vector3.new(0, 0, 0), C.leaf, Enum.Material.Grass)
	local colors = { EXTRA.flowerRed, EXTRA.flowerYellow, EXTRA.flowerWhite, EXTRA.flowerPurple }
	local base = colors[rng.int(1, 4)]
	for i = 1, 7 do
		local a = i * 0.9 + rng.range(-0.2, 0.2)
		local r = rng.range(0.4, 2.0)
		local pos = Vector3.new(math.cos(a) * r, 0.9 + rng.range(0, 0.5), math.sin(a) * r)
		ball(ctx, "Flower", 0.8, pos, if i % 3 == 0 then colors[rng.int(1, 4)] else base, Enum.Material.SmoothPlastic)
	end
end

-- ---------------------------------------------------------------- rocks and resources

local function rocks(ctx, rng, scale: number, tint: Color3)
	local main = Vector3.new(6, 4, 5) * scale
	local cf1 = CFrame.new(0, main.Y * 0.42, 0)
		* CFrame.Angles(rng.range(-0.15, 0.15), rng.range(0, 3), rng.range(-0.2, 0.2))
	block(ctx, "Rock", main, cf1, tint, Enum.Material.Slate)
	local cf2 = CFrame.new(main.X * 0.25, main.Y * 0.75, 0) * CFrame.Angles(0, rng.range(0, 3), 0)
	wedge(ctx, "Rock", Vector3.new(4.5, 3, 3.5) * scale, cf2, shade(tint, 1.1), Enum.Material.Slate)
	local cf3 = CFrame.new(main.X * 0.55, 0.8 * scale, main.Z * 0.35)
		* CFrame.Angles(rng.range(-0.3, 0.3), rng.range(0, 3), 0.2)
	block(ctx, "Rock", Vector3.new(3, 2.2, 2.6) * scale, cf3, shade(tint, 0.9), Enum.Material.Slate)
end

local function quarryNode(ctx, rng)
	rocks(ctx, rng, 1.6, C.stone)
	for i = 0, 2 do
		local cf = CFrame.new(-5 + i * 2.5, 0.8 + (i % 2) * 1.6, -4) * CFrame.Angles(0, rng.range(-0.2, 0.2), 0)
		block(ctx, "CutBlock", Vector3.new(2.2, 1.6, 2.2), cf, C.stoneLight, Enum.Material.Slate)
	end
	local pick = CFrame.new(4.5, 1.6, -3.5) * CFrame.Angles(0, 0, math.rad(25))
	block(ctx, "Pick", Vector3.new(0.3, 3.2, 0.3), pick, C.wood, Enum.Material.Wood)
end

local function oreNode(ctx, rng, variant: number)
	rocks(ctx, rng, 1.3, shade(C.stone, 0.85))
	local ore = if variant <= 2 then EXTRA.ironOre elseif variant <= 4 then EXTRA.goldOre else EXTRA.crystal
	for i = 1, 6 do
		local a = i * 1.05
		local pos = Vector3.new(math.cos(a) * 3, 2.2 + (i % 3) * 1.2, math.sin(a) * 2.6)
		if variant >= 5 then
			local cf = CFrame.new(pos) * CFrame.Angles(rng.range(-0.5, 0.5), 0, rng.range(-0.5, 0.5))
			block(ctx, "Crystal", Vector3.new(0.9, rng.range(2.2, 3.6), 0.9), cf, ore, Enum.Material.Neon)
		else
			local cf = CFrame.new(pos) * CFrame.Angles(rng.range(0, 3), rng.range(0, 3), 0)
			block(ctx, "Ore", Vector3.new(1.1, 0.9, 1.0), cf, ore, Enum.Material.Metal)
		end
	end
end

local function woodNode(ctx, rng)
	for row = 0, 2 do
		for i = 0, 3 - row do
			local cf = CFrame.new((i - 1.5 + row * 0.5) * 1.5, 0.75 + row * 1.3, 0) * CFrame.Angles(0, math.rad(90), 0)
			log(ctx, "Log", 0.75, 7, cf, C.bark)
		end
	end
	column(ctx, "Stump", 1.2, 1.5, Vector3.new(4.5, 0, 2.5), C.bark, Enum.Material.Wood)
	column(ctx, "StumpTop", 1.0, 0.1, Vector3.new(4.5, 1.5, 2.5), C.woodLight, Enum.Material.Wood)
	local handle = CFrame.new(4.5, 2.6, 2.5) * CFrame.Angles(0, 0, math.rad(rng.range(15, 30)))
	block(ctx, "AxeHandle", Vector3.new(0.25, 2.4, 0.25), handle, C.wood, Enum.Material.Wood)
	block(ctx, "AxeHead", Vector3.new(1.0, 0.7, 0.2), CFrame.new(4.1, 1.7, 2.5), C.iron, Enum.Material.Metal)
end

-- ---------------------------------------------------------------- village props

-- Kingdom banner on a stand: the cloth in the kingdom colour on an ivory backing (reads against grass under
-- every colour-vision type), with the kingdom's emblem (D-039) filling 80 % of its width.
local function bannerProp(ctx, color: Color3)
	column(ctx, "Pole", 0.25, 12, Vector3.new(0, 0, 0), C.woodDark, Enum.Material.Wood)
	block(ctx, "Base", Vector3.new(2, 0.8, 2), CFrame.new(0, 0.4, 0), C.stone, Enum.Material.Slate)
	block(ctx, "CrossBar", Vector3.new(4, 0.3, 0.3), CFrame.new(0, 11, -0.3), C.woodDark, Enum.Material.Wood)
	local cloth =
		block(ctx, "Banner", Vector3.new(3.4, 6, 0.25), CFrame.new(0, 7.9, -0.4), color, Enum.Material.Fabric, 1)
	block(
		ctx,
		"BannerBorder",
		Vector3.new(3.8, 6.2, 0.15),
		CFrame.new(0, 7.9, -0.33),
		Pieces.IVORY,
		Enum.Material.Fabric
	)
	local tip = CFrame.new(0, 4.9, -0.4) * CFrame.Angles(0, 0, math.rad(45))
	block(ctx, "BannerTip", Vector3.new(2.4, 2.4, 0.25), tip, color, Enum.Material.Fabric, 1)
	Pieces.emblem(ctx, cloth, CFrame.new(0, 8.3, -0.525), 2.75, color)
	ball(ctx, "Finial", 0.7, Vector3.new(0, 12.3, 0), C.gold, Enum.Material.Metal)
end

local function well(ctx)
	column(ctx, "Curb", 3, 2.6, Vector3.new(0, 0, 0), C.stone, Enum.Material.Cobblestone)
	column(ctx, "Water", 2.3, 0.1, Vector3.new(0, 2.4, 0), EXTRA.water, Enum.Material.Glass)
	for _, sx in { -1, 1 } do
		block(ctx, "Post", Vector3.new(0.6, 6.5, 0.6), CFrame.new(sx * 2.8, 3.25, 0), C.wood, Enum.Material.Wood)
	end
	log(ctx, "Winch", 0.35, 6, CFrame.new(0, 5, 0), C.woodDark)
	block(ctx, "Rope", Vector3.new(0.15, 2.6, 0.15), CFrame.new(0, 3.6, 0), C.canvas, Enum.Material.Fabric)
	block(ctx, "Bucket", Vector3.new(0.9, 0.9, 0.9), CFrame.new(0, 2.6, 0), C.wood, Enum.Material.WoodPlanks)
	wedge(ctx, "Roof", Vector3.new(7.6, 2.4, 2.4), CFrame.new(0, 7.5, -1.2), C.thatch, Enum.Material.Grass)
	local back = CFrame.new(0, 7.5, 1.2) * CFrame.Angles(0, math.rad(180), 0)
	wedge(ctx, "Roof", Vector3.new(7.6, 2.4, 2.4), back, C.thatch, Enum.Material.Grass)
end

local function cart(ctx, variant: number)
	block(ctx, "Bed", Vector3.new(4.4, 0.5, 6.5), CFrame.new(0, 2.4, 0), C.wood, Enum.Material.WoodPlanks)
	for _, sx in { -1, 1 } do
		block(ctx, "Side", Vector3.new(0.3, 1.2, 6.5), CFrame.new(sx * 2.1, 3.2, 0), C.woodDark, Enum.Material.Wood)
		log(ctx, "Wheel", 1.7, 0.4, CFrame.new(sx * 2.5, 1.7, 0.6), C.woodDark)
		block(ctx, "Handle", Vector3.new(0.3, 0.3, 4), CFrame.new(sx * 1.4, 2.5, -5), C.wood, Enum.Material.Wood)
	end
	if variant % 2 == 0 then
		ball(ctx, "Load", 3.6, Vector3.new(0, 3.9, 0), EXTRA.hay, Enum.Material.Grass)
		ball(ctx, "Load", 3.0, Vector3.new(0, 4.4, 1.6), EXTRA.hayDark, Enum.Material.Grass)
	else
		for i = 0, 3 do
			local pos = Vector3.new(-1 + (i % 2) * 2, 3.4, -1.8 + math.floor(i / 2) * 2.4)
			ball(ctx, "Sack", 1.7, pos, EXTRA.sack, Enum.Material.Fabric)
		end
	end
end

local function goods(ctx, rng)
	for i = 0, 2 do
		local cf = CFrame.new(i * 2.2 - 2, 1, 0) * CFrame.Angles(0, rng.range(-0.2, 0.2), 0)
		block(ctx, "Crate", Vector3.new(2, 2, 2), cf, C.wood, Enum.Material.WoodPlanks)
	end
	local top = CFrame.new(-1, 2.9, 0.1) * CFrame.Angles(0, 0.3, 0)
	block(ctx, "Crate", Vector3.new(1.8, 1.8, 1.8), top, C.woodLight, Enum.Material.WoodPlanks)
	column(ctx, "Barrel", 1.1, 2.4, Vector3.new(3.2, 0, 1.6), C.wood, Enum.Material.Wood)
	column(ctx, "BarrelHoop", 1.15, 0.25, Vector3.new(3.2, 1.6, 1.6), C.iron, Enum.Material.Metal)
	ball(ctx, "Sack", 1.8, Vector3.new(-3.2, 0.8, 1.4), EXTRA.sack, Enum.Material.Fabric)
end

local function haystack(ctx)
	ball(ctx, "Hay", 6, Vector3.new(0, 2.4, 0), EXTRA.hay, Enum.Material.Grass)
	ball(ctx, "Hay", 4.2, Vector3.new(0, 4.8, 0), EXTRA.hayDark, Enum.Material.Grass)
	local fork = CFrame.new(2.6, 3, -1) * CFrame.Angles(0, 0, math.rad(-20))
	block(ctx, "Pitchfork", Vector3.new(0.25, 5, 0.25), fork, C.wood, Enum.Material.Wood)
end

local function fence(ctx, variant: number)
	for i = 0, 4 do
		block(ctx, "Post", Vector3.new(0.5, 3.4, 0.5), CFrame.new(-8 + i * 4, 1.7, 0), C.woodDark, Enum.Material.Wood)
	end
	for _, y in (if variant % 2 == 0 then { 1.4, 2.7 } else { 2.2 }) do
		block(ctx, "Rail", Vector3.new(16.2, 0.35, 0.3), CFrame.new(0, y, 0), C.wood, Enum.Material.Wood)
	end
end

local function bridge(ctx)
	local w = 14 -- deck width; spans ~60 studs along local Z
	block(ctx, "Deck", Vector3.new(w, 1.2, 24), CFrame.new(0, 3.2, 0), C.stoneLight, Enum.Material.Cobblestone)
	block(ctx, "Arch", Vector3.new(w, 2.6, 14), CFrame.new(0, 1.3, 0), C.stone, Enum.Material.Slate)
	for _, s in { -1, 1 } do
		local ramp = CFrame.new(0, 1.9, s * 21) * CFrame.Angles(0, if s < 0 then 0 else math.rad(180), 0)
		wedge(ctx, "Ramp", Vector3.new(w, 3.8, 18), ramp, C.stoneLight, Enum.Material.Cobblestone)
		block(
			ctx,
			"Parapet",
			Vector3.new(1.2, 3, 24),
			CFrame.new(s * (w / 2 - 0.6), 5.3, 0),
			C.stone,
			Enum.Material.Slate
		)
		block(ctx, "Pier", Vector3.new(w + 2, 8, 4), CFrame.new(0, -2, s * 9), C.stone, Enum.Material.Cobblestone)
		for e = -1, 1, 2 do
			local newel = CFrame.new(s * (w / 2 - 0.6), 4.8, e * 12.5)
			block(ctx, "Newel", Vector3.new(1.6, 4, 1.6), newel, C.stoneLight, Enum.Material.Slate)
		end
	end
end

-- Crop plot 38 x 28 (matches the 40 x 30 terrain field): rows of wheat or cabbages on the soil.
local function cropField(ctx, rng, crop: string)
	local rows = 7
	for r = 0, rows - 1 do
		local z = -12 + r * 4
		if crop == "cabbage" then
			for k = 0, 8 do
				local pos = Vector3.new(-16 + k * 4 + rng.range(-0.4, 0.4), 0.9, z)
				ball(
					ctx,
					"Cabbage",
					rng.range(1.8, 2.3),
					pos,
					if k % 3 == 0 then C.leafLight else C.leaf,
					Enum.Material.Grass
				)
			end
		else
			local h = rng.range(2.6, 3.2)
			block(ctx, "Wheat", Vector3.new(36, h, 2.6), CFrame.new(0, h / 2, z), C.wheat, Enum.Material.Grass)
			block(
				ctx,
				"WheatTop",
				Vector3.new(35.6, 0.5, 2.0),
				CFrame.new(0, h + 0.2, z),
				EXTRA.hay,
				Enum.Material.Grass
			)
		end
	end
	for _, s in { -1, 1 } do
		block(ctx, "Furrow", Vector3.new(38, 0.4, 0.6), CFrame.new(0, 0.2, s * 14), C.soil, Enum.Material.Ground)
	end
end

local function crate(ctx)
	block(ctx, "Crate", Vector3.new(2, 2, 2), CFrame.new(0, 1, 0), C.wood, Enum.Material.WoodPlanks)
	block(ctx, "CrateBand", Vector3.new(2.1, 0.3, 2.1), CFrame.new(0, 1, 0), C.woodDark, Enum.Material.Wood)
end

local function standIn(assetId: string): Model
	local ctx = newModel(assetId, Vector2.new(4, 4))
	ctx.model:SetAttribute("KitStandIn", true)
	local rng = WorldPlan._prng(hash(assetId))
	local variant = variantOf(assetId)
	local function has(prefix: string): boolean
		return string.sub(assetId, 1, #prefix) == prefix
	end
	if has("tree_pine") then
		pine(ctx, rng)
	elseif has("tree_birch") then
		birch(ctx, rng)
	elseif has("tree_") then
		oak(ctx, rng)
	elseif has("bush") then
		bush(ctx, rng, variant)
	elseif has("plant_") then
		flowers(ctx, rng)
	elseif has("rock_boulder_s") then
		rocks(ctx, rng, 0.6, C.stone)
	elseif has("rock_boulder_m") then
		rocks(ctx, rng, 1.1, C.stone)
	elseif has("rock_") then
		rocks(ctx, rng, 2.0, shade(C.stone, 0.95))
	elseif has("resource_stone") then
		quarryNode(ctx, rng)
	elseif has("resource_ore") then
		oreNode(ctx, rng, variant)
	elseif has("resource_wood") then
		woodNode(ctx, rng)
	elseif has("prop_banner_") then
		local colour = string.match(assetId, "^prop_banner_(%a+)_")
		bannerProp(ctx, BANNER_COLORS[colour or "red"] or BANNER_COLORS.red)
	elseif has("prop_well") then
		well(ctx)
	elseif has("prop_cart") then
		cart(ctx, variant)
	elseif has("prop_goods") then
		goods(ctx, rng)
	elseif has("farm_haystack") then
		haystack(ctx)
	elseif has("farm_field") then
		cropField(ctx, rng, if string.find(assetId, "cabbage") then "cabbage" else "wheat")
	elseif has("farm_fence") then
		fence(ctx, variant)
	elseif has("bridge_") then
		bridge(ctx)
	else
		crate(ctx)
	end
	return ctx.model
end
Props._standIn = standIn

function Props.prop(assetId: string): Model
	if assetSource then
		local found = assetSource:FindFirstChild(assetId)
		if found and found:IsA("Model") then
			return found:Clone()
		end
	end
	return standIn(assetId)
end

-- ------------------------------------------------------------------ build slot markers (G13.5)

-- Ground marker for a free build slot: a cleared-earth pad inside a low timber sill, survey stakes with
-- kingdom pennants on the corners and a kingdom sign tablet with the emblem at the front (-Z). `size` is
-- slot-local (X width, Y depth). At most 20 parts (BuildSlots.spec).
-- Only Root (0.12 thick, under a building's 0.2 Root) is queryable, so a selection raycast hits the slot
-- Root unless a building stands on it. Nothing collides; units walk across.
function Props.slotMarker(size: Vector2, kingdomColor: Color3): Model
	local ctx = newModel("BuildSlot", size)
	local root = ctx.root
	root.Size = Vector3.new(size.X, 0.12, size.Y)
	root.CFrame = CFrame.new(0, 0.06, 0)
	root.PivotOffset = CFrame.new(0, -0.06, 0)
	local w, d = size.X, size.Y
	local pad = block(
		ctx,
		"Pad",
		Vector3.new(w - 1.4, 0.16, d - 1.4),
		CFrame.new(0, 0.08, 0),
		Color3.fromRGB(176, 144, 102),
		Enum.Material.Ground
	)
	pad.CastShadow = false
	for _, sx in { -1, 1 } do
		block(
			ctx,
			"Sill",
			Vector3.new(0.7, 0.45, d),
			CFrame.new(sx * (w / 2 - 0.35), 0.22, 0),
			C.wood,
			Enum.Material.Wood
		)
		block(
			ctx,
			"Sill",
			Vector3.new(w - 1.4, 0.45, 0.7),
			CFrame.new(0, 0.22, sx * (d / 2 - 0.35)),
			C.wood,
			Enum.Material.Wood
		)
	end
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			local x, z = sx * (w / 2 - 0.35), sz * (d / 2 - 0.35)
			block(ctx, "Stake", Vector3.new(0.45, 3.2, 0.45), CFrame.new(x, 1.6, z), C.woodLight, Enum.Material.Wood)
			block(
				ctx,
				"Pennant",
				Vector3.new(0.12, 0.9, 1.3),
				CFrame.new(x, 2.7, z - sz * 0.75),
				kingdomColor,
				Enum.Material.Fabric,
				1
			)
		end
	end
	-- the slot sign: a kingdom-colour tablet planted at the front, leaning back 35° so its emblem (D-039)
	-- faces the overview camera as well as a walker; the bottom edge sits 0.15 in the ground
	local sign = CFrame.new(w / 2 - 3.5, 0, -d / 2 - 1.7) * CFrame.Angles(math.rad(35), 0, 0) -- top stays outside
	local board = block(
		ctx,
		"SignBoard",
		Vector3.new(2.6, 2.8, 0.3),
		sign * CFrame.new(0, 1.25, 0),
		kingdomColor,
		Enum.Material.SmoothPlastic,
		1
	)
	Pieces.emblem(ctx, board, sign * CFrame.new(0, 1.3, -0.15), 2.15, kingdomColor)
	for _, part in ctx.model:GetChildren() do
		if part:IsA("BasePart") then
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = part == root
		end
	end
	return ctx.model
end

-- ------------------------------------------------------------------ territory markers

function Props.regionMarkers(polygon: { Vector2 }, kingdomColor: Color3): Model
	local ctx = newModel("RegionMarkers", Vector2.new(1, 1))
	local n = #polygon
	for i = 1, n do
		local a, b = polygon[i], polygon[(i % n) + 1]
		for _, t in { 0, 0.5 } do
			local p = a:Lerp(b, t)
			block(
				ctx,
				"MarkerBase",
				Vector3.new(1.6, 0.8, 1.6),
				CFrame.new(p.X, 0.4, p.Y),
				C.stone,
				Enum.Material.Slate
			)
			flagpole(ctx, p.X, 0.8, p.Y, 7, kingdomColor)
		end
	end
	return ctx.model
end

return Props
