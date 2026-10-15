--[[
	Kit architecture v0 (FL-0054, FORGE-02) + G13 (FL-0085): part budgets, house variants, kingdom tinting,
	placement sanity, the keep Throne (G13.6), visible levels and the VS-2 stand-in types (G13.5).
	Budgets live in Kit/Buildings.luau (PART_BUDGET, justified there against BRIEF §14: ≤ 25k parts in the
	world at VS-2).
]]

local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local Kit = require("@game/ReplicatedStorage/Game/Kit/Kit")
local Buildings = require("@game/ReplicatedStorage/Game/Kit/Buildings")

local KingdomsConfig = require("@game/ReplicatedStorage/Forge/Config/Kingdoms")

-- canonical kingdom colours (config Kingdoms, D-033), keyed by KingdomId
local CANON: { [string]: Color3 } = {}
for _, identity in KingdomsConfig.identities do
	local c = identity.color
	CANON[identity.id] = Color3.fromRGB(c[1], c[2], c[3])
end
local COLORS = {
	CANON.crimson,
	CANON.azure,
	CANON.emerald,
	CANON.gold,
	Kit.NEUTRAL_COLOR,
	-- off-palette tints of the emerald and gold hue styles (the pre-D-033 values): any kingdom colour,
	-- not only the canonical four, must map to a tower style and stay inside the budgets
	Color3.fromRGB(40, 127, 71),
	Color3.fromRGB(245, 205, 48),
}
-- a second colour of the same hue style as each COLORS entry (same silhouette, different tint)
local SAME_STYLE = {
	Color3.fromRGB(170, 30, 50),
	Color3.fromRGB(40, 80, 200),
	Color3.fromRGB(30, 150, 60),
	Color3.fromRGB(230, 180, 30),
	Color3.fromRGB(190, 190, 190),
	Color3.fromRGB(30, 150, 80),
	Color3.fromRGB(225, 175, 30),
}
local EXPECTED_FOOTPRINTS = {
	keep = { Vector2.new(32, 32), Vector2.new(40, 40), Vector2.new(46, 46) },
	house = { Vector2.new(20, 16), Vector2.new(22, 18) },
	farm = { Vector2.new(34, 28), Vector2.new(40, 32) },
	storehouse = { Vector2.new(22, 18), Vector2.new(26, 20) },
	lumbercamp = { Vector2.new(22, 18) },
	quarry = { Vector2.new(22, 20) },
	barracks = { Vector2.new(30, 20), Vector2.new(34, 22) },
	watchtower = { Vector2.new(14, 14), Vector2.new(16, 16) },
	wall = { Vector2.new(32, 8) },
	gate = { Vector2.new(32, 12) },
	-- G13.5 VS-2 types (announced to FORGE-05; slot sizes: house S, barracks..shrine M, farm/lumber/quarry/mine L)
	mine = { Vector2.new(22, 20) },
	blacksmith = { Vector2.new(22, 18) },
	market = { Vector2.new(26, 22) },
	infirmary = { Vector2.new(22, 18) },
	granary = { Vector2.new(18, 18) },
	shrine = { Vector2.new(16, 16) },
}
local NEW_TYPES = { "mine", "blacksmith", "market", "infirmary", "granary", "shrine" }
-- levels with a distinct look (G13.5); other types build L1–L2
local MAX_LEVEL = { keep = 3, barracks = 4 }

local function parts(model: Instance): { BasePart }
	local out = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(out, d)
		end
	end
	return out
end

-- world-axis half extents of a part's bounding box
local function halfExtents(p: BasePart): Vector3
	local s = p.Size
	local rv, uv, lv = p.CFrame.RightVector, p.CFrame.UpVector, p.CFrame.LookVector
	return Vector3.new(
		math.abs(rv.X) * s.X / 2 + math.abs(uv.X) * s.Y / 2 + math.abs(lv.X) * s.Z / 2,
		math.abs(rv.Y) * s.X / 2 + math.abs(uv.Y) * s.Y / 2 + math.abs(lv.Y) * s.Z / 2,
		math.abs(rv.Z) * s.X / 2 + math.abs(uv.Z) * s.Y / 2 + math.abs(lv.Z) * s.Z / 2
	)
end

