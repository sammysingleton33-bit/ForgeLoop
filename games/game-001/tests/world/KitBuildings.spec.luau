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

	it("flies a kingdom pennant on every roof, tile and thatch (B12: house identity was colour-only)", function()
		for v = 1, 8 do
			for level = 1, 2 do
				local m = Kit.build("house", level, "complete", COLORS[2], v)
				local pennant = m:FindFirstChild("Pennant")
				expect(pennant).never.toBeNil()
				expect((pennant :: BasePart):GetAttribute("KitTint")).toBe(1)
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

	it("keeps every throne part at least 0.1 clear of the entrance bay and the door behind it", function()
		-- B12 review: the throne's knobs touched the arch; now nothing of the throne group (dossal, canopy,
		-- edge) comes within 0.1 of the bay, the leaf, the jambs or the voussoirs along some axis
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
				expect(#doorParts).toBeGreaterThan(6)
				for _, a in throneParts do
					local ea, ca = halfExtents(a), a.CFrame.Position
					for _, b in doorParts do
						local eb, cb = halfExtents(b), b.CFrame.Position
						local dc = ca - cb
						local gap = Vector3.new(math.abs(dc.X), math.abs(dc.Y), math.abs(dc.Z)) - (ea + eb)
						if math.max(gap.X, gap.Y, gap.Z) < 0.1 then
							error(`keep L{level}: throne part {a.Name} within 0.1 of {b.Name}`)
						end
					end
				end
			end
		end
	end)

	-- B12 (FORGE-00 D-019 review): the canopy sits low over the seat (it read as an entrance awning 24 studs up),
	-- on two posts beside the dais, and the throne stands against a framed cloth of estate instead of the dark
	-- door; the marker for the overview camera from behind is the royal standard pair (KitEmblems.spec)
	it("covers the throne with a low baldachin and hangs a framed dossal behind it", function()
		for level = 1, 3 do
			for _, color in COLORS do
				local m = Kit.build("keep", level, "complete", color)
				local seat = m:FindFirstChild("Throne", true) :: BasePart
				local seatTop = seat.CFrame.Position.Y + seat.Size.Y / 2
				local sp = seat.CFrame.Position
				local byName: { [string]: { BasePart } } = {}
				for _, p in parts(m) do
					byName[p.Name] = byName[p.Name] or {}
					table.insert(byName[p.Name], p)
				end
				local function one(name: string): BasePart
					local list = byName[name]
					if list == nil or #list ~= 1 then
						error(`keep L{level}: want one {name}, found {if list then #list else 0}`)
					end
					return list[1]
				end
				-- baldachin: 2 posts, 2 tinted canopy wedges, a finial (5 parts)
				expect(#(byName.BaldachinPost or {})).toBe(2)
				expect(#(byName.BaldachinCanopy or {})).toBe(2)
				expect(#(byName.BaldachinFinial or {})).toBe(1)
				local lo, ridge = math.huge, -math.huge
				local xMin, xMax, zMin, zMax = math.huge, -math.huge, math.huge, -math.huge
				for _, p in byName.BaldachinCanopy do
					expect(p:GetAttribute("KitTint")).never.toBeNil()
					local e, c = halfExtents(p), p.CFrame.Position
					lo, ridge = math.min(lo, c.Y - e.Y), math.max(ridge, c.Y + e.Y)
					xMin, xMax = math.min(xMin, c.X - e.X), math.max(xMax, c.X + e.X)
					zMin, zMax = math.min(zMin, c.Z - e.Z), math.max(zMax, c.Z + e.Z)
				end
				-- low: 8–9 studs over the seat (the open-sky rule's minimum), and it covers the whole seat
				expect(lo - seatTop).toBeGreaterThanOrEqual(8)
				expect(lo - seatTop).toBeLessThanOrEqual(9)
				local se = halfExtents(seat)
				local covers = xMin <= sp.X - se.X
					and xMax >= sp.X + se.X
					and zMin <= sp.Z - se.Z
					and zMax >= sp.Z + se.Z
				if not covers then
					error(`keep L{level}: the canopy does not cover the seat`)
				end
				-- the posts stand clear of the dais (an angled view saw a post cut across the seat)
				for _, post in byName.BaldachinPost do
					local pp, r = post.CFrame.Position, post.Size.Y / 2
					for _, step in byName.DaisStep do
						local e, c = halfExtents(step), step.CFrame.Position
						local dx = math.max(math.abs(pp.X - c.X) - e.X, 0)
						local dz = math.max(math.abs(pp.Z - c.Z) - e.Z, 0)
						if math.sqrt(dx * dx + dz * dz) < r then
							error(`keep L{level}: a baldachin post stands on the dais`)
						end
					end
				end
				-- the dossal: kingdom cloth between the throne back and the bay, wider than the back, in an
				-- ivory border; the back has an ivory edge and carries the emblem slot
				local back, edge = one("ThroneBack"), one("ThroneEdge")
				local dossal, border, bay = one("Dossal"), one("DossalBorder"), one("EntranceBay")
				expect(dossal:GetAttribute("KitTint")).never.toBeNil()
				expect(back:GetAttribute("KitEmblemCF")).never.toBeNil()
				local bayFace = bay.CFrame.Position.Z - bay.Size.Z / 2
				local backRear = back.CFrame.Position.Z + back.Size.Z / 2
				local dz = dossal.CFrame.Position.Z
				expect(dz > backRear and dz < bayFace).toBe(true)
				expect(dossal.Size.X).toBeGreaterThan(back.Size.X)
				expect(border.Size.X).toBeGreaterThan(dossal.Size.X)
				expect(edge.Size.X).toBeGreaterThan(back.Size.X)
				for _, p in { border, edge } do
					expect(p.Color.R > 0.85 and p.Color.G > 0.85 and p.Color.B > 0.75).toBe(true) -- ivory
				end
				-- the wall shield hangs above the canopy: its lowest point (the tip) no lower than the ridge
				local shieldLow = math.huge
				for _, p in { one("Crest"), one("CrestTip") } do
					shieldLow = math.min(shieldLow, p.CFrame.Position.Y - halfExtents(p).Y)
				end
				expect(shieldLow).toBeGreaterThanOrEqual(ridge - 0.05)
			end
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

	it("raises every house variant by at least 4 studs from L1 to L2 (B12: v1 read the same at 90 studs)", function()
		for v = 1, 8 do
			local h = {}
			for level = 1, 2 do
				local lo, hi = bounds(Buildings.build("house", level, "complete", COLORS[4], v))
				h[level] = hi.Y - lo.Y
			end
			if h[2] < h[1] + 4 then
				error(`house v{v}: L2 is {h[2] - h[1]} studs taller than L1 (want ≥ 4)`)
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
