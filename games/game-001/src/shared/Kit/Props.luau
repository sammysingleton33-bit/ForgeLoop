--!strict
--[[
	Kit/Props — props by asset id (CONTRACTS G10): the imported Blender mesh when an asset source is
	registered (Kit.setAssetSource(ReplicatedStorage.Forge.Assets)), otherwise a part-built stand-in
	with the same id, so imports swap in automatically (D-021). Also territory markers.
	The nature meshes of FL-0136 (trees, bushes, rocks, resource nodes, flowers, crops) are Models in
	Forge.Assets (or Forge.Assets.EnvKit) checked and prepared by Kit/EnvMesh against Kit/EnvMeshData.

	Stand-ins follow the art bible (blender/ART_DIRECTION.md) as far as primitives allow: chunky,
	layered, colour-varied. They are deterministic per asset id (Park–Miller PRNG from WorldPlan,
	never Random) so Lune previews match Roblox. Ids follow blender/manifest.json:
	tree_oak_NN, tree_pine_NN, tree_birch_NN, bush_NN, plant_flowers_NN, rock_boulder_{s,m,l}_NN,
	rock_cliff_NN, resource_{stone,ore,wood}_NN, prop_banner_<colour>_NN, prop_well_NN, prop_cart_NN,
	prop_goods_NN, farm_haystack_NN, farm_fence_NN, bridge_stone_NN; anything else is a crate.
]]

local KingdomsConfig = require("@game/ReplicatedStorage/Forge/Config/Kingdoms")
local EnvMesh = require("./EnvMesh")
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

-- Foliage colour ramps, dark (shaded underside) to light (sunlit top). Parts take the ramp colour of their
-- height, so a canopy of a dozen solid balls still reads with a gradient.
local OAK_RAMP = { shade(C.leafDark, 0.72), C.leafDark, C.leaf, C.leafLight, EXTRA.oakSun }
local PINE_RAMP = { EXTRA.pine, EXTRA.pineMid, EXTRA.pineLight }
local BIRCH_RAMP = { shade(EXTRA.birchLeaf, 0.86), EXTRA.birchLeaf, EXTRA.birchLeafLight }