local function bounds(model: Model): (Vector3, Vector3)
	local lo, hi = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, p in parts(model) do
		if p.Transparency < 1 then
			local e, c = halfExtents(p), p.CFrame.Position
			lo = lo:Min(c - e)
			hi = hi:Max(c + e)
		end
	end
	return lo, hi
end

local function signature(model: Model): string
	local rows = {}
	for _, p in parts(model) do
		local s, pos = p.Size, p.CFrame.Position
		table.insert(
			rows,
			string.format(
				"%s %s %.2f %.2f %.2f %.2f %.2f %.2f",
				p.ClassName,
				p.Name,
				s.X,
				s.Y,
				s.Z,
				pos.X,
				pos.Y,
				pos.Z
			)
		)
	end
	return table.concat(rows, "\n")
end

local function variantsFor(bt: string): { number }
	return if bt == "house" then { 1, 2, 3, 4, 5, 6, 7, 8 } else { 1 }
end

local function levelsFor(bt: string): number
	return MAX_LEVEL[bt] or 2
end

describe("Kit architecture budgets (FL-0054)", function()
	it("keeps every building, level, variant and kingdom colour within its part budget", function()
		local report, over = {}, {}
		for _, bt in Kit.BUILDING_TYPES do
			local budget = Buildings.PART_BUDGET[bt]
			expect(budget).never.toBeNil()
			local lo, hi = math.huge, 0
			for level = 1, levelsFor(bt) do
				for _, v in variantsFor(bt) do
					for _, color in COLORS do
						local n = Kit.partCount(Buildings.build(bt, level, "complete", color, v))
						lo, hi = math.min(lo, n), math.max(hi, n)
						if n > budget then
							table.insert(over, `{bt} L{level} v{v}: {n} > {budget}`)
						end
					end
				end
			end
			table.insert(report, `{bt} {lo}-{hi}/{budget}`)
		end
		local slo, shi = math.huge, 0
		for _, bt in Kit.BUILDING_TYPES do
			for level = 1, levelsFor(bt) do
				for stage = 1, 3 do
					-- every colour: emblems make stage part counts differ by kingdom
					for ci, color in COLORS do
						local n = Kit.partCount(Buildings.build(bt, level, stage, color))
						slo, shi = math.min(slo, n), math.max(shi, n)
						if n > Buildings.PART_BUDGET.stage then
							table.insert(
								over,
								`{bt} L{level} stage {stage} colour {ci}: {n} > {Buildings.PART_BUDGET.stage}`
							)
						end
					end
				end
			end
		end
		table.insert(report, `stages {slo}-{shi}/{Buildings.PART_BUDGET.stage}`)
		print("kit part counts (min-max/budget): " .. table.concat(report, ", "))
		if #over > 0 then
			error("over budget: " .. table.concat(over, "; "))
		end
	end)

	it("pins the FOOTPRINTS table for every type and level (slot picker, server and Build/Fit read it)", function()
		for _, bt in Kit.BUILDING_TYPES do
			local levels = EXPECTED_FOOTPRINTS[bt]
			if not levels then
				error(`{bt}: footprint not pinned in this spec`)
			end
			for level = 0, 5 do
				local want = levels[math.clamp(level, 1, #levels)]
				local got = Kit.footprint(bt, level)
				if got ~= want then
					error(`{bt} L{level}: footprint {got} changed (pinned {want})`)
				end
			end
		end
		-- barracks L3–4 stay in the level-2 footprint; keep levels in 32/40/46
		expect(Kit.footprint("barracks", 4)).toEqual(Vector2.new(34, 22))
		expect(Kit.footprint("keep", 3)).toEqual(Vector2.new(46, 46))
	end)
end)

describe("Kit house variants", function()
	it("keeps the 4-argument call identical to variant 1", function()
		for level = 1, 2 do
			local a = Kit.build("house", level, "complete", COLORS[2])
			local b = Kit.build("house", level, "complete", COLORS[2], 1)
			expect(signature(a)).toBe(signature(b))
			expect(a:GetAttribute("KitVariant")).toBe(1)
		end
	end)

	it("is deterministic and gives at least four visibly different houses", function()
		local seen = {}
		local distinct = 0
		for v = 1, 8 do
			local a = signature(Kit.build("house", 1, "complete", COLORS[1], v))
			local b = signature(Kit.build("house", 1, "complete", COLORS[1], v))
			expect(a).toBe(b)
			if not seen[a] then
				seen[a] = true
				distinct += 1
			end
		end
		expect(distinct).toBe(8)
		-- the four archetypes differ in roof style (tile vs thatch) and silhouette
		local roofs = {}
		for v = 1, 4 do
			local m = Kit.build("house", 1, "complete", COLORS[1], v)
			local tile, thatch = false, false
			for _, p in parts(m) do
				tile = tile or p.Name == "RoofTiles"
				thatch = thatch or p.Name == "Thatch"
			end
			roofs[v] = if tile then "tile" elseif thatch then "thatch" else "none"
		end
		expect(roofs[1]).toBe("tile")
		expect(roofs[2]).toBe("thatch")
		expect(roofs[3]).toBe("tile")
		expect(roofs[4]).toBe("thatch")
	end)

	it("flies a kingdom pennant on every thatch roof", function()
		for v = 1, 8 do
			for level = 1, 2 do
				local m = Kit.build("house", level, "complete", COLORS[2], v)
				if m:FindFirstChild("Thatch") then
					local pennant = m:FindFirstChild("Pennant")
					expect(pennant).never.toBeNil()
					expect((pennant :: BasePart):GetAttribute("KitTint")).toBe(1)
				end
			end
		end
	end)

	it("puts the Door attachment in front of the visible door for every variant", function()
		for level = 1, 2 do
			for v = 1, 8 do
				local m = Kit.build("house", level, "complete", COLORS[3], v)
				local fp = Kit.footprint("house", level)
				local door = (m.PrimaryPart :: BasePart):FindFirstChild("Door") :: Attachment
				local p = door.CFrame.Position
				expect(math.abs(p.Z) >= fp.Y / 2 - 0.5).toBe(true)
				local leaf = m:FindFirstChild("Door") :: BasePart
				expect(leaf).never.toBeNil()
				expect(leaf.CFrame.Position.X).toBeNear(p.X, 0.05)
			end
		end
	end)
end)

describe("Kit keep throne (G13.6)", function()
	it("seats a Throne on a raised dais, facing -Z, open to the aerial camera, at every keep level", function()
		for level = 1, 3 do
			for _, color in COLORS do
				local m = Kit.build("keep", level, "complete", color)
				local found = m:FindFirstChild("Throne", true)
				expect(found).never.toBeNil()
				local s = found :: BasePart
				expect(s.ClassName).toBe("Seat")
				expect(s.Anchored).toBe(true)
				expect(s.CanCollide).toBe(true)
				expect(s.CFrame.LookVector:Dot(Vector3.new(0, 0, -1))).toBeGreaterThan(0.99)
				-- dais: 2–3 steps, raised ≥ 1.5 studs above the keep's floor (the plinth top)
				local steps, floorTop, daisTop = 0, 0, 0
				for _, p in parts(m) do
					if p.Name == "DaisStep" then
						steps += 1
						daisTop = math.max(daisTop, p.CFrame.Position.Y + p.Size.Y / 2)
					elseif p.Name == "Plinth" then
						floorTop = math.max(floorTop, p.CFrame.Position.Y + p.Size.Y / 2)
					end
				end
				expect(steps >= 2 and steps <= 3).toBe(true)
				expect(daisTop - floorTop).toBeGreaterThanOrEqual(1.5)
				expect(s.CFrame.Position.Y - s.Size.Y / 2).toBeGreaterThanOrEqual(daisTop - 0.01)
				-- open to the aerial camera (40–220 studs, looking down): the only thing above the seat is the
				-- baldachin, held high (≥ 8 studs over the seat) so oblique views see under it
				local top = s.CFrame.Position.Y + s.Size.Y / 2
				for _, p in parts(m) do
					if p ~= s and p.Transparency < 1 then
						local e, c = halfExtents(p), p.CFrame.Position
						local covers = math.abs(c.X - s.CFrame.Position.X) < e.X
							and math.abs(c.Z - s.CFrame.Position.Z) < e.Z
						local baldachin = p:GetAttribute("KitThrone") == true
							and string.sub(p.Name, 1, 9) == "Baldachin"
						if covers and c.Y - e.Y > top and not (baldachin and c.Y - e.Y >= top + 8) then
							error(`keep L{level}: {p.Name} roofs over the throne`)
						end
					end
				end
			end
		end
	end)

	it("keeps every throne part clear of the entrance bay and the door behind it", function()
		local door = {
			EntranceBay = true,
			Door = true,
			DoorArch = true,
			DoorStrap = true,
			DoorJamb = true,
			Voussoir = true,
			Keystone = true,
		}
		for level = 1, 3 do
			for _, color in COLORS do
				local m = Kit.build("keep", level, "complete", color)
				local throneParts, doorParts = {}, {}
				for _, p in parts(m) do
					if p:GetAttribute("KitThrone") == true then
						table.insert(throneParts, p)
					elseif door[p.Name] then
						table.insert(doorParts, p)
					end
				end
				expect(#throneParts).toBeGreaterThan(10)
				expect(#doorParts).toBeGreaterThan(8)
				for _, a in throneParts do
					local ea, ca = halfExtents(a), a.CFrame.Position
					for _, b in doorParts do
						local eb, cb = halfExtents(b), b.CFrame.Position
						local dc = ca - cb
						local gap = Vector3.new(math.abs(dc.X), math.abs(dc.Y), math.abs(dc.Z)) - (ea + eb) -- < 0 everywhere = overlap
						if gap.X < -0.001 and gap.Y < -0.001 and gap.Z < -0.001 then
							error(`keep L{level}: throne part {a.Name} intersects {b.Name}`)
						end
					end
				end
			end
		end
	end)

	it("marks the throne from behind with a high kingdom baldachin (≤ 6 parts, over the bay merlons)", function()
		for level = 1, 3 do
			local m = Kit.build("keep", level, "complete", COLORS[2])
			local n, canopyLow, tinted = 0, math.huge, true
			local bayTop = 0
			for _, p in parts(m) do
				if string.sub(p.Name, 1, 9) == "Baldachin" then
					n += 1
					if p.Name == "BaldachinCanopy" then
						canopyLow = math.min(canopyLow, p.CFrame.Position.Y - halfExtents(p).Y)
						tinted = tinted and p:GetAttribute("KitTint") ~= nil
					end
				elseif p.Name == "EntranceBay" then
					bayTop = p.CFrame.Position.Y + p.Size.Y / 2
				end
			end
			expect(n >= 4 and n <= 6).toBe(true)
			expect(tinted).toBe(true)
			-- the bay merlons are 2.4 tall on a corbel that tops the bay by 0.55
			expect(canopyLow).toBeGreaterThan(bayTop + 2.95)
		end
	end)

	it("leaves the throne out of construction stages", function()
		for stage = 1, 3 do
			expect(Kit.build("keep", 1, stage, COLORS[1]):FindFirstChild("Throne", true)).toBeNil()
		end
	end)
end)

describe("Kit visible levels (G13.5)", function()
	it("grows part count, bounding volume and height with every level", function()
		local cases = { barracks = 4, keep = 3, house = 2, farm = 2 }
		for bt, maxLevel in cases do
			for _, v in variantsFor(bt) do
				local prevN, prevVol, prevH = 0, 0, 0
				for level = 1, maxLevel do
					local m = Buildings.build(bt, level, "complete", COLORS[1], v)
					local n = Kit.partCount(m)
					local lo, hi = bounds(m)
					local size = hi - lo
					local vol = size.X * size.Y * size.Z
					if n <= prevN or vol <= prevVol or size.Y < prevH then
						error(
							`{bt} v{v} L{level}: {n} parts, volume {vol}, height {size.Y} do not grow on L{level - 1}`
						)
					end
					prevN, prevVol, prevH = n, vol, size.Y
				end
			end
		end
	end)
end)

-- The farm sheet failed D-019 three times (a flat tan slab; stacked planks; spikes and flames). The final crop is
-- the reviewer's recipe: low, flat, uniform golden rows with a lighter cap over brown furrows, under the fence top.
-- These tests pin it, the grayscale value bands, the kingdom read on L1, the L2 growth, and the barn alignment.
describe("Kit farm crop and levels (G13.5, D-019)", function()
	local function named(m: Model, name: string): { BasePart }
		local out = {}
		for _, p in parts(m) do
			if p.Name == name then
				table.insert(out, p)
			end
		end
		return out
	end
	local function top(p: BasePart): number
		return p.CFrame.Position.Y + halfExtents(p).Y
	end
	local function maxTop(list: { BasePart }): number
		local t = -math.huge
		for _, p in list do
			t = math.max(t, top(p))
		end
		return t
	end
	-- Rec. 709 luma of the gamma-encoded colour on 0–255: the grayscale value the reviewer samples
	local function luma(c: Color3): number
		return 255 * (0.2126 * c.R + 0.7152 * c.G + 0.0722 * c.B)
	end
	-- the cottage stands on the right (+X), the barn on the left: split same-named roof parts by side
	local function side(list: { BasePart }, sgn: number): { BasePart }
		local out = {}
		for _, p in list do
			if p.CFrame.Position.X * sgn > 0 then
				table.insert(out, p)
			end
		end
		return out
	end
	local function cropArea(m: Model): number
		local a = 0
		for _, p in named(m, "WheatTop") do
			a += p.Size.X * p.Size.Z
		end
		return a
	end

	it("plants low, flat, uniform golden rows along Z over open furrows, each with a lighter cap", function()
		for level = 1, 2 do
			for _, color in COLORS do
				local m = Buildings.build("farm", level, "complete", color)
				local rows, caps = named(m, "Wheat"), named(m, "WheatTop")
				table.sort(rows, function(a, b)
					return a.CFrame.Position.X < b.CFrame.Position.X
				end)
				expect(#rows).toBeGreaterThanOrEqual(if level == 1 then 7 else 9)
				expect(#caps).toBe(#rows)
				local fenceTop = maxTop(named(m, "FencePost"))
				local lo, hi = math.huge, -math.huge
				for i, r in rows do
					expect(r.ClassName).toBe("Part")
					expect((r :: Part).Shape).toBe(Enum.PartType.Block)
					expect(r.Size.Z).toBeGreaterThan(4 * r.Size.X)
					if i > 1 then
						local prev = rows[i - 1]
						local gap = (r.CFrame.Position.X - r.Size.X / 2) - (prev.CFrame.Position.X + prev.Size.X / 2)
						if gap < 0.9 then
							error(`farm L{level}: furrow between rows {i - 1} and {i} is {gap} (< 0.9)`)
						end
					end
					local cap: BasePart? = nil
					for _, c in caps do
						local d = c.CFrame.Position - r.CFrame.Position
						if math.abs(d.X) < r.Size.X / 2 and math.abs(d.Z) < r.Size.Z / 2 then
							cap = c
						end
					end
					if not cap then
						error(`farm L{level} row {i}: no WheatTop cap`)
					end
					local c = cap :: BasePart
					-- a thin cap inset on the row's top (a soft bevel), lighter than the row
					expect(c.Size.X).toBeLessThan(r.Size.X - 0.1)
					expect(c.Size.Z).toBeLessThan(r.Size.Z - 0.1)
					expect(c.CFrame.Position.Y - c.Size.Y / 2).toBeLessThan(top(r))
					expect(top(c)).toBeGreaterThan(top(r))
					expect(luma(c.Color) - luma(r.Color)).toBeGreaterThan(25)
					lo, hi = math.min(lo, top(c)), math.max(hi, top(c))
				end
				-- uniform height, about 2–2.5 studs, below the fence top
				expect(hi - lo).toBeLessThan(0.05)
				expect(lo).toBeGreaterThanOrEqual(2)
				expect(hi).toBeLessThanOrEqual(2.6)
				expect(hi).toBeLessThan(fenceTop)
				-- no pointed crop parts
				for _, p in parts(m) do
					if string.sub(p.Name, 1, 5) == "Wheat" and p.ClassName ~= "Part" then
						error(`farm L{level}: crop part {p.Name} is a {p.ClassName}`)
					end
				end
			end
		end
	end)

	it(
		"keeps the grayscale bands apart: brown soil 60–90, hay ≥ 25 below the crop tops, a dark kingdom roof",
		function()
			for level = 1, 2 do
				for _, color in COLORS do
					local m = Buildings.build("farm", level, "complete", color)
					local soil = luma(named(m, "Field")[1].Color)
					expect(soil >= 60 and soil <= 90).toBe(true)
					local capL = math.huge
					for _, c in named(m, "WheatTop") do
						capL = math.min(capL, luma(c.Color))
					end
					expect(capL).toBeGreaterThanOrEqual(200)
					for _, name in { "Haystack", "HaystackTop", "Rick", "RickTop" } do
						for _, p in named(m, name) do
							expect(capL - luma(p.Color)).toBeGreaterThanOrEqual(25)
						end
					end
					-- the cottage roof carries the kingdom colour (tinted, recoloured with the kingdom) and stays dark
					local roof = side(named(m, "RoofTiles"), 1)
					expect(#roof).toBeGreaterThan(0)
					for _, p in roof do
						expect(p:GetAttribute("KitTint")).never.toBeNil()
						expect(capL - luma(p.Color)).toBeGreaterThan(60)
					end
				end
			end
		end
	)

	it("flies the kingdom flag upright on a tall pole at the front-left corner", function()
		for level = 1, 2 do
			local m = Buildings.build("farm", level, "complete", COLORS[3])
			local fp = Kit.footprint("farm", level)
			local pole, flag = named(m, "FlagPole")[1], named(m, "Flag")[1]
			expect(pole.Size.X).toBeGreaterThanOrEqual(10) -- a column: its length runs along local X
			expect(pole.CFrame.Position.X).toBeLessThan(-fp.X / 2 + 2)
			expect(pole.CFrame.Position.Z).toBeLessThan(-fp.Y / 2 + 1)
			expect(flag.CFrame.UpVector.Y).toBeGreaterThan(0.99)
			expect(flag.CFrame.Position.Y).toBeGreaterThan(8)
		end
	end)

	it("gives L1 a front-visible haystack and L2 more rows, more crop and a barn clear of the cottage", function()
		for _, color in COLORS do
			local l1 = Buildings.build("farm", 1, "complete", color)
			local l2 = Buildings.build("farm", 2, "complete", color)
			local hay = named(l1, "Haystack")[1]
			local cottage1 = named(l1, "Walls")[1]
			expect(hay).never.toBeNil()
			expect(hay.CFrame.Position.Z).toBeLessThan(0)
			expect(hay.CFrame.Position.X).toBeLessThan(cottage1.CFrame.Position.X - cottage1.Size.X / 2 - 5)
			expect(#named(l2, "Wheat")).toBeGreaterThan(#named(l1, "Wheat"))
			expect(cropArea(l2)).toBeGreaterThanOrEqual(cropArea(l1))
			expect(l1:FindFirstChild("BarnWalls")).toBeNil()
			local barn = l2:FindFirstChild("BarnWalls") :: BasePart
			expect(barn).never.toBeNil()
			expect(maxTop(side(named(l2, "RidgeCap"), -1))).toBeGreaterThan(maxTop(side(named(l2, "RidgeCap"), 1)) + 1)
			local cottage = named(l2, "Walls")[1]
			local cMinX = cottage.CFrame.Position.X - cottage.Size.X / 2
			expect(cMinX - (barn.CFrame.Position.X + barn.Size.X / 2)).toBeGreaterThanOrEqual(10)
		end
	end)

	it("keeps the barn, its base slab and its roof square to the plot grid in every colour", function()
		local function square(v: Vector3): boolean
			return (math.abs(v.X) < 1e-4 or math.abs(v.Z) < 1e-4)
		end
		for _, color in COLORS do
			local m = Buildings.build("farm", 2, "complete", color)
			local walls, base = named(m, "BarnWalls")[1], named(m, "BarnBase")[1]
			for _, name in { "BarnWalls", "BarnBase", "BarnDoor", "BarnLintel", "HayloftDoor", "HoistBeam" } do
				for _, p in named(m, name) do
					local cf = p.CFrame
					if
						math.abs(cf.RightVector.X) < 0.9999
						or cf.UpVector.Y < 0.9999
						or math.abs(cf.LookVector.Z) < 0.9999
					then
						error(`farm L2: {p.Name} is not square to the plot`)
					end
				end
			end
			local d = walls.CFrame.Position - base.CFrame.Position
			expect(math.abs(d.X) + math.abs(d.Z)).toBeLessThan(0.01)
			-- the barn roof: every axis of every part yawed by a multiple of 90 degrees
			for _, p in parts(m) do
				local roofPart = p.Name == "RoofTiles" or p.Name == "RidgeCap" or p.Name == "BargeBoard"
				if roofPart and p.CFrame.Position.X < 0 then
					local cf = p.CFrame
					if not (square(cf.RightVector) and square(cf.UpVector) and square(cf.LookVector)) then
						error(`farm L2: barn {p.Name} is yawed off the plot grid`)
					end
				end
			end
		end
	end)
end)

describe("Kit VS-2 stand-ins (G13.5)", function()
	it("builds the new types at every level and stage, labelled, with a Door and a work spot", function()
		for _, bt in NEW_TYPES do
			expect(table.find(Kit.BUILDING_TYPES, bt)).never.toBeNil()
			for level = 1, 3 do
				local fp = Kit.footprint(bt, level)
				expect(fp.X > 0 and fp.Y > 0).toBe(true)
				for _, stage in { 1, 2, 3, "complete" } do
					local m = Kit.build(bt, level, stage :: any, COLORS[2])
					local root = m.PrimaryPart :: BasePart
					expect(root:FindFirstChild("Door")).never.toBeNil()
					expect(root:FindFirstChild("WorkSpot1")).never.toBeNil()
					if stage == "complete" then
						expect(m:GetAttribute("KitStandIn")).toBe(true)
						expect(m:GetAttribute("KitLabel")).toBe(bt)
						expect(#parts(m)).toBeGreaterThan(25)
					end
				end
			end
		end
	end)
end)

-- Coplanar overlapping faces between axis-aligned blocks (z-fighting / flicker in Studio): two faces facing the
-- same way within 0.005 studs of one plane that share > 0.05 stud². Downward faces resting on the ground
-- (y ≈ 0) are skipped: the terrain hides them and the camera never looks up at them.
local AXES = { "X", "Y", "Z" }

local function axisAligned(cf: CFrame): boolean
	for _, v in { cf.RightVector, cf.UpVector, cf.LookVector } do
		if math.max(math.abs(v.X), math.abs(v.Y), math.abs(v.Z)) < 0.9999 then
			return false
		end
	end
	return true
end

local function zFights(model: Model): { string }
	local boxes = {}
	for _, p in parts(model) do
		if (p.ClassName == "Part" or p.ClassName == "Seat") and (p :: Part).Shape == Enum.PartType.Block then
			if p.Transparency < 1 and axisAligned(p.CFrame) then
				local e = halfExtents(p)
				table.insert(boxes, { name = p.Name, lo = p.CFrame.Position - e, hi = p.CFrame.Position + e })
			end
		end
	end
	local out = {}
	for i = 1, #boxes do
		local a = boxes[i]
		for j = i + 1, #boxes do
			local b = boxes[j]
			local touch = a.lo.X <= b.hi.X + 0.005
				and b.lo.X <= a.hi.X + 0.005
				and a.lo.Y <= b.hi.Y + 0.005
				and b.lo.Y <= a.hi.Y + 0.005
				and a.lo.Z <= b.hi.Z + 0.005
				and b.lo.Z <= a.hi.Z + 0.005
			if touch then
				for k, ax in AXES do
					local u, v = AXES[k % 3 + 1], AXES[(k + 1) % 3 + 1]
					local ou = math.min(a.hi[u], b.hi[u]) - math.max(a.lo[u], b.lo[u])
					local ov = math.min(a.hi[v], b.hi[v]) - math.max(a.lo[v], b.lo[v])
					if ou > 0 and ov > 0 and ou * ov > 0.05 then
						if math.abs(a.hi[ax] - b.hi[ax]) < 0.005 then
							table.insert(out, `{a.name}/{b.name} +{ax}`)
						end
						local ground = ax == "Y" and math.abs(a.lo.Y) < 0.01
						if math.abs(a.lo[ax] - b.lo[ax]) < 0.005 and not ground then
							table.insert(out, `{a.name}/{b.name} -{ax}`)
						end
					end
				end
			end
		end
	end
	return out
end

describe("Kit z-fighting probe", function()
	it("has no coplanar overlapping block faces in any building, level, house archetype or kingdom", function()
		local found = {}
		for _, bt in Kit.BUILDING_TYPES do
			for level = 1, levelsFor(bt) do
				for v = 1, (if bt == "house" then 4 else 1) do
					for _, color in COLORS do
						for _, hit in zFights(Buildings.build(bt, level, "complete", color, v)) do
							table.insert(found, `{bt} L{level} v{v}: {hit}`)
						end
					end
				end
			end
		end
		if #found > 0 then
			error(`{#found} coplanar face pairs, e.g. ` .. table.concat(found, "; ", 1, math.min(#found, 8)))
		end
	end)
end)

describe("Kit kingdom tint", function()
	it("recolours every kingdom-coloured part (recoloured == freshly built) for every type", function()
		for _, bt in Kit.BUILDING_TYPES do
			for _, v in variantsFor(bt) do
				for i, color in COLORS do
					for _, stage in { 2, "complete" } do
						local a = Buildings.build(bt, levelsFor(bt), stage :: any, color, v)
						Kit.setKingdomColor(a, SAME_STYLE[i])
						local b = Buildings.build(bt, levelsFor(bt), stage :: any, SAME_STYLE[i], v)
						local pa, pb = parts(a), parts(b)
						expect(#pa).toBe(#pb)
						for k, p in pa do
							local q = pb[k]
							local same = math.abs(p.Color.R - q.Color.R) < 1e-4
								and math.abs(p.Color.G - q.Color.G) < 1e-4
								and math.abs(p.Color.B - q.Color.B) < 1e-4
							if not same then
								error(`{bt} v{v} {stage} colour {i}: part {p.Name} is kingdom-coloured without KitTint`)
							end
						end
					end
				end
			end
		end
	end)

	it("gives the neutral watchtower a recolourable roof, banner and flag", function()
		local m = Kit.build("watchtower", 1, "complete", Kit.NEUTRAL_COLOR)
		local names = {}
		for _, p in parts(m) do
			if p:GetAttribute("KitTint") ~= nil then
				names[p.Name] = true
			end
		end
		expect(names.RoofCorner).toBe(true)
		expect(names.Banner).toBe(true)
		expect(names.Flag).toBe(true)
	end)
end)

describe("Kit placement sanity", function()
	it("keeps every part above the ground and inside its footprint (front apron ≤ 2 for steps)", function()
		for _, bt in Kit.BUILDING_TYPES do
			for level = 1, levelsFor(bt) do
				for _, v in variantsFor(bt) do
					for _, stage in { 1, 2, 3, "complete" } do
						local colors = if stage == "complete" then COLORS else { COLORS[1] }
						for _, color in colors do
							local m = Buildings.build(bt, level, stage :: any, color, v)
							local fp = Kit.footprint(bt, level)
							for _, p in parts(m) do
								local e, pos = halfExtents(p), p.CFrame.Position
								if pos.Y - e.Y < -0.3 then
									error(`{bt} L{level} v{v} {stage}: {p.Name} below ground ({pos.Y - e.Y})`)
								end
								-- sides and back strictly inside; the front may carry entrance steps/stoops (≤ 2)
								if
									math.abs(pos.X) + e.X > fp.X / 2 + 0.05
									or pos.Z + e.Z > fp.Y / 2 + 0.05
									or pos.Z - e.Z < -fp.Y / 2 - 2
								then
									error(
										`{bt} L{level} v{v} {stage}: {p.Name} outside footprint {fp} at {pos} (±{e})`
									)
								end
							end
						end
					end
				end
			end
		end
	end)

	it("keeps the Door just outside the front of the footprint and every attachment near it", function()
		for _, bt in Kit.BUILDING_TYPES do
			for level = 1, levelsFor(bt) do
				for _, stage in { 1, "complete" } do
					local m = Buildings.build(bt, level, stage :: any, COLORS[1])
					local fp = Kit.footprint(bt, level)
					for _, a in (m.PrimaryPart :: BasePart):GetChildren() do
						if a:IsA("Attachment") then
							local p = a.CFrame.Position + Vector3.new(0, 0.1, 0)
							expect(math.abs(p.Y)).toBeLessThan(0.01)
							if a.Name == "Door" then
								local inside = math.abs(p.X) < fp.X / 2 - 0.5 and math.abs(p.Z) < fp.Y / 2 - 0.5
								expect(inside).toBe(false)
								expect(math.abs(p.X) <= fp.X / 2 + 0.01).toBe(true)
								expect(p.Z >= -fp.Y / 2 - 4.5 and p.Z <= -fp.Y / 2 + 0.6).toBe(true)
							else
								expect(math.abs(p.X) <= fp.X / 2 + 12).toBe(true)
								expect(math.abs(p.Z) <= fp.Y / 2 + 12).toBe(true)
							end
						end
					end
				end
			end
		end
	end)
end)
