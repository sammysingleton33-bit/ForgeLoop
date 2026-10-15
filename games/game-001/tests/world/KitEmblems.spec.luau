--[[
	Kingdom emblems (FORGE-02 Kit; D-033 (3), D-039; FORGE-05 colour-vision finding 3).
	- Kit.emblemKind maps a colour to its emblem with the tower-cap hue map: crimson crown, azure star,
	  emerald oak leaf, gold sun, neutral none.
	- Every banner, flag, pennant, shield, keep plaque, prop banner and slot sign (the emblem "fields") carries
	  the colour's emblem; neutral models carry none but keep the slots.
	- Emblem parts are anchored decoration (no collide / touch / query), sit in front of their field inside the
	  emblem box, and differ from the field by ΔL* ≥ 25 (ivory crown, star and oak; the sun deep gold on gold).
	- The keep carries two large aerial plaques for the overview camera (G13.6): one on the roof facing up,
	  one on the donjon's back; nothing covers either.
	- B12: every house variant flies an emblem pennant at both levels; the throne back carries the emblem; the
	  aerial plaques' oak is the full 8-part lobed leaf; and the throne's marker (the royal standard pair and the
	  baldachin) stays in view of the overview camera from behind the keep.
	- Kit.setKingdomColor re-forms emblems to the new colour's kind on the same anchors (also after the model
	  moved), removes them for neutral, adds them to a neutral model, and leaves every other part in place.
]]

local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local Kit = require("@game/ReplicatedStorage/Game/Kit/Kit")
local Buildings = require("@game/ReplicatedStorage/Game/Kit/Buildings")
local KingdomsConfig = require("@game/ReplicatedStorage/Forge/Config/Kingdoms")

local CANON: { [string]: Color3 } = {}
for _, identity in KingdomsConfig.identities do
	local c = identity.color
	CANON[identity.id] = Color3.fromRGB(c[1], c[2], c[3])
end
local KINDS = { crimson = "crown", azure = "star", emerald = "oak", gold = "sun" }
-- { colour, expected kind }: the four canonical colours, neutral, and off-palette tints of each hue style
-- (pre-D-033 values and the KitBuildings SAME_STYLE set): any kingdom colour gets its style's emblem
local CASES: { { any } } = {
	{ CANON.crimson, "crown" },
	{ CANON.azure, "star" },
	{ CANON.emerald, "oak" },
	{ CANON.gold, "sun" },
	{ Kit.NEUTRAL_COLOR, nil },
	{ Color3.fromRGB(170, 30, 50), "crown" },
	{ Color3.fromRGB(40, 80, 200), "star" },
	{ Color3.fromRGB(40, 127, 71), "oak" },
	{ Color3.fromRGB(245, 205, 48), "sun" },
	{ Color3.fromRGB(190, 190, 190), nil },
}
local MAX_LEVEL = { keep = 3, barracks = 4 }
local FIELD_NAMES = {
	Banner = true,
	Flag = true,
	Pennant = true,
	Crest = true,
	EmblemPlaque = true,
	SignBoard = true,
	ThroneBack = true,
}
local MIN_DL = 0.25 -- CIE L* / 100 between an emblem's silhouette and its field

local function parts(model: Instance): { BasePart }
	local out = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(out, d)
		end
	end
	return out
end

-- CIE L* (0..1) of an sRGB colour
local function lstar(c: Color3): number
	local function lin(v: number): number
		return if v <= 0.04045 then v / 12.92 else ((v + 0.055) / 1.055) ^ 2.4
	end
	local y = 0.2126 * lin(c.R) + 0.7152 * lin(c.G) + 0.0722 * lin(c.B)
	return (if y > 0.008856 then 116 * y ^ (1 / 3) - 16 else 903.3 * y) / 100
end

type Slot = { field: BasePart?, marks: { BasePart } }

local function slotsOf(model: Instance): { [number]: Slot }
	local out: { [number]: Slot } = {}
	for _, p in parts(model) do
		local id = p:GetAttribute("KitEmblemSlot")
		if type(id) == "number" then
			local s = out[id] or { field = nil, marks = {} }
			out[id] = s
			if p:GetAttribute("KitEmblem") ~= nil then
				table.insert(s.marks, p)
			elseif p:GetAttribute("KitEmblemCF") ~= nil then
				s.field = p
			end
		end
	end
	return out
end

local function anchorOf(field: BasePart): CFrame
	return field.CFrame * (field:GetAttribute("KitEmblemCF") :: CFrame)
end

-- emblem parts relative to their anchor: { kind, class, 12 CFrame components, 3 size components }
local function localRows(slot: Slot): { { any } }
	local anchor = anchorOf(slot.field :: BasePart)
	local rows = {}
	for _, p in slot.marks do
		local comps = { anchor:ToObjectSpace(p.CFrame):GetComponents() }
		table.insert(comps, p.Size.X)
		table.insert(comps, p.Size.Y)
		table.insert(comps, p.Size.Z)
		table.insert(rows, { p:GetAttribute("KitEmblem"), p.ClassName, comps })
	end
	return rows
end

-- the same emblem on the same anchor: every part matches one part of the other within 1e-3
local function sameEmblem(a: Slot, b: Slot): boolean
	local ra, rb = localRows(a), localRows(b)
	if #ra ~= #rb then
		return false
	end
	local used = {}
	for _, x in ra do
		local found = false
		for j, y in rb do
			if not used[j] and x[1] == y[1] and x[2] == y[2] then
				local close = true
				for k, v in x[3] do
					if math.abs(v - y[3][k]) > 1e-3 then
						close = false
						break
					end
				end
				if close then
					used[j], found = true, true
					break
				end
			end
		end
		if not found then
			return false
		end
	end
	return true
