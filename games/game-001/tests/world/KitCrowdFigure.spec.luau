--[[
	Kit.crowdFigure (FL-0072, FORGE-02; CONTRACTS G12.6, design/crown-arena.md §7; D-026, D-033): the Crown Arena's
	crowd. At most 4 primitive parts (8 for the six key citizens, CONTRACTS v0.4-g11a), client-only (no Root, Humanoid, motors, welds or scripts), deterministic, pivoted on the feet and
	facing -Z, kingdom-coloured with the kingdom's crest shape (never colour alone), twelve variants so a stand is not a row of
	clones, six role props that read apart by silhouette alone, and a fit on every seat and rail place of Kit.arena.
]]

local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local Kit = require("@game/ReplicatedStorage/Game/Kit/Kit")
local KingdomsConfig = require("@game/ReplicatedStorage/Forge/Config/Kingdoms")

local CANON: { [string]: Color3 } = {}
for _, identity in KingdomsConfig.identities do
	local c = identity.color
	CANON[identity.id] = Color3.fromRGB(c[1], c[2], c[3])
end
local KINGDOMS = { "crimson", "azure", "emerald", "gold" }
local NEUTRAL = Kit.NEUTRAL_COLOR
local COLORS: { Color3 } = {
	CANON.crimson,
	CANON.azure,
	CANON.emerald,
	CANON.gold,
	NEUTRAL,
	Color3.fromRGB(40, 127, 71),
	Color3.fromRGB(245, 205, 48),
}
local ROLES = Kit.CROWD_ROLES
-- the part names of each role (after Body and Head), in build order
local ROLE_PARTS: { [string]: { string } } = {
	blacksmith = { "Crest", "Arms", "Apron", "Handle", "Hammer", "Peen" },
	healer = { "Crest", "Arms", "Satchel", "CrossV", "CrossH", "Strap" },
	captain = { "Plume", "Arms", "Cape", "Sash", "Sword" },
	provisioner = { "Crest", "Basket", "HandleL", "HandleR", "HandleBar", "Bread" },
	elder = { "Crest", "Staff", "Crossbar", "Banner", "Finial", "Beard" },
	merchant = { "Crest", "Arm", "Post", "Beam", "PanL", "PanR" },
}
local VARIANTS = Kit.CROWD_VARIANTS

local function noYield<R>(fn: () -> R): R
	local co = coroutine.create(fn)
	local ok, result = coroutine.resume(co)
	assert(ok, result)
	assert(coroutine.status(co) == "dead", "Kit yielded")
	return result
end

local function parts(model: Instance): { BasePart }
	local out = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(out, d)
		end
	end
	return out
end

local function halfExtents(p: BasePart): Vector3
	local s = p.Size
	local rv, uv, lv = p.CFrame.RightVector, p.CFrame.UpVector, p.CFrame.LookVector
	return Vector3.new(
		math.abs(rv.X) * s.X / 2 + math.abs(uv.X) * s.Y / 2 + math.abs(lv.X) * s.Z / 2,
		math.abs(rv.Y) * s.X / 2 + math.abs(uv.Y) * s.Y / 2 + math.abs(lv.Y) * s.Z / 2,
		math.abs(rv.Z) * s.X / 2 + math.abs(uv.Z) * s.Y / 2 + math.abs(lv.Z) * s.Z / 2
	)
end

local function bounds(model: Instance): (Vector3, Vector3)
	local lo, hi = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, p in parts(model) do
		local e, c = halfExtents(p), p.CFrame.Position
		lo = lo:Min(c - e)
		hi = hi:Max(c + e)
	end
	return lo, hi
end

local function signature(model: Instance): string
	local rows = {}
	for _, p in parts(model) do
		local s, pos, c = p.Size, p.CFrame.Position, p.Color
		table.insert(
			rows,
			string.format(
				"%s %s %.2f %.2f %.2f %.2f %.2f %.2f %.3f %.3f %.3f",
				p.ClassName,
				p.Name,
				s.X,
				s.Y,
				s.Z,
				pos.X,
				pos.Y,
				pos.Z,
				c.R,
				c.G,
				c.B
			)
		)
	end
	return table.concat(rows, "\n")
