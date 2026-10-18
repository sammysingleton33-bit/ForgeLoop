--[[
	Kingdom architecture styles (FL-0127 part 2, FORGE-02, Operation Crownfall D-053): Kit/KingdomStyle.luau is one
	table keyed by the kingdom's hue style (crimson Emberhold, azure Frostmere, emerald Thornwood, gold Sunspire).
	This spec pins what a style may and may not do:

	  1. the four styles differ measurably on every building type, in more than one attribute: untinted palette
	     (stone, timber, plaster, thatch), tint, material, geometry; and the roof silhouette (pitch) is ordered
	     steep (Emberhold) > Frostmere > Thornwood > flat (Sunspire);
	  2. a style never adds or removes a part: every building, level, variant and stage has exactly the part count of
	     the same build in the neutral style (and, measured once against main, of the Kit before styles);
	  3. emblem and tower-cap silhouette stay unique per kingdom, so a colour-blind player keeps two non-colour
	     cues on every tower-bearing building (D-033 (3), D-039);
	  4. determinism: a building is a function of (type, level, stage, hue style, variant);
	  5. the palette pass re-skins what it says it does (and the palette roles are unambiguous);
	  6. mutants of the table and of its functions are caught (style ignored, two styles equal, a style adding
	     parts, palette pass skipped, pitch or merlons or banner tails ignored, a style that is not deterministic,
	     a stone accent that equals the plain stone).
	Footprints, part budgets and placement inside the footprint are pinned by KitBuildings.spec.
]]

local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local Kit = require("@game/ReplicatedStorage/Game/Kit/Kit")
local Buildings = require("@game/ReplicatedStorage/Game/Kit/Buildings")
local KingdomStyle = require("@game/ReplicatedStorage/Game/Kit/KingdomStyle")
local Parts = require("@game/ReplicatedStorage/Game/Kit/Parts")
local KingdomsConfig = require("@game/ReplicatedStorage/Forge/Config/Kingdoms")

local CANON: { [string]: Color3 } = {}
for _, identity in KingdomsConfig.identities do
	local c = identity.color
	CANON[identity.id] = Color3.fromRGB(c[1], c[2], c[3])
end
local shade = Parts.shade
local KINGDOMS = KingdomStyle.KINGDOM_STYLES -- { "crimson", "azure", "emerald", "gold" }
local KINDS = { crimson = "crown", azure = "star", emerald = "oak", gold = "sun" }
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

local function lstar(c: Color3): number
	local function lin(v: number): number
		return if v <= 0.04045 then v / 12.92 else ((v + 0.055) / 1.055) ^ 2.4
	end
	local y = 0.2126 * lin(c.R) + 0.7152 * lin(c.G) + 0.0722 * lin(c.B)
	return if y > 0.008856 then 116 * y ^ (1 / 3) - 16 else 903.3 * y
end

local function hex(c: Color3): string
	return string.format(
		"%02x%02x%02x",
		math.floor(c.R * 255 + 0.5),
		math.floor(c.G * 255 + 0.5),
		math.floor(c.B * 255 + 0.5)
	)
end

local function r2(n: number): string
	return string.format("%.2f", n)
end

type Sig = { palette: string, tint: string, material: string, geometry: string }

-- Four fingerprints of a model without its emblems (the emblem differs per kingdom by design, D-039): the
-- palette of the parts that are not kingdom-coloured, the tint factors of those that are, the materials and the
-- geometry (class, size, position).
local function signature(model: Instance): Sig
	local palette, tint, material, geometry = {}, {}, {}, {}
	for _, p in parts(model) do
		if p:GetAttribute("KitEmblem") == nil then
			local t = p:GetAttribute("KitTint")
			if t ~= nil then
				table.insert(tint, `{p.Name}:{r2(t :: number)}`)
			else
				table.insert(palette, `{p.Name}:{hex(p.Color)}`)
			end
			table.insert(material, `{p.Name}:{p.Material.Name}`)
			local s, c = p.Size, p.CFrame.Position
			table.insert(geometry, `{p.ClassName}:{p.Name}:{r2(s.X)},{r2(s.Y)},{r2(s.Z)}@{r2(c.X)},{r2(c.Y)},{r2(c.Z)}`)
		end
	end
	for _, list in { palette, tint, material, geometry } do
		table.sort(list)
	end
	return {
		palette = table.concat(palette, ";"),
		tint = table.concat(tint, ";"),
		material = table.concat(material, ";"),
		geometry = table.concat(geometry, ";"),
	}
