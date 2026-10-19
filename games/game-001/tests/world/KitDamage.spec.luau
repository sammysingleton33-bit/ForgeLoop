--[[
	Damage states on buildings (FL-0128, FORGE-02, Operation Crownfall): the model attribute `Damage` (0..1) is turned into
	parts by Kit.applyDamage (Kit/Damage.luau). This spec pins:

	  1. states     Damage 0 (and anything under 0.25 or not a number) is exactly the model as built; the four thresholds
	                0.25/0.5/0.75/0.95 add and remove exactly the documented cracks, soot, chips, rubble, a broken gate leaf
	                and missing parts, at most 14 extra parts, harmless to touch; cracks and soot are lit dark browns (every
	                channel above 40 / 255, never black), chips are paler stone, a gate keeps one broken leaf at 0.9, a
	                gate's two tower caps stay identical (a cap falls whole or not at all);
	  2. repair     deterministic, idempotent and reversible in any order: a repaired model is exactly the model as built;
	  3. burning    the Burning attribute and the model's top are untouched (FORGE-04's Burning look reads both), every mark
	                stays inside the model;
	  4. recolour   Kit.setKingdomColor works on damaged models and on the parts waiting for a repair;
	  5. mutants    the key rules above are caught when broken.
]]

local T = require("../../../../roblox/tests/harness/Test")
local describe, it = T.describe, T.it

local Kit = require("@game/ReplicatedStorage/Game/Kit/Kit")
local Damage = require("@game/ReplicatedStorage/Game/Kit/Damage")
local KingdomsConfig = require("@game/ReplicatedStorage/Forge/Config/Kingdoms")

local CANON: { [string]: Color3 } = {}
for _, identity in KingdomsConfig.identities do
	local c = identity.color
	CANON[identity.id] = Color3.fromRGB(c[1], c[2], c[3])
end
local MAX_LEVEL = { keep = 3, barracks = 4, wall = 3, gate = 3 }
-- everything a tower cap is made of (Kit/Damage CAP_PARTS)
local CAP_PARTS = {
	Drum = true,
	DrumBand = true,
	Dome = true,
	DomeTip = true,
	Spire = true,
	SpireEave = true,
	CapEave = true,
	Hoarding = true,
	HoardingBeam = true,
	RoofCorner = true,
	Finial = true,
	FinialBall = true,
}

-- ------------------------------------------------------------------ helpers

local function parts(model: Instance): { BasePart }
	local out = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(out, d)
		end
	end
	return out
end

local function count(model: Instance): number
	return #parts(model)
end

local function hist(model: Instance): { [string]: number }
	local h: { [string]: number } = {}
	for _, p in parts(model) do
		h[p.Name] = (h[p.Name] or 0) + 1
	end
	return h
end

local function halfExtents(p: BasePart): Vector3
	local cf, s = p.CFrame, p.Size
	local r, u, l = cf.RightVector, cf.UpVector, cf.LookVector
	return Vector3.new(
		(math.abs(r.X) * s.X + math.abs(u.X) * s.Y + math.abs(l.X) * s.Z) / 2,
		(math.abs(r.Y) * s.X + math.abs(u.Y) * s.Y + math.abs(l.Y) * s.Z) / 2,
		(math.abs(r.Z) * s.X + math.abs(u.Z) * s.Y + math.abs(l.Z) * s.Z) / 2
	)
end

local function topOf(model: Instance, skipDamage: boolean?): number
	local top = -math.huge
	for _, p in parts(model) do
		if p.Transparency < 1 and not (skipDamage and p:GetAttribute("KitDamage") == true) then
			top = math.max(top, p.CFrame.Position.Y + halfExtents(p).Y)
		end
	end
	return top
end

local function r3(n: number): string
	local v = math.floor(n * 1000 + 0.5) / 1000
	return if v == 0 then "0" else tostring(v)
end

-- every part as one line (name, class, shape, size, cframe, colour, material, transparency), sorted

