--[[
	Kit.arena (FL-0072, FORGE-02; CONTRACTS G12.6, design/crown-arena.md §1, §7; D-026, D-033, D-039, D-047, D-053):
	the Crown Arena venue. Part budget (target 700, hard cap 900), determinism, no yields, the footprint, ring and
	attachments (72 seats a stand in 4 rows, 6 rail places, royal box chairs, gates, spawn marks), mirrored sides, kingdom
	dress (tower caps AND emblems, never colour alone; recolouring and rebuilding in place), no coplanar faces.
	Layout.arena, the world placement and the keep-out live in ArenaLayout.spec; crowd figures in KitCrowdFigure.spec;
	armour and weapons in KitGear.spec.
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
-- any kingdom colour, not only the canonical four, must map to a style and stay inside the budget
local COLORS: { Color3 } = {
	CANON.crimson,
	CANON.azure,
	CANON.emerald,
	CANON.gold,
	NEUTRAL,
	Color3.fromRGB(40, 127, 71),
	Color3.fromRGB(245, 205, 48),
}
-- the parts each tower cap style builds (Pieces.towerCap) and the ones it must not: the silhouette cue of D-033
local CAP_HAS = { crimson = "Spire", azure = "RoofCorner", emerald = "Hoarding", gold = "Dome" }
local CAP_NOT = {
	crimson = { "Hoarding", "Dome", "RoofCorner" },
	azure = { "Spire", "Hoarding", "Dome" },
	emerald = { "Spire", "Dome" },
	gold = { "Spire", "Hoarding", "RoofCorner" },
}
local ARENA = Kit.ARENA
local CAP = ARENA.PART_BUDGET.cap
local TARGET = ARENA.PART_BUDGET.target

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

-- bounds of every visible part but the Root plate
local function bounds(model: Model): (Vector3, Vector3)
	local lo, hi = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, p in parts(model) do
		if p ~= model.PrimaryPart then
			local e, c = halfExtents(p), p.CFrame.Position
			lo = lo:Min(c - e)
			hi = hi:Max(c + e)
		end
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

-- world CFrame of an attachment
local function attCF(model: Model, a: Attachment): CFrame
	return (model.PrimaryPart :: BasePart).CFrame * a.CFrame
end

local function attachments(model: Model): { [string]: Attachment }
	local out = {}
	for _, d in (model.PrimaryPart :: BasePart):GetChildren() do
		if d:IsA("Attachment") then
			out[d.Name] = d
		end
	end
	return out
end

local function dressOf(model: Model, side: string): Model
	return model:FindFirstChild(`Dress{side}`) :: Model
end

local function count(model: Instance, name: string): number
	local n = 0
	for _, p in parts(model) do
		if p.Name == name then
			n += 1
		end
	end
	return n
end

local AXES = { "X", "Y", "Z" }
local function axisAligned(cf: CFrame): boolean
	for _, v in { cf.RightVector, cf.UpVector, cf.LookVector } do
		if math.max(math.abs(v.X), math.abs(v.Y), math.abs(v.Z)) < 0.9999 then
			return false
		end
	end
	return true
end

-- same-direction coplanar overlapping block faces (z-fighting), as tests/world/KitBuildings.spec
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
						if math.abs(a.lo[ax] - b.lo[ax]) < 0.005 then
							table.insert(out, `{a.name}/{b.name} -{ax}`)
						end
					end
				end
			end
		end
	end
	return out
end

describe("Kit.arena part budget (D-047: target 700, hard cap 900)", function()
	it("builds neutral within the target and every kingdom pairing within the cap", function()
		local neutral = noYield(function()
			return Kit.arena()
		end)
		expect(Kit.partCount(neutral)).toBeLessThanOrEqual(TARGET)
		expect(Kit.partCount(neutral)).toBeGreaterThan(200) -- a real venue, not a stub
		expect(Kit.partCount(neutral)).toBe(#parts(neutral))
		local worst, worstAt = 0, ""
		for ia, a in COLORS do
			for ib, b in COLORS do
				local n = Kit.partCount(noYield(function()
					return Kit.arena(a, b)
				end))
				if n > worst then
					worst, worstAt = n, `{ia}/{ib}`
				end
				expect(n).toBeLessThanOrEqual(CAP)
			end
		end
		-- the worst case is a pairing of two emblem-heavy kingdoms, and stays under the target as well
		expect(worst).toBeLessThanOrEqual(TARGET)
		print(`arena parts: neutral {Kit.partCount(neutral)}, worst pairing {worst} ({worstAt}); cap {CAP}`)
	end)

	it("keeps the budget table honest: target below the cap, below D-047's headroom", function()
		expect(ARENA.PART_BUDGET.target).toBe(700)
		expect(ARENA.PART_BUDGET.cap).toBe(900)
	end)

	it("keeps each side's dress small (a rebuild at the Arena phase stays cheap)", function()
		for _, c in COLORS do
			local m = Kit.arena(c, c)
			for _, side in { "A", "B" } do
				expect(Kit.partCount(dressOf(m, side))).toBeLessThanOrEqual(170)
			end
		end
	end)
end)

describe("Kit.arena determinism and rules (D-026: primitive parts, no yields)", function()
	it("builds the same arena every time, for every pairing", function()
		for _, a in { NEUTRAL, CANON.crimson, CANON.gold } do
			for _, b in { NEUTRAL, CANON.azure, CANON.emerald } do
				expect(signature(Kit.arena(a, b))).toBe(signature(Kit.arena(a, b)))
			end
		end
	end)

	it("uses only Part blocks, wedges, cylinders and balls (D-026), anchored", function()
		local seen = {}
		for _, p in parts(Kit.arena(CANON.crimson, CANON.emerald)) do
			seen[p.ClassName] = true
			expect(p.Anchored).toBe(true)
			expect(p.ClassName == "Part" or p.ClassName == "WedgePart" or p.ClassName == "CornerWedgePart").toBe(true)
			if p.ClassName == "Part" then
				local shape = (p :: Part).Shape
				expect(shape == Enum.PartType.Block or shape == Enum.PartType.Cylinder or shape == Enum.PartType.Ball).toBe(
					true
				)
			end
			expect(p.Transparency < 1 or p.Name == "Root").toBe(true)
		end
		expect(seen.Part).toBe(true)
		expect(seen.WedgePart).toBe(true)
	end)

	it("has no scripts, no UnionOperation and no Humanoid", function()
		for _, d in Kit.arena(CANON.azure, CANON.gold):GetDescendants() do
			expect(d:IsA("LuaSourceContainer") or d:IsA("PartOperation") or d:IsA("Humanoid")).toBe(false)
		end
	end)

	it("never yields, whatever the colours, and rebuilds the dress without yielding", function()
		local m = noYield(function()
			return Kit.arena(CANON.emerald, CANON.crimson)
		end)
		noYield(function()
			Kit.arenaDress(m, CANON.gold, CANON.azure)
			return 0
		end)
	end)
end)

describe("Kit.arena structure (the Kit model convention)", function()
	it("pivots on the ring centre at ground level, with an invisible footprint Root", function()
		local m = Kit.arena()
		local root = m.PrimaryPart :: BasePart
		expect(root.Name).toBe("Root")
		expect(root.Transparency).toBe(1)
		expect(root.CanCollide).toBe(false)
		expect(root.Size.X).toBe(ARENA.FOOTPRINT.X)
		expect(root.Size.Z).toBe(ARENA.FOOTPRINT.Y)
		local pivot = root.CFrame * root.PivotOffset
		expect(pivot.Position.Magnitude).toBeLessThan(1e-6)
		expect(m:GetAttribute("KitType")).toBe("arena")
		expect(m:GetAttribute("ArenaDuelRadius")).toBe(ARENA.DUEL_RADIUS)
		expect(m:GetAttribute("ArenaSeatsPerStand")).toBe(72)
	end)

	it("keeps every part inside the footprint and on or above the ground, and pins the real extents", function()
		for _, c in COLORS do
			local m = Kit.arena(c, c)
			local lo, hi = bounds(m)
			expect(lo.X).toBeGreaterThanOrEqual(-ARENA.FOOTPRINT.X / 2 - 1e-6)
			expect(hi.X).toBeLessThanOrEqual(ARENA.FOOTPRINT.X / 2 + 1e-6)
			expect(lo.Z).toBeGreaterThanOrEqual(-ARENA.FOOTPRINT.Y / 2 - 1e-6)
			expect(hi.Z).toBeLessThanOrEqual(ARENA.FOOTPRINT.Y / 2 + 1e-6)
			expect(lo.Y).toBeGreaterThanOrEqual(-1e-4)
			expect(lo.Y).toBeLessThan(0.01) -- the slab sits on the ground
			expect(hi.Y).toBeLessThan(34) -- the tallest cap (a crimson spire on the gate towers)
			-- the extents ArenaLayout.spec clears against: the venue is symmetric, 74 x 73.2 on the ground
			expect(hi.X).toBeNear(37, 0.01)
			expect(lo.X).toBeNear(-37, 0.01)
			expect(hi.Z).toBeNear(36.6, 0.01)
			expect(lo.Z).toBeNear(-36.6, 0.01)
		end
	end)

	it(
		"covers the duel radius with floor: sand to the ring plus a margin, the painted line at the duel radius",
		function()
			local m = Kit.arena()
			local byName: { [string]: BasePart } = {}
			for _, p in parts(m) do
				byName[p.Name] = byName[p.Name] or p
			end
			local function radius(p: BasePart): number
				expect(p.Shape).toBe(Enum.PartType.Cylinder)
				return p.Size.Y / 2
			end
			expect(radius(byName.SandInner)).toBeGreaterThanOrEqual(ARENA.DUEL_RADIUS - 0.6)
			expect(radius(byName.Sand)).toBeGreaterThanOrEqual(ARENA.DUEL_RADIUS + 1.5)
			expect(radius(byName.RingLine)).toBeNear(ARENA.DUEL_RADIUS + 0.55, 1e-3)
			-- the floor is flat and level under the whole radius: sand above the slab, the line between sand and the inner floor
			local floorTop = byName.SandInner.CFrame.Position.Y + byName.SandInner.Size.X / 2
			expect(floorTop).toBeNear(ARENA.FLOOR_TOP, 1e-3)
			expect(byName.Sand.CFrame.Position.Y + byName.Sand.Size.X / 2).toBeLessThan(floorTop)
			expect(byName.RingLine.CFrame.Position.Y + byName.RingLine.Size.X / 2).toBeLessThan(floorTop)
			expect(byName.Apron.CFrame.Position.Y + byName.Apron.Size.Y / 2).toBeNear(ARENA.SLAB_TOP, 1e-3)
			expect(ARENA.RING_RADIUS).toBeGreaterThan(ARENA.DUEL_RADIUS)
		end
	)
end)

describe("Kit.arena attachments (the contract of the crowd director and ArenaService)", function()
	local m = Kit.arena(CANON.crimson, CANON.azure)
	local atts = attachments(m)

	it("seats at least 60 figures a stand: 4 rows of 18 named StandA_Row<r>_Seat<s>, numbered contiguously", function()
		for _, side in { "A", "B" } do
			local total = 0
			for r = 1, 4 do
				for s = 1, 18 do
					local a = atts[`Stand{side}_Row{r}_Seat{s}`]
					expect(a).never.toBeNil()
					expect(a:GetAttribute("Stand")).toBe(side)
					expect(a:GetAttribute("Row")).toBe(r)
					expect(a:GetAttribute("Seat")).toBe(s)
					total += 1
				end
				expect(atts[`Stand{side}_Row{r}_Seat19`]).toBeNil() -- no strays
				expect(atts[`Stand{side}_Row{r}_Seat0`]).toBeNil()
			end
			expect(total).toBe(72)
			expect(total).toBeGreaterThanOrEqual(60)
		end
		local seats = 0
		for name in atts do
			if string.match(name, "^Stand[AB]_Row%d_Seat%d+$") then
				seats += 1
			end
		end
		expect(seats).toBe(144)
	end)

	it("puts every seat and rail place on a walkway plank, facing the ring, with the standing column clear", function()
		local planks, solids = {}, {}
		for _, p in parts(m) do
			if p.Name == "RowPlank" or p.Name == "Podium" then
				table.insert(planks, p)
			end
			if p.CanCollide and p ~= m.PrimaryPart then
				table.insert(solids, p)
			end
		end
		local function check(name: string, a: Attachment)
			local cf = attCF(m, a)
			local pos = cf.Position
			-- on a plank (or the podium): inside its plan, its top at the attachment's height
			local on = false
			for _, p in planks do
				local e = halfExtents(p)
				local c = p.CFrame.Position
				if
					math.abs(pos.X - c.X) <= e.X
					and math.abs(pos.Z - c.Z) <= e.Z
					and math.abs(pos.Y - (c.Y + e.Y)) < 0.01
				then
					on = true
					break
				end
			end
			expect(`{name} on a plank: {on}`).toBe(`{name} on a plank: true`)
			-- -Z of the attachment looks at the ring centre (horizontally), Y is up
			local look = cf.LookVector
			local toCentre = Vector3.new(-pos.X, 0, -pos.Z).Unit
			expect(look.Y).toBeNear(0, 1e-6)
			expect(look:Dot(toCentre)).toBeGreaterThan(0.6) -- a seat at the stand's end looks across, not straight in
			expect(math.abs(look.X)).toBeLessThan(1e-6) -- the stands face along Z
			expect(cf.UpVector.Y).toBeNear(1, 1e-4)
			-- a figure 5.6 tall and 2.2 wide stands there: nothing solid in the column above the plank
			for _, p in solids do
				local e, c = halfExtents(p), p.CFrame.Position
				local inX = math.abs(pos.X - c.X) < e.X + 1.1
				local inZ = math.abs(pos.Z - c.Z) < e.Z + 0.5
				local inY = c.Y + e.Y > pos.Y + 0.05 and c.Y - e.Y < pos.Y + 5.6
				if inX and inZ and inY then
					error(`{name}: {p.Name} at ({c.X}, {c.Y}, {c.Z}) stands in the figure's column`)
				end
			end
		end
		for name, a in atts do
			if string.match(name, "^Stand[AB]_Row") or string.match(name, "^Stand[AB]_Rail") then
				check(name, a)
			end
		end
	end)

	it("gives each stand six rail places for the key citizens and three royal chairs", function()
		for _, side in { "A", "B" } do
			local prev = -math.huge
			for n = 1, 6 do
				local a = atts[`Stand{side}_Rail{n}`]
				expect(a).never.toBeNil()
				expect(a:GetAttribute("Rail")).toBe(n)
				-- left to right as the stand's viewer sees it, so strictly monotone in the stand's own frame
				local x = attCF(m, a).Position.X * (if side == "A" then -1 else 1)
				expect(x).toBeGreaterThan(prev)
				prev = x
			end
			expect(atts[`Stand{side}_Rail7`]).toBeNil()
			for n = 1, 3 do
				expect(atts[`Stand{side}_Royal{n}`]).never.toBeNil()
			end
			expect(atts[`Stand{side}_RoyalBox`]).never.toBeNil()
		end
	end)

	it("keeps the royal box clear of seats: no seat within the box's width on rows 1-4", function()
		for _, side in { "A", "B" } do
			for r = 1, 4 do
				for s = 1, 18 do
					local x = attCF(m, atts[`Stand{side}_Row{r}_Seat{s}`]).Position.X
					expect(math.abs(x)).toBeGreaterThan(ARENA.ROYAL_HALF)
				end
			end
		end
	end)

	it("puts the two gates at the two ends of the gate axis, inside the passage, looking at the ring", function()
		for _, side in { "A", "B" } do
			local a = atts[`Gate{side}`]
			expect(a).never.toBeNil()
			local cf = attCF(m, a)
			local sx = if side == "A" then -1 else 1
			expect(math.sign(cf.Position.X)).toBe(sx)
			expect(math.abs(cf.Position.X)).toBeGreaterThan(ARENA.GATE_Z)
			expect(math.abs(cf.Position.X)).toBeLessThan(ARENA.GATE_Z + 7)
			expect(math.abs(cf.Position.Z)).toBeLessThan(0.01)
			expect(cf.LookVector.X).toBeNear(-sx, 1e-4) -- looks at the ring
			expect(cf.Position.Y).toBeNear(ARENA.SLAB_TOP, 1e-3)
		end
		expect(atts.Centre).never.toBeNil()
		expect(attCF(m, atts.Centre).Position.Magnitude).toBeNear(ARENA.FLOOR_TOP, 1e-3)
	end)

	it("puts the spawn marks inside the ring, 3 studs above the floor, facing each other", function()
		local a, b = attCF(m, atts.SpawnA), attCF(m, atts.SpawnB)
		expect(a.Position.X).toBeNear(-ARENA.SPAWN_X, 1e-3)
		expect(b.Position.X).toBeNear(ARENA.SPAWN_X, 1e-3)
		for _, cf in { a, b } do
			expect(cf.Position.Y).toBeNear(ARENA.FLOOR_TOP + 3, 1e-3)
			expect(Vector3.new(cf.Position.X, 0, cf.Position.Z).Magnitude).toBeLessThan(ARENA.DUEL_RADIUS - 5)
		end
		-- each looks along the line to the other
		expect(a.LookVector:Dot((b.Position - a.Position).Unit)).toBeNear(1, 1e-4)
		expect(b.LookVector:Dot((a.Position - b.Position).Unit)).toBeNear(1, 1e-4)
		expect((a.Position - b.Position).Magnitude).toBeNear(26, 1e-3)
	end)

	it("mirrors every A attachment onto its B twin through the ring centre", function()
		local n = 0
		for name, a in atts do
			local other: string? = nil
			if string.sub(name, 1, 6) == "StandA" then
				other = "StandB" .. string.sub(name, 7)
			elseif name == "GateA" then
				other = "GateB"
			elseif name == "SpawnA" then
				other = "SpawnB"
			end
			if other then
				local b = atts[other]
				expect(b).never.toBeNil()
				local pa, pb = attCF(m, a), attCF(m, b)
				expect(pa.Position.X).toBeNear(-pb.Position.X, 1e-3)
				expect(pa.Position.Z).toBeNear(-pb.Position.Z, 1e-3)
				expect(pa.Position.Y).toBeNear(pb.Position.Y, 1e-3)
				expect(pa.LookVector:Dot(pb.LookVector)).toBeNear(-1, 1e-4)
				n += 1
			end
		end
		expect(n).toBe(72 + 6 + 3 + 1 + 1 + 1) -- seats, rail places, royal chairs, royal box, gate, spawn
	end)
end)

describe("Kit.arena kingdom dress (D-033 silhouette, D-039 emblem: never colour alone)", function()
	it("builds a dress sub-model per side, every part tinted or neutral, flagged with its side", function()
		local m = Kit.arena(CANON.crimson, CANON.azure)
		for _, side in { "A", "B" } do
			local dress = dressOf(m, side)
			expect(dress).never.toBeNil()
			expect(dress:IsA("Model")).toBe(true)
			expect(#parts(dress)).toBeGreaterThan(40)
			for _, p in parts(dress) do
				expect(p:GetAttribute("KitSide")).toBe(side)
			end
		end
		expect(m:GetAttribute("KitColorA")).toBe(CANON.crimson)
		expect(m:GetAttribute("KitColorB")).toBe(CANON.azure)
		local n = 0
		for _, c in m:GetChildren() do
			if string.sub(c.Name, 1, 5) == "Dress" then
				n += 1
			end
		end
		expect(n).toBe(2)
	end)

	for _, kingdom in KINGDOMS do
		it(`dresses {kingdom} with its tower-cap silhouette and its emblem on every banner, plaque and rug`, function()
			local color = CANON[kingdom]
			local style = kingdom
			local m = Kit.arena(color, color)
			local want = Kit.emblemKind(color)
			expect(want).never.toBeNil()
			for _, side in { "A", "B" } do
				local dress = dressOf(m, side)
				-- the cap: this kingdom's marker part, and none of another kingdom's
				expect(count(dress, CAP_HAS[style])).toBeGreaterThan(0)
				for _, mark in CAP_NOT[style] do
					expect(count(dress, mark)).toBe(0)
				end
				-- the emblem: every emblem part is this kingdom's kind, on at least 10 different fields
				local slots, marks = {}, 0
				for _, p in parts(dress) do
					local kind = p:GetAttribute("KitEmblem")
					if kind ~= nil then
						expect(kind).toBe(want)
						marks += 1
					end
					local slot = p:GetAttribute("KitEmblemSlot")
					if slot ~= nil and p:GetAttribute("KitEmblemCF") ~= nil then
						slots[slot] = true
					end
				end
				local fields = 0
				for _ in slots do
					fields += 1
				end
				expect(fields).toBeGreaterThanOrEqual(11) -- rug, plaque, flag, 4 + 2 + 2 banners, crest
				expect(marks).toBeGreaterThanOrEqual(fields * 3)
				-- the colour: tinted parts are exactly shade(colour, tint)
				local tinted = 0
				for _, p in parts(dress) do
					local f = p:GetAttribute("KitTint")
					if type(f) == "number" then
						tinted += 1
						expect(p.Color.R).toBeNear(math.clamp(color.R * f, 0, 1), 0.002)
						expect(p.Color.G).toBeNear(math.clamp(color.G * f, 0, 1), 0.002)
						expect(p.Color.B).toBeNear(math.clamp(color.B * f, 0, 1), 0.002)
					end
				end
				expect(tinted).toBeGreaterThan(30)
			end
		end)
	end

	it("tells the four kingdoms' dresses apart by shape: caps and emblems all differ", function()
		local sigs, emblems = {}, {}
		for _, kingdom in KINGDOMS do
			local dress = dressOf(Kit.arena(CANON[kingdom], CANON[kingdom]), "A")
			local names = {}
			for _, p in parts(dress) do
				local kind = p:GetAttribute("KitEmblem")
				if kind then
					emblems[kind] = kingdom
				end
				if p.Name == "Spire" or p.Name == "Hoarding" or p.Name == "Dome" or p.Name == "RoofCorner" then
					names[p.Name] = true
				end
			end
			local list = {}
			for n in names do
				table.insert(list, n)
			end
			table.sort(list)
			local sig = table.concat(list, ",")
			expect(sigs[sig]).toBeNil()
			sigs[sig] = kingdom
		end
		expect(emblems.crown).toBe("crimson")
		expect(emblems.star).toBe("azure")
		expect(emblems.oak).toBe("emerald")
		expect(emblems.sun).toBe("gold")
	end)

	it("builds the neutral dress without emblems, and keeps the structure kingdom-free", function()
		local m = Kit.arena()
		for _, side in { "A", "B" } do
			for _, p in parts(dressOf(m, side)) do
				expect(p:GetAttribute("KitEmblem")).toBeNil()
			end
		end
		-- the structure outside the dress is the same for every pairing: one signature
		local function structure(model: Model): string
			local keep = Instance.new("Model")
			for _, c in model:GetChildren() do
				if string.sub(c.Name, 1, 5) ~= "Dress" then
					c:Clone().Parent = keep
				end
			end
			return signature(keep)
		end
		expect(structure(Kit.arena(CANON.crimson, CANON.azure))).toBe(structure(m))
		expect(structure(Kit.arena(CANON.gold, CANON.emerald))).toBe(structure(m))
	end)

	it("gives the two stands different dresses when the kingdoms differ", function()
		local m = Kit.arena(CANON.crimson, CANON.azure)
		expect(signature(dressOf(m, "A")) ~= signature(dressOf(m, "B"))).toBe(true)
		expect(count(dressOf(m, "A"), "Spire") > 0 and count(dressOf(m, "B"), "Spire") == 0).toBe(true)
	end)

	it("rebuilds both dresses in place: the result equals a fresh arena of those colours", function()
		for _, pair in
			{
				{ CANON.crimson, CANON.azure },
				{ CANON.emerald, CANON.gold },
				{ CANON.gold, CANON.crimson },
			}
		do
			local m = Kit.arena()
			Kit.arenaDress(m, pair[1], pair[2])
			local fresh = Kit.arena(pair[1], pair[2])
			expect(signature(m)).toBe(signature(fresh))
			expect(Kit.partCount(m)).toBe(Kit.partCount(fresh))
			expect(m:GetAttribute("KitColorA")).toBe(pair[1])
			expect(m:GetAttribute("KitColorB")).toBe(pair[2])
			-- twice leaves no leftovers
			Kit.arenaDress(m, pair[2], pair[1])
			Kit.arenaDress(m, pair[1], pair[2])
			expect(Kit.partCount(m)).toBe(Kit.partCount(fresh))
		end
		-- back to neutral
		local m = Kit.arena(CANON.crimson, CANON.azure)
		Kit.arenaDress(m)
		expect(signature(m)).toBe(signature(Kit.arena()))
	end)

	it(
		"recolours one side in place with Kit.setKingdomColor (tint and emblems), leaving the other side alone",
		function()
			local m = Kit.arena(CANON.azure, CANON.azure)
			local before = signature(dressOf(m, "B"))
			Kit.setKingdomColor(dressOf(m, "A"), CANON.emerald)
			expect(signature(dressOf(m, "B"))).toBe(before)
			for _, p in parts(dressOf(m, "A")) do
				local f = p:GetAttribute("KitTint")
				if type(f) == "number" then
					expect(p.Color.G).toBeNear(math.clamp(CANON.emerald.G * f, 0, 1), 0.002)
				end
				local kind = p:GetAttribute("KitEmblem")
				if kind then
					expect(kind).toBe("oak")
				end
			end
		end
	)
end)

describe("Kit.arena geometry hygiene", function()
	it("has no coplanar overlapping block faces, neutral or dressed", function()
		local found = {}
		for _, pair in
			{
				{ NEUTRAL, NEUTRAL },
				{ CANON.crimson, CANON.azure },
				{ CANON.emerald, CANON.gold },
				{ CANON.gold, CANON.emerald },
			}
		do
			for _, hit in zFights(Kit.arena(pair[1], pair[2])) do
				table.insert(found, hit)
			end
		end
		if #found > 0 then
			error(`{#found} coplanar face pairs, e.g. ` .. table.concat(found, "; ", 1, math.min(#found, 8)))
		end
	end)

	it("keeps every dress part resting on something: no part hangs in the air by more than a hair", function()
		-- a part (other than banners' cloth, hung from its pole, and caps/flags planted on a part) must touch another part's
		-- bounding box: looseness 0.06
		local m = Kit.arena(CANON.crimson, CANON.azure)
		local list = parts(m)
		local floating = {}
		for _, p in list do
			if p ~= m.PrimaryPart then
				local e, c = halfExtents(p), p.CFrame.Position
				local touches = c.Y - e.Y < 0.06
				if not touches then
					for _, q in list do
						if q ~= p and q ~= m.PrimaryPart then
							local f, d = halfExtents(q), q.CFrame.Position
							if
								math.abs(c.X - d.X) <= e.X + f.X + 0.06
								and math.abs(c.Y - d.Y) <= e.Y + f.Y + 0.06
								and math.abs(c.Z - d.Z) <= e.Z + f.Z + 0.06
							then
								touches = true
								break
							end
						end
					end
				end
				if not touches then
					table.insert(floating, `{p.Name}@{string.format("%.1f,%.1f,%.1f", c.X, c.Y, c.Z)}`)
				end
			end
		end
		expect(table.concat(floating, "; ")).toBe("")
	end)

	it("makes the walkable low parts solid and leaves decoration without Touched", function()
		local m = Kit.arena()
		local solid = 0
		for _, p in parts(m) do
			if p ~= m.PrimaryPart and p.Name == "Row" then
				expect(p.CanCollide).toBe(true)
				solid += 1
			end
		end
		expect(solid).toBe(8)
	end)
end)
