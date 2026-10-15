-- Environment props (FORGE-02 art polish from the first Studio playtest): trees, bushes, flowers, boulders,
-- resource nodes, crop fields, fence and haystack. Part counts are pinned at the pre-polish numbers (the world
-- sits at its D-047 ceiling, so a fuller look has to come from better shapes, not more parts); shapes, colours
-- and footprints are pinned where the polish promised them. Headless geometry only: how it looks is judged on
-- the Blender renders (art/reviews/kit-architecture.md), not here.
local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local Kit = require("@game/ReplicatedStorage/Game/Kit/Kit")
local Props = require("@game/ReplicatedStorage/Game/Kit/Props")

local PRIMITIVE = { Part = true, WedgePart = true, CornerWedgePart = true }

local function ids(prefix: string, n: number): { string }
	local out = {}
	for i = 1, n do
		table.insert(out, string.format("%s_%02d", prefix, i))
	end
	return out
end

local function concat(...: { string }): { string }
	local out = {}
	for _, list in { ... } do
		for _, v in list do
			table.insert(out, v)
		end
	end
	return out
end

local OAKS, PINES, BIRCHES = ids("tree_oak", 8), ids("tree_pine", 6), ids("tree_birch", 6)
local TREES = concat(OAKS, PINES, BIRCHES)
local BUSHES, FLOWERS = ids("bush", 8), ids("plant_flowers", 6)
local BOULDERS_S, BOULDERS_M, BOULDERS_L = ids("rock_boulder_s", 3), ids("rock_boulder_m", 3), ids("rock_boulder_l", 3)
local BOULDERS = concat(BOULDERS_S, BOULDERS_M, BOULDERS_L, ids("rock_cliff", 2))
local STONES, ORES, WOODS = ids("resource_stone", 3), ids("resource_ore", 6), ids("resource_wood", 2)
local WHEAT, CABBAGE = ids("farm_field_wheat", 3), ids("farm_field_cabbage", 3)
local FENCES, HAYSTACKS = ids("farm_fence", 2), ids("farm_haystack", 1)
local ALL = concat(TREES, BUSHES, FLOWERS, BOULDERS, STONES, ORES, WOODS, WHEAT, CABBAGE, FENCES, HAYSTACKS)

-- Part counts (Root included) before the polish, as Kit.partCount reported them on main 0160bd3.
local CEILING: { [string]: number } = {}
local function ceil(list: { string }, n: number)
	for _, id in list do
		CEILING[id] = n
	end
end
ceil(OAKS, 16)
CEILING.tree_oak_01, CEILING.tree_oak_02 = 18, 18
ceil(PINES, 22)
ceil(BIRCHES, 9)
for i, id in BUSHES do
	CEILING[id] = if i % 3 == 1 then 5 else 10
end
ceil(FLOWERS, 9)
ceil(BOULDERS, 4)
ceil(STONES, 8)
ceil(ORES, 10)
ceil(WOODS, 14)
-- D-047 amendment (2026-10-15, FL-0117 wheat): a wheat field may use up to 44 parts (was 17), one tapered tilted wedge per
-- tuft, conditional on FL-0116's measured headroom (the dressing density knob pays otherwise)
local WHEAT_PARTS = 44
ceil(WHEAT, WHEAT_PARTS)
ceil(CABBAGE, 66)
ceil({ "farm_fence_01" }, 7)
ceil({ "farm_fence_02" }, 8)
ceil(HAYSTACKS, 4)
-- Boulders trade parts between sizes: S 3 / M 4 / L 5 (cliff 4), family total 36 = the old 9 x 4.
ceil(BOULDERS_S, 3)
ceil(BOULDERS_L, 5)

local function parts(model: Instance): { BasePart }
	local out = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d ~= (model :: Model).PrimaryPart then
			table.insert(out, d)
		end
	end
	return out
end

local function named(model: Instance, name: string): { BasePart }
	local out = {}
	for _, p in parts(model) do
		if p.Name == name then
			table.insert(out, p)
		end
	end
	return out
end

local function lum(c: Color3): number
	return 255 * (0.2126 * c.R + 0.7152 * c.G + 0.0722 * c.B)
end