local function signature(model: Instance, withCFrame: boolean?): string
	local rows = {}
	for _, p in parts(model) do
		local shape = if p:IsA("Part") then (p :: Part).Shape.Name else p.ClassName
		local s = p.Size
		local cf = ""
		if withCFrame ~= false then
			local comps = { p.CFrame:GetComponents() }
			for i, v in comps do
				comps[i] = r3(v)
			end
			cf = table.concat(comps, ",")
		end
		table.insert(
			rows,
			`{p.Name}|{p.ClassName}|{shape}|{r3(s.X)},{r3(s.Y)},{r3(s.Z)}|{cf}|{p.Color:ToHex()}|{p.Material.Name}|{r3(
				p.Transparency
			)}`
		)
	end
	table.sort(rows)
	return table.concat(rows, "\n")
end

type Check = () -> { string }
local CHECKS: { [string]: Check } = {}

local function shapeOf(p: BasePart): string
	if p:IsA("Part") and (p :: Part).Shape == Enum.PartType.Ball then
		return "ball"
	elseif p:IsA("Part") and (p :: Part).Shape == Enum.PartType.Cylinder then
		return "cylinder"
	end
	return "box"
end

-- ------------------------------------------------------------------ 6. damage

-- every building type at its highest level for Emberhold; a spread of four for Thornwood, whose hoarding roofs differ most;
-- `quick` (the mutants' run) is three small types in Emberhold
local FULL = {}
for _, bt in Kit.BUILDING_TYPES do
	table.insert(FULL, { bt, MAX_LEVEL[bt] or 2, "crimson" })
end
for _, bt in { "keep", "house", "wall", "gate" } do
	table.insert(FULL, { bt, MAX_LEVEL[bt] or 2, "emerald" })
end
local QUICK =
	{ { "house", 2, "crimson" }, { "wall", 2, "crimson" }, { "watchtower", 2, "crimson" }, { "gate", 3, "crimson" } }

local function damaged(bt: string, lv: number, hue: string, d: any): Model
	local m = Kit.build(bt, lv, "complete", CANON[hue])
	m:SetAttribute("Damage", d)
	Kit.applyDamage(m)
	return m
end

local function extras(m: Model, kind: string?): number
	local n = 0
	for _, c in m:GetChildren() do
		if
			c:IsA("BasePart")
			and c:GetAttribute("KitDamage") == true
			and (kind == nil or c:GetAttribute("KitDamageKind") == kind)
		then
			n += 1
		end
	end
	return n
end

local STATE_AT = { 0.25, 0.5, 0.75, 0.95 }

CHECKS.damage = function(quick: boolean?)
	local out: { string } = {}
	-- the table and the pure functions
	if table.concat(Kit.DAMAGE_THRESHOLDS, ",") ~= "0.25,0.5,0.75,0.95" or Damage.MAX_EXTRA_PARTS ~= 14 then
		table.insert(out, "thresholds are not 0.25/0.5/0.75/0.95 or the extra budget is not 14")
	end
	for _, c in
		{
			{ 0, 0 },
			{ 0.2499, 0 },
			{ 0.25, 1 },
			{ 0.4999, 1 },
			{ 0.5, 2 },
			{ 0.75, 3 },
			{ 0.9499, 3 },
			{ 0.95, 4 },
			{ 1, 4 },
			{ 7, 4 },
			{ -1, 0 },
			{ 0 / 0, 0 },
		}
	do
		if Kit.damageState(c[1]) ~= c[2] then
			table.insert(out, `damageState({c[1]}) = {Kit.damageState(c[1])}, want {c[2]}`)
		end
	end
	if Kit.damageState("0.9" :: any) ~= 0 or Kit.damageState(nil :: any) ~= 0 then
		table.insert(out, "damageState of a non-number must be 0")
	end
	for _, c in { { 50, 100, 0.5 }, { 0, 100, 1 }, { 100, 100, 0 }, { 150, 100, 0 }, { -5, 100, 1 }, { 1, 0, 0 } } do
		if math.abs(Kit.damageFromHp(c[1], c[2]) - c[3]) > 1e-9 then
			table.insert(out, `damageFromHp({c[1]}, {c[2]}) = {Kit.damageFromHp(c[1], c[2])}, want {c[3]}`)
		end
	end
	local cracks, rubble, soot, chips = Damage.CRACKS, Damage.RUBBLE, Damage.SOOT, Damage.CHIPS
	do
		for _, e in if quick then QUICK else FULL do
			local bt, lv, hue = e[1], e[2], e[3]
			local tag = `{bt} L{lv} {hue}`
			local base = Kit.build(bt, lv, "complete", CANON[hue])
			local baseSig, baseN, baseTop = signature(base), count(base), topOf(base)
			-- Damage 0 (and every non-number, and 0.2499) is exactly the model as built
			for _, zero in if quick then { 0, 0.2499 } else { 0, 0.2499, "x", 0 / 0 } do
				local z = damaged(bt, lv, hue, zero)
				if signature(z) ~= baseSig or z:GetAttribute("KitDamageState") ~= nil or extras(z) > 0 then
					table.insert(out, `{tag}: Damage {zero} is not the model as built`)
				end
			end
			local removedBefore = 0
			local baseHist = hist(base)
			local pool, topPart, topAt = 0, nil, -math.huge
			for _, p in parts(base) do
				if p.CFrame.Position.Y + p.Size.Y / 2 > topAt then
					topPart, topAt = p, p.CFrame.Position.Y + p.Size.Y / 2
				end
			end
			for _, p in parts(base) do
				if Damage.MISSING[p.Name] and p ~= topPart then
					pool += 1
				end
			end
			for s = 1, 4 do
				local m = damaged(bt, lv, hue, STATE_AT[s])
				local stag = `{tag} state {s}`
				if m:GetAttribute("KitDamageState") ~= s then
					table.insert(out, `{stag}: KitDamageState {m:GetAttribute("KitDamageState")}`)
				end
				local ex = extras(m)
				if ex > Damage.MAX_EXTRA_PARTS then
					table.insert(out, `{stag}: {ex} extra parts (cap 14)`)
				end
				local hasBody = extras(m, "crack") > 0
				if hasBody then
					if
						extras(m, "crack") ~= cracks[s]
						or extras(m, "rubble") ~= rubble[s]
						or extras(m, "chip") ~= chips[s]
					then
						table.insert(
							out,
							`{stag}: cracks {extras(m, "crack")}/{cracks[s]} chips {extras(m, "chip")}/{chips[s]} rubble {extras(
								m,
								"rubble"
							)}/{rubble[s]}`
						)
					end
				elseif not (bt == "wall" and lv == 1) then
					table.insert(out, `{stag}: no wall to crack`)
				end
				-- the stump (a slab on a tower whose cap fell): none before the corner collapses, at most one after
				if extras(m, "stump") > (if s >= 3 then 1 else 0) then
					table.insert(out, `{stag}: {extras(m, "stump")} stump parts`)
				end
				if hasBody and extras(m, "soot") ~= soot[s] then
					table.insert(out, `{stag}: soot {extras(m, "soot")}, want {soot[s]}`)
				end
				-- parts that went missing: monotone, at least the documented number where the model has them
				local removed = baseN - (count(m) - ex)
				if removed < removedBefore then
					table.insert(out, `{stag}: {removed} parts removed, fewer than state {s - 1} ({removedBefore})`)
				end
				removedBefore = removed
				-- a gate loses one leaf (with its bands) at state 1 and both from state 3
				local hm = hist(m)
				local leafGone = (baseHist.GateLeaf or 0)
					- (hm.GateLeaf or 0)
					+ (baseHist.LeafBand or 0)
					- (hm.LeafBand or 0)
				if (baseHist.GateLeaf or 0) > 0 then
					local wantLeaves = if s >= 3 then 0 else (baseHist.GateLeaf :: number) - 1
					if (hm.GateLeaf or 0) ~= wantLeaves then
						table.insert(out, `{stag}: {hm.GateLeaf or 0} gate leaves left, want {wantLeaves}`)
					end
				end
				-- a gate at 0.75 and above keeps one broken leaf (a damage part, so it stands whether the gate is open or shut);
				-- no other model has one
				local wantBroken = if (baseHist.GateLeaf or 0) > 0 and s >= 3 then 1 else 0
				if extras(m, "leaf") ~= wantBroken then
					table.insert(out, `{stag}: {extras(m, "leaf")} broken leaves, want {wantBroken}`)
				end
				-- a gate's two tower caps change the same way: whole, or not at all
				if bt == "gate" then
					local left, right = 0, 0
					for _, p in parts(m) do
						if CAP_PARTS[p.Name] then
							if p.CFrame.Position.X < 0 then
								left += 1
							else
								right += 1
							end
						end
					end
					if left ~= right then
						table.insert(out, `{stag}: the gate's tower caps differ ({left} parts left, {right} right)`)
					end
				end
				-- the parts that can go missing (not the highest part of the model): exactly the documented number, or all of
				-- them; the collapsed corner (state 3 and 4) takes more on top
				local want = math.min(Damage.REMOVED[s], pool)
				if removed - leafGone < want or (s <= 2 and removed - leafGone ~= want) then
					table.insert(
						out,
						`{stag}: {removed - leafGone} parts removed besides the leaves, want {want} (pool {pool}, table {Damage.REMOVED[s]})`
					)
				end
				-- state 1 is a bite, not a scatter: the removed parts lie close together, and the model visibly differs
				if s == 1 and want >= 3 then
					local keyOf = function(p: BasePart): string
						local at = p.CFrame.Position
						return `{p.Name}|{string.format("%.2f,%.2f,%.2f", at.X, at.Y, at.Z)}`
					end
					local present: { [string]: boolean } = {}
					for _, p in parts(m) do
						present[keyOf(p)] = true
					end
					local gone: { Vector3 } = {}
					for _, p in parts(base) do
						if Damage.MISSING[p.Name] and not present[keyOf(p)] then
							table.insert(gone, p.CFrame.Position)
						end
					end
					local sum = Vector3.zero
					for _, v in gone do
						sum += v
					end
					local centre = sum / math.max(#gone, 1)
					for _, v in gone do
						if (v - centre).Magnitude > 10 then
							table.insert(
								out,
								`{stag}: the bite is scattered ({r3((v - centre).Magnitude)} from its centre)`
							)
							break
						end
					end
				end
				if s == 1 and hasBody and ex < 3 then
					table.insert(out, `{stag}: state 1 adds only {ex} marks (cracks and soot)`)
				end
				-- the damage parts: cracks and soot are thin dark slabs lying on a face (opaque, never a wedge or a ball), rubble
				-- and the stump blocks; all harmless to touch
				for _, p in m:GetChildren() do
					if p:IsA("BasePart") and p:GetAttribute("KitDamage") == true then
						local kind = p:GetAttribute("KitDamageKind")
						if p.CanCollide or p.CanQuery or p.CanTouch then
							table.insert(out, `{stag}: a {kind} part can collide or be touched`)
						end
						-- a lit dark brown, never black: every channel at least 40 / 255 (32 for blue), the luminance still dark
						local c = p.Color
						local lum = 0.2126 * c.R + 0.7152 * c.G + 0.0722 * c.B
						local dark = c.R >= 40 / 255 and c.G >= 36 / 255 and c.B >= 32 / 255 and lum <= 0.3
						if
							kind == "crack"
							and not (
								shapeOf(p) == "box"
								and p.ClassName == "Part"
								and p.Size.Z <= 0.12
								and p.Size.X <= 0.4
								and dark
								and p.Transparency == 0
								and p.Material ~= Enum.Material.Neon
							)
						then
							table.insert(out, `{stag}: a crack is not a thin dark-brown slab`)
						elseif
							kind == "soot"
							and not (
								shapeOf(p) == "box"
								and p.ClassName == "Part"
								and p.Size.Z <= 0.12
								and p.Size.X >= 1.2
								and dark
								and p.Transparency == 0
								and p.Material ~= Enum.Material.Neon
							)
						then
							table.insert(
								out,
								`{stag}: soot is not a flat dark-brown opaque streak (not black, not Neon)`
							)
						elseif
							kind == "chip"
							and not (
								shapeOf(p) == "box"
								and p.Size.X <= 1.6
								and p.Size.Y <= 1.2
								and p.Size.Z <= 0.6
								and p.Transparency == 0
								and lum > 0.7
							)
						then
							table.insert(out, `{stag}: a chip is not a small block of pale stone`)
						elseif
							kind == "leaf"
							and not (
								shapeOf(p) == "box"
								and p.Size.Y >= 4
								and p.Size.Y <= 7
								and p.Size.X <= 3
								and p.Transparency == 0
							)
						then
							table.insert(out, `{stag}: the broken leaf is not a short board`)
						elseif (kind == "rubble" or kind == "stump") and shapeOf(p) ~= "box" then
							table.insert(out, `{stag}: rubble is not a block`)
						elseif
							kind ~= "crack"
							and kind ~= "soot"
							and kind ~= "chip"
							and kind ~= "leaf"
							and kind ~= "rubble"
							and kind ~= "stump"
						then
							table.insert(out, `{stag}: unknown damage kind {kind}`)
						end
					end
				end
				-- the Burning look reads the model's top: still the same part, no smoke above it
				if math.abs(topOf(m, true) - baseTop) > 1e-3 or topOf(m) > baseTop + 1e-3 then
					table.insert(out, `{stag}: the model's top moved ({r3(baseTop)} -> {r3(topOf(m))})`)
				end
				-- deterministic: the same build and damage, the same parts
				if signature(m) ~= signature(damaged(bt, lv, hue, STATE_AT[s])) then
					table.insert(out, `{stag}: not deterministic`)
				end
				-- repair: back to exactly the model as built
				m:SetAttribute("Damage", 0)
				Kit.applyDamage(m)
				if signature(m) ~= baseSig or m:GetAttribute("KitDamageState") ~= nil then
					table.insert(out, `{stag}: repair does not restore the model exactly`)
				end
			end
			-- any order, and applying twice is applying once
			local m = Kit.build(bt, lv, "complete", CANON[hue])
			for _, d in if quick then { 0.97, 0.3, 0.6, 0.1 } else { 0.97, 0.3, 0.6, 0.1, 0.8 } do
				m:SetAttribute("Damage", d)
				Kit.applyDamage(m)
				Kit.applyDamage(m)
				if signature(m) ~= signature(damaged(bt, lv, hue, d)) then
					table.insert(
						out,
						`{tag}: after the sequence ending at Damage {d} the model differs from a fresh one`
					)
					break
				end
			end
			-- a burning model still burns: the attribute is not touched
			local burning = Kit.build(bt, lv, "complete", CANON[hue])
			burning:SetAttribute("Burning", true)
			burning:SetAttribute("Hp", 12)
			burning:SetAttribute("MaxHp", 100)
			burning:SetAttribute("Damage", Kit.damageFromHp(12, 100))
			Kit.applyDamage(burning)
			if
				burning:GetAttribute("Burning") ~= true
				or burning:GetAttribute("Hp") ~= 12
				or burning:GetAttribute("MaxHp") ~= 100
			then
				table.insert(out, `{tag}: damage touched the Burning, Hp or MaxHp attributes`)
			end
			-- cracks and soot lie on the walls: inside the model's width and below its top
			do
				local lo, hi = math.huge, -math.huge
				for _, q in parts(base) do
					lo = math.min(lo, q.CFrame.Position.X - halfExtents(q).X)
					hi = math.max(hi, q.CFrame.Position.X + halfExtents(q).X)
				end
				for _, p in burning:GetChildren() do
					local kind = p:GetAttribute("KitDamageKind")
					if p:IsA("BasePart") and (kind == "crack" or kind == "soot" or kind == "chip") then
						local x = p.CFrame.Position.X
						if x < lo - 0.2 or x > hi + 0.2 or p.CFrame.Position.Y + halfExtents(p).Y > baseTop + 1e-3 then
							table.insert(
								out,
								`{tag}: a {kind} mark lies outside the model ({r3(x)} in {r3(lo)}..{r3(hi)})`
							)
						end
					end
				end
			end
			-- a gate opened while a leaf is knocked out comes back from repair in the open pose
			if bt == "gate" then
				local g = damaged(bt, lv, hue, 0.3)
				Kit.setGateOpen(g, true)
				g:SetAttribute("Damage", 0)
				Kit.applyDamage(g)
				local ref = Kit.build(bt, lv, "complete", CANON[hue])
				Kit.setGateOpen(ref, true)
				if signature(g) ~= signature(ref) then
					table.insert(out, `{tag}: a gate opened while a leaf was out is not the open gate after repair`)
				end
			end
			-- the kingdom colour still works on a damaged model, before and after the repair
			if bt ~= "wall" or lv > 1 then
				local newColor = Color3.fromRGB(196, 60, 52)
				local hurt = damaged(bt, lv, hue, 0.9)
				Kit.setKingdomColor(hurt, newColor)
				local fresh = damaged(bt, lv, hue, 0.9)
				Kit.setKingdomColor(fresh, newColor)
				local direct = Kit.build(bt, lv, "complete", CANON[hue])
				Kit.setKingdomColor(direct, newColor)
				direct:SetAttribute("Damage", 0.9)
				Kit.applyDamage(direct)
				if signature(hurt, false) ~= signature(direct, false) then
					table.insert(out, `{tag}: recolour then damage differs from damage then recolour`)
				end
				hurt:SetAttribute("Damage", 0)
				Kit.applyDamage(hurt)
				local plain = Kit.build(bt, lv, "complete", CANON[hue])
				Kit.setKingdomColor(plain, newColor)
				if signature(hurt, false) ~= signature(plain, false) then
					table.insert(out, `{tag}: parts that were off while recolouring come back in the old colour`)
				end
			end
		end
	end
	-- construction stages and part-less models ignore Damage
	local stage = damaged("keep", 1, "crimson", 0.9)
	stage:Destroy()
	local building = Kit.build("keep", 1, 1, CANON.crimson)
	building:SetAttribute("Damage", 0.9)
	Kit.applyDamage(building)
	if extras(building) > 0 or building:GetAttribute("KitDamageState") ~= nil then
		table.insert(out, "a construction stage was damaged")
	end
	local empty = Instance.new("Model")
	empty:SetAttribute("Damage", 0.9)
	local ok = pcall(Kit.applyDamage, empty)
	if not ok then
		table.insert(out, "a model without a PrimaryPart made applyDamage error")
	end
	return out
end

-- ------------------------------------------------------------------ the spec

local function expectClean(list: { string })
	if #list > 0 then
		error(`{#list} violations, e.g. ` .. table.concat(list, "; ", 1, math.min(#list, 6)))
	end
end

describe("Damage states (FL-0128)", function()
	it("adds and removes exactly the documented parts, deterministically and reversibly", function()
		expectClean(CHECKS.damage())
	end)
end)

-- ------------------------------------------------------------------ mutants

describe("Damage mutants are caught", function()
	local original = {
		build = Kit.build,
		applyDamage = Kit.applyDamage,
		setKingdomColor = Kit.setKingdomColor,
		stashed = Damage.stashed,
	}
	local function restore()
		Kit.build = original.build
		Kit.applyDamage = original.applyDamage
		Kit.setKingdomColor = original.setKingdomColor
		Damage.stashed = original.stashed
	end
	local function caught(name: string, by: string, mutate: () -> ())
		it(`catches: {name} (by {by})`, function()
			mutate()
			local ok, list = pcall(CHECKS[by], true)
			restore()
			if not ok then
				error(`the mutant crashed instead of failing a check: {list}`)
			end
			if #(list :: { string }) == 0 then
				error(`mutant not caught: {name}`)
			end
		end)
	end
	it("passes unmutated (the baseline)", function()
		for _, name in { "damage" } do
			expectClean(CHECKS[name]())
		end
	end)

	caught("applyDamage does nothing", "damage", function()
		Kit.applyDamage = function() end
	end)
	caught("Damage 0 still adds a part", "damage", function()
		Kit.applyDamage = function(m)
			original.applyDamage(m)
			if Damage.stateOf(m:GetAttribute("Damage")) == 0 then
				local p = Instance.new("Part")
				p.Name = "Soot"
				p:SetAttribute("KitDamage", true)
				p.Parent = m
			end
		end
	end)
	caught("the damage budget is exceeded", "damage", function()
		Kit.applyDamage = function(m)
			original.applyDamage(m)
			if Damage.stateOf(m:GetAttribute("Damage")) == 4 then
				for i = 1, 4 do
					local p = Instance.new("Part")
					p.Name = `Soot{i}`
					p.Anchored = true
					p.CanCollide = false
					p.CanTouch = false
					p.CanQuery = false
					p:SetAttribute("KitDamage", true)
					p:SetAttribute("KitDamageKind", "rubble")
					p.Parent = m
				end
			end
		end
	end)
	caught("a crack is a jutting wedge again", "damage", function()
		Kit.applyDamage = function(m)
			original.applyDamage(m)
			for _, p in m:GetChildren() do
				if p:IsA("BasePart") and p:GetAttribute("KitDamageKind") == "crack" then
					p.Size = Vector3.new(0.3, p.Size.Y, 0.6)
				end
			end
		end
	end)
	caught("soot is a translucent ball again", "damage", function()
		Kit.applyDamage = function(m)
			original.applyDamage(m)
			for _, p in m:GetChildren() do
				if p:IsA("Part") and p:GetAttribute("KitDamageKind") == "soot" then
					local ball = p :: Part
					ball.Shape = Enum.PartType.Ball
					ball.Transparency = 0.5
				end
			end
		end
	end)
	local function eachMark(m: Model, kinds: { string }, fn: (BasePart) -> ())
		for _, p in m:GetChildren() do
			if p:IsA("BasePart") and table.find(kinds, tostring(p:GetAttribute("KitDamageKind"))) then
				fn(p)
			end
		end
	end
	caught("soot is pure black again", "damage", function()
		Kit.applyDamage = function(m)
			original.applyDamage(m)
			eachMark(m, { "soot" }, function(p)
				p.Color = Color3.fromRGB(10, 8, 8)
			end)
		end
	end)
	caught("cracks are pure black again", "damage", function()
		Kit.applyDamage = function(m)
			original.applyDamage(m)
			eachMark(m, { "crack" }, function(p)
				p.Color = Color3.fromRGB(20, 18, 16)
			end)
		end
	end)
	caught("soot glows (Neon)", "damage", function()
		Kit.applyDamage = function(m)
			original.applyDamage(m)
			eachMark(m, { "soot" }, function(p)
				p.Material = Enum.Material.Neon
			end)
		end
	end)
	caught("the chipped stone is gone", "damage", function()
		Kit.applyDamage = function(m)
			original.applyDamage(m)
			eachMark(m, { "chip" }, function(p)
				p:Destroy()
			end)
		end
	end)
	caught("the chips are as dark as the soot", "damage", function()
		Kit.applyDamage = function(m)
			original.applyDamage(m)
			eachMark(m, { "chip" }, function(p)
				p.Color = Color3.fromRGB(80, 66, 56)
			end)
		end
	end)
	caught("a gate at 0.9 loses its broken leaf (reads as open, not ruined)", "damage", function()
		Kit.applyDamage = function(m)
			original.applyDamage(m)
			eachMark(m, { "leaf" }, function(p)
				p:Destroy()
			end)
		end
	end)
	caught("one gate tower loses a piece of its roof", "damage", function()
		Kit.applyDamage = function(m)
			original.applyDamage(m)
			if Damage.stateOf(m:GetAttribute("Damage")) >= 1 and m:GetAttribute("KitType") == "gate" then
				for _, p in m:GetChildren() do
					if p:IsA("BasePart") and p.Name == "Spire" and p.CFrame.Position.X > 0 then
						p:Destroy()
						break
					end
				end
			end
		end
	end)
	caught("state 1 takes nothing off the model", "damage", function()
		Kit.applyDamage = function(m)
			original.applyDamage(m)
			if Damage.stateOf(m:GetAttribute("Damage")) == 1 then
				for _, p in Damage.stashed(m) do
					p.Parent = m
				end
			end
		end
	end)
	caught("the bite is scattered along the crenellation", "damage", function()
		Kit.applyDamage = function(m)
			original.applyDamage(m)
			if Damage.stateOf(m:GetAttribute("Damage")) == 1 then
				for _, p in Damage.stashed(m) do
					p.Parent = m
				end
				local merlons = {}
				for _, p in m:GetChildren() do
					if p:IsA("BasePart") and p.Name == "Merlon" then
						table.insert(merlons, p)
					end
				end
				table.sort(merlons, function(a, b)
					return a.CFrame.X < b.CFrame.X
				end)
				for i = 1, 4 do
					local p = merlons[1 + (i - 1) * math.max(1, math.floor(#merlons / 4))]
					if p then
						p.Parent = nil
					end
				end
			end
		end
	end)
	caught("a gate keeps both its leaves under fire", "damage", function()
		Kit.applyDamage = function(m)
			original.applyDamage(m)
			if Damage.stateOf(m:GetAttribute("Damage")) >= 1 then
				for _, p in Damage.stashed(m) do
					if p.Name == "GateLeaf" or p.Name == "LeafBand" then
						p.Parent = m
					end
				end
			end
		end
	end)
	caught("damage is random", "damage", function()
		Kit.applyDamage = function(m)
			original.applyDamage(m)
			for _, p in m:GetChildren() do
				if p:IsA("BasePart") and p:GetAttribute("KitDamageKind") == "crack" then
					p.CFrame = p.CFrame + Vector3.new(math.random(), 0, 0)
				end
			end
		end
	end)
	caught("a repair leaves the damage parts behind", "damage", function()
		Kit.applyDamage = function(m)
			local before = m:GetAttribute("KitDamageState")
			original.applyDamage(m)
			if Damage.stateOf(m:GetAttribute("Damage")) == 0 and before ~= nil then
				local p = Instance.new("Part")
				p.Name = "Stain"
				p:SetAttribute("KitDamage", true)
				p.Parent = m
			end
		end
	end)
	caught("damage clears the Burning attribute", "damage", function()
		Kit.applyDamage = function(m)
			original.applyDamage(m)
			m:SetAttribute("Burning", nil)
		end
	end)
	caught("damage removes the top of the model", "damage", function()
		Kit.applyDamage = function(m)
			original.applyDamage(m)
			if Damage.stateOf(m:GetAttribute("Damage")) >= 2 then
				local top, topY = nil, -math.huge
				for _, p in parts(m) do
					if p:GetAttribute("KitDamage") ~= true and p.CFrame.Position.Y + halfExtents(p).Y > topY then
						top, topY = p, p.CFrame.Position.Y + halfExtents(p).Y
					end
				end
				if top then
					top:Destroy()
				end
			end
		end
	end)
	caught("the recolour forgets the parts waiting for a repair", "damage", function()
		Damage.stashed = function()
			return {}
		end
	end)
	caught("damage is applied to construction stages", "damage", function()
		Kit.build = function(bt, lv, stage, ...)
			local m = original.build(bt, lv, stage, ...)
			if stage ~= "complete" then
				m:SetAttribute("KitStage", "complete")
			end
			return m
		end
	end)
end)