local function rampColor(stops: { Color3 }, t: number): Color3
	local x = math.clamp(t, 0, 1) * (#stops - 1)
	local i = math.min(#stops - 2, math.floor(x))
	return stops[i + 1]:Lerp(stops[i + 2], x - i)
end

-- Frame centred between a and b whose local X (cylinders) or Y (blocks) runs from a to b; returns its length.
local function limb(a: Vector3, b: Vector3, alongX: boolean): (CFrame, number)
	local d = b - a
	local len = d.Magnitude
	local dir = d / len
	local up = if math.abs(dir.Y) > 0.98 then Vector3.new(1, 0, 0) else Vector3.new(0, 1, 0)
	local mid = (a + b) / 2
	if alongX then
		local z = dir:Cross(up).Unit
		return CFrame.fromMatrix(mid, dir, z:Cross(dir), z), len
	end
	local x = up:Cross(dir).Unit
	return CFrame.fromMatrix(mid, x, dir, x:Cross(dir)), len
end

-- Oak archetypes by variant id: the eight oaks differ in silhouette, not only in ball sizes.
local OAK_ARCH = { "dome", "tall", "wide", "lopsided", "twin", "dome", "tall", "wide" }
local OAK_TH = {
	dome = { 10.0, 12.0 },
	tall = { 8.2, 9.8 },
	wide = { 11.2, 12.8 },
	lopsided = { 10.0, 11.6 },
	twin = { 10.2, 11.8 },
}

type Lobe = { r: number, a: number, dy: number, d: number, limb: boolean }

-- Ten canopy lobes (polar round the canopy centre) per archetype, exactly two flagged for a limb to reach them.
local function oakLobes(arch: string, rng, a0: number): { Lobe }
	local L: { Lobe } = {}
	local R = rng.range
	local function add(r: number, a: number, dy: number, d: number, holdsLimb: boolean?)
		table.insert(L, { r = r, a = a, dy = dy, d = d, limb = holdsLimb == true })
	end
	if arch == "tall" then
		-- a tall narrow ovoid: four low lobes, three middle, three crowns
		for k = 0, 3 do
			add(R(3.8, 4.8), a0 + k * math.pi / 2 + R(-0.3, 0.3), R(-4.4, -2.8), R(7.2, 8.8), k == 0 or k == 2)
		end
		for k = 0, 2 do
			add(R(2.2, 3.2), a0 + 0.6 + k * 2.1, R(0.8, 2.8), R(6.8, 8.2))
		end
		for k = 0, 2 do
			add(R(0.6, 1.8), a0 + 1.1 + k * 2.1, R(5.6, 7.4), R(5.4, 7.0))
		end
	elseif arch == "wide" then
		-- a wide flat spreading crown: a low core, a ring of six broad lobes, three flat crowns
		add(0, 0, 0, R(10.0, 11.0))
		for k = 0, 5 do
			add(R(6.0, 7.0), a0 + k * math.pi / 3 + R(-0.25, 0.25), R(-1.6, 0.8), R(8.6, 10.0), k == 0 or k == 3)
		end
		for k = 0, 2 do
			add(R(1.0, 3.4), a0 + k * 2.1, R(3.0, 3.8), R(6.0, 7.6))
		end
	elseif arch == "lopsided" then
		-- heavy on one side; on the other a gap with a bare limb carrying one small lobe
		add(2.8, a0, 0.8, R(10.4, 11.4), true)
		for k = 0, 2 do
			add(R(5.6, 7.2), a0 + (k - 1) * 0.85, R(-2.2, 1.4), R(8.0, 9.6))
		end
		for k = 0, 3 do
			add(R(3.6, 5.2), a0 + (k - 1.5) * 0.75, R(-4.6, -3.4), R(5.8, 7.0))
		end
		add(R(5.6, 6.4), a0 + math.pi + R(-0.2, 0.2), R(-1.8, -0.6), R(5.6, 6.6), true)
		add(R(1.0, 2.6), a0 + 0.4, R(4.6, 5.4), R(6.0, 7.2))
	elseif arch == "twin" then
		-- two crowns on a forked trunk: each a core, two shoulders and a crown, joined by two small lobes
		for side = 0, 1 do
			local a = a0 + side * math.pi
			local up = if side == 0 then 1.0 else -0.4
			add(R(5.0, 5.6), a, up + 0.4, R(8.4, 9.2), true)
			add(R(8.2, 9.0), a + R(-0.5, 0.5), up - 1.2, R(6.2, 7.0))
			add(R(7.2, 8.0), a + R(0.8, 1.2), up + 1.4, R(6.0, 6.8))
			add(R(4.6, 5.4), a + R(-0.3, 0.3), up + 4.2, R(5.2, 6.0))
		end
		add(0.6, a0 + 1.4, 3.6, R(5.4, 6.2))
		add(1.2, a0 + 4.0, -2.2, R(5.0, 5.8))
	else
		-- dome: a broad core, two hanging skirt lobes, four shoulders, three sunlit crowns
		add(0, 0, 0, R(11.6, 12.6))
		for k = 0, 1 do
			add(R(4.8, 6.0), a0 + k * math.pi + R(-0.5, 0.5), -R(3.4, 4.2), R(6.5, 7.6), true)
		end
		for k = 0, 3 do
			add(R(4.8, 6.8), a0 + 0.8 + k * (math.pi / 2) + R(-0.4, 0.4), R(-2.0, 1.6), R(8.2, 10.4))
		end
		for _ = 1, 3 do
			add(R(0.8, 3.8), R(0, 2 * math.pi), R(3.8, 4.8), R(6.4, 8.4))
		end
	end
	return L
end

local function oak(ctx, rng, variant: number)
	local arch = OAK_ARCH[(variant - 1) % #OAK_ARCH + 1]
	local thRange = OAK_TH[arch]
	local th = rng.range(thRange[1], thRange[2])
	local la = rng.range(0, 2 * math.pi)
	local lean = math.rad(rng.range(3.5, 8))
	local dir = Vector3.new(math.sin(lean) * math.cos(la), math.cos(lean), math.sin(lean) * math.sin(la))
	-- trunk: a broad root flare in the bark colour, a straight foot, then a slightly leaning stem into the canopy
	column(ctx, "TrunkFlare", 2.05, 0.9, Vector3.zero, C.bark, Enum.Material.Wood)
	column(ctx, "Trunk", 1.6, 3.6, Vector3.new(0, 0.7, 0), C.bark, Enum.Material.Wood)
	local p0 = Vector3.new(0, 4.3, 0)
	local tip = p0 + dir * (th - 1.0)
	local stemCF, stemLen = limb(p0 - dir * 0.3, tip, true)
	log(ctx, "Trunk", 1.25, stemLen, stemCF, C.bark)

	local cc = tip + Vector3.new(dir.X * 1.5, 2.6, dir.Z * 1.5)
	local lobes = oakLobes(arch, rng, rng.range(0, 2 * math.pi))
	local lo, hi = math.huge, -math.huge
	for _, l in lobes do
		lo, hi = math.min(lo, l.dy), math.max(hi, l.dy)
	end
	local targets = {}
	for _, l in lobes do
		local pos = Vector3.new(cc.X + math.cos(l.a) * l.r, cc.Y + l.dy, cc.Z + math.sin(l.a) * l.r)
		local t = 0.2 + 0.78 * (l.dy - lo) / math.max(hi - lo, 1) + rng.range(-0.05, 0.05)
		local part = ball(ctx, "Canopy", l.d, pos, rampColor(OAK_RAMP, t), Enum.Material.Grass)
		part.CastShadow = l.d > 7.7
		if l.limb then
			table.insert(targets, pos)
		end
	end
	-- two thick limbs reach out to the flagged lobes; the canopy hides their far ends (a forked archetype shows them)
	local forked = arch == "twin" or arch == "lopsided"
	for k, target in targets do
		local from = p0 + (tip - p0) * (if forked then 0.55 + 0.1 * k else 0.2 + 0.14 * k)
		local to = from + (target - from) * (if forked then 0.9 else 0.8)
		local cf, len = limb(from, to, true)
		log(ctx, "Branch", 0.8, len, cf, shade(C.bark, 0.95))
	end
end

local function pine(ctx, rng)
	local h = rng.range(28, 33)
	local la = rng.range(0, 2 * math.pi)
	local lean = rng.range(0.025, 0.06)
	local function axis(y: number): Vector3
		return Vector3.new(math.cos(la) * lean * y, y, math.sin(la) * lean * y)
	end
	local cf, len = limb(Vector3.zero, axis(h * 0.62), true)
	log(ctx, "Trunk", 1.0, len, cf, C.bark)
	-- six whorls of drooping boughs (the lowest two of four, a full skirt), each turned against the last, narrowing to the tip: wedges whose
	-- tall face meets the trunk and whose slope falls away outward
	local counts = { 4, 4, 3, 3, 2, 2 }
	local top = h - 6.4
	for i, n in counts do
		local t = (i - 1) / (#counts - 1)
		local reach = 5.6 * (1 - t) ^ 0.9 + 2.4
		local thick = 3.8 - 0.5 * t
		local y = 3.6 + t * (top - 3.6)
		local turn = i * math.rad(if n == 3 then 47 elseif n == 4 then 45 else 90) + rng.range(-0.12, 0.12)
		for b = 0, n - 1 do
			local a = turn + b * (2 * math.pi / n)
			local c = axis(y)
			local bough = CFrame.new(c.X, y + thick / 2, c.Z)
				* CFrame.Angles(0, a, 0)
				* CFrame.new(0, 0, -(reach / 2 - 0.6))
			wedge(
				ctx,
				"Bough",
				Vector3.new(math.min(reach * 1.0, 2 * math.pi * reach * 0.6 / n * 1.05), thick, reach),
				bough,
				shade(rampColor(PINE_RAMP, t ^ 0.8), 0.92 + 0.08 * (b % 2)),
				Enum.Material.Grass
			)
		end
	end
	-- tapering tip: two crossed quarter pyramids
	local base = axis(top + 1.6)
	for q = 0, 1 do
		local tipCF = CFrame.new(base.X, top + 1.6 + 2.2, base.Z)
			* CFrame.Angles(0, math.rad(180 * q), 0)
			* CFrame.new(0.8, 0, 0.8)
			* CFrame.Angles(0, math.rad(90), 0)
		cornerWedge(ctx, "Tip", Vector3.new(1.6, 4.4, 1.6), tipCF, EXTRA.pineLight, Enum.Material.Grass)
	end
end

local function birch(ctx, rng)
	local h = rng.range(17, 21)
	local la = rng.range(0, 2 * math.pi)
	local lean = math.rad(rng.range(2, 5))
	local dir = Vector3.new(math.sin(lean) * math.cos(la), math.cos(lean), math.sin(lean) * math.sin(la))
	local cf, len = limb(Vector3.zero, dir * (h + 0.5), true)
	log(ctx, "Trunk", 0.65, len, cf, EXTRA.birch, Enum.Material.SmoothPlastic)
	-- one dark bark mark low on the trunk (the birch giveaway)
	local markCF = limb(dir * (h * 0.3 - 0.2), dir * (h * 0.3 + 0.2), true)
	log(ctx, "Bark", 0.7, 0.4, markCF, EXTRA.birchMark, Enum.Material.SmoothPlastic)
	-- a crown of five overlapping clumps stacked up the trunk top, wound into the trunk so nothing floats...
	local a0 = rng.range(0, 2 * math.pi)
	for i = 1, 4 do
		local f = (i - 1) / 3
		local a = a0 + i * 2.2 + rng.range(-0.3, 0.3)
		local r = rng.range(0.9, 2.4) * (1 - 0.3 * f)
		local y = h - 5.4 + f * 5.6 + rng.range(-0.4, 0.4)
		local d = rng.range(5.0, 6.4) * (1 - 0.2 * f)
		local pos = dir * y + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
		local part =
			ball(ctx, "Canopy", d, pos, rampColor(BIRCH_RAMP, f * 0.8 + rng.range(0, 0.25)), Enum.Material.Grass)
		part.CastShadow = false
	end
	-- ... and one side branch stub carrying a fifth clump out to the side, so the crown has a fork and a gap
	local sa = a0 + math.pi + rng.range(-0.5, 0.5)
	local from = dir * (h * 0.56)
	local to = from + Vector3.new(math.cos(sa) * 3.4, 3.0, math.sin(sa) * 3.4)
	local stubCF, stubLen = limb(from, to, true)
	log(ctx, "Stub", 0.3, stubLen, stubCF, EXTRA.birch, Enum.Material.SmoothPlastic)
	local side = ball(
		ctx,
		"Canopy",
		rng.range(4.2, 5.0),
		to + Vector3.new(math.cos(sa) * 0.8, 0.9, math.sin(sa) * 0.8),
		rampColor(BIRCH_RAMP, 0.3),
		Enum.Material.Grass
	)
	side.CastShadow = false
end

local function bush(ctx, rng, variant: number)
	-- a broad sunlit dome with three darker lobes tucked around its foot
	local main = rng.range(4.8, 5.6)
	local top = ball(ctx, "Bush", main, Vector3.new(0, main / 2 - 0.5, 0), C.leafLight, Enum.Material.Grass)
	local a0 = rng.range(0, 2 * math.pi)
	local lobeTones = { C.leafDark, C.leaf, shade(C.leafDark, 1.12) }
	for k = 0, 2 do
		local a = a0 + k * 2.1 + rng.range(-0.25, 0.25)
		local d = rng.range(3.2, 4.2)
		local r = main * rng.range(0.34, 0.42)
		ball(
			ctx,
			"Bush",
			d,
			Vector3.new(math.cos(a) * r, d / 2 - 0.5, math.sin(a) * r),
			lobeTones[k + 1],
			Enum.Material.Grass
		)
	end
	if variant % 3 ~= 1 then
		local c = if variant % 3 == 0 then EXTRA.berry else EXTRA.flowerWhite
		for i = 1, 5 do
			local a = i * 1.25 + a0
			local el = math.rad(34 + (i % 3) * 14)
			local rr = main / 2 + 0.05
			local pos = Vector3.new(
				math.cos(a) * math.cos(el) * rr,
				main / 2 - 0.5 + math.sin(el) * rr,
				math.sin(a) * math.cos(el) * rr
			)
			ball(ctx, "Berry", 1.0, pos, c, Enum.Material.SmoothPlastic).CastShadow = false
		end
	end
	top.CastShadow = true
end

local function flowers(ctx, rng)
	-- a leafy mound with six large blooms sitting on it, so the colour reads from the aerial camera too
	ball(ctx, "Leaves", 2.5, Vector3.new(0, 0.2, 0), C.leaf, Enum.Material.Grass).CastShadow = false
	ball(ctx, "Leaves", 1.8, Vector3.new(1.2, 0.1, -0.8), C.leafDark, Enum.Material.Grass).CastShadow = false
	local colors = { EXTRA.flowerRed, EXTRA.flowerYellow, EXTRA.flowerWhite, EXTRA.flowerPurple }
	local base = colors[rng.int(1, 4)]
	for i = 1, 6 do
		local a = i * 1.05 + rng.range(-0.2, 0.2)
		local r = rng.range(0.2, 1.9)
		local y = if r < 1.2 then 0.2 + math.sqrt(1.25 ^ 2 - r ^ 2) + 0.1 else 0.5 + rng.range(0, 0.3)
		local pos = Vector3.new(math.cos(a) * r, y, math.sin(a) * r)
		local part = ball(
			ctx,
			"Flower",
			1.0,
			pos,
			if i % 3 == 0 then colors[rng.int(1, 4)] else base,
			Enum.Material.SmoothPlastic
		)
		part.CastShadow = false
	end
end

-- ---------------------------------------------------------------- rocks and resources

-- Cooler, darker foot; warmer, lighter top; a touch of moss.
local ROCK = {
	base = Color3.fromRGB(106, 110, 118),
	mid = Color3.fromRGB(136, 136, 138),
	top = Color3.fromRGB(172, 170, 162),
	moss = Color3.fromRGB(96, 132, 62),
}

-- One angular rock mass: a block, wedge or corner wedge turned by yaw and tipped by tx/tz (radians).
local function chunk(
	ctx,
	kind: string,
	size: Vector3,
	pos: Vector3,
	yaw: number,
	tx: number,
	tz: number,
	color: Color3,
	name: string?
)
	local cf = CFrame.new(pos) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(tx, 0, tz)
	local make = if kind == "wedge" then wedge elseif kind == "corner" then cornerWedge else block
	return make(ctx, name or "Rock", size, cf, color, Enum.Material.Slate)
end

-- A faceted lump: a block tipped hard on two axes (a cube balanced on an edge reads as an angular boulder, not a
-- box). With no `y` it sits on the ground, sunk 0.45; with `y` it is centred there. Returns the part and the
-- height of its highest point so the next lump can be bedded into it.
local function lump(
	ctx,
	size: Vector3,
	x: number,
	z: number,
	yaw: number,
	tx: number,
	tz: number,
	color: Color3,
	name: string?,
	y: number?
): (BasePart, number, number)
	local rot = CFrame.Angles(0, yaw, 0) * CFrame.Angles(tx, 0, tz)
	local c = { rot:GetComponents() }
	local ey = 0.5 * (math.abs(c[7]) * size.X + math.abs(c[8]) * size.Y + math.abs(c[9]) * size.Z)
	local cy = y or (ey - 0.45)
	return block(ctx, name or "Rock", size, CFrame.new(x, cy, z) * rot, color, Enum.Material.Slate), cy + ey, ey
end

-- Boulders differ in structure, not just scale: S is two tipped lumps (2 parts), M a dark lump under a lighter
-- one plus a pebble (3), L a foot, a mid mass, a leaning lump and a moss tuft (4); cliffs (3) are the L stack
-- taller. Budget: S + M + L = 12 parts incl. Root, same as the old 3 x 4.
local function boulder(ctx, rng, kind: string)
	local yaw = rng.range(0, 2 * math.pi)
	local k = rng.range(0.92, 1.1)
	local function tilt(m: number): number
		return m * rng.range(0.75, 1.15) * (if rng.next() < 0.5 then -1 else 1)
	end
	if kind == "s" then
		lump(ctx, Vector3.new(4.0 * k, 2.3, 3.5 * k), -0.4, 0, yaw, tilt(0.25), tilt(0.22), ROCK.mid)
		lump(ctx, Vector3.new(2.8 * k, 2.0, 2.4 * k), 1.8, 1.0, yaw + 1.0, tilt(0.3), tilt(0.3), ROCK.top)
	elseif kind == "m" then
		local _, top = lump(ctx, Vector3.new(6.2 * k, 2.4, 5.2 * k), 0, 0, yaw, tilt(0.2), tilt(0.2), ROCK.base)
		lump(
			ctx,
			Vector3.new(4.4 * k, 2.4, 3.6 * k),
			0.5,
			-0.3,
			yaw + 0.8,
			tilt(0.3),
			tilt(0.28),
			ROCK.top,
			nil,
			top - 0.8
		)
		local a = yaw + rng.range(2.2, 4.0)
		lump(ctx, Vector3.new(1.9, 1.2, 1.7), math.cos(a) * 4.6, math.sin(a) * 4.6, a, 0.4, 0.3, ROCK.mid, "Pebble")
	else
		local g = if kind == "cliff" then 1.4 else 1.25 -- L is big; cliffs the biggest and tallest
		local _, top = lump(ctx, Vector3.new(10.0 * k, 3.0, 8.4 * k) * g, 0, 0, yaw, tilt(0.14), tilt(0.12), ROCK.base)
		local _, top2 = lump(
			ctx,
			Vector3.new(6.0 * k, 3.0, 5.0 * k) * g,
			-0.8 * g,
			0.5 * g,
			yaw + 0.6,
			tilt(0.3),
			tilt(0.26),
			ROCK.mid,
			nil,
			top - 1.2
		)
		if kind ~= "cliff" then
			local a = yaw + 2.6
			lump(
				ctx,
				Vector3.new(4.4 * k, 2.8, 3.8 * k) * g,
				math.cos(a) * 5.8 * g,
				math.sin(a) * 5.8 * g,
				a,
				tilt(0.34),
				tilt(0.34),
				ROCK.top
			)
		end
		ball(ctx, "Moss", 2.2 * g, Vector3.new(-0.8 * g, top2 - 0.9, 0.5 * g), ROCK.moss, Enum.Material.Grass).CastShadow =
			false
	end
end

-- Quarry: stepped, stratified slabs in alternating bands (dark / pale / mid) with flat cut faces, rubble
-- sloping off one side, a neat stack of dressed blocks and a pick. 7 parts.
local function quarryNode(ctx, rng)
	local bands = { ROCK.base, C.stoneLight, ROCK.mid }
	local sizes = { Vector3.new(11, 2.6, 9), Vector3.new(9, 2.4, 7.4), Vector3.new(6.6, 2.2, 5.4) }
	local offs = { Vector3.new(0, 1.0, 0), Vector3.new(-0.6, 3.8, 0.5), Vector3.new(-1.2, 6.1, -0.4) }
	for i = 1, 3 do
		chunk(
			ctx,
			"block",
			sizes[i],
			offs[i],
			rng.range(-0.18, 0.18),
			rng.range(-0.03, 0.03),
			rng.range(-0.03, 0.03),
			bands[i],
			"Stratum"
		)
	end
	chunk(
		ctx,
		"wedge",
		Vector3.new(4.2, 2.8, 3.6),
		Vector3.new(7.0, 1.1, 0.8),
		math.rad(90) + rng.range(-0.2, 0.2),
		0,
		0,
		ROCK.mid,
		"Rubble"
	)
	chunk(
		ctx,
		"block",
		Vector3.new(3.0, 1.7, 2.4),
		Vector3.new(-6.2, 0.55, -4.6),
		rng.range(-0.15, 0.15),
		0,
		0,
		C.stoneLight,
		"CutBlock"
	)
	chunk(
		ctx,
		"block",
		Vector3.new(2.8, 1.6, 2.2),
		Vector3.new(-6.0, 2.15, -4.5),
		rng.range(0.2, 0.4),
		0,
		0,
		shade(C.stoneLight, 0.94),
		"CutBlock"
	)
	local pick = CFrame.new(-4.2, 1.55, -5.1) * CFrame.Angles(0, 0.4, math.rad(28))
	block(ctx, "Pick", Vector3.new(0.3, 3.4, 0.3), pick, C.wood, Enum.Material.Wood)
end

-- Ore: an angular host rock (3 chunks and a pebble) studded with 5 bright nuggets (iron: rust, gold: yellow)
-- or tall crystals; the nuggets sit proud of the faces so the colour reads from every side.
local function oreNode(ctx, rng, variant: number)
	local yaw = rng.range(0, 2 * math.pi)
	local _, top = lump(ctx, Vector3.new(8.2, 2.8, 6.8), 0.3, 0, yaw, 0.2, -0.18, ROCK.base)
	lump(ctx, Vector3.new(5.0, 3.6, 4.4), 0.1, -0.2, yaw + 0.7, 0.35, -0.3, ROCK.mid, nil, top - 0.5)
	lump(ctx, Vector3.new(3.4, 2.4, 3.0), -4.2 * math.cos(yaw), -4.2 * math.sin(yaw), yaw + 0.4, 0.3, 0.34, ROCK.top)
	local pa = yaw + 2.4
	lump(ctx, Vector3.new(2.0, 1.4, 1.8), math.cos(pa) * 6.0, math.sin(pa) * 6.0, pa, 0.5, 0.4, ROCK.base, "Pebble")
	local ore = if variant <= 2 then EXTRA.ironOre elseif variant <= 4 then EXTRA.goldOre else EXTRA.crystal
	for i = 1, 5 do
		local a = yaw + i * 1.25 + rng.range(-0.2, 0.2)
		local r = 2.6 + (i % 2) * 0.5
		local y = 2.6 + (i % 3) * 1.2
		local pos = Vector3.new(math.cos(a) * r, y, math.sin(a) * r)
		if variant >= 5 then
			local cf = CFrame.new(pos) * CFrame.Angles(rng.range(-0.5, 0.5), 0, rng.range(-0.5, 0.5))
			block(ctx, "Crystal", Vector3.new(1.1, rng.range(2.6, 4.2), 1.1), cf, ore, Enum.Material.Neon)
		else
			local cf = CFrame.new(pos) * CFrame.Angles(rng.range(0, 3), rng.range(0, 3), rng.range(0, 1))
			block(ctx, "Ore", Vector3.new(2.4, 1.9, 2.1), cf, ore, Enum.Material.Metal)
		end
	end
end

-- Wood: a pile of five logs (end rings in pale cut wood on the -Z ends) beside a chopped stump with its
-- axe stuck in the top. 13 parts.
local function woodNode(ctx, rng)
	local rows = { { -1.8, 0 }, { 0, 0.15 }, { 1.8, -0.2 }, { -0.9, 1.5 }, { 0.9, 1.5 } }
	for i, spot in rows do
		local len = 6.2 + rng.range(-0.4, 0.4)
		local x, y = spot[1], if i <= 3 then 0.85 else 2.35
		local cf = CFrame.new(x, y, spot[2]) * CFrame.Angles(0, math.rad(90), 0)
		log(ctx, "Log", 0.88, len, cf, C.bark)
		if i ~= 5 then
			local ring = CFrame.new(x, y, spot[2] - len / 2 - 0.02) * CFrame.Angles(0, math.rad(90), 0)
			log(ctx, "LogEnd", 0.74, 0.12, ring, C.woodLight)
		end
	end
	column(ctx, "Stump", 1.4, 1.7, Vector3.new(5.0, 0, 2.6), C.bark, Enum.Material.Wood)
	column(ctx, "StumpTop", 1.2, 0.12, Vector3.new(5.0, 1.7, 2.6), C.woodLight, Enum.Material.Wood)
	local handle = CFrame.new(5.5, 2.9, 2.6) * CFrame.Angles(0, 0, math.rad(rng.range(18, 28)))
	block(ctx, "AxeHandle", Vector3.new(0.28, 2.6, 0.28), handle, C.wood, Enum.Material.Wood)
	block(
		ctx,
		"AxeHead",
		Vector3.new(1.1, 0.8, 0.22),
		CFrame.new(4.7, 1.95, 2.6) * CFrame.Angles(0, 0, math.rad(-18)),
		C.iron,
		Enum.Material.Metal
	)
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

-- Haystack: a round-shouldered stack: a drum of hay under a domed top (hay-coloured, Grass material) and a
-- pitchfork leaning on it. 3 parts.
local function haystack(ctx)
	column(ctx, "Hay", 3.0, 3.0, Vector3.new(0, 0, 0), EXTRA.hay, Enum.Material.Grass)
	ball(ctx, "HayDome", 6.2, Vector3.new(0, 3.0, 0), shade(EXTRA.hay, 1.06), Enum.Material.Grass)
	local fork = CFrame.new(3.3, 2.9, -0.8) * CFrame.Angles(0, 0, math.rad(-18))
	block(ctx, "Pitchfork", Vector3.new(0.25, 5, 0.25), fork, C.wood, Enum.Material.Wood)
end

-- Low field fence, 16.2 long: five posts and one or two rails, lower than the old fence (2.7 vs 3.4) so it
-- frames a field without walling it in; still taller than the crop rows (top at 2.4).
local function fence(ctx, variant: number)
	for i = 0, 4 do
		local h = 2.7 + (if i % 2 == 0 then 0.1 else -0.1)
		block(ctx, "Post", Vector3.new(0.5, h, 0.5), CFrame.new(-8 + i * 4, h / 2, 0), C.wood, Enum.Material.Wood)
	end
	for _, y in (if variant % 2 == 0 then { 1.0, 1.95 } else { 1.7 }) do
		block(ctx, "Rail", Vector3.new(16.2, 0.32, 0.28), CFrame.new(0, y, 0), C.woodLight, Enum.Material.Wood)
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

-- Crop plot: its visual footprint is exactly FIELD_SIZE (38 x 28, inside the 40 x 30 terrain field): a brown soil
-- bed with the rows on it, so the soil shows as a border and as furrows between the rows. Wheat rows are
-- uniform, low (1.7 over the bed plus a 0.22 lighter top slab, flat-topped) and one block each; cabbages sit on soil
-- ridges. Soil luminance is about 74-86, brown, never black.
local FIELD_W, FIELD_D = 38, 28
Props.FIELD_SIZE = Vector2.new(FIELD_W, FIELD_D)
local SOIL = Color3.fromRGB(96, 70, 44)
local SOIL_RIDGE = Color3.fromRGB(112, 82, 52)
local BED_H = 0.5 -- the terrain field's top is 0.2 above ground: the bed clears it so nothing z-fights

local function cropField(ctx, rng, crop: string)
	block(ctx, "SoilBed", Vector3.new(FIELD_W, BED_H, FIELD_D), CFrame.new(0, BED_H / 2, 0), SOIL, Enum.Material.Ground)
	if crop == "cabbage" then
		for r = 0, 6 do
			local z = -12 + r * 4
			block(
				ctx,
				"Ridge",
				Vector3.new(34, 0.5, 2.2),
				CFrame.new(0, BED_H + 0.25, z),
				SOIL_RIDGE,
				Enum.Material.Ground
			)
			for k = 0, 7 do
				local d = rng.range(2.0, 2.4)
				local pos = Vector3.new((k - 3.5) * 4.2 + rng.range(-0.3, 0.3), BED_H + 0.5 + d / 2 - 0.25, z)
				ball(ctx, "Cabbage", d, pos, if (k + r) % 3 == 0 then C.leafLight else C.leaf, Enum.Material.Grass)
			end
		end
		return
	end
	local rowH = 1.7
	for r = 0, 5 do
		local z = (r - 2.5) * 4.4
		block(
			ctx,
			"Wheat",
			Vector3.new(34, rowH, 2.6),
			CFrame.new(0, BED_H + rowH / 2, z),
			C.wheat,
			Enum.Material.Grass
		)
		block(
			ctx,
			"WheatTop",
			Vector3.new(33.4, 0.22, 2.0),
			CFrame.new(0, BED_H + rowH + 0.11, z),
			shade(EXTRA.hay, 1.1),
			Enum.Material.Grass
		)
	end
	-- three sheaves on the soil border
	for i, x in { -13, 1, 14 } do
		ball(
			ctx,
			"Sheaf",
			1.9,
			Vector3.new(x + rng.range(-1, 1), BED_H + 0.8, 13.05),
			if i == 2 then EXTRA.hayDark else EXTRA.hay,
			Enum.Material.Grass
		)
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
	-- adjacent ids hash to adjacent seeds, whose first draws are nearly equal: burn a few so variants differ
	for _ = 1, 4 do
		rng.next()
	end
	local variant = variantOf(assetId)
	local function has(prefix: string): boolean
		return string.sub(assetId, 1, #prefix) == prefix
	end
	if has("tree_pine") then
		pine(ctx, rng)
	elseif has("tree_birch") then
		birch(ctx, rng)
	elseif has("tree_") then
		oak(ctx, rng, variant)
	elseif has("bush") then
		bush(ctx, rng, variant)
	elseif has("plant_") then
		flowers(ctx, rng)
	elseif has("rock_boulder_s") then
		boulder(ctx, rng, "s")
	elseif has("rock_boulder_m") then
		boulder(ctx, rng, "m")
	elseif has("rock_boulder_l") then
		boulder(ctx, rng, "l")
	elseif has("rock_") then
		boulder(ctx, rng, "cliff")
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

-- A Model for the id in the asset source is cloned. The nature meshes (Kit/EnvMeshData lists their ids) are made ready by
-- Kit/EnvMesh first and rejected, in favour of the stand-in, when they do not match their data (never an error); an id
-- the data does not list is cloned and passed through unchanged (nothing is checked).
function Props.prop(assetId: string): Model
	local found = EnvMesh.find(assetSource, assetId)
	if found and found:IsA("Model") then
		local ready = EnvMesh.accept(assetId, found:Clone()) -- the clone itself for an id the data does not list
		if ready then
			return ready
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