end

local function fullSignature(model: Instance): string
	local s = signature(model)
	return table.concat({ s.palette, s.tint, s.material, s.geometry }, "|")
end

type Case = { type: string, level: number, variant: number }

local function levelsFor(bt: string): number
	return MAX_LEVEL[bt] or 2
end

-- every building type at every level, the four house archetypes
local function fullCases(): { Case }
	local out = {}
	for _, bt in Kit.BUILDING_TYPES do
		for level = 1, levelsFor(bt) do
			for v = 1, (if bt == "house" then 4 else 1) do
				table.insert(out, { type = bt, level = level, variant = v })
			end
		end
	end
	return out
end

-- a fast subset for the mutants: the roofed, the stone and the tower-bearing types
local QUICK_CASES: { Case } = {
	{ type = "house", level = 1, variant = 1 },
	{ type = "house", level = 1, variant = 2 },
	{ type = "house", level = 1, variant = 3 },
	{ type = "farm", level = 1, variant = 1 },
	{ type = "keep", level = 1, variant = 1 },
	{ type = "barracks", level = 3, variant = 1 },
	{ type = "quarry", level = 1, variant = 1 },
	{ type = "lumbercamp", level = 1, variant = 1 },
	{ type = "watchtower", level = 1, variant = 1 },
	{ type = "wall", level = 1, variant = 1 },
	{ type = "gate", level = 1, variant = 1 },
}

local function build(c: Case, hue: string, stage: any?): Model
	return Buildings.build(c.type, c.level, stage or "complete", CANON[hue], c.variant)
end

local function label(c: Case): string
	return `{c.type} L{c.level} v{c.variant}`
end

-- ------------------------------------------------------------------ the checks (each returns its violations)

-- 1. the styles differ per type, in more than one attribute, and from neutral
local function differenceViolations(cases: { Case }): { string }
	local out = {}
	for _, c in cases do
		local sigs: { [string]: Sig } = {}
		for _, hue in KINGDOMS do
			sigs[hue] = signature(build(c, hue))
		end
		local neutral = signature(Buildings.build(c.type, c.level, "complete", Kit.NEUTRAL_COLOR, c.variant))
		for i = 1, #KINGDOMS do
			local a = sigs[KINGDOMS[i]]
			if a.palette == neutral.palette then
				table.insert(out, `{label(c)}: {KINGDOMS[i]} keeps the neutral palette`)
			end
			for j = i + 1, #KINGDOMS do
				local b = sigs[KINGDOMS[j]]
				if a.palette == b.palette then
					table.insert(out, `{label(c)}: {KINGDOMS[i]} and {KINGDOMS[j]} share a palette`)
				end
				local more = (if a.tint ~= b.tint then 1 else 0)
					+ (if a.material ~= b.material then 1 else 0)
					+ (if a.geometry ~= b.geometry then 1 else 0)
				if more < 1 then
					table.insert(out, `{label(c)}: {KINGDOMS[i]} and {KINGDOMS[j]} differ in the palette only`)
				end
			end
		end
	end
	return out
end

-- tallest roof surface above the lowest roof tile / thatch (the rise the eye reads as pitch)
local function roofRise(model: Instance): number
	local lo, hi = math.huge, -math.huge
	for _, p in parts(model) do
		if p.Name == "RoofTiles" or p.Name == "Thatch" then
			local half = (math.abs(p.CFrame.UpVector.Y) * p.Size.Y + math.abs(p.CFrame.LookVector.Y) * p.Size.Z) / 2
			lo = math.min(lo, p.CFrame.Position.Y - half)
			hi = math.max(hi, p.CFrame.Position.Y + half)
		end
	end
	return hi - lo
end