end

-- A coarse outline from one axis pair: the part bounding boxes rasterised on a 0.5-stud grid (columns x rows)
local function outline(
	model: Instance,
	u: string,
	v: string,
	uMin: number,
	vMin: number,
	cols: number,
	rows: number
): { boolean }
	local cells = table.create(cols * rows, false)
	for _, p in parts(model) do
		local e, c = halfExtents(p), p.CFrame.Position
		local u0, u1 = math.floor((c[u] - e[u] - uMin) / 0.5), math.ceil((c[u] + e[u] - uMin) / 0.5) - 1
		local v0, v1 = math.floor((c[v] - e[v] - vMin) / 0.5), math.ceil((c[v] + e[v] - vMin) / 0.5) - 1
		for i = math.max(0, u0), math.min(cols - 1, u1) do
			for j = math.max(0, v0), math.min(rows - 1, v1) do
				cells[j * cols + i + 1] = true
			end
		end
	end
	return cells
end

-- front (X-Y) and side (Z-Y) outlines of a figure, concatenated
local function silhouette(model: Instance): { boolean }
	local front = outline(model, "X", "Y", -4, 0, 16, 16)
	local side = outline(model, "Z", "Y", -4, 0, 16, 16)
	for _, c in side do
		table.insert(front, c)
	end
	return front
end

local function hamming(a: { boolean }, b: { boolean }): number
	local n = 0
	for i = 1, #a do
		if a[i] ~= b[i] then
			n += 1
		end
	end
	return n
end

local function names(model: Instance): { string }
	local out = {}
	for _, p in parts(model) do
		table.insert(out, p.Name)
	end
	return out
end

local function partNamed(model: Instance, name: string): BasePart
	for _, p in parts(model) do
		if p.Name == name then
			return p
		end
	end
	error(`no part {name} in {model.Name}`)
end