end

local function eachBuilding(fn: (label: string, model: Model, kind: string?) -> ())
	for _, bt in Kit.BUILDING_TYPES do
		for level = 1, MAX_LEVEL[bt] or 2 do
			for v = 1, (if bt == "house" then 8 else 1) do
				for _, case in CASES do
					fn(`{bt} L{level} v{v}`, Buildings.build(bt, level, "complete", case[1], v), case[2])
				end
			end
			for stage = 1, 3 do
				for _, case in CASES do
					fn(`{bt} L{level} stage {stage}`, Buildings.build(bt, level, stage, case[1]), case[2])
				end
			end
		end
	end
end

local POLY = { Vector2.new(0, 0), Vector2.new(60, 0), Vector2.new(60, 60), Vector2.new(0, 60) }
local BANNER_ASSET = { crimson = "red", azure = "blue", emerald = "green", gold = "yellow" }

-- the non-building models that carry emblems, for a colour
local function props(color: Color3): { [string]: Model }
	return {
		slotMarker = Kit.slotMarker(Vector2.new(24, 20), color),
		regionMarkers = Kit.regionMarkers(POLY, color),
	}
end

-- every field has its emblem of the expected kind (or none for neutral); returns the number of slots.
-- A slot marker's 0.9-stud stake pennants are exempt: the marker's emblem is on its sign tablet.
local function checkKinds(label: string, model: Instance, kind: string?): number
	local n = 0
	for id, slot in slotsOf(model) do
		n += 1
		if slot.field == nil then
			error(`{label}: emblem slot {id} has no field`)
		end
		if kind == nil then
			if #slot.marks > 0 then
				error(`{label}: neutral model carries a {slot.marks[1]:GetAttribute("KitEmblem")} emblem`)
			end
		else
			if #slot.marks < 3 then
				error(`{label}: slot {id} on {(slot.field :: BasePart).Name} has {#slot.marks} emblem parts`)
			end
			for _, p in slot.marks do
				if p:GetAttribute("KitEmblem") ~= kind then
					error(`{label}: {p.Name} is a {p:GetAttribute("KitEmblem")}, want {kind}`)
				end
			end
		end
	end
	-- no banner, flag, pennant, shield, plaque or sign without an emblem slot
	local stakes = model.Name == "BuildSlot"
	for _, p in parts(model) do
		if FIELD_NAMES[p.Name] and p:GetAttribute("KitEmblemCF") == nil and not (stakes and p.Name == "Pennant") then
			error(`{label}: {p.Name} carries no emblem slot`)
		end
	end
	return n
end

describe("Kit.emblemKind (D-039)", function()
	it("maps every kingdom colour to its emblem with the tower-cap hue map, neutral to none", function()
		for _, case in CASES do
			expect(Kit.emblemKind(case[1])).toBe(case[2])
		end
		for style, kind in KINDS do
			expect(Kit.EMBLEM_KINDS[style]).toBe(kind)
			expect(Kit.emblemKind(CANON[style])).toBe(kind)
			expect(Kit._hueStyle(CANON[style])).toBe(style) -- emblem and silhouette from one map
		end
	end)
end)