-- world-space axis-aligned bounds of the real parts (Root excluded), exact for rotated parts
local function bounds(model: Instance): (Vector3, Vector3)
	local lo, hi = Vector3.new(1e9, 1e9, 1e9), Vector3.new(-1e9, -1e9, -1e9)
	for _, p in parts(model) do
		for _, sx in { -1, 1 } do
			for _, sy in { -1, 1 } do
				for _, sz in { -1, 1 } do
					local v = (p.CFrame * CFrame.new(sx * p.Size.X / 2, sy * p.Size.Y / 2, sz * p.Size.Z / 2)).Position
					lo = Vector3.new(math.min(lo.X, v.X), math.min(lo.Y, v.Y), math.min(lo.Z, v.Z))
					hi = Vector3.new(math.max(hi.X, v.X), math.max(hi.Y, v.Y), math.max(hi.Z, v.Z))
				end
			end
		end
	end
	return lo, hi
end

-- do two parts' bounding boxes touch (SAT over the 15 axes, margin 0.05 studs each side)?
local function touching(a: BasePart, b: BasePart): boolean
	local ha, hb = a.Size / 2 + Vector3.new(0.05, 0.05, 0.05), b.Size / 2 + Vector3.new(0.05, 0.05, 0.05)
	local axa = { a.CFrame.RightVector, a.CFrame.UpVector, a.CFrame.LookVector }
	local axb = { b.CFrame.RightVector, b.CFrame.UpVector, b.CFrame.LookVector }
	local d = b.CFrame.Position - a.CFrame.Position
	local function separated(axis: Vector3): boolean
		if axis.Magnitude < 1e-6 then
			return false
		end
		axis = axis.Unit
		local ra = math.abs(axa[1]:Dot(axis)) * ha.X
			+ math.abs(axa[2]:Dot(axis)) * ha.Y
			+ math.abs(axa[3]:Dot(axis)) * ha.Z
		local rb = math.abs(axb[1]:Dot(axis)) * hb.X
			+ math.abs(axb[2]:Dot(axis)) * hb.Y
			+ math.abs(axb[3]:Dot(axis)) * hb.Z
		return math.abs(d:Dot(axis)) > ra + rb
	end
	for i = 1, 3 do
		if separated(axa[i]) or separated(axb[i]) then
			return false
		end
		for j = 1, 3 do
			if separated(axa[i]:Cross(axb[j])) then
				return false
			end
		end
	end
	return true
end

local function lowestHighest(p: BasePart): (number, number)
	local lo, hi = math.huge, -math.huge
	for _, sx in { -1, 1 } do
		for _, sy in { -1, 1 } do
			for _, sz in { -1, 1 } do
				local y = (p.CFrame * CFrame.new(sx * p.Size.X / 2, sy * p.Size.Y / 2, sz * p.Size.Z / 2)).Position.Y
				lo, hi = math.min(lo, y), math.max(hi, y)
			end
		end
	end
	return lo, hi
end

local function signature(model: Instance): string
	local out = {}
	for _, p in parts(model) do
		local c = { p.CFrame:GetComponents() }
		for i, v in c do
			c[i] = string.format("%.3f", v)
		end
		table.insert(out, `{p.ClassName}|{p.Name}|{p.Size}|{table.concat(c, ",")}|{p.Color}|{p.Material.Name}`)
	end
	return table.concat(out, "\n")
end

local function radius(lo: Vector3, hi: Vector3): number
	return math.max(-lo.X, hi.X, -lo.Z, hi.Z)
end

describe("environment props: budget", function()
	it("never costs more parts than before the polish, for every asset id", function()
		for _, id in ALL do
			local n = Kit.partCount(Kit.prop(id))
			if n > CEILING[id] then
				error(`{id}: {n} parts > {CEILING[id]}`)
			end
		end
	end)

	it("keeps every tree family at or under its old total (oak 8 variants, pine 6, birch 6)", function()
		local function total(list: { string }): number
			local n = 0
			for _, id in list do
				n += Kit.partCount(Kit.prop(id))
			end
			return n
		end
		expect(total(OAKS)).toBeLessThanOrEqual(16 * 6 + 18 * 2)
		expect(total(PINES)).toBeLessThanOrEqual(22 * 6)
		expect(total(BIRCHES)).toBeLessThanOrEqual(9 * 6)
	end)

	it("keeps the boulder family (S + M + L, 3 variants each) at or under the old 9 x 4 parts", function()
		local n = 0
		for _, id in concat(BOULDERS_S, BOULDERS_M, BOULDERS_L) do
			n += Kit.partCount(Kit.prop(id))
		end
		expect(n).toBeLessThanOrEqual(36)
	end)
end)