-- 1b. roof silhouette: steep Emberhold > Frostmere > Thornwood > flat Sunspire, each step visible
local function silhouetteViolations(): { string }
	local out = {}
	local order = { "crimson", "azure", "emerald", "gold" }
	for _, c in { { 1, 1 }, { 1, 2 }, { 1, 3 }, { 1, 4 }, { 2, 1 } } do
		local rises = {}
		for _, hue in order do
			rises[hue] = roofRise(Buildings.build("house", c[1], "complete", CANON[hue], c[2]))
		end
		for i = 1, #order - 1 do
			local hi, lo = rises[order[i]], rises[order[i + 1]]
			if hi < lo * 1.03 then
				table.insert(
					out,
					`house L{c[1]} v{c[2]}: {order[i]} roof ({r2(hi)}) not above {order[i + 1]} ({r2(lo)})`
				)
			end
		end
		if rises.crimson < rises.gold * 1.3 then
			table.insert(out, `house L{c[1]} v{c[2]}: steep and flat roofs are less than 1.3x apart`)
		end
	end
	-- merlons: Emberhold tall and narrow, Frostmere low and broad, the same count (the watchtower's gallery)
	local function merlonSize(hue: string): (number, number, number)
		local n, h, w = 0, 0, 0
		for _, p in parts(Buildings.build("watchtower", 1, "complete", CANON[hue])) do
			if p.Name == "Merlon" then
				n += 1
				h = math.max(h, p.Size.Y)
				w = math.max(w, p.Size.X, p.Size.Z)
			end
		end
		return n, h, w
	end
	local nC, hC, wC = merlonSize("crimson")
	local nA, hA, wA = merlonSize("azure")
	if nC ~= nA then
		table.insert(out, `watchtower merlon count differs: {nC} vs {nA}`)
	end
	if hC < hA * 1.4 or wC > wA * 0.85 then
		table.insert(
			out,
			`watchtower merlons: Emberhold {r2(hC)}x{r2(wC)} is not taller and narrower than Frostmere {r2(hA)}x{r2(wA)}`
		)
	end
	-- banner tails: three shapes (diamond / pennon wedge / half disc), part class carries them
	local function tail(hue: string): string
		for _, p in parts(Buildings.build("watchtower", 1, "complete", CANON[hue])) do
			if p.Name == "BannerTip" then
				return if p:IsA("WedgePart")
					then "wedge"
					elseif (p :: any).Shape == Enum.PartType.Cylinder then "disc"
					else "block"
			end
		end
		return "none"
	end
	local tails = { tail("crimson"), tail("azure"), tail("emerald"), tail("gold") }
	if tails[2] ~= "wedge" or tails[4] ~= "disc" or tails[1] ~= "block" then
		table.insert(out, `banner tails: {table.concat(tails, ",")} (want block, wedge, block, disc)`)
	end
	-- value: the stones span the range (dark Emberhold, mossy Thornwood, sandstone Sunspire, pale Frostmere)
	local L = {}
	for _, hue in order do
		L[hue] = lstar(KingdomStyle.get(hue).stone.base)
	end
	if not (L.azure > L.gold + 8 and L.gold > L.emerald + 8 and L.emerald > L.crimson + 8) then
		table.insert(
			out,
			`stone value (L*): azure {r2(L.azure)}, gold {r2(L.gold)}, emerald {r2(L.emerald)}, crimson {r2(L.crimson)} not spread by 8`
		)
	end
	return out
end

-- 3. the non-colour cues: tower cap and emblem unique per kingdom on every tower-bearing building
local CAP_NAMES = {
	Spire = true,
	SpireEave = true,
	CapEave = true,
	RoofCorner = true,
	Hoarding = true,
	HoardingBeam = true,
	Drum = true,
	DrumBand = true,
	Dome = true,
	DomeTip = true,
}

local function capSignature(model: Instance): string
	local names = {}
	for _, p in parts(model) do
		if CAP_NAMES[p.Name] then
			names[p.Name] = true
		end
	end
	local list = {}
	for n in names do
		table.insert(list, n)
	end
	table.sort(list)
	return table.concat(list, ",")
end

local function emblemKinds(model: Instance): string
	local kinds = {}
	for _, p in parts(model) do
		local k = p:GetAttribute("KitEmblem")
		if k ~= nil then
			kinds[k :: string] = true
		end
	end
	local list = {}
	for k in kinds do
		table.insert(list, k)
	end
	table.sort(list)
	return table.concat(list, ",")
end

local function cueViolations(): { string }
	local out = {}
	local towerBearing: { Case } = {
		{ type = "keep", level = 1, variant = 1 },
		{ type = "keep", level = 3, variant = 1 },
		{ type = "barracks", level = 3, variant = 1 },
		{ type = "watchtower", level = 1, variant = 1 },
		{ type = "gate", level = 1, variant = 1 },
	}
	for _, c in towerBearing do
		local caps, marks = {}, {}
		for _, hue in KINGDOMS do
			local m = build(c, hue)
			caps[hue], marks[hue] = capSignature(m), emblemKinds(m)
			if caps[hue] == "" then
				table.insert(out, `{label(c)} {hue}: no tower cap`)
			end
			if marks[hue] ~= KINDS[hue] then
				table.insert(out, `{label(c)} {hue}: emblem {marks[hue]} (want {KINDS[hue]})`)
			end
		end
		for i = 1, #KINGDOMS do
			for j = i + 1, #KINGDOMS do
				local a, b = KINGDOMS[i], KINGDOMS[j]
				if caps[a] == caps[b] then
					table.insert(out, `{label(c)}: {a} and {b} share a tower-cap silhouette`)
				end
				if marks[a] == marks[b] then
					table.insert(out, `{label(c)}: {a} and {b} share an emblem`)
				end
			end
		end
	end
	return out
end

-- 4. determinism: the same arguments give the same building, whatever was built in between
local function determinismViolations(cases: { Case }): { string }
	local out = {}
	for _, c in cases do
		for _, hue in KINGDOMS do
			local a = fullSignature(build(c, hue))
			build(c, KINGDOMS[#KINGDOMS + 1 - table.find(KINGDOMS, hue)])
			local b = fullSignature(build(c, hue))
			if a ~= b then
				table.insert(out, `{label(c)} {hue}: two builds differ`)
			end
		end
	end
	return out
end

-- 2. a style never adds or removes a part: the count equals the neutral style's, build by build
local function countViolations(cases: { Case }, stages: boolean): { string }
	local out = {}
	local saved = table.clone(KingdomStyle.STYLES)
	local function counts(c: Case, stage: any): { [string]: number }
		local res = {}
		for _, hue in KINGDOMS do
			res[hue] = Kit.partCount(build(c, hue, stage))
		end
		return res
	end
	for _, c in cases do
		for _, stage in (if stages and c.variant == 1 then { 1, 2, 3, "complete" } else { "complete" }) do
			local styled = counts(c, stage)
			for _, hue in KINGDOMS do
				KingdomStyle.STYLES[hue] = KingdomStyle.NEUTRAL -- the same build, in the Kit's original style
			end
			local plain = counts(c, stage)
			for hue, st in saved do
				KingdomStyle.STYLES[hue] = st
			end
			for _, hue in KINGDOMS do
				if styled[hue] ~= plain[hue] then
					table.insert(
						out,
						`{label(c)} {stage} {hue}: {styled[hue]} parts vs {plain[hue]} in the neutral style`
					)
				end
			end
		end
	end
	return out
end

-- 5. the palette pass: each role takes the kingdom's colour (checked on parts that carry one role at factor 1)
local function paletteViolations(): { string }
	local out = {}
	for _, hue in KINGDOMS do
		local st = KingdomStyle.get(hue)
		local want = {
			Post = st.timber, -- house framing (C.timber)
			Plinth = st.stone.dark, -- the plinth's core (S.dark)
			ChimneyBand = st.stone.light, -- C.stoneLight
		}
		local house = Buildings.build("house", 1, "complete", CANON[hue], 1)
		for _, p in parts(house) do
			local w = want[p.Name]
			if w and p:GetAttribute("KitTint") == nil and hex(p.Color) ~= hex(w) then
				table.insert(out, `house v1 {hue}: {p.Name} is {hex(p.Color)}, want {hex(w)}`)
			end
		end
		local seenThatch, seenWalls = false, false
		for _, v in { 2, 4 } do
			for _, p in parts(Buildings.build("house", 1, "complete", CANON[hue], v)) do
				if p.Name == "Thatch" and not seenThatch then
					-- the first thatch slab is the neutral thatch (191,163,108) at factor 1
					seenThatch = true
					if hex(p.Color) ~= hex(st.thatch) then
						table.insert(out, `house thatch {hue}: {hex(p.Color)}, want {hex(st.thatch)}`)
					end
				end
				if p.Name == "Walls" and p.Material == Enum.Material.Plaster and v == 2 then
					seenWalls = true
					-- house v2's plaster is the neutral variant (236, 219, 186): the kingdom plaster's gain on it
					local n, pl = Color3.fromRGB(236, 219, 186), Parts.C.plaster
					local wantPlaster = Color3.new(
						math.clamp(n.R * st.plaster.R / pl.R, 0, 1),
						math.clamp(n.G * st.plaster.G / pl.G, 0, 1),
						math.clamp(n.B * st.plaster.B / pl.B, 0, 1)
					)
					if hex(p.Color) ~= hex(wantPlaster) then
						table.insert(out, `house plaster {hue}: {hex(p.Color)}, want {hex(wantPlaster)}`)
					end
				end
			end
		end
		if not (seenThatch and seenWalls) then
			table.insert(out, `house {hue}: no thatch or plaster walls to check`)
		end
		-- the farm's grain takes the kingdom's crop (stalks at factor 1)
		local wheat = 0
		for _, p in parts(Buildings.build("farm", 1, "complete", CANON[hue])) do
			if p.Name == "Wheat" then
				wheat += 1
				if hex(p.Color) ~= hex(st.crop.stalk) then
					table.insert(out, `farm wheat {hue}: {hex(p.Color)}, want {hex(st.crop.stalk)}`)
				end
			end
		end
		if wheat == 0 then
			table.insert(out, `farm {hue}: no wheat rows to check`)
		end
		-- the quarry's rock takes the kingdom's stone
		for _, p in parts(Buildings.build("quarry", 1, "complete", CANON[hue])) do
			if p.Name == "RockFace" then
				local f = lstar(p.Color) - lstar(st.stone.base)
				if math.abs(f) > 20 then
					table.insert(
						out,
						`quarry {hue}: rock {hex(p.Color)} is far from the kingdom stone {hex(st.stone.base)}`
					)
				end
			end
		end
	end
	return out
end

-- the table itself: roles unambiguous, own colours never re-skinnable, accents distinct, deterministic data
local function tableViolations(): { string }
	local out = {}
	for _, r in KingdomStyle.ROLE_REFS do
		local role = KingdomStyle.roleOf(r.ref)
		if role ~= r.role then
			table.insert(out, `palette role {r.role} ({hex(r.ref)}) reads as {role}`)
		end
		for _, k in { 0.8, 0.9, 1.06 } do
			local s = Color3.new(r.ref.R * k, r.ref.G * k, r.ref.B * k)
			if KingdomStyle.roleOf(s) ~= r.role then
				table.insert(out, `palette role {r.role} shaded {k} reads as {KingdomStyle.roleOf(s)}`)
			end
		end
	end
	for _, hue in KINGDOMS do
		local st = KingdomStyle.get(hue)
		local fixed: { [string]: Color3? } = {
			stoneBase = st.stone.base,
			stoneLight = st.stone.light,
			stoneDark = st.stone.dark,
			stoneAccent = st.stone.accent,
			trim = st.trim,
			capColor = st.roof.capColor,
			altColor = st.roof.altColor,
			altColorLit = if st.roof.altColor then shade(st.roof.altColor, 1.1) else nil, -- the 3rd moss course
			ridgeColor = st.roof.ridgeColor,
		}
		for name, c in fixed do
			if KingdomStyle.roleOf(c :: Color3) ~= nil then
				table.insert(out, `{hue}.{name} {hex(c :: Color3)} would be re-skinned by the palette pass`)
			end
		end
		if hex(st.stone.accent) == hex(st.stone.light) or hex(st.stone.accent) == hex(st.stone.base) then
			table.insert(out, `{hue}: the plinth accent stone equals the plain stone`)
		end
		if st.id ~= hue then
			table.insert(out, `{hue}: style id {st.id}`)
		end
	end
	return out
end

-- every check by name; a mutant is run against the checks that must catch it (and the baseline against all)
local CHECKS: { [string]: (quick: boolean) -> { string } } = {
	differences = function(quick)
		return differenceViolations(if quick then QUICK_CASES else fullCases())
	end,
	silhouette = function()
		return silhouetteViolations()
	end,
	cues = function()
		return cueViolations()
	end,
	determinism = function(quick)
		return determinismViolations(if quick then QUICK_CASES else fullCases())
	end,
	counts = function(quick)
		return countViolations(if quick then QUICK_CASES else fullCases(), not quick)
	end,
	palette = function()
		return paletteViolations()
	end,
	table = function()
		return tableViolations()
	end,
}

local function allViolations(quick: boolean, only: { string }?): { string }
	local out = {}
	for name, check in CHECKS do
		if not only or table.find(only, name) then
			for _, v in check(quick) do
				table.insert(out, `[{name}] {v}`)
			end
		end
	end
	return out
end

local function expectClean(list: { string })
	if #list > 0 then
		error(`{#list} violations, e.g. ` .. table.concat(list, "; ", 1, math.min(#list, 6)))
	end
end

-- ------------------------------------------------------------------ the spec

describe("Kingdom architecture styles (FL-0127)", function()
	it("has one style per hue style plus the neutral original, with the right ids", function()
		for _, hue in KINGDOMS do
			expect(KingdomStyle.get(hue).id).toBe(hue)
			expect(Kit._hueStyle(CANON[hue])).toBe(hue)
		end
		expect(KingdomStyle.get("neutral")).toBe(KingdomStyle.NEUTRAL)
		expect(KingdomStyle.get(nil)).toBe(KingdomStyle.NEUTRAL)
		expect(KingdomStyle.get("nonsense")).toBe(KingdomStyle.NEUTRAL)
	end)

	it("makes the four kingdoms differ on every building type in the palette and in more than one attribute", function()
		expectClean(differenceViolations(fullCases()))
	end)

	it(
		"orders the roofs by silhouette (steep Emberhold to flat Sunspire), merlons, banner tails and stone value",
		function()
			expectClean(silhouetteViolations())
		end
	)

	it("keeps a tower-cap silhouette and an emblem unique per kingdom on every tower-bearing building", function()
		expectClean(cueViolations())
	end)

	it(
		"never adds or removes a part: every building, level, variant and stage has the neutral style's count",
		function()
			expectClean(countViolations(fullCases(), true))
		end
	)

	it("is deterministic: the same arguments build the same building, whatever was built in between", function()
		expectClean(determinismViolations(fullCases()))
	end)

	it(
		"re-skins stone, timber, plaster, thatch, grain and quarry rock with the kingdom's palette, and only those",
		function()
			expectClean(paletteViolations())
			expectClean(tableViolations())
		end
	)

	it("leaves kingdom-coloured parts to Kit.setKingdomColor: the palette pass never touches a KitTint part", function()
		for _, hue in KINGDOMS do
			local m = Buildings.build("barracks", 2, "complete", CANON[hue])
			local before = {}
			for i, p in parts(m) do
				before[i] = p.Color
			end
			KingdomStyle.paint(m, hue)
			for i, p in parts(m) do
				if p:GetAttribute("KitTint") ~= nil and p.Color ~= before[i] then
					error(`{p.Name} is kingdom-coloured and was repainted`)
				end
			end
		end
	end)

	it("keeps the neutral style the Kit's original look (outposts, props and uncaptured towers)", function()
		for _, c in QUICK_CASES do
			local m = Buildings.build(c.type, c.level, "complete", Kit.NEUTRAL_COLOR, c.variant)
			-- the neutral pass is the identity
			local again = Buildings.build(c.type, c.level, "complete", Kit.NEUTRAL_COLOR, c.variant)
			KingdomStyle.paint(again, "neutral")
			expect(fullSignature(again)).toBe(fullSignature(m))
		end
		local m = Buildings.build("watchtower", 1, "complete", Kit.NEUTRAL_COLOR)
		local merlons = 0
		for _, p in parts(m) do
			if p.Name == "Plinth" then
				expect(hex(p.Color)).toBe(hex(Color3.fromRGB(111, 106, 99))) -- C.stoneDark, as built
			elseif p.Name == "Merlon" then
				merlons += 1
				expect(p.Size.Y).toBeNear(2.4, 1e-3) -- crenellate's proportions, as built
				expect(math.max(p.Size.X, p.Size.Z)).toBeNear(1.9, 1e-3)
			end
		end
		expect(merlons).toBeGreaterThan(8)
	end)
end)

-- ------------------------------------------------------------------ mutants

describe("Kingdom style mutants are caught", function()
	local original = {
		styles = table.clone(KingdomStyle.STYLES),
		shapeRoof = KingdomStyle.shapeRoof,
		paint = KingdomStyle.paint,
		get = KingdomStyle.get,
	}
	local function restore()
		for k in KingdomStyle.STYLES do
			KingdomStyle.STYLES[k] = nil
		end
		for k, v in original.styles do
			KingdomStyle.STYLES[k] = v
		end
		KingdomStyle.shapeRoof = original.shapeRoof
		KingdomStyle.paint = original.paint
		KingdomStyle.get = original.get
	end
	local function cloneStyle(st: any): any
		local c = table.clone(st)
		c.roof = table.clone(st.roof)
		c.merlon = table.clone(st.merlon)
		c.banner = table.clone(st.banner)
		c.stone = table.clone(st.stone)
		return c
	end
	local function caught(name: string, by: { string }, mutate: () -> ())
		it(`catches: {name} (by {table.concat(by, ", ")})`, function()
			mutate()
			local ok, list = pcall(allViolations, true, by)
			restore()
			if not ok then
				error(`the mutant crashed instead of failing a check: {list}`)
			end
			if #(list :: { string }) == 0 then
				error(`mutant not caught: {name}`)
			end
		end)
	end

	it("passes the quick suite unmutated (the mutants' baseline)", function()
		expectClean(allViolations(true))
	end)

	caught("style ignored (every kingdom builds in the neutral style)", { "differences" }, function()
		for _, hue in KINGDOMS do
			KingdomStyle.STYLES[hue] = KingdomStyle.NEUTRAL
		end
	end)

	caught("two styles equal (Frostmere built as Thornwood)", { "differences" }, function()
		local s = cloneStyle(KingdomStyle.STYLES.emerald)
		s.id = "azure"
		KingdomStyle.STYLES.azure = s
	end)

	caught("a style adds parts (every gable roof gets one more tile course)", { "counts" }, function()
		KingdomStyle.shapeRoof = function(style, r, a, b)
			local out = original.shapeRoof(style, r, a, b)
			if out ~= r and out.rows then
				out = table.clone(out)
				out.rows += 1
			end
			return out
		end
	end)

	caught("palette pass skipped (timber, plaster and thatch stay neutral)", { "palette" }, function()
		KingdomStyle.paint = function() end
	end)

	caught("every roof the same pitch", { "silhouette" }, function()
		for _, hue in KINGDOMS do
			local s = cloneStyle(KingdomStyle.STYLES[hue])
			s.roof.pitch = 1
			KingdomStyle.STYLES[hue] = s
		end
	end)

	caught("merlon proportions ignored", { "silhouette" }, function()
		for _, hue in KINGDOMS do
			local s = cloneStyle(KingdomStyle.STYLES[hue])
			s.merlon = { w = 1, h = 1 }
			KingdomStyle.STYLES[hue] = s
		end
	end)

	caught("banner tails ignored (every banner ends in the diamond)", { "silhouette" }, function()
		for _, hue in KINGDOMS do
			local s = cloneStyle(KingdomStyle.STYLES[hue])
			s.banner.tip = "point"
			KingdomStyle.STYLES[hue] = s
		end
	end)

	caught("a style that is not deterministic (the pitch is drawn at random)", { "determinism" }, function()
		KingdomStyle.shapeRoof = function(style, r, a, b)
			local out = original.shapeRoof(style, r, a, b)
			if out ~= r then
				out = table.clone(out)
				out.rise = r.rise * (0.5 + math.random() * 1.5)
			end
			return out
		end
	end)

	caught("the plinth accent stone equals the plain stone", { "table" }, function()
		for _, hue in KINGDOMS do
			local s = cloneStyle(KingdomStyle.STYLES[hue])
			s.stone.accent = s.stone.light
			KingdomStyle.STYLES[hue] = s
		end
	end)

	caught("Sunspire built as Emberhold (the style lookup is remapped)", { "differences", "silhouette" }, function()
		local get = original.get
		KingdomStyle.get = function(style)
			return get(if style == "gold" then "crimson" else style)
		end
	end)
end)