describe("Kingdom emblems on every banner, flag, pennant and shield", function()
	it("gives each colour its emblem on every building, level, house variant and stage; neutral none", function()
		local withSlots = {}
		eachBuilding(function(label, model, kind)
			if checkKinds(label, model, kind) > 0 then
				withSlots[string.match(label, "^%a+") :: string] = true
			end
		end)
		-- every type flies at least one emblem-bearing banner, flag, pennant or shield
		for _, bt in Kit.BUILDING_TYPES do
			if not withSlots[bt] then
				error(`{bt}: no emblem anywhere`)
			end
		end
	end)

	it("flies an emblem pennant on every house variant at both levels (B12: identity was colour-only)", function()
		for level = 1, 2 do
			for v = 1, 8 do
				for _, case in CASES do
					local m = Buildings.build("house", level, "complete", case[1], v)
					local pennants = 0
					for _, slot in slotsOf(m) do
						if (slot.field :: BasePart).Name == "Pennant" then
							pennants += 1
						end
					end
					if pennants ~= 1 then
						error(`house L{level} v{v}: {pennants} emblem pennants (want 1)`)
					end
					checkKinds(`house L{level} v{v}`, m, case[2])
				end
			end
		end
	end)

	it("puts the right emblem on prop banners, slot signs and region-marker flags", function()
		for _, case in CASES do
			for name, model in props(case[1]) do
				expect(checkKinds(name, model, case[2])).toBeGreaterThan(0)
			end
		end
		for id, asset in BANNER_ASSET do
			local model = Kit.prop(`prop_banner_{asset}_01`)
			expect(checkKinds(asset, model, KINDS[id])).toBe(1)
		end
		-- one emblem per region-marker flag
		local m = Kit.regionMarkers(POLY, CANON.azure)
		local flags = 0
		for _, p in parts(m) do
			flags += if p.Name == "Flag" then 1 else 0
		end
		expect(checkKinds("regionMarkers", m, "star")).toBe(flags)
	end)

	it("builds emblems from anchored, non-colliding primitive parts in front of their field", function()
		local function check(label: string, model: Instance)
			for _, slot in slotsOf(model) do
				local field = slot.field :: BasePart
				local anchor = anchorOf(field)
				local half = (field:GetAttribute("KitEmblemSize") :: number) / 2
				for _, p in slot.marks do
					expect(p.ClassName == "Part" or p.ClassName == "WedgePart").toBe(true)
					expect(p.Anchored).toBe(true)
					if p.CanCollide or p.CanTouch or p.CanQuery then
						error(`{label}: emblem part {p.Name} collides, touches or is queryable`)
					end
					local q = anchor:PointToObjectSpace(p.CFrame.Position)
					-- in front of the field face (never coplanar with it) and inside the emblem box
					if q.Z > -0.05 or math.abs(q.X) > half + 0.01 or math.abs(q.Y) > half + 0.01 then
						error(`{label}: emblem part {p.Name} at {q} is off its field (box ±{half})`)
					end
				end
			end
		end
		for _, case in CASES do
			for _, bt in { "keep", "barracks", "watchtower", "gate", "farm", "shrine" } do
				local level = MAX_LEVEL[bt] or 2
				check(`{bt} L{level}`, Buildings.build(bt, level, "complete", case[1]))
			end
			check("house v2", Buildings.build("house", 1, "complete", case[1], 2))
			for name, model in props(case[1]) do
				check(name, model)
			end
		end
	end)

	it("makes every emblem differ from its field by ΔL* ≥ 25: ivory crown, star and oak; deep-gold sun", function()
		local worst = {}
		local function check(label: string, model: Instance)
			for _, slot in slotsOf(model) do
				local field = slot.field :: BasePart
				local lf = lstar(field.Color)
				for _, p in slot.marks do
					if p:GetAttribute("KitEmblemAccent") ~= true then
						local kind = p:GetAttribute("KitEmblem") :: string
						-- crown, star and oak are lighter than the field; the sun is darker than its light gold
						local dl = if kind == "sun" then lf - lstar(p.Color) else lstar(p.Color) - lf
						worst[kind] = math.min(worst[kind] or math.huge, dl)
						if dl < MIN_DL then
							error(`{label}: {kind} {p.Name} ΔL* {math.floor(dl * 100)} on {field.Name} (< 25)`)
						end
					end
				end
			end
		end
		for _, case in CASES do
			eachBuilding(function(label, model, _kind)
				if string.find(label, "stage") == nil and string.find(label, "v[2-8]") == nil then
					check(label, model)
				end
			end)
			for name, model in props(case[1]) do
				check(name, model)
			end
		end
		for _, asset in BANNER_ASSET do
			check(asset, Kit.prop(`prop_banner_{asset}_01`))
		end
		local report = {}
		for kind, dl in worst do
			table.insert(report, `{kind} {math.floor(dl * 100 + 0.5)}`)
		end
		table.sort(report)
		print("emblem ΔL* (worst per kind): " .. table.concat(report, ", "))
		expect(#report).toBe(4)
	end)

	it("keeps the D-039 shapes: crown 3 points, star 5 wedges, oak lobes + midrib, sun disc + rays", function()
		local want = {
			crown = "Part 1, WedgePart 2",
			star = "WedgePart 5",
			oak = "Part 5", -- 2 stacked lobes (cylinders), diamond base, ivory stem, midrib accent
			sun = "Part 4", -- compact: 2 ray squares, ring accent, disc
		}
		for id, kind in KINDS do
			local m = Kit.prop(`prop_banner_{BANNER_ASSET[id]}_01`)
			for _, slot in slotsOf(m) do
				if kind == "oak" then
					-- B12: an ivory stem below the leaf (a dark one vanished on the dark field)
					local anchor = anchorOf(slot.field :: BasePart)
					local stemLow, lobeLow = math.huge, math.huge
					for _, p in slot.marks do
						-- the leaf axis is each part's own +Y (every part shares the leaf's tilt)
						local up = anchor:VectorToObjectSpace(p.CFrame.UpVector)
						local q = anchor:PointToObjectSpace(p.CFrame.Position)
						local axis = Vector2.new(up.X, up.Y).Unit
						local along = q.X * axis.X + q.Y * axis.Y
						if p.Name == "EmblemStem" then
							expect(p:GetAttribute("KitEmblemAccent")).toBeNil()
							stemLow = math.min(stemLow, along - p.Size.Y / 2)
						elseif p.Name == "Emblem" or p.Name == "EmblemLobe" then
							lobeLow = math.min(lobeLow, along - math.max(p.Size.Y, p.Size.Z) / 2)
						end
					end
					expect(stemLow < lobeLow - 0.05).toBe(true)
				end
				local n = {}
				for _, p in slot.marks do
					n[p.ClassName] = (n[p.ClassName] or 0) + 1
				end
				local rows = {}
				for class, k in n do
					table.insert(rows, `{class} {k}`)
				end
				table.sort(rows)
				expect(table.concat(rows, ", ")).toBe(want[kind])
			end
		end
		-- the aerial plaques use the full sun: a disc and 8 separate wedge rays
		local keep = Buildings.build("keep", 1, "complete", CANON.gold)
		local fullSuns = 0
		for _, slot in slotsOf(keep) do
			if (slot.field :: BasePart).Name == "EmblemPlaque" then
				local wedges = 0
				for _, p in slot.marks do
					wedges += if p.ClassName == "WedgePart" then 1 else 0
				end
				expect(wedges).toBe(8)
				expect(#slot.marks).toBe(9)
				fullSuns += 1
			end
		end
		expect(fullSuns).toBe(2)
		-- and the full oak (B12): a slim core, the tip and two lobe pairs, the ivory stem and the midrib accent
		local emerald = Buildings.build("keep", 1, "complete", CANON.emerald)
		local fullOaks = 0
		for _, slot in slotsOf(emerald) do
			if (slot.field :: BasePart).Name == "EmblemPlaque" then
				local discs, accents = 0, 0
				for _, p in slot.marks do
					expect(p.ClassName).toBe("Part")
					discs += if (p :: Part).Shape == Enum.PartType.Cylinder then 1 else 0
					accents += if p:GetAttribute("KitEmblemAccent") == true then 1 else 0
				end
				expect(#slot.marks).toBe(8)
				expect(discs).toBe(5)
				expect(accents).toBe(1)
				fullOaks += 1
			end
		end
		expect(fullOaks).toBe(2)
	end)

	it("draws the compact sun's 8 points: two equal squares at 45°, tips beyond the ring, disc inside it", function()
		local m = Kit.prop(`prop_banner_{BANNER_ASSET.gold}_01`)
		local checked = 0
		for _, slot in slotsOf(m) do
			local anchor = anchorOf(slot.field :: BasePart)
			local rays, ring, disc = {}, nil, nil
			for _, p in slot.marks do
				if p.Name == "EmblemRay" then
					table.insert(rays, p)
				elseif p.Name == "EmblemRing" then
					ring = p
				elseif p.Name == "Emblem" then
					disc = p
				end
			end
			expect(#rays).toBe(2)
			expect(ring).never.toBeNil()
			expect(disc).never.toBeNil()
			local r1, r2 = rays[1], rays[2]
			for _, r in rays do
				expect(r.ClassName).toBe("Part")
				expect(math.abs(r.Size.X - r.Size.Y)).toBeLessThan(1e-3) -- square
				-- lies flat on the field: its face normal is the anchor's normal
				local n = anchor:VectorToObjectSpace(r.CFrame.LookVector)
				expect(math.abs(math.abs(n.Z) - 1)).toBeLessThan(1e-3)
			end
			expect(math.abs(r1.Size.X - r2.Size.X)).toBeLessThan(1e-3)
			-- 45° apart about the normal, so the 8 corners are evenly spaced
			local u1 = anchor:VectorToObjectSpace(r1.CFrame.RightVector)
			local u2 = anchor:VectorToObjectSpace(r2.CFrame.RightVector)
			local ang = math.deg(math.acos(math.clamp(math.abs(u1.X * u2.X + u1.Y * u2.Y), 0, 1)))
			expect(math.abs(ang - 45)).toBeLessThan(0.5)
			-- the points (half-diagonals) stick out past the field-coloured ring, the disc sits inside it
			local tip = r1.Size.X * math.sqrt(2) / 2
			local ringR = math.max(ring.Size.Y, ring.Size.Z) / 2
			local discR = math.max((disc :: BasePart).Size.Y, (disc :: BasePart).Size.Z) / 2
			expect(tip > ringR * 1.1).toBe(true)
			expect(discR < ringR).toBe(true)
			checked += 1
		end
		expect(checked >= 1).toBe(true)
	end)
end)

-- Overview camera (FORGE-04 RulerCameraController): pitch 50° at 120 studs, 57.5° at 170, 65° at 220.
local PITCHES = { 50, 57.5, 65 }

-- Half-spaces n·q ≤ c of each primitive in normalized part space (q = local position / Size, so the box is
-- ±0.5); geometry as in blender/lib/kitparts.py (WedgePart: slope descending to -Z; CornerWedgePart: apex
-- over the local (+X, -Z) corner). Balls and cylinders are tested exactly (B12: as boxes, the crimson spire
-- tiers' corners hid what the renders show; Roblox cylinders run along the local X axis, radius min(Y, Z) / 2).
local BOX =
	{ { 1, 0, 0, 0.5 }, { -1, 0, 0, 0.5 }, { 0, 1, 0, 0.5 }, { 0, -1, 0, 0.5 }, { 0, 0, 1, 0.5 }, { 0, 0, -1, 0.5 } }
local WEDGE = table.clone(BOX)
table.insert(WEDGE, { 0, 1, -1, 0 })
local CORNER = table.clone(BOX)
table.insert(CORNER, { 0, 1, 1, 0 })
table.insert(CORNER, { -1, 1, 0, 0 })

-- does the ray o + t·d (0 < t < 400) hit the part?
local function rayHits(p: BasePart, o: Vector3, d: Vector3): boolean
	local cf, size = p.CFrame, p.Size
	if p.ClassName == "Part" and (p :: Part).Shape == Enum.PartType.Ball then
		local r = math.min(size.X, size.Y, size.Z) / 2
		local oc = o - cf.Position
		local b = oc:Dot(d)
		local disc = b * b - (oc:Dot(oc) - r * r)
		return disc >= 0 and -b + math.sqrt(disc) > 0
	end
	local lo, ld = cf:PointToObjectSpace(o), cf:VectorToObjectSpace(d)
	if p.ClassName == "Part" and (p :: Part).Shape == Enum.PartType.Cylinder then
		-- the slab |x| ≤ X/2 intersected with the infinite cylinder y² + z² ≤ r²
		local r, hx = math.min(size.Y, size.Z) / 2, size.X / 2
		local t0, t1 = 0, 400
		if math.abs(ld.X) < 1e-12 then
			if math.abs(lo.X) > hx then
				return false
			end
		else
			local a, b = (-hx - lo.X) / ld.X, (hx - lo.X) / ld.X
			t0, t1 = math.max(t0, math.min(a, b)), math.min(t1, math.max(a, b))
		end
		local qa = ld.Y * ld.Y + ld.Z * ld.Z
		local qb = lo.Y * ld.Y + lo.Z * ld.Z
		local qc = lo.Y * lo.Y + lo.Z * lo.Z - r * r
		if qa < 1e-12 then
			if qc > 0 then
				return false
			end
		else
			local disc = qb * qb - qa * qc
			if disc < 0 then
				return false
			end
			local sq = math.sqrt(disc)
			t0, t1 = math.max(t0, (-qb - sq) / qa), math.min(t1, (-qb + sq) / qa)
		end
		return t0 <= t1
	end
	local planes = if p.ClassName == "WedgePart" then WEDGE elseif p.ClassName == "CornerWedgePart" then CORNER else BOX
	local qo = Vector3.new(lo.X / size.X, lo.Y / size.Y, lo.Z / size.Z)
	local qd = Vector3.new(ld.X / size.X, ld.Y / size.Y, ld.Z / size.Z)
	local t0, t1 = 0, 400
	for _, pl in planes do
		local n = Vector3.new(pl[1], pl[2], pl[3])
		local den, num = n:Dot(qd), pl[4] - n:Dot(qo)
		if math.abs(den) < 1e-12 then
			if num < 0 then
				return false
			end
		elseif den < 0 then
			t0 = math.max(t0, num / den)
		else
			t1 = math.min(t1, num / den)
		end
		if t0 > t1 then
			return false
		end
	end
	return true
end

-- Fraction of a plaque's emblem box (7 × 7 points, 0.2 out of the face) that sees the camera along
-- direction `toCamera`, past every visible part of the model except the plaque's own.
local function visibleFraction(model: Model, field: BasePart, toCamera: Vector3): number
	local anchor = anchorOf(field)
	local half = (field:GetAttribute("KitEmblemSize") :: number) / 2
	local slot = field:GetAttribute("KitEmblemSlot")
	-- broad phase: only parts whose bounding sphere reaches the prism the plaque sweeps toward the camera can
	-- block a ray (exact per-ray test below); this keeps the 4 kingdoms x 3 levels x 18 views affordable
	local o0 = (anchor * CFrame.new(0, 0, -0.2)).Position
	local reach = half * math.sqrt(2)
	local others = {}
	for _, p in parts(model) do
		if p.Transparency >= 1 or p:GetAttribute("KitEmblemSlot") == slot or p.Name == "EmblemPlaqueBorder" then
			continue
		end
		local v = p.CFrame.Position - o0
		local r = p.Size.Magnitude / 2
		local t = v:Dot(toCamera)
		if t < -r or (v - toCamera * t).Magnitude > r + reach then
			continue
		end
		table.insert(others, p)
	end
	local seen, n = 0, 0
	for i = 0, 6 do
		for j = 0, 6 do
			local o = (anchor * CFrame.new((i / 3 - 1) * half, (j / 3 - 1) * half, -0.2)).Position
			local blocked = false
			for _, p in others do
				if rayHits(p, o, toCamera) then
					blocked = true
					break
				end
			end
			n += 1
			seen += if blocked then 0 else 1
		end
	end
	return seen / n
end

local function toCamera(azimuthDeg: number, pitchDeg: number): Vector3
	-- azimuth 0 = the camera in front of the keep (-Z), 90 = on its +X side, 180 = behind it
	local a, p = math.rad(azimuthDeg), math.rad(pitchDeg)
	return Vector3.new(math.sin(a) * math.cos(p), math.sin(p), -math.cos(a) * math.cos(p))
end

describe("Keep aerial heraldry (overview camera, G13.6)", function()
	it("carries a large up-facing roof plaque and a donjon-back plaque at every level", function()
		for level = 1, 3 do
			for _, case in CASES do
				local m = Buildings.build("keep", level, "complete", case[1])
				local roof, back = nil, nil
				for _, slot in slotsOf(m) do
					local field = slot.field :: BasePart
					if field.Name == "EmblemPlaque" then
						local n = anchorOf(field).LookVector -- out of the face (-Z of the anchor)
						if n.Y > 0.99 then
							roof = field
						elseif n.Z > 0.99 then
							back = field
						end
						expect(field:GetAttribute("KitEmblemDetail")).toBe("full")
						expect(field:GetAttribute("KitEmblemSize") :: number).toBeGreaterThan(4)
						expect(#slot.marks > 0).toBe(case[2] ~= nil)
					end
				end
				if roof == nil or back == nil then
					error(`keep L{level}: missing the roof or the donjon-back plaque`)
				end
				expect(math.min((roof :: BasePart).Size.X, (roof :: BasePart).Size.Y)).toBeGreaterThanOrEqual(5.5)
				expect(math.min((back :: BasePart).Size.X, (back :: BasePart).Size.Y)).toBeGreaterThanOrEqual(5)
			end
		end
	end)

	-- Gate: ≥ 80 % of the emblem from the plaque's own side (roof: the front and both front diagonals; donjon
	-- back: behind and both rear diagonals) at every overview pitch, with the widest caps (emerald hoardings)
	-- and the tallest (crimson spires). Measured (B12, cylinders exact): 100 % head-on; ≥ 85 % on the roof
	-- plaque's diagonals (crimson spires clip a corner at 50°), ≥ 97 % on the donjon plaque's. Pure side views
	-- are reported: a vertical plaque is edge-on there, and the L1 hall's turrets hide up to a third of the roof
	-- plaque at 50°.
	it("keeps each plaque's emblem in view of the overview camera at 120–220 studs (50–65° down)", function()
		local report = {}
		local runs = {}
		for _, id in { "crimson", "azure", "emerald", "gold" } do
			for level = 1, 3 do
				table.insert(runs, { level, id })
			end
		end
		for _, run in runs do
			local level = run[1]
			local m = Buildings.build("keep", level, "complete", CANON[run[2]])
			local plaques = {}
			for _, slot in slotsOf(m) do
				local f = slot.field :: BasePart
				if f.Name == "EmblemPlaque" then
					plaques[if anchorOf(f).LookVector.Y > 0.99 then "roof" else "back"] = f
				end
			end
			-- the roof plaque from the front half (the donjon hides it from behind), the back plaque from behind
			for which, azimuths in { roof = { -45, 0, 45 }, back = { 135, 180, 225 } } do
				for _, az in azimuths do
					for _, pitch in PITCHES do
						local f = visibleFraction(m, plaques[which], toCamera(az, pitch))
						if f < 0.8 then
							error(
								`keep L{level} {run[2]}: {which} plaque {math.floor(f * 100)} % visible at azimuth {az}, {pitch}°`
							)
						end
					end
				end
				-- from the sides the front turrets may hide a corner of the roof plaque: reported, not gated
				local side = math.huge
				for _, az in (if which == "roof" then { -90, 90 } else { 90, 270 }) do
					side = math.min(side, visibleFraction(m, plaques[which], toCamera(az, 50)))
				end
				table.insert(report, `L{level} {run[2]} {which} {math.floor(side * 100)}%`)
			end
		end
		print("aerial plaque visibility from the sides at 50°: " .. table.concat(report, ", "))
	end)

	it("has a probe that sees occlusion: the donjon hides the roof plaque from straight behind at 50°", function()
		for level = 1, 3 do
			local m = Buildings.build("keep", level, "complete", CANON.crimson)
			for _, slot in slotsOf(m) do
				local f = slot.field :: BasePart
				if f.Name == "EmblemPlaque" and anchorOf(f).LookVector.Y > 0.99 then
					expect(visibleFraction(m, f, toCamera(180, 50))).toBeLessThan(0.5)
				end
			end
		end
	end)
end)

-- Throne marker from the overview camera (B12). The camera focuses on the ruler seated on the throne
-- (RulerCameraController's first focus) and turns to any side; from behind, the hall and the donjon's cap hide
-- the throne and its low baldachin, so the keep flies a royal standard pair at the terrace's front corners.
-- The marker is every part tagged KitThroneMarker: the baldachin canopy and finial, and each standard's flag,
-- border and finial. Unlike the plaque probe above, rays go to the camera's position (perspective): the
-- controller's zoom/pitch pairs, 120 studs at 50°, 170 at 57.5°, 220 at 65° (Def.pitchFor).
local ZOOMS = { { 120, 50 }, { 170, 57.5 }, { 220, 65 } }
local SAMPLE_STEP = 0.6 -- studs between surface samples
-- screen pixels per stud at distance d: Roblox's 70° vertical field of view on a 1080-pixel-high screen
local function pixelsPerStud(d: number): number
	return 1080 / (2 * d * math.tan(math.rad(35)))
end

type Sample = { p: Vector3, n: Vector3, a: number }

-- Surface samples (point, outward normal, area) on a part's faces: a box's six faces, a wedge's five (its two
-- triangles, back, bottom and slope), a cylinder as its box, a ball on a Fibonacci sphere.
local function surfaceSamples(p: BasePart): { Sample }
	local out: { Sample } = {}
	local cf, s = p.CFrame, p.Size
	if p.ClassName == "Part" and (p :: Part).Shape == Enum.PartType.Ball then
		local r, n = math.min(s.X, s.Y, s.Z) / 2, 40
		for i = 0, n - 1 do
			local y = 1 - (i + 0.5) / n * 2
			local rr, th = math.sqrt(1 - y * y), i * 2.399963
			local dir = Vector3.new(math.cos(th) * rr, y, math.sin(th) * rr)
			table.insert(out, { p = cf.Position + dir * r, n = dir, a = 4 * math.pi * r * r / n })
		end
		return out
	end
	local wedge = p.ClassName == "WedgePart"
	local function face(n: Vector3, u: Vector3, v: Vector3, slope: boolean)
		local lu = if slope then s.X else math.abs(u:Dot(s))
		local lv = if slope then math.sqrt(s.Y * s.Y + s.Z * s.Z) else math.abs(v:Dot(s))
		local nu, nv = math.max(1, math.ceil(lu / SAMPLE_STEP)), math.max(1, math.ceil(lv / SAMPLE_STEP))
		local wn = cf:VectorToWorldSpace(Vector3.new(n.X / s.X, n.Y / s.Y, n.Z / s.Z)).Unit
		for i = 0, nu - 1 do
			for j = 0, nv - 1 do
				local a, b = (i + 0.5) / nu - 0.5, (j + 0.5) / nv - 0.5
				-- q in normalized part space; the slope runs from (y, z) = (-0.5, -0.5) to (0.5, 0.5)
				local q = if slope then Vector3.new(a, b, b) else n * 0.5 + u * a + v * b
				if wedge and not slope and q.Y > q.Z + 1e-6 then
					continue -- outside the wedge (its +Y and -Z faces are edges, its sides triangles)
				end
				table.insert(out, {
					p = cf:PointToWorldSpace(Vector3.new(q.X * s.X, q.Y * s.Y, q.Z * s.Z)),
					n = wn,
					a = lu * lv / (nu * nv),
				})
			end
		end
	end
	local X, Y, Z = Vector3.xAxis, Vector3.yAxis, Vector3.zAxis
	for _, f in { { X, Y, Z }, { -X, Y, Z }, { Y, X, Z }, { -Y, X, Z }, { Z, X, Y }, { -Z, X, Y } } do
		face(f[1], f[2], f[3], false)
	end
	if wedge then
		face(Vector3.new(0, 1, -1), X, Y, true)
	end
	return out
end

-- Screen pixels (1080p) of the throne marker the camera at `camera` sees, and the marker's tagged part count.
-- A sample counts when it faces the camera and no other part of the model hides it (other marker parts too, so
-- the gabled canopy's inside faces never count). Broad phase as in visibleFraction, per marker part: the rays
-- of one part's samples stay inside the cylinder of its bounding radius around the axis to the camera.
local function markerPixels(model: Model, camera: Vector3): (number, number)
	local all, marks = {}, {}
	for _, p in parts(model) do
		if p.Transparency < 1 then
			table.insert(all, p)
		end
		if p:GetAttribute("KitThroneMarker") == true and p:GetAttribute("KitEmblem") == nil then
			table.insert(marks, p)
		end
	end
	local px = 0
	for _, mp in marks do
		local c, reach = mp.CFrame.Position, mp.Size.Magnitude / 2
		local axis = (camera - c).Unit
		local others = {} -- every part (other marker parts too) that can block a ray from this one
		for _, p in all do
			local v = p.CFrame.Position - c
			local r = p.Size.Magnitude / 2
			local t = v:Dot(axis)
			if p == mp or t < -r or (v - axis * t).Magnitude > r + reach then
				continue
			end
			table.insert(others, p)
		end
		for _, smp in surfaceSamples(mp) do
			local o = smp.p + smp.n * 0.03
			local d = (camera - o).Unit
			local facing = smp.n:Dot(d)
			if facing <= 0.05 then
				continue
			end
			local hidden = false
			for _, p in others do
				if rayHits(p, o, d) then
					hidden = true
					break
				end
			end
			if not hidden then
				local k = pixelsPerStud((camera - o).Magnitude)
				px += smp.a * facing * k * k
			end
		end
	end
	return px, #marks
end

local function throneCamera(model: Model, azimuth: number, zoom: { number }): Vector3
	local seat = model:FindFirstChild("Throne", true) :: BasePart
	local focus = seat.CFrame.Position + Vector3.new(0, seat.Size.Y / 2 + 2, 0) -- the seated ruler
	return focus + toCamera(azimuth, zoom[2]) * zoom[1]
end

-- Gate: ≥ 150 px of marker at 1080p from every rear-arc view (behind and the two rear diagonals, at every zoom),
-- for every kingdom at keep L1–L3. 150 px is two 12 × 6 px flags, each about the 10 px at which FORGE-05's run 4
-- still read the star and the sun at 220 studs. Measured (B12): 257 px at the worst view (keep L3, 220 studs,
-- 65°, where both standards are in full view but small); at 120 studs the standards alone show 700+ px. The
-- high baldachin it replaced showed 0 px from straight behind at 120 studs for all four kingdoms.
local MARKER_MIN_PX = 150
describe("Throne marker from the overview camera (B12)", function()
	it("tests cylinders exactly: a ray past a tier's box corner misses, one through the tier hits", function()
		local tier = Instance.new("Part")
		tier.Shape = Enum.PartType.Cylinder
		tier.Size = Vector3.new(2, 8, 8) -- upright (axis along world Y), radius 4
		tier.CFrame = CFrame.Angles(0, 0, math.rad(90))
		local up = Vector3.new(0, 1, 0)
		-- (3.6, 3.6) lies inside the 8 x 8 box but 5.09 from the axis: outside the radius-4 cylinder
		expect(rayHits(tier, Vector3.new(3.6, -5, 3.6), up)).toBe(false)
		expect(rayHits(tier, Vector3.new(2.5, -5, 2.5), up)).toBe(true)
		expect(rayHits(tier, Vector3.new(-20, 0.5, 0), Vector3.new(1, 0, 0))).toBe(true)
		expect(rayHits(tier, Vector3.new(-20, 1.5, 0), Vector3.new(1, 0, 0))).toBe(false) -- above the slab
	end)

	it("keeps the throne's standards and baldachin in view from behind the keep (rear arc, every zoom)", function()
		local worst, report = math.huge, {}
		for _, id in { "crimson", "azure", "emerald", "gold" } do
			for level = 1, 3 do
				local m = Buildings.build("keep", level, "complete", CANON[id])
				local low = math.huge
				for _, az in { 135, 180, 225 } do
					for _, zoom in ZOOMS do
						local px, n = markerPixels(m, throneCamera(m, az, zoom))
						expect(n).toBeGreaterThanOrEqual(5) -- canopy x2, finial, a flag on each standard
						if px < MARKER_MIN_PX then
							error(
								`keep L{level} {id}: throne marker {math.floor(px)} px at azimuth {az}, {zoom[1]} studs`
							)
						end
						low = math.min(low, px)
					end
				end
				worst = math.min(worst, low)
				table.insert(report, `L{level} {id} {math.floor(low)}`)
			end
		end
		print("throne marker, fewest pixels from behind (1080p): " .. table.concat(report, ", "))
		expect(worst).toBeGreaterThanOrEqual(MARKER_MIN_PX)
	end)

	it("has a marker probe that sees occlusion: the donjon hides the baldachin from straight behind", function()
		-- with the standards' tags removed, only the canopy is left: hidden behind the hall and the donjon at 120
		-- studs, while the same probe sees it from the front
		local m = Buildings.build("keep", 1, "complete", CANON.crimson)
		for _, p in parts(m) do
			if p:GetAttribute("KitThroneMarker") == true and string.sub(p.Name, 1, 9) ~= "Baldachin" then
				p:SetAttribute("KitThroneMarker", nil)
			end
		end
		local behind = markerPixels(m, throneCamera(m, 180, ZOOMS[1]))
		local front = markerPixels(m, throneCamera(m, 0, ZOOMS[1]))
		expect(behind).toBeLessThan(MARKER_MIN_PX / 3)
		expect(front).toBeGreaterThan(MARKER_MIN_PX * 3)
	end)
end)

describe("Kit.setKingdomColor re-forms emblems", function()
	local function samples(color: Color3): { [string]: Model }
		local out = props(color)
		out.keepL2 = Buildings.build("keep", 2, "complete", color)
		out.barracksL4 = Buildings.build("barracks", 4, "complete", color)
		out.watchtower = Buildings.build("watchtower", 1, "complete", color)
		out.houseThatch = Buildings.build("house", 1, "complete", color, 2)
		out.gate = Buildings.build("gate", 1, "complete", color)
		out.stage = Buildings.build("farm", 1, 2, color)
		return out
	end

	local function compare(label: string, got: Model, want: Model, kind: string?)
		local a, b = slotsOf(got), slotsOf(want)
		local na, nb = 0, 0
		for id, slot in b do
			nb += 1
			local other = a[id]
			if other == nil then
				error(`{label}: slot {id} missing after recolour`)
			end
			if not sameEmblem(other, slot) then
				error(`{label}: slot {id} on {(slot.field :: BasePart).Name} differs from a fresh build`)
			end
		end
		for _ in a do
			na += 1
		end
		expect(na).toBe(nb)
		checkKinds(label, got, kind)
	end

	it("swaps the emblem to the new colour's kind on the same anchors, for every pair of colours", function()
		for i = 1, 5 do
			for j = 1, 5 do
				if i ~= j then
					local from, to = CASES[i], CASES[j]
					local fresh = samples(to[1])
					for name, m in samples(from[1]) do
						Kit.setKingdomColor(m, to[1])
						compare(`{name} {from[2]}->{to[2]}`, m, fresh[name], to[2])
					end
				end
			end
		end
	end)

	it("only replaces emblem parts: every other part stays, with the colour of a same-style rebuild", function()
		local m = Buildings.build("keep", 2, "complete", CANON.crimson)
		local kept = {}
		for _, p in parts(m) do
			if p:GetAttribute("KitEmblem") == nil then
				kept[p] = true
			end
		end
		Kit.setKingdomColor(m, CANON.azure)
		local n = 0
		for _, p in parts(m) do
			if p:GetAttribute("KitEmblem") == nil then
				expect(kept[p]).toBe(true)
				n += 1
			end
		end
		local before = 0
		for _ in kept do
			before += 1
		end
		expect(n).toBe(before)
		-- tinted fields follow the colour
		for _, slot in slotsOf(m) do
			local f = slot.field :: BasePart
			local tint = f:GetAttribute("KitTint") :: number
			local want = Color3.new(
				math.clamp(CANON.azure.R * tint, 0, 1),
				math.clamp(CANON.azure.G * tint, 0, 1),
				math.clamp(CANON.azure.B * tint, 0, 1)
			)
			expect((Vector3.new(f.Color.R, f.Color.G, f.Color.B) - Vector3.new(want.R, want.G, want.B)).Magnitude).toBeLessThan(
				1e-4
			)
		end
	end)

	it("re-forms emblems on a model that was moved and turned (WorldService placement)", function()
		local m = Buildings.build("watchtower", 2, "complete", CANON.gold)
		local delta = CFrame.new(812, 14, -377) * CFrame.Angles(0, math.rad(130), 0)
		for _, p in parts(m) do
			p.CFrame = delta * p.CFrame
		end
		Kit.setKingdomColor(m, CANON.emerald)
		compare("moved watchtower", m, Buildings.build("watchtower", 2, "complete", CANON.emerald), "oak")
		for _, slot in slotsOf(m) do
			local anchor = anchorOf(slot.field :: BasePart)
			for _, p in slot.marks do
				-- the new parts sit on the moved field, not at the build origin
				expect((anchor:PointToObjectSpace(p.CFrame.Position)).Magnitude).toBeLessThan(5)
			end
		end
	end)

	it("re-forms every model's emblems when the recoloured container holds several Kit models", function()
		-- slots are numbered per model, so two towers both have slot 1: pair by (model, slot)
		local container = Instance.new("Model")
		local a = Buildings.build("watchtower", 1, "complete", CANON.crimson)
		local b = Buildings.build("watchtower", 1, "complete", CANON.crimson)
		for _, p in parts(b) do
			p.CFrame = CFrame.new(40, 0, 0) * p.CFrame
		end
		a.Parent = container
		b.Parent = container
		Kit.setKingdomColor(container, CANON.azure)
		compare("container tower A", a, Buildings.build("watchtower", 1, "complete", CANON.azure), "star")
		compare("container tower B", b, Buildings.build("watchtower", 1, "complete", CANON.azure), "star")
	end)
end)