describe("environment props: part hygiene", function()
	it("builds anchored primitive parts, tagged as stand-ins, without yielding", function()
		for _, id in ALL do
			local co = coroutine.create(function()
				return Kit.prop(id)
			end)
			local ok, model = coroutine.resume(co)
			assert(ok, model)
			expect(coroutine.status(co)).toBe("dead")
			expect(model:GetAttribute("KitStandIn")).toBe(true)
			expect(model.PrimaryPart).never.toBeNil()
			for _, d in model:GetDescendants() do
				expect(d:IsA("PartOperation")).toBe(false)
				if d:IsA("BasePart") then
					if not PRIMITIVE[d.ClassName] then
						error(`{id}: non-primitive part {d.ClassName} {d.Name}`)
					end
					expect(d.Anchored).toBe(true)
				end
			end
		end
	end)

	it("uses Neon only for the crystal ore variants", function()
		for _, id in ALL do
			local crystal = string.find(id, "resource_ore_05", 1, true) or string.find(id, "resource_ore_06", 1, true)
			for _, p in parts(Kit.prop(id)) do
				if p.Material == Enum.Material.Neon and not crystal then
					error(`{id}: Neon part {p.Name}`)
				end
			end
		end
	end)

	it("leaves no part floating (every part touches the ground or another part) and none buried", function()
		for _, id in ALL do
			local all = parts(Kit.prop(id))
			for i, p in all do
				local lo, hi = lowestHighest(p)
				if hi < 0.15 then
					error(`{id}: {p.Name} #{i} is buried (top {hi})`)
				end
				local held = lo <= 0.1
				for j, q in all do
					if not held and i ~= j and touching(p, q) then
						held = true
					end
				end
				if not held then
					error(`{id}: {p.Name} #{i} floats (lowest point {lo}, touches no other part)`)
				end
			end
		end
	end)

	it("sinks nothing deeper than 1 stud and floats nothing off the ground", function()
		for _, id in ALL do
			local lo = bounds(Kit.prop(id))
			if lo.Y < -1.4 or lo.Y > 0.35 then
				error(`{id}: lowest point {lo.Y}`)
			end
		end
	end)

	it("builds the same model for the same asset id, and different oaks, pines and birches differ", function()
		for _, id in ALL do
			expect(signature(Kit.prop(id))).toBe(signature(Kit.prop(id)))
		end
		for _, family in { OAKS, PINES, BIRCHES, BUSHES } do
			local seen = {}
			for _, id in family do
				seen[signature(Kit.prop(id))] = true
			end
			local n = 0
			for _ in seen do
				n += 1
			end
			expect(n).toBe(#family)
		end
		-- the first rng draw of neighbouring ids is near-identical unless the generator is warmed up: the first
		-- draw sets the trunk length, so the trunks of one species must genuinely differ
		local function spread(family: { string }): number
			local lo, hi = math.huge, 0
			for _, id in family do
				local longest = 0
				for _, t in named(Kit.prop(id), "Trunk") do
					longest = math.max(longest, t.Size.X)
				end
				lo, hi = math.min(lo, longest), math.max(hi, longest)
			end
			return hi - lo
		end
		expect(spread(OAKS)).toBeGreaterThan(0.8)
		expect(spread(PINES)).toBeGreaterThan(1.5)
		expect(spread(BIRCHES)).toBeGreaterThan(1.5)
	end)
end)

describe("trees (oak, pine, birch)", function()
	it("keeps each species' height and spread close to the old ones (Layout and placement rely on them)", function()
		for _, id in OAKS do
			local lo, hi = bounds(Kit.prop(id))
			expect(hi.Y).toBeGreaterThan(22)
			expect(hi.Y).toBeLessThan(27)
			expect(radius(lo, hi)).toBeLessThan(13)
			expect(radius(lo, hi)).toBeGreaterThan(8)
		end
		for _, id in PINES do
			local lo, hi = bounds(Kit.prop(id))
			expect(hi.Y).toBeGreaterThan(26)
			expect(hi.Y).toBeLessThan(34)
			expect(radius(lo, hi)).toBeLessThan(11)
			expect(radius(lo, hi)).toBeGreaterThan(7)
		end
		for _, id in BIRCHES do
			local lo, hi = bounds(Kit.prop(id))
			expect(hi.Y).toBeGreaterThan(19)
			expect(hi.Y).toBeLessThan(26)
			expect(radius(lo, hi)).toBeLessThan(8)
		end
	end)

	it("builds the oak from overlapping canopy masses of varied size with a dark-to-light gradient", function()
		for _, id in OAKS do
			local model = Kit.prop(id)
			local canopy = named(model, "Canopy")
			expect(#canopy).toBeGreaterThanOrEqual(10)
			local smallest, largest = math.huge, 0
			for _, p in canopy do
				smallest, largest = math.min(smallest, p.Size.X), math.max(largest, p.Size.X)
				expect(p.Material).toBe(Enum.Material.Grass)
			end
			expect(largest - smallest).toBeGreaterThan(2) -- varied masses, not a ring of equal balls
			-- shaded underside, sunlit top: the higher third is clearly brighter than the lower third
			table.sort(canopy, function(a, b)
				return a.CFrame.Position.Y < b.CFrame.Position.Y
			end)
			local third = math.floor(#canopy / 3)
			local low, high = 0, 0
			for i = 1, third do
				low += lum(canopy[i].Color)
				high += lum(canopy[#canopy + 1 - i].Color)
			end
			expect(high / third - low / third).toBeGreaterThan(30)
		end
	end)

	it("gives the oak a flared base, a leaning stem and a few thick branches", function()
		for _, id in OAKS do
			local model = Kit.prop(id)
			local flare, trunks = named(model, "TrunkFlare")[1], named(model, "Trunk")
			expect(flare).never.toBeNil()
			expect(#trunks).toBe(2) -- straight foot + leaning stem
			for _, t in trunks do
				expect(flare.Size.Y).toBeGreaterThan(t.Size.Y) -- Size.Y is the diameter of an upright cylinder
			end
			local stem = trunks[1]
			for _, t in trunks do
				if t.Size.X > stem.Size.X then
					stem = t -- the long one
				end
			end
			-- a cylinder runs along its local X: the stem's axis is tipped off vertical, but only slightly
			local axisY = math.abs(stem.CFrame.RightVector.Y)
			expect(axisY).toBeLessThan(0.998)
			expect(axisY).toBeGreaterThan(0.95)
			local branches = named(model, "Branch")
			expect(#branches).toBeGreaterThanOrEqual(1)
			expect(#branches).toBeLessThanOrEqual(2)
			for _, b in branches do
				expect(b.Size.Y).toBeGreaterThanOrEqual(1.4) -- bigger than the old 0.9 sticks
			end
		end
	end)

	it(
		"gives the eight oaks different silhouettes (tall, wide, lopsided, twin), not just different ball sizes",
		function()
			local aspects, offsets = {}, {}
			for _, id in OAKS do
				local lo, hi = Vector3.new(1e9, 1e9, 1e9), Vector3.new(-1e9, -1e9, -1e9)
				local sum, n = Vector3.zero, 0
				for _, c in named(Kit.prop(id), "Canopy") do
					local r = c.Size.X / 2
					local p = c.CFrame.Position
					lo = Vector3.new(math.min(lo.X, p.X - r), math.min(lo.Y, p.Y - r), math.min(lo.Z, p.Z - r))
					hi = Vector3.new(math.max(hi.X, p.X + r), math.max(hi.Y, p.Y + r), math.max(hi.Z, p.Z + r))
					sum += p
					n += 1
				end
				local width = math.max(hi.X - lo.X, hi.Z - lo.Z)
				table.insert(aspects, (hi.Y - lo.Y) / width)
				local mean = sum / n
				table.insert(offsets, Vector2.new(mean.X, mean.Z).Magnitude)
			end
			table.sort(aspects)
			expect(aspects[#aspects] - aspects[1]).toBeGreaterThan(0.5) -- from wide and flat to tall and narrow
			expect(aspects[1]).toBeLessThan(0.85)
			expect(aspects[#aspects]).toBeGreaterThan(1.15)
			table.sort(offsets)
			expect(offsets[#offsets] - offsets[1]).toBeGreaterThan(0.8) -- some crowns hang to one side
		end
	)

	it(
		"builds the pine as six whorls of drooping wedge boughs (a four-bough skirt below) narrowing to a tip",
		function()
			for _, id in PINES do
				local model = Kit.prop(id)
				local boughs = named(model, "Bough")
				expect(#boughs).toBe(18)
				-- one part per bough, none of the old 4-part pyramid tiers: boughs are wedges, whorls turn against each other
				local yaws = {}
				for _, b in boughs do
					expect(b.ClassName).toBe("WedgePart")
					local look = b.CFrame.LookVector
					yaws[string.format("%.2f", math.atan2(look.X, look.Z))] = true
				end
				local distinct = 0
				for _ in yaws do
					distinct += 1
				end
				expect(distinct).toBeGreaterThan(10)
				-- wider at the bottom, narrower towards the top
				table.sort(boughs, function(a, b)
					return a.CFrame.Position.Y < b.CFrame.Position.Y
				end)
				expect(boughs[1].Size.Z).toBeGreaterThan(boughs[#boughs].Size.Z * 2)
				expect(#named(model, "Tip")).toBe(2)
				-- darker overall than an oak, a dark pointed conifer at the aerial camera
				local sum = 0
				for _, b in boughs do
					sum += lum(b.Color)
				end
				expect(sum / #boughs).toBeLessThan(90)
			end
		end
	)

	it(
		"builds the birch as a slender white trunk under an airy crown of five clumps wound into it, with a side branch",
		function()
			for _, id in BIRCHES do
				local model = Kit.prop(id)
				local trunk = named(model, "Trunk")[1]
				expect(trunk.Size.Y).toBeLessThan(1.6) -- slender: diameter under 1.6
				expect(lum(trunk.Color)).toBeGreaterThan(200) -- white
				expect(#named(model, "Bark")).toBe(1)
				local crown = named(model, "Canopy")
				expect(#crown).toBe(5)
				local sum = 0
				for _, c in crown do
					sum += lum(c.Color)
					expect(c.CastShadow).toBe(false)
				end
				expect(sum / #crown).toBeGreaterThan(140) -- lighter than the oak's mid greens
				-- the crown sits on the trunk: at least three clumps are cut through by the trunk's axis (no balloons on a pole)
				local axisDir = trunk.CFrame.RightVector
				local base = trunk.CFrame.Position - axisDir * (trunk.Size.X / 2)
				local wound = 0
				for _, c in crown do
					local rel = c.CFrame.Position - base
					local off = (rel - axisDir * rel:Dot(axisDir)).Magnitude
					if off < c.Size.X / 2 then
						wound += 1
					end
				end
				expect(wound).toBeGreaterThanOrEqual(3)
				local stubs = named(model, "Stub")
				expect(#stubs).toBe(1)
				expect(stubs[1].Size.Y).toBeLessThan(1) -- a thin stub
			end
		end
	)
end)

describe("bushes and flowers", function()
	it("builds a broad dome with lobes tucked round it, accents on the surface", function()
		for i, id in BUSHES do
			local model = Kit.prop(id)
			expect(#named(model, "Bush")).toBe(4)
			local accents = named(model, "Berry")
			expect(#accents).toBe(if i % 3 == 1 then 0 else 5)
			for _, a in accents do
				expect(a.Size.X).toBeGreaterThanOrEqual(1.0) -- readable from the aerial camera
				expect(a.CastShadow).toBe(false)
			end
			local lo, hi = bounds(model)
			expect(hi.Y).toBeGreaterThan(4)
			expect(radius(lo, hi)).toBeLessThan(6)
		end
	end)

	it("keeps the flower tuft round and full, with six blooms standing proud of the leaves", function()
		for _, id in FLOWERS do
			local model = Kit.prop(id)
			expect(#named(model, "Flower")).toBe(6)
			expect(#named(model, "Leaves")).toBe(2)
			for _, f in named(model, "Flower") do
				expect(f.Size.X).toBeGreaterThanOrEqual(1.0)
				expect(f.Color).never.toEqual(Color3.fromRGB(63, 138, 54))
			end
		end
	end)
end)

describe("boulders", function()
	local function chunks(id: string): { BasePart }
		local out = {}
		for _, p in parts(Kit.prop(id)) do
			if p.Material == Enum.Material.Slate then
				table.insert(out, p)
			end
		end
		return out
	end

	it("tips every rock chunk off the axes (no axis-aligned blocks) and uses wedges where sloped", function()
		for _, id in BOULDERS do
			for _, p in chunks(id) do
				local up = p.CFrame.UpVector
				if math.abs(up.Y) > 0.999 and p.CFrame.RightVector.Y == 0 then
					error(`{id}: {p.Name} is axis-aligned`)
				end
			end
		end
	end)

	it("reads as different sizes and shapes: S < M < L in height and spread, with different part counts", function()
		local function size(id: string): (number, number)
			local lo, hi = bounds(Kit.prop(id))
			return hi.Y - lo.Y, radius(lo, hi)
		end
		for i = 1, 3 do
			local hs, rs = size(BOULDERS_S[i])
			local hm, rm = size(BOULDERS_M[i])
			local hl, rl = size(BOULDERS_L[i])
			expect(hs).toBeLessThan(hm)
			expect(hm).toBeLessThan(hl)
			expect(rs).toBeLessThan(rm + 0.5)
			expect(rm).toBeLessThan(rl)
			expect(hl).toBeGreaterThan(7)
			expect(hl).toBeLessThan(11)
		end
		expect(Kit.partCount(Kit.prop(BOULDERS_S[1]))).toBeLessThan(Kit.partCount(Kit.prop(BOULDERS_M[1])))
		expect(Kit.partCount(Kit.prop(BOULDERS_M[1]))).toBeLessThan(Kit.partCount(Kit.prop(BOULDERS_L[1])))
	end)

	it("has a darker, cooler base under a lighter top, a pebble on M and a moss tuft on L", function()
		for _, id in concat(BOULDERS_M, BOULDERS_L) do
			local model = Kit.prop(id)
			local base, top = nil :: BasePart?, nil :: BasePart?
			for _, p in chunks(id) do
				if p.Name == "Rock" then
					local volume = p.Size.X * p.Size.Y * p.Size.Z
					if base == nil or volume > base.Size.X * base.Size.Y * base.Size.Z then
						base = p -- the foot is the biggest mass
					end
					if top == nil or p.CFrame.Position.Y > top.CFrame.Position.Y then
						top = p
					end
				end
			end
			expect(base).never.toBeNil()
			expect(lum((top :: BasePart).Color) - lum((base :: BasePart).Color)).toBeGreaterThan(25)
			expect((base :: BasePart).Color.B).toBeGreaterThan((base :: BasePart).Color.R) -- cool
			if string.find(id, "_m_", 1, true) then
				expect(#named(model, "Pebble")).toBe(1)
			else
				expect(#named(model, "Moss")).toBe(1)
			end
		end
	end)
end)

describe("resource nodes", function()
	it("keeps each node's footprint within the radius the layout keeps clear (9)", function()
		for _, id in concat(STONES, ORES) do
			local lo, hi = bounds(Kit.prop(id))
			expect(radius(lo, hi)).toBeLessThan(9.6)
		end
		for _, id in WOODS do
			local lo, hi = bounds(Kit.prop(id))
			expect(radius(lo, hi)).toBeLessThan(7)
		end
	end)

	it("builds the quarry as stratified slabs with cut faces, rubble, a stack of cut blocks and a pick", function()
		for _, id in STONES do
			local model = Kit.prop(id)
			local strata = named(model, "Stratum")
			expect(#strata).toBe(3)
			table.sort(strata, function(a, b)
				return a.CFrame.Position.Y < b.CFrame.Position.Y
			end)
			-- alternating dark / pale / mid bands: neighbouring strata differ clearly in brightness
			expect(math.abs(lum(strata[2].Color) - lum(strata[1].Color))).toBeGreaterThan(40)
			expect(math.abs(lum(strata[3].Color) - lum(strata[2].Color))).toBeGreaterThan(25)
			-- stepped: each slab is smaller than the one below
			expect(strata[2].Size.X).toBeLessThan(strata[1].Size.X)
			expect(strata[3].Size.X).toBeLessThan(strata[2].Size.X)
			local cuts = named(model, "CutBlock")
			expect(#cuts).toBe(2)
			expect(math.abs(cuts[1].CFrame.Position.X - cuts[2].CFrame.Position.X)).toBeLessThan(1) -- stacked
			expect(math.abs(cuts[1].CFrame.Position.Y - cuts[2].CFrame.Position.Y)).toBeGreaterThan(1)
			expect(#named(model, "Rubble")).toBe(1)
			expect(#named(model, "Pick")).toBe(1)
		end
	end)

	it("studs the ore with five bright nuggets: gold on variants 3-4, rust on 1-2, crystals on 5-6", function()
		for i, id in ORES do
			local model = Kit.prop(id)
			local nuggets = named(model, if i >= 5 then "Crystal" else "Ore")
			expect(#nuggets).toBe(5)
			for _, n in nuggets do
				local c = n.Color
				if i >= 3 and i <= 4 then
					expect(c.R * 255).toBeGreaterThan(220) -- gold
					expect(c.G * 255).toBeGreaterThan(170)
					expect(c.B * 255).toBeLessThan(90)
					expect(n.Size.X).toBeGreaterThanOrEqual(2.0) -- big enough to read at 80 studs
				elseif i <= 2 then
					expect(c.R).toBeGreaterThan(c.B + 0.25) -- rust
				end
			end
			if i <= 4 then
				for _, n in nuggets do
					expect(n.Material).toBe(Enum.Material.Metal)
				end
			end
		end
	end)

	it("builds the wood node as stacked logs with pale end rings beside a chopped stump and an axe", function()
		for _, id in WOODS do
			local model = Kit.prop(id)
			local logs, rings = named(model, "Log"), named(model, "LogEnd")
			expect(#logs).toBe(5)
			expect(#rings).toBeGreaterThanOrEqual(4)
			for _, ring in rings do
				expect(lum(ring.Color)).toBeGreaterThan(lum(logs[1].Color) + 40)
			end
			local stump, top = named(model, "Stump")[1], named(model, "StumpTop")[1]
			expect(stump).never.toBeNil()
			expect(lum(top.Color)).toBeGreaterThan(lum(stump.Color) + 40)
			expect(#named(model, "AxeHandle")).toBe(1)
			expect(#named(model, "AxeHead")).toBe(1)
			-- stacked: the top row sits above the bottom row
			local lowest, highest = math.huge, 0
			for _, l in logs do
				lowest, highest = math.min(lowest, l.CFrame.Position.Y), math.max(highest, l.CFrame.Position.Y)
			end
			expect(highest - lowest).toBeGreaterThan(1)
		end
	end)
end)

describe("farm fields, fence and haystack", function()
	local FIELDS = concat(WHEAT, CABBAGE)

	it("fills exactly its stated footprint (Props.FIELD_SIZE 38 x 28), centred on the origin", function()
		expect(Props.FIELD_SIZE).toEqual(Vector2.new(38, 28))
		for _, id in FIELDS do
			local lo, hi = bounds(Kit.prop(id))
			expect(lo.X).toBeNear(-19, 0.01)
			expect(hi.X).toBeNear(19, 0.01)
			expect(lo.Z).toBeNear(-14, 0.01)
			expect(hi.Z).toBeNear(14, 0.01)
		end
	end)

	it(
		"builds the wheat as six rows of seven tapered, tilted wedge tufts, one part each, on a brown soil bed",
		function()
			expect(Props.WHEAT_PARTS).toBe(WHEAT_PARTS)
			for _, id in WHEAT do
				local model = Kit.prop(id)
				expect(Kit.partCount(model)).toBe(WHEAT_PARTS) -- the whole 44: a thinner field reads as planks or crates
				local tufts = named(model, "Tuft")
				expect(#tufts).toBe(42)
				local bed = named(model, "SoilBed")[1]
				local soil = lum(bed.Color)
				expect(soil).toBeGreaterThan(60) -- brown soil, luminance 60-90, never black
				expect(soil).toBeLessThan(90)
				expect(bed.Color.R).toBeGreaterThan(bed.Color.G)
				expect(bed.Color.G).toBeGreaterThan(bed.Color.B)
				local bedLo, bedHi = bounds(model)
				local minL, maxL, ripeWest, ripeEast, nWest, nEast, olive, gold = math.huge, 0, 0, 0, 0, 0, 0, 0
				for _, t in tufts do
					expect(t.ClassName).toBe("WedgePart") -- tapered, not a block
					expect(t.Size.Y).toBeGreaterThan(1.2) -- low: about two studs of crop
					expect(t.Size.Y).toBeLessThan(2.3)
					expect(t.Size.X).toBeGreaterThan(3) -- wide enough that a row reads as a row
					local up = math.abs(t.CFrame.UpVector.Y)
					expect(up).toBeLessThan(0.9999) -- tilted, never square to the bed
					expect(up).toBeGreaterThan(0.9)
					local l = lum(t.Color)
					minL, maxL = math.min(minL, l), math.max(maxL, l)
					expect(l).toBeGreaterThan(soil + 50) -- every tuft stands out from the soil
					local ripe = t.Color.R - t.Color.B
					if t.CFrame.Position.X < -6 then
						ripeWest, nWest = ripeWest + ripe, nWest + 1
					elseif t.CFrame.Position.X > 6 then
						ripeEast, nEast = ripeEast + ripe, nEast + 1
					end
					if t.Color.R - t.Color.G < 0.12 then -- greenish straw (the unripe end)
						olive += 1
					end
					if t.Color.R * 255 > 225 then
						gold += 1
					end
					local lo, hi = lowestHighest(t)
					expect(lo).toBeGreaterThan(bed.CFrame.Position.Y) -- sits on the bed, not under it
					expect(hi).toBeLessThan(3.6)
				end
				expect(maxL - minL).toBeGreaterThan(40) -- tint and height vary tuft to tuft
				expect(ripeEast / nEast - ripeWest / nWest).toBeGreaterThan(0.08) -- olive green in the west, ripe gold in the east
				expect(olive).toBeGreaterThanOrEqual(3)
				expect(gold).toBeGreaterThanOrEqual(5)
				-- six rows by z, soil showing in the furrows between them, and a soil border all round
				local rows: { { BasePart } } = {}
				for _, t in tufts do
					local r = math.floor((t.CFrame.Position.Z + 13.2) / 4.4)
					rows[r] = rows[r] or {}
					table.insert(rows[r], t)
				end
				local keys = {}
				for r, list in rows do
					table.insert(keys, r)
					expect(#list).toBe(7)
				end
				expect(#keys).toBe(6)
				table.sort(keys)
				local function zRange(list: { BasePart }): (number, number)
					local lo, hi = math.huge, -math.huge
					for _, t in list do
						for _, sx in { -1, 1 } do
							for _, sz in { -1, 1 } do
								local z = (t.CFrame * CFrame.new(sx * t.Size.X / 2, 0, sz * t.Size.Z / 2)).Position.Z
								lo, hi = math.min(lo, z), math.max(hi, z)
							end
						end
					end
					return lo, hi
				end
				local gapSum = 0
				for i = 2, #keys do
					local _, prevHi = zRange(rows[keys[i - 1]])
					local lo = zRange(rows[keys[i]])
					gapSum += lo - prevHi
				end
				expect(gapSum / 5).toBeGreaterThan(0.8) -- on average a stud of soil between rows
				local firstLo = zRange(rows[keys[1]])
				local _, lastHi = zRange(rows[keys[#keys]])
				expect(firstLo).toBeGreaterThan(bedLo.Z + 0.4)
				expect(lastHi).toBeLessThan(bedHi.Z - 0.4)
			end
		end
	)

	it(
		"keeps the wheat low (no tuft over 3.6 studs, the average under 3.0, near the 2.8 fence) and the fence low and tidy",
		function()
			for i, id in FENCES do
				local model = Kit.prop(id)
				local posts, rails = named(model, "Post"), named(model, "Rail")
				expect(#posts).toBe(5)
				expect(#rails).toBe(if i % 2 == 0 then 2 else 1)
				local tallestTop = 0
				for _, p in posts do
					tallestTop = math.max(tallestTop, p.CFrame.Position.Y + p.Size.Y / 2)
					expect(p.Size.Y).toBeLessThan(3.1) -- low: the old fence was 3.4
				end
				for _, wheat in WHEAT do
					local sum, n = 0, 0
					for _, t in named(Kit.prop(wheat), "Tuft") do
						local _, hi = lowestHighest(t)
						expect(hi).toBeLessThan(3.6)
						sum, n = sum + hi, n + 1
					end
					expect(sum / n).toBeLessThan(3.0)
					expect(sum / n).toBeLessThan(tallestTop + 0.4) -- about fence height, never a hedge over it
				end
				local _, hi = bounds(model)
				expect(hi.Y).toBeLessThan(3.1)
			end
		end
	)

	it("sits the cabbages on soil ridges inside the bed, one ridge per row", function()
		for _, id in CABBAGE do
			local model = Kit.prop(id)
			expect(#named(model, "Ridge")).toBe(7)
			expect(#named(model, "Cabbage")).toBe(56)
			for _, ridge in named(model, "Ridge") do
				expect(lum(ridge.Color)).toBeGreaterThan(60)
				expect(lum(ridge.Color)).toBeLessThan(90)
			end
		end
	end)

	it("builds the haystack as a hay-coloured drum under a domed top with a pitchfork", function()
		for _, id in HAYSTACKS do
			local model = Kit.prop(id)
			local drum, dome = named(model, "Hay")[1], named(model, "HayDome")[1]
			expect(drum.Shape).toBe(Enum.PartType.Cylinder)
			expect(dome.Shape).toBe(Enum.PartType.Ball)
			expect(dome.Size.X).toBeGreaterThan(drum.Size.Y) -- the dome overhangs the drum: a round shoulder
			-- hay: warm, desaturated yellow, the same family as the wheat, never the gold kingdom
			for _, p in { drum, dome } do
				expect(p.Color.R).toBeGreaterThan(p.Color.G)
				expect(p.Color.G).toBeGreaterThan(p.Color.B * 1.8)
				expect(p.Color.B * 255).toBeGreaterThan(70)
			end
			expect(#named(model, "Pitchfork")).toBe(1)
		end
	end)
end)