describe("Kit.crowdFigure part budget and rules (G12.6: at most 4 parts, client-only)", function()
	it("builds at most 4 parts for every role, variant and colour", function()
		local seen = 0
		for _, color in COLORS do
			for _, role in { false, table.unpack(ROLES) } do
				for variant = 1, VARIANTS do
					local m = noYield(function()
						return Kit.crowdFigure(color, if role then role else nil, variant)
					end)
					local n = Kit.partCount(m)
					if role then
						expect(n).toBeLessThanOrEqual(Kit.CROWD_ROLE_MAX_PARTS) -- a key citizen: 8 (v0.4-g11a)
						expect(n).toBeGreaterThanOrEqual(7) -- and it spends them on its prop
					else
						expect(n).toBeLessThanOrEqual(Kit.CROWD_MAX_PARTS) -- every other figure: 4
						expect(n).toBe(4)
					end
					seen += 1
				end
			end
		end
		expect(Kit.CROWD_MAX_PARTS).toBe(4)
		expect(Kit.CROWD_ROLE_MAX_PARTS).toBe(8)
		expect(seen).toBe(#COLORS * 7 * VARIANTS)
	end)

	it("uses primitive parts only, anchored, non-colliding, non-queryable, casting no shadow", function()
		for _, role in { false, table.unpack(ROLES) } do
			local m = Kit.crowdFigure(CANON.crimson, if role then role else nil, 3)
			for _, p in parts(m) do
				expect(p.ClassName == "Part" or p.ClassName == "WedgePart" or p.ClassName == "CornerWedgePart").toBe(
					true
				)
				if p.ClassName == "Part" then
					local shape = (p :: Part).Shape
					expect(
						shape == Enum.PartType.Block or shape == Enum.PartType.Cylinder or shape == Enum.PartType.Ball
					).toBe(true)
				end
				expect(p.Anchored).toBe(true)
				expect(p.CanCollide).toBe(false)
				expect(p.CanTouch).toBe(false)
				expect(p.CanQuery).toBe(false)
				expect(p.CastShadow).toBe(false)
				expect(p.Transparency).toBe(0)
			end
			for _, d in m:GetDescendants() do
				expect(
					d:IsA("LuaSourceContainer")
						or d:IsA("Humanoid")
						or d:IsA("JointInstance")
						or d:IsA("WeldConstraint")
						or d:IsA("Attachment")
				).toBe(false)
			end
		end
	end)

	it("is deterministic and never errors on a variant: wraps over 1..12, survives NaN and infinity", function()
		for _, role in { false, table.unpack(ROLES) } do
			for v = 1, VARIANTS do
				local r = if role then role else nil
				expect(signature(Kit.crowdFigure(CANON.azure, r, v))).toBe(
					signature(Kit.crowdFigure(CANON.azure, r, v))
				)
			end
			local r = if role then role else nil
			expect(signature(Kit.crowdFigure(CANON.azure, r, VARIANTS + 1))).toBe(
				signature(Kit.crowdFigure(CANON.azure, r, 1))
			)
			expect(signature(Kit.crowdFigure(CANON.azure, r, 0))).toBe(
				signature(Kit.crowdFigure(CANON.azure, r, VARIANTS))
			)
			expect(signature(Kit.crowdFigure(CANON.azure, r, -3))).toBe(
				signature(Kit.crowdFigure(CANON.azure, r, VARIANTS - 3))
			)
			expect(signature(Kit.crowdFigure(CANON.azure, r, 2.7))).toBe(signature(Kit.crowdFigure(CANON.azure, r, 2)))
			for _, bad in { 0 / 0, math.huge, -math.huge } do
				expect(signature(Kit.crowdFigure(CANON.azure, r, bad))).toBe(
					signature(Kit.crowdFigure(CANON.azure, r, nil))
				)
			end
			expect(signature(Kit.crowdFigure(CANON.azure, r))).toBe(signature(Kit.crowdFigure(CANON.azure, r, 1)))
		end
	end)

	it("rejects an unknown role", function()
		local ok = pcall(function()
			Kit.crowdFigure(CANON.crimson, "jester" :: any)
		end)
		expect(ok).toBe(false)
	end)

	it("pivots on the feet, front -Z, body first: a figure placed on a surface stands on it", function()
		for _, role in { false, table.unpack(ROLES) } do
			for v = 1, VARIANTS do
				local m = Kit.crowdFigure(CANON.gold, if role then role else nil, v)
				local body = m.PrimaryPart :: BasePart
				expect(body.Name).toBe("Body")
				expect(parts(m)[1]).toBe(body)
				local pivot = body.CFrame * body.PivotOffset
				expect(pivot.Position.Magnitude).toBeLessThan(1e-4)
				expect(pivot.UpVector.Y).toBeNear(1, 1e-4) -- upright, even when the body is a turned cylinder
				expect(pivot.LookVector.Z).toBeNear(-1, 1e-4)
				local lo, hi = bounds(m)
				expect(lo.Y).toBeGreaterThanOrEqual(-1e-4)
				expect(lo.Y).toBeLessThan(0.05) -- the feet (the body block) are on y = 0, nothing below
				-- readable size: a person-sized figure, props taller at most
				expect(hi.Y).toBeGreaterThan(4.4)
				expect(hi.Y).toBeLessThan(8.0)
				expect(hi.X - lo.X).toBeLessThan(5.2)
				expect(hi.Z - lo.Z).toBeLessThan(4.0)
			end
		end
	end)
end)

describe("Kit.crowdFigure kingdom identity (D-033: never colour alone)", function()
	it("colours the body and the kingdom parts exactly shade(colour, KitTint)", function()
		for _, color in COLORS do
			for _, role in { false, table.unpack(ROLES) } do
				local m = Kit.crowdFigure(color, if role then role else nil, 2)
				local tinted = 0
				for _, p in parts(m) do
					local f = p:GetAttribute("KitTint")
					if type(f) == "number" then
						tinted += 1
						expect(p.Color.R).toBeNear(math.clamp(color.R * f, 0, 1), 0.002)
						expect(p.Color.G).toBeNear(math.clamp(color.G * f, 0, 1), 0.002)
						expect(p.Color.B).toBeNear(math.clamp(color.B * f, 0, 1), 0.002)
					end
				end
				expect(tinted).toBeGreaterThanOrEqual(1)
				if role ~= "blacksmith" and role ~= "merchant" then
					expect(tinted).toBeGreaterThanOrEqual(2) -- the body and a crest, plume or sleeves
				end
				expect((m.PrimaryPart :: BasePart):GetAttribute("KitTint")).never.toBeNil()
			end
		end
	end)

	it("gives each kingdom its own crest shape, as the soldiers' helmets do (spire, square, plume, dome)", function()
		local want = {
			crimson = { "CornerWedgePart", "crest_spire" },
			azure = { "Part", "crest_square" },
			emerald = { "Part", "crest_plume" },
			gold = { "Part", "crest_dome" },
		}
		local shapes = {}
		for _, k in KINGDOMS do
			local m = Kit.crowdFigure(CANON[k], nil, 1)
			local crest = partNamed(m, "Crest")
			expect(crest.ClassName).toBe(want[k][1])
			expect(m:GetAttribute("KitCrest")).toBe(want[k][2])
			expect(m:GetAttribute("KitStyle")).toBe(k)
			local shape = if crest.ClassName == "Part" then (crest :: Part).Shape.Name else crest.ClassName
			expect(shapes[shape]).toBeNil() -- four different primitives... azure Block, emerald Cylinder, gold Ball, crimson wedge
			shapes[shape] = k
		end
		expect(Kit.crowdFigure(NEUTRAL, nil, 1):GetAttribute("KitCrest")).toBe("cap")
	end)

	it("tells the four kingdoms apart by outline, not only colour", function()
		local sil = {}
		for _, k in KINGDOMS do
			sil[k] = silhouette(Kit.crowdFigure(CANON[k], nil, 1))
		end
		for i = 1, #KINGDOMS do
			for j = i + 1, #KINGDOMS do
				expect(hamming(sil[KINGDOMS[i]], sil[KINGDOMS[j]])).toBeGreaterThanOrEqual(4)
			end
		end
	end)

	it("recolours a pooled figure to the same look as a fresh one of the same hue style", function()
		local a = Kit.crowdFigure(CANON.crimson, "healer", 4)
		local other = Color3.fromRGB(170, 30, 50) -- still crimson
		expect(Kit.crowdPoolKey(a:GetAttribute("KitStyle") and CANON.crimson, "healer", 4)).toBe(
			Kit.crowdPoolKey(other, "healer", 4)
		)
		Kit.setKingdomColor(a, other)
		expect(signature(a)).toBe(signature(Kit.crowdFigure(other, "healer", 4)))
		-- pool keys separate style, role and variant
		local keys = {}
		for _, k in KINGDOMS do
			for _, role in { false, table.unpack(ROLES) } do
				for v = 1, VARIANTS do
					local key = Kit.crowdPoolKey(CANON[k], if role then role else nil, v)
					expect(keys[key]).toBeNil()
					keys[key] = true
				end
			end
		end
		expect(Kit.crowdPoolKey(CANON.crimson, nil, VARIANTS + 1)).toBe(Kit.crowdPoolKey(CANON.crimson, nil, 1))
	end)
end)

describe("Kit.crowdFigure variants (a stand is not a row of clones)", function()
	it("gives twelve different figures: outlines, widths, heights and skin tones vary", function()
		local sils, widths, heights, skins = {}, {}, {}, {}
		for v = 1, VARIANTS do
			local m = Kit.crowdFigure(CANON.emerald, nil, v)
			local body = partNamed(m, "Body")
			widths[string.format("%.2f", body.Size.X)] = true
			local lo, hi = bounds(m)
			heights[string.format("%.2f", hi.Y - lo.Y)] = true
			local head = partNamed(m, "Head")
			skins[head.Color:ToHex()] = true
			local sil = silhouette(m)
			local key = {}
			for _, c in sil do
				table.insert(key, if c then "1" else "0")
			end
			sils[table.concat(key)] = true
		end
		local function size(t: { [string]: boolean }): number
			local n = 0
			for _ in t do
				n += 1
			end
			return n
		end
		expect(size(sils)).toBeGreaterThanOrEqual(11)
		expect(size(widths)).toBeGreaterThanOrEqual(9)
		expect(size(heights)).toBeGreaterThanOrEqual(10)
		expect(size(skins)).toBeGreaterThanOrEqual(5)
	end)

	it(
		"mixes two body shapes, a wide spread of heights and of tabard shades (the FL-0072 review: not clones)",
		function()
			local round, block, shades = 0, 0, {}
			local lowest, tallest = math.huge, 0
			for v = 1, VARIANTS do
				local m = Kit.crowdFigure(CANON.emerald, nil, v)
				local body = partNamed(m, "Body")
				if (body :: Part).Shape == Enum.PartType.Cylinder then
					round += 1
				else
					block += 1
				end
				local f = body:GetAttribute("KitTint") :: number
				shades[string.format("%.2f", f)] = true
				local _, hi = bounds(m)
				local head = partNamed(m, "Head")
				lowest = math.min(lowest, head.CFrame.Position.Y)
				tallest = math.max(tallest, head.CFrame.Position.Y)
				expect(hi.Y).toBeGreaterThan(4.2)
			end
			expect(round).toBeGreaterThanOrEqual(3)
			expect(block).toBeGreaterThanOrEqual(6)
			-- three head shapes (ball, block, drum) and a spread of crest sizes
			local heads = {}
			for v = 1, VARIANTS do
				local head = partNamed(Kit.crowdFigure(CANON.emerald, nil, v), "Head") :: Part
				heads[`{head.Shape.Name}`] = (heads[`{head.Shape.Name}`] or 0) + 1
			end
			expect(heads.Ball).toBeGreaterThanOrEqual(5)
			expect(heads.Block).toBeGreaterThanOrEqual(3)
			expect(heads.Cylinder).toBeGreaterThanOrEqual(3)
			local crestLo, crestHi = math.huge, 0
			for v = 1, VARIANTS do
				local c = partNamed(Kit.crowdFigure(CANON.crimson, nil, v), "Crest")
				crestLo = math.min(crestLo, c.Size.Y)
				crestHi = math.max(crestHi, c.Size.Y)
			end
			expect(crestHi / crestLo).toBeGreaterThan(1.2)
			local n = 0
			for _ in shades do
				n += 1
			end
			expect(n).toBeGreaterThanOrEqual(6) -- six or more different tabard shades in twelve figures
			expect(tallest / lowest).toBeGreaterThan(1.25) -- the tallest head stands a quarter over the lowest
			-- the arms are kingdom cloth or skin-tone sleeves, never a pale shard beside the body
			for v = 1, VARIANTS do
				local arms = partNamed(Kit.crowdFigure(CANON.azure, nil, v), "Arms")
				local c = arms.Color
				expect(c.R + c.G + c.B < 2.1).toBe(true)
			end
		end
	)

	it("poses the arms five ways: level, waving, an arm thrown up, one arm straight up, folded at the waist", function()
		local cheer, waving, level, straightUp, folded = 0, 0, 0, 0, 0
		for v = 1, VARIANTS do
			local arms = partNamed(Kit.crowdFigure(CANON.azure, nil, v), "Arms")
			local tilt = math.abs(math.deg(math.atan2(arms.CFrame.RightVector.Y, arms.CFrame.RightVector.X)))
			if arms.Size.Y > 2 then
				straightUp += 1 -- one raised arm, beside the head
				expect(arms.CFrame.Position.Y + arms.Size.Y / 2).toBeGreaterThan(
					partNamed(Kit.crowdFigure(CANON.azure, nil, v), "Body").Size.Y
				)
			elseif arms.Size.Z > 1.1 then
				folded += 1 -- the arms folded in front at the waist
			elseif tilt > 30 then
				cheer += 1
			elseif tilt > 10 then
				waving += 1
			elseif tilt < 1 then
				level += 1
			end
		end
		expect(cheer).toBeGreaterThanOrEqual(2)
		expect(waving).toBeGreaterThanOrEqual(3)
		expect(level).toBeGreaterThanOrEqual(1)
		expect(straightUp).toBeGreaterThanOrEqual(2)
		expect(folded).toBeGreaterThanOrEqual(2)
	end)
end)

describe("Kit.crowdFigure role props (the six key citizens read by silhouette)", function()
	it("builds each role's props by name, replacing the arms bar or the crest as documented", function()
		for _, k in KINGDOMS do
			for _, role in ROLES do
				local m = Kit.crowdFigure(CANON[k], role, 1)
				expect(m:GetAttribute("KitRole")).toBe(role)
				local got = names(m)
				expect(got[1]).toBe("Body")
				expect(got[2]).toBe("Head")
				for i, n in ROLE_PARTS[role] do
					expect(got[2 + i]).toBe(n)
				end
				expect(#got).toBe(2 + #ROLE_PARTS[role])
			end
		end
		expect(Kit.crowdFigure(CANON.azure, nil, 1):GetAttribute("KitRole")).toBe("none")
	end)

	it("makes every role distinct from the plain figure and from every other role, in every kingdom", function()
		for _, k in KINGDOMS do
			local sils = { plain = silhouette(Kit.crowdFigure(CANON[k], nil, 1)) }
			for _, role in ROLES do
				sils[role] = silhouette(Kit.crowdFigure(CANON[k], role, 1))
			end
			local keys = { "plain", table.unpack(ROLES) }
			for i = 1, #keys do
				for j = i + 1, #keys do
					local d = hamming(sils[keys[i]], sils[keys[j]])
					if d < 10 then
						error(`{k}: {keys[i]} and {keys[j]} differ by only {d} cells`)
					end
				end
			end
		end
	end)

	it(
		"keeps the props where their silhouette says: hammer beside the head, staff taller than all, plume above the helm",
		function()
			local m = Kit.crowdFigure(CANON.crimson, "blacksmith", 1)
			local hammer, head = partNamed(m, "Hammer"), partNamed(m, "Head")
			expect(hammer.CFrame.Position.Y).toBeGreaterThan(head.CFrame.Position.Y) -- raised over the shoulder
			expect(math.abs(hammer.CFrame.Position.X)).toBeGreaterThan(1.2) -- beside the head, not on it
			expect(hammer.Size.X).toBeGreaterThan(partNamed(m, "Handle").Size.Y * 3) -- a chunky head on a thin haft
			expect(partNamed(m, "Apron").Color).never.toBe(partNamed(m, "Body").Color) -- a dark apron on the chest
			local tops = {}
			for _, role in ROLES do
				local _, hi = bounds(Kit.crowdFigure(CANON.crimson, role, 1))
				tops[role] = hi.Y
			end
			expect(tops.elder).toBeGreaterThan(tops.blacksmith) -- the staff reaches over the hammer's raise ...
			expect(tops.elder).toBeGreaterThan(tops.healer + 0.5) -- ... and over a plain figure's spire (the tallest crest)
			expect(tops.captain).toBeGreaterThan(tops.healer + 0.5) -- the plume rises over the helm
			local captain = Kit.crowdFigure(CANON.crimson, "captain", 1)
			expect(partNamed(captain, "Plume").CFrame.Position.Y).toBeGreaterThan(
				partNamed(captain, "Head").CFrame.Position.Y + 1
			)
			-- the provisioner's basket is the widest thing at the belt; the healer's satchel hangs at a hip
			local basket = partNamed(Kit.crowdFigure(CANON.crimson, "provisioner", 1), "Basket")
			expect(basket.Size.Y).toBeGreaterThan(2)
			expect(basket.CFrame.Position.Z).toBeLessThan(-1) -- carried in front
			local satchel = partNamed(Kit.crowdFigure(CANON.crimson, "healer", 1), "Satchel")
			expect(math.abs(satchel.CFrame.Position.X)).toBeGreaterThan(1)
			expect(satchel.CFrame.Position.Y).toBeLessThan(2.4)
			-- the scales: a brass beam much wider than the head, over a post, above the shoulders, a pan under each end
			local merchant = Kit.crowdFigure(CANON.crimson, "merchant", 1)
			local beam = partNamed(merchant, "Beam")
			expect(beam.Size.X).toBeGreaterThan(3.2)
			expect(beam.CFrame.Position.Y).toBeGreaterThan(5.2)
			expect(beam.Color).toBe(partNamed(merchant, "Post").Color)
			local panL, panR = partNamed(merchant, "PanL"), partNamed(merchant, "PanR")
			expect(panL.CFrame.Position.X).toBeLessThan(beam.CFrame.Position.X - 1)
			expect(panR.CFrame.Position.X).toBeGreaterThan(beam.CFrame.Position.X + 1)
			expect(panL.CFrame.Position.Y).toBeLessThan(beam.CFrame.Position.Y)
			expect(panR.CFrame.Position.Y).toBeLessThan(beam.CFrame.Position.Y + 1)
			expect(panL.Color).toBe(beam.Color)
			-- the healer's satchel carries a red cross on its face (a cross: two bars of one centre, one colour, in front)
			local healer = Kit.crowdFigure(CANON.azure, "healer", 1)
			local sat, cv, ch = partNamed(healer, "Satchel"), partNamed(healer, "CrossV"), partNamed(healer, "CrossH")
			expect(math.abs(cv.CFrame.Position.X - ch.CFrame.Position.X)).toBeLessThan(1e-3) -- one centre, two bars
			expect(math.abs(cv.CFrame.Position.Y - ch.CFrame.Position.Y)).toBeLessThan(1e-3)
			expect(ch.CFrame.Position.Z).toBeLessThan(cv.CFrame.Position.Z) -- CrossH 0.02 proud of CrossV (no coplanar faces)
			expect(cv.Color).toBe(ch.Color)
			expect(cv.Color.R).toBeGreaterThan(cv.Color.G * 2) -- red on a cream bag, whatever the kingdom
			expect(cv.CFrame.Position.Z).toBeLessThan(sat.CFrame.Position.Z - 0.4)
			expect(cv.Size.Y).toBeGreaterThan(sat.Size.Y / 2)
			-- the elder's staff carries the kingdom's banner, taller than the head and clear of it
			local elder = Kit.crowdFigure(CANON.azure, "elder", 1)
			local banner, staff = partNamed(elder, "Banner"), partNamed(elder, "Staff")
			expect(banner:GetAttribute("KitTint")).never.toBeNil()
			expect(banner.Size.Y).toBeGreaterThan(2)
			expect(banner.CFrame.Position.Y - banner.Size.Y / 2).toBeGreaterThan(Kit.CROWD_HEIGHT * 0.6) -- hangs above the shoulders
			expect(math.abs(banner.CFrame.Position.X - staff.CFrame.Position.X)).toBeLessThan(0.1)
			-- the provisioner's basket has a bridge handle over it; the smith's hammer a peen on its far end
			local prov = Kit.crowdFigure(CANON.azure, "provisioner", 1)
			expect(partNamed(prov, "HandleBar").CFrame.Position.Y).toBeGreaterThan(
				partNamed(prov, "Basket").CFrame.Position.Y + 1.5
			)
		end
	)

	it("leaves no part floating: every part of every figure touches another (props are held, not hovering)", function()
		for _, role in { false, table.unpack(ROLES) } do
			for v = 1, VARIANTS do
				local m = Kit.crowdFigure(CANON.gold, if role then role else nil, v)
				local list = parts(m)
				for _, p in list do
					local e, c = halfExtents(p), p.CFrame.Position
					local touches = false
					for _, q in list do
						if q ~= p then
							local f, d = halfExtents(q), q.CFrame.Position
							if
								math.abs(c.X - d.X) <= e.X + f.X + 0.08
								and math.abs(c.Y - d.Y) <= e.Y + f.Y + 0.08
								and math.abs(c.Z - d.Z) <= e.Z + f.Z + 0.08
							then
								touches = true
								break
							end
						end
					end
					if not touches then
						error(`{m.Name} variant {v}: {p.Name} floats clear of the rest of the figure`)
					end
				end
			end
		end
	end)

	it("keeps the elder white-haired and the captain helmeted, so the heads differ too", function()
		local elder = partNamed(Kit.crowdFigure(CANON.gold, "elder", 1), "Head")
		local captain = partNamed(Kit.crowdFigure(CANON.gold, "captain", 1), "Head")
		local plain = partNamed(Kit.crowdFigure(CANON.gold, nil, 1), "Head")
		expect(elder.Color:ToHex() ~= plain.Color:ToHex()).toBe(true)
		expect(captain.Color:ToHex() ~= plain.Color:ToHex()).toBe(true)
		expect(captain.Material).toBe(Enum.Material.Metal)
	end)
end)

describe("Kit.crowdFigure on the arena's stands", function()
	-- put a figure's pivot on an attachment (no PivotTo in Lune)
	local function place(model: Model, cf: CFrame)
		local primary = model.PrimaryPart :: BasePart
		local delta = cf * (primary.CFrame * primary.PivotOffset):Inverse()
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				d.CFrame = delta * d.CFrame
			end
		end
	end

	it(
		"stands every variant on every seat and every role on every rail place, facing the ring, clear of the stand",
		function()
			local arena = Kit.arena(CANON.crimson, CANON.azure)
			local root = arena.PrimaryPart :: BasePart
			local solids = {}
			for _, p in parts(arena) do
				if p ~= root and p.CanCollide and p.Name ~= "RowPlank" and p.Name ~= "Podium" and p.Name ~= "Row" then
					table.insert(solids, p)
				end
			end
			local function clear(model: Model, label: string)
				for _, fp in parts(model) do
					local e, c = halfExtents(fp), fp.CFrame.Position
					for _, s in solids do
						local f, d = halfExtents(s), s.CFrame.Position
						if
							math.abs(c.X - d.X) < e.X + f.X - 0.05
							and math.abs(c.Y - d.Y) < e.Y + f.Y - 0.05
							and math.abs(c.Z - d.Z) < e.Z + f.Z - 0.05
						then
							error(`{label}: {fp.Name} pokes into {s.Name} at ({d.X}, {d.Y}, {d.Z})`)
						end
					end
				end
			end
			local seats, rails = 0, 0
			for _, a in root:GetChildren() do
				if a:IsA("Attachment") then
					local side, row, seat = string.match(a.Name, "^Stand(%a)_Row(%d)_Seat(%d+)$")
					local rside, rail = string.match(a.Name, "^Stand(%a)_Rail(%d)$")
					if side then
						local fig = Kit.crowdFigure(
							if side == "A" then CANON.crimson else CANON.azure,
							nil,
							tonumber(seat) :: number + tonumber(row) :: number
						)
						place(fig, root.CFrame * a.CFrame)
						expect((fig.PrimaryPart :: BasePart).CFrame.LookVector:Dot((root.CFrame * a.CFrame).LookVector)).toBeNear(
							1,
							1e-4
						)
						clear(fig, a.Name)
						seats += 1
					elseif rside then
						local role = ROLES[tonumber(rail) :: number]
						local fig = Kit.crowdFigure(if rside == "A" then CANON.crimson else CANON.azure, role, 1)
						place(fig, root.CFrame * a.CFrame)
						clear(fig, a.Name)
						rails += 1
					end
				end
			end
			expect(seats).toBe(144)
			expect(rails).toBe(12)
		end
	)

	it("keeps neighbouring figures' arms inside the seat spacing, so two figures never share a surface", function()
		for v = 1, VARIANTS do
			local lo, hi = bounds(Kit.crowdFigure(CANON.azure, nil, v))
			-- the figure's width stays within the 2.4-stud seat spacing plus the crowd's allowed 0.5 overlap
			expect(hi.X - lo.X).toBeLessThanOrEqual(Kit.ARENA.SEAT_SPACING + 0.7)
		end
	end)
end)
