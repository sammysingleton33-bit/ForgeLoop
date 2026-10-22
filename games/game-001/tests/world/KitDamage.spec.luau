--[[
	Damage states on buildings (FL-0128, FORGE-02, Operation Crownfall): the model attribute `Damage` (0..1) is turned into
	parts by Kit.applyDamage (Kit/Damage.luau). This spec pins:

	  1. states     Damage 0 (and anything under 0.25 or not a number) is exactly the model as built; the four thresholds
	                0.25/0.5/0.75/0.95 add and remove exactly the documented breaches, hairline cracks, chips, rubble, a
	                broken gate leaf and missing parts, at most 14 extra parts, harmless to touch; BREACH MARKS read as broken
	                stone, not stickers: each is the colour of the wall it sits on (a recess 0.5-0.9x its value, a hairline
	                crack 0.65-0.92x, chips 1.05-1.6x; luminance above 0.1, never black, never Neon), lies on the
	                FRONT face and wholly inside that wall block (nothing overhangs a silhouette); a gate keeps one broken leaf
	                at 0.9, a gate's two tower caps stay identical (a cap falls whole or not at all);
	  2. repair     deterministic, idempotent and reversible in any order: a repaired model is exactly the model as built;
	  2b. frames    damage is worked out in the model's OWN frame (the pivot): a model turned (90, 180 degrees) or moved (to any
	                height, with WorldView.placeModel) before it is damaged is damaged exactly like one at the origin, a model
	                moved after it is damaged takes its marks, its rubble and the parts it lost along (repair puts every part back
	                exactly in place at the new spot), rubble stands on the model's base plane at any height, every wall and gate
	                level of the four kingdoms stays inside the model's own bounds with at most 14 extra parts, the L1 palisade's
	                marks are spread over its logs and posts, each wholly inside one and below its top, and a level the Kit does
	                not have (a wall asked for at level 5) is damaged like the level it really is;
	  3. burning    the Burning attribute and the model's top are untouched (FORGE-04's Burning look reads both), every mark
	                stays inside the model;
	  4. recolour   Kit.setKingdomColor works on damaged models and on the parts waiting for a repair;
	  4b. order     Kit.build numbers every part of a model (the part attribute KitOrder: unique integers 1..n), the damage
	                walks that order (reversing the numbers changes which parts are chosen), and float noise on the parts
	                (1e-4, what a turn or a move leaves) does not change a choice the numbers decide (without them it does:
	                keep L1 and L3, barracks L4 and granary L2 at state 1 change);
	  5. mutants    the key rules above are caught when broken.
]]

local T = require("../../../../roblox/tests/harness/Test")
local describe, it = T.describe, T.it

local Kit = require("@game/ReplicatedStorage/Game/Kit/Kit")
local Damage = require("@game/ReplicatedStorage/Game/Kit/Damage")
local WorldView = require("@game/ReplicatedStorage/Game/Sim/WorldView")
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

local function luminance(c: Color3): number
	return 0.2126 * c.R + 0.7152 * c.G + 0.0722 * c.B
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
-- the lower wall and gate levels too: the L1 palisade (logs and posts, no wall block) is the odd one out
for _, e in { { "wall", 1, "crimson" }, { "wall", 2, "crimson" }, { "gate", 1, "crimson" }, { "gate", 2, "crimson" } } do
	table.insert(FULL, e)
end
local QUICK = {
	{ "house", 2, "crimson" },
	{ "wall", 2, "crimson" },
	{ "wall", 2, "azure" }, -- a pale wall: a mark in its own colour is not "within 0.06" of it
	{ "wall", 1, "crimson" }, -- the palisade: marks on logs and posts, at the floor of the mark colours
	{ "watchtower", 2, "crimson" },
	{ "gate", 3, "crimson" },
}

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
	local cracks, rubble, breach, chips = Damage.CRACKS, Damage.RUBBLE, Damage.BREACH, Damage.CHIPS
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
				if hasBody and extras(m, "breach") ~= breach[s] then
					table.insert(out, `{stag}: breaches {extras(m, "breach")}, want {breach[s]}`)
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
					table.insert(out, `{stag}: state 1 adds only {ex} marks (a breach, a crack and chips)`)
				end
				-- the damage parts: breaches, hairline cracks and chips are thin boxes of the wall's own stone lying on its front face
				-- (opaque, never a wedge or a ball), rubble and the stump blocks; all harmless to touch
				local supports: { BasePart } = {} -- the wall blocks a mark may sit on: upright blocks at least 3 tall, not a plinth
				local standIn = m:GetAttribute("KitStandIn") == true -- the VS-2 stand-ins (mine, market, granary, shrine) have posts, not walls
				for _, q in parts(m) do
					if not standIn and q:GetAttribute("KitDamage") ~= true and q:IsA("Part") and q.Transparency < 1 then
						local shape = (q :: Part).Shape
						if q.Name == "Palisade" then -- the L1 palisade's logs: vertical cylinders, a mark sits inside one
							if shape == Enum.PartType.Cylinder then
								table.insert(supports, q)
							end
						elseif
							shape == Enum.PartType.Block
							and q.Size.Y >= 3
							and q.Name ~= "Plinth"
							and math.abs(q.CFrame.UpVector.Y) > 0.99
							and math.abs(q.CFrame.LookVector.Z) > 0.99
						then
							table.insert(supports, q)
						end
					end
				end
				for _, p in m:GetChildren() do
					if p:IsA("BasePart") and p:GetAttribute("KitDamage") == true then
						local kind = p:GetAttribute("KitDamageKind")
						if p.CanCollide or p.CanQuery or p.CanTouch then
							table.insert(out, `{stag}: a {kind} part can collide or be touched`)
						end
						-- breach marks are the supporting wall's own stone, shaded (see `supports` below), never black, never Neon
						local c = p.Color
						local lum = luminance(c)
						local notBlack = lum >= 0.1 and math.max(c.R, c.G, c.B) >= 40 / 255
						local lit = p.Transparency == 0
							and p.Material ~= Enum.Material.Neon
							and p.Material ~= Enum.Material.Glass
						if kind == "breach" or kind == "crack" or kind == "chip" then
							local sizeOk = if kind == "breach"
								then p.Size.Z <= 0.12 and p.Size.X >= 0.6 and p.Size.Y <= 4.4
								elseif kind == "crack" then p.Size.Z <= 0.1 and p.Size.X <= 0.2
								else p.Size.X <= 1.5 and p.Size.Y <= 1.1 and p.Size.Z <= 0.5
							-- the floor of the marks on an untinted wall: no channel under (44,40,36) / 255 (a spec pins it so that a
							-- floor lowered towards black is caught: the palisade's posts are dark enough to sit on it)
							local underFloor = p:GetAttribute("KitTint") == nil
								and (c.R * 255 < 43.5 or c.G * 255 < 39.5 or c.B * 255 < 35.5)
							if shapeOf(p) ~= "box" or p.ClassName ~= "Part" or not sizeOk then
								table.insert(out, `{stag}: a {kind} is not a thin box of the right size`)
							elseif not (notBlack and lit) or underFloor then
								table.insert(out, `{stag}: a {kind} is black, glowing or see-through`)
							elseif math.abs(p.CFrame.LookVector.Z) < 0.99 then
								table.insert(out, `{stag}: a {kind} is not on the front face`)
							else
								-- the wall blocks it can sit on: wholly inside one (x and y), on its front face
								local pe, cp = halfExtents(p), p.CFrame.Position
								local ok, band = false, false
								local lo, hi = 0.5, 0.9
								if kind == "crack" then
									lo, hi = 0.65, 0.92
								elseif kind == "chip" then
									lo, hi = 1.05, 1.6
								end
								ok = standIn -- a stand-in has no wall to hold the mark inside
								for _, sup in supports do
									local se, sp = halfExtents(sup), sup.CFrame.Position
									if
										math.abs(cp.X - sp.X) + pe.X <= se.X + 0.05
										and math.abs(cp.Y - sp.Y) + pe.Y <= se.Y + 0.05
										and cp.Z < sp.Z - se.Z + 0.2
										and cp.Z > sp.Z - se.Z - 0.8
									then
										ok = true
										local ratio = lum / math.max(luminance(sup.Color), 1e-3)
										-- a light wall's mark must be in the band by ratio; only a wall so dark that the marks' floor
										-- (44,40,36) keeps them from the band (the palisade's posts) may be within 0.06 of it
										band = band
											or (ratio >= lo and ratio <= hi)
											or (
												luminance(sup.Color) < 0.25
												and math.abs(lum - luminance(sup.Color)) < 0.06
											)
									end
								end
								if not ok then
									table.insert(
										out,
										`{stag}: a {kind} overhangs or floats off the wall it sits on ({r3(cp.X)}, {r3(
											cp.Y
										)})`
									)
								elseif not band and not standIn then
									table.insert(
										out,
										`{stag}: a {kind} is not within {lo}-{hi}x of its wall's value (a dark patch, not stone)`
									)
								end
							end
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
							kind ~= "breach"
							and kind ~= "crack"
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
			-- breaches, cracks and chips lie on the walls: inside the model's width and below its top
			do
				local lo, hi = math.huge, -math.huge
				for _, q in parts(base) do
					lo = math.min(lo, q.CFrame.Position.X - halfExtents(q).X)
					hi = math.max(hi, q.CFrame.Position.X + halfExtents(q).X)
				end
				for _, p in burning:GetChildren() do
					local kind = p:GetAttribute("KitDamageKind")
					if p:IsA("BasePart") and (kind == "breach" or kind == "crack" or kind == "chip") then
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

-- ------------------------------------------------------------------ 7. frames: turned, moved, at any height

local function pivotOf(m: Model): CFrame
	local root = m.PrimaryPart :: BasePart
	return root.CFrame * root.PivotOffset
end

-- every part of a model in the model's OWN frame (its pivot), bucketed by what it is (name, shape, size, colour, material, damage
-- kind): the same damaged model gives the same buckets wherever it stands. CFrames are 32-bit floats in Roblox (and in the Lune
-- mock), so two placements of one model differ in the last digits: buckets are compared with a tolerance, not as text.
type Rows = { [string]: { { number } } }
local function frameRows(model: Model, world: boolean?): Rows
	local inv = if world then CFrame.new() else pivotOf(model):Inverse()
	local rows: Rows = {}
	for _, p in parts(model) do
		local shape = if p:IsA("Part") then (p :: Part).Shape.Name else p.ClassName
		local s = p.Size
		local key = `{p.Name}|{shape}|{r3(s.X)},{r3(s.Y)},{r3(s.Z)}|{p.Color:ToHex()}|{p.Material.Name}|{p:GetAttribute(
			"KitDamageKind"
		)}`
		rows[key] = rows[key] or {}
		table.insert(rows[key], { (inv * p.CFrame):GetComponents() })
	end
	return rows
end

-- nil when the two are the same parts in the same places (within 0.002), else what differs first
local function rowsDiff(a: Rows, b: Rows): string?
	for key, list in a do
		local other = b[key]
		if other == nil or #other ~= #list then
			return `{key}: {#list} here, {if other then #other else 0} there`
		end
		local free = table.clone(other)
		for _, comps in list do
			local at = nil
			for i, cand in free do
				local same = true
				for j = 1, 12 do
					if math.abs(cand[j] - comps[j]) > 0.002 then
						same = false
						break
					end
				end
				if same then
					at = i
					break
				end
			end
			if at == nil then
				local c = comps
				return `{key}: nothing there at ({r3(c[1])}, {r3(c[2])}, {r3(c[3])})`
			end
			table.remove(free, at)
		end
	end
	for key, other in b do
		if a[key] == nil then
			return `{key}: {#other} there, none here`
		end
	end
	return nil
end

-- WorldView.placeModel is what puts every building in the world: the pivot lands on the CFrame, parts parked off the model stay
local function moveTo(m: Model, at: Vector3, yawDeg: number)
	WorldView.placeModel(m, CFrame.new(at) * CFrame.Angles(0, math.rad(yawDeg), 0))
end

-- { type, level, kingdom, every state and both turns }: the wall and gate levels are the ones that matter, the other types at their top
-- level get one turn and two states
local FRAMES_QUICK: { { any } } = {
	{ "wall", 1, "crimson", true },
	{ "wall", 2, "crimson", true },
	{ "gate", 2, "crimson", true },
	{ "watchtower", 2, "crimson", false },
	{ "keep", 1, "crimson", false },
}
local FRAMES_FULL: { { any } } = {}
for _, hue in { "crimson", "azure", "emerald", "gold" } do
	for lv = 1, 3 do
		table.insert(FRAMES_FULL, { "wall", lv, hue, true })
		table.insert(FRAMES_FULL, { "gate", lv, hue, true })
	end
end
for _, bt in Kit.BUILDING_TYPES do
	if bt ~= "wall" and bt ~= "gate" then
		table.insert(FRAMES_FULL, { bt, MAX_LEVEL[bt] or 2, "crimson", false })
	end
end
table.insert(FRAMES_FULL, { "keep", 1, "crimson", false })
table.insert(FRAMES_FULL, { "keep", 2, "crimson", false })

CHECKS.frames = function(quick: boolean?)
	local out: { string } = {}
	-- a first spot 40 studs up and a second well off the origin, each with its own turn
	local spots = { Vector3.new(123.4, 40, -77.7), Vector3.new(-310.25, 3.5, 58.1) }
	for _, e in if quick then FRAMES_QUICK else FRAMES_FULL do
		local bt, lv, hue, every = e[1], e[2], e[3], e[4]
		local yaws = if every and not quick then { 90, 180 } else { 90 }
		local states = if every and not quick then { 1, 2, 3, 4 } else { 2, 4 }
		local tag = `{bt} L{lv} {hue}`
		local base = Kit.build(bt, lv, "complete", CANON[hue])
		local baseRows = frameRows(base)
		-- the bounds the damage parts must stay inside, in the model's own frame: the as-built extent of the visible parts
		-- (x and y), a little in front for the rubble and the chips (z), and nothing above the top or below the base plane
		local lo, hi = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
		for _, p in parts(base) do
			if p ~= base.PrimaryPart and p.Transparency < 1 then
				local c, h = p.CFrame.Position, halfExtents(p)
				lo, hi = lo:Min(c - h), hi:Max(c + h)
			end
		end
		for si, s in states do
			local d = STATE_AT[s]
			local stag = `{tag} state {s}`
			local ref = damaged(bt, lv, hue, d)
			local refRows = frameRows(ref)
			-- the budget, and the bounds (every damage part, in the model's own frame)
			if extras(ref) > Damage.MAX_EXTRA_PARTS then
				table.insert(out, `{stag}: {extras(ref)} extra parts (cap {Damage.MAX_EXTRA_PARTS})`)
			end
			for _, p in ref:GetChildren() do
				if p:IsA("BasePart") and p:GetAttribute("KitDamage") == true then
					local c, h = p.CFrame.Position, halfExtents(p)
					local kind = p:GetAttribute("KitDamageKind")
					-- breaches, cracks, chips and the broken leaf lie inside the box of the model as built; rubble (the foot of the
					-- corner, in front) and the stump may reach 0.6 past a side, rubble 4 in front; nothing above the top or under
					-- the base plane
					local out2 = if kind == "rubble" or kind == "stump" then 0.6 else 0.01
					local front = if kind == "rubble" then 4 else 0.01
					if
						c.X - h.X < lo.X - out2
						or c.X + h.X > hi.X + out2
						or c.Y - h.Y < -0.3
						or c.Y + h.Y > hi.Y + 1e-3
						or c.Z - h.Z < lo.Z - front
						or c.Z + h.Z > hi.Z + 0.01
					then
						table.insert(
							out,
							`{stag}: a {p:GetAttribute("KitDamageKind")} lies outside the model's own bounds ({r3(c.X)}, {r3(
								c.Y
							)}, {r3(c.Z)})`
						)
					end
				end
			end
			-- plain repair, the model not moved: exactly the model as built (every wall and gate level, four kingdoms, every state)
			do
				local fixed = damaged(bt, lv, hue, d)
				fixed:SetAttribute("Damage", 0)
				Kit.applyDamage(fixed)
				local left = rowsDiff(baseRows, frameRows(fixed))
				if left or count(fixed) ~= count(base) or #Damage.stashed(fixed) > 0 then
					table.insert(
						out,
						`{stag}: repair does not restore the model exactly ({left or "parts left parked or doubled"})`
					)
				end
			end
			-- turned (and moved to another height) BEFORE the damage: exactly the damage of the model at the origin
			for i, yaw in yaws do
				local at = spots[i]
				local t = Kit.build(bt, lv, "complete", CANON[hue])
				moveTo(t, at, yaw)
				t:SetAttribute("Damage", d)
				Kit.applyDamage(t)
				local diff = rowsDiff(refRows, frameRows(t))
				if diff then
					table.insert(
						out,
						`{stag}: turned {yaw} degrees and moved to y {at.Y}, the damage differs in the model's own frame ({diff})`
					)
				end
				-- rubble stands on the model's base plane wherever that is (y = 40 for the first spot)
				for _, p in t:GetChildren() do
					if p:IsA("BasePart") and p:GetAttribute("KitDamageKind") == "rubble" then
						local bottom = p.CFrame.Position.Y - p.Size.Y / 2
						if math.abs(bottom - (at.Y - 0.2)) > 0.01 then
							table.insert(
								out,
								`{stag}: rubble rests at world y {r3(bottom)}, not on the base plane ({r3(at.Y - 0.2)})`
							)
							break
						end
					end
				end
				-- the repair after that move is exactly the model as built
				t:SetAttribute("Damage", 0)
				Kit.applyDamage(t)
				if rowsDiff(baseRows, frameRows(t)) then
					table.insert(out, `{stag}: repair after the turn does not restore the model exactly`)
				end
			end
			-- moved AFTER the damage: the marks, the rubble and the parts that were taken off all follow the model
			local m = damaged(bt, lv, hue, d)
			moveTo(m, spots[1], yaws[1])
			if rowsDiff(refRows, frameRows(m)) then
				table.insert(out, `{stag}: the damage did not follow the model when it was moved`)
			end
			m:SetAttribute("Damage", 0)
			Kit.applyDamage(m)
			local back = rowsDiff(baseRows, frameRows(m))
			if back then
				table.insert(out, `{stag}: repair after a move leaves parts behind ({back})`)
			end
			local other = states[1 + si % #states]
			-- the G13.9 move (WorldView.placeModel on a damaged building: FORGE-04's FL-0143): damaged, moved to a new place AND a
			-- new yaw, repaired: EVERY part is where it is in a pristine copy moved the same way, in world CFrames (nothing left
			-- at the old place, nothing doubled); then damaged again at another state in the new place: the same as a copy moved
			-- the same way and damaged at that state
			do
				local pristine = Kit.build(bt, lv, "complete", CANON[hue])
				moveTo(pristine, spots[2], yaws[#yaws])
				local mv = damaged(bt, lv, hue, d)
				moveTo(mv, spots[2], yaws[#yaws])
				mv:SetAttribute("Damage", 0)
				Kit.applyDamage(mv)
				local drift = rowsDiff(frameRows(pristine, true), frameRows(mv, true))
				if drift then
					table.insert(
						out,
						`{stag}: after a move and a repair a part is not where the pristine copy has it ({drift})`
					)
				end
				if count(mv) ~= count(pristine) or #Damage.stashed(mv) > 0 then
					table.insert(
						out,
						`{stag}: after a move and a repair the model has {count(mv)} parts (pristine {count(pristine)}) and {#Damage.stashed(
							mv
						)} still parked`
					)
				end
				mv:SetAttribute("Damage", STATE_AT[other])
				Kit.applyDamage(mv)
				local twin = Kit.build(bt, lv, "complete", CANON[hue])
				moveTo(twin, spots[2], yaws[#yaws])
				twin:SetAttribute("Damage", STATE_AT[other])
				Kit.applyDamage(twin)
				local again = rowsDiff(frameRows(twin, true), frameRows(mv, true))
				if again then
					table.insert(out, `{stag}: damaged again at state {other} after a move and a repair ({again})`)
				end
			end
			-- moved twice, then damaged again at another state: the same as a fresh model at that state
			local m2 = damaged(bt, lv, hue, d)
			moveTo(m2, spots[1], yaws[1])
			moveTo(m2, spots[2], yaws[#yaws])
			m2:SetAttribute("Damage", STATE_AT[other])
			Kit.applyDamage(m2)
			local again = rowsDiff(frameRows(damaged(bt, lv, hue, STATE_AT[other])), frameRows(m2))
			if again then
				table.insert(
					out,
					`{stag}: after two moves, state {other} differs from a fresh model at that state ({again})`
				)
			end
		end
		-- a gate opened while a leaf is out, then moved and repaired: the open gate, in place
		if bt == "gate" then
			local g = damaged(bt, lv, hue, 0.3)
			Kit.setGateOpen(g, true)
			moveTo(g, spots[1], yaws[1])
			g:SetAttribute("Damage", 0)
			Kit.applyDamage(g)
			local ref = Kit.build(bt, lv, "complete", CANON[hue])
			Kit.setGateOpen(ref, true)
			if rowsDiff(frameRows(ref), frameRows(g)) then
				table.insert(
					out,
					`{tag}: a gate opened and moved while a leaf was out does not repair to the open gate`
				)
			end
		end
	end
	-- re-dressing a model turned a quarter turn (or half): every damage part stays inside the footprint, in the model's own
	-- frame, at every state it is re-dressed to (a world-axes damage drops rubble outside it): the sides and the back strictly,
	-- the front no more than 2 studs beyond (the Kit's own allowance for entrance steps; only rubble goes that far)
	local footEntries = if quick
		then { { "keep", 1 }, { "wall", 2 } }
		else {
			{ "keep", 1 },
			{ "keep", 2 },
			{ "keep", 3 },
			{ "wall", 1 },
			{ "wall", 2 },
			{ "wall", 3 },
			{ "gate", 1 },
			{ "gate", 3 },
			{ "watchtower", 1 },
			{ "watchtower", 2 },
			{ "house", 1 },
			{ "house", 2 },
		}
	for _, e in footEntries do
		local bt, lv = e[1], e[2]
		local fp = Kit.footprint(bt, lv)
		for yi, yaw in if quick then { 90, 270 } else { 90, 180, 270 } do
			local t = Kit.build(bt, lv, "complete", CANON.crimson)
			moveTo(t, spots[1 + yi % 2], yaw)
			local inv = pivotOf(t):Inverse()
			for _, d in if quick then { 0.6, 0.97 } else { 0.3, 0.97, 0.6, 0.75, 0, 0.5, 0.95 } do
				t:SetAttribute("Damage", d)
				Kit.applyDamage(t)
				for _, p in t:GetChildren() do
					local kind = p:GetAttribute("KitDamageKind")
					if p:IsA("BasePart") and kind ~= nil then
						local cf = inv * p.CFrame
						local lc = cf.Position
						-- the half extents in the model's frame
						local r, u, l = cf.RightVector, cf.UpVector, cf.LookVector
						local hx = (math.abs(r.X) * p.Size.X + math.abs(u.X) * p.Size.Y + math.abs(l.X) * p.Size.Z) / 2
						local hz = (math.abs(r.Z) * p.Size.X + math.abs(u.Z) * p.Size.Y + math.abs(l.Z) * p.Size.Z) / 2
						local front = if kind == "rubble" then 2.05 else 0.05
						if
							math.abs(lc.X) + hx > fp.X / 2 + 0.05
							or lc.Z - hz < -fp.Y / 2 - front
							or lc.Z + hz > fp.Y / 2 + 0.05
						then
							table.insert(
								out,
								`{bt} L{lv} turned {yaw}, re-dressed to Damage {d}: a {kind} lies outside the footprint {fp.X}x{fp.Y} (x {r3(
									lc.X
								)} +-{r3(hx)}, z {r3(lc.Z)} +-{r3(hz)})`
							)
						end
					end
				end
			end
		end
	end
	-- the L1 palisade: its marks are spread over its logs and posts, each wholly inside one and below its top
	for _, hue in if quick then { "crimson" } else { "crimson", "azure", "emerald", "gold" } do
		for _, s in { 1, 2, 3, 4 } do
			local m = damaged("wall", 1, hue, STATE_AT[s])
			local stag = `palisade {hue} state {s}`
			local supports: { BasePart } = {}
			for _, p in parts(m) do
				if p.Name == "Palisade" or p.Name == "PalisadePost" then
					table.insert(supports, p)
				end
			end
			local used: { [BasePart]: boolean } = {}
			local nMarks = 0
			for _, p in m:GetChildren() do
				local kind = p:GetAttribute("KitDamageKind")
				if p:IsA("BasePart") and (kind == "breach" or kind == "crack" or kind == "chip") then
					local pe, cp = halfExtents(p), p.CFrame.Position
					local home: BasePart? = nil
					for _, sup in supports do
						local se, sp = halfExtents(sup), sup.CFrame.Position
						if
							math.abs(cp.X - sp.X) + pe.X <= se.X + 0.05
							and cp.Y + pe.Y <= sp.Y + se.Y - 0.05
							and cp.Y - pe.Y >= sp.Y - se.Y
							and cp.Z < sp.Z - se.Z + 0.2
							and cp.Z > sp.Z - se.Z - 0.8
						then
							home = sup
							break
						end
					end
					if home == nil then
						table.insert(
							out,
							`{stag}: a {kind} is not wholly inside a log or a post, below its top ({r3(cp.X)}, {r3(cp.Y)})`
						)
					elseif kind ~= "chip" then
						used[home] = true
						nMarks += 1
					end
				end
			end
			local distinct = 0
			for _ in used do
				distinct += 1
			end
			if nMarks >= 2 and distinct < 2 then
				table.insert(out, `{stag}: all {nMarks} marks are on one log or post`)
			end
		end
	end
	return out
end

-- the level a model stores is the level that was built: a level the Kit does not have is the highest it has (or 1), and the
-- damage of a wall asked for at level 5 is that of the level 3 wall
local TOP_LEVEL = {
	keep = 3,
	house = 2,
	farm = 3,
	storehouse = 2,
	lumbercamp = 3,
	quarry = 3,
	barracks = 4,
	watchtower = 2,
	wall = 3,
	gate = 3,
	mine = 1,
	blacksmith = 1,
	market = 1,
	infirmary = 1,
	granary = 1,
	shrine = 1,
}
CHECKS.level = function()
	local out: { string } = {}
	for _, bt in Kit.BUILDING_TYPES do
		for _, asked in { -3, 0, 0.5, 1, 2, 3, 4, 5, 99, 2.7, 0 / 0 } do
			local want = if asked ~= asked then 1 else math.clamp(math.floor(asked), 1, TOP_LEVEL[bt])
			local m = Kit.build(bt, asked, "complete", CANON.crimson)
			if m:GetAttribute("KitLevel") ~= want then
				table.insert(
					out,
					`{bt} asked for level {asked} stores KitLevel {m:GetAttribute("KitLevel")}, want {want}`
				)
			end
		end
	end
	for _, e in
		{
			{ "wall", 5, 3 },
			{ "gate", 9, 3 },
			{ "keep", 7, 3 },
			{ "barracks", 8, 4 },
			{ "house", 5, 2 },
			{ "wall", 0, 1 },
		}
	do
		local a, b = damaged(e[1], e[2], "crimson", 0.97), damaged(e[1], e[3], "crimson", 0.97)
		if signature(a) ~= signature(b) then
			table.insert(out, `{e[1]} asked for level {e[2]} is not damaged like level {e[3]}`)
		end
	end
	return out
end

-- ------------------------------------------------------------------ 8. order: the KitOrder part attribute

-- Kit.build numbers the model's parts (the Root excepted) in the order the damage walks them: the part attribute KitOrder. A
-- choice between two equally distant parts then never depends on float noise from a turn or a move, nor on the order a repair
-- left the children in. Without the attribute the walk falls back to a key of name, position (rounded to 0.01) and size, which
-- a part at a rounding edge can flip.
local ORDER_BUILDS: { { any } } = {}
for _, bt in Kit.BUILDING_TYPES do
	table.insert(ORDER_BUILDS, { bt, MAX_LEVEL[bt] or 2, "crimson" })
end
for _, e in
	{
		{ "wall", 1, "azure" },
		{ "wall", 2, "azure" },
		{ "gate", 1, "emerald" },
		{ "gate", 2, "gold" },
		{ "keep", 1, "crimson" },
	}
do
	table.insert(ORDER_BUILDS, e)
end
-- { type, level, kingdom, Damage }: at state 1 the first five choose differently when the numbers are not read (measured on 168
-- combinations: type x state x two kingdoms); the last two are the wall and the gate at other states
local ORDER_NOISE: { { any } } = {
	{ "keep", 3, "crimson", 0.3 },
	{ "keep", 1, "crimson", 0.3 },
	{ "barracks", 4, "crimson", 0.3 },
	{ "granary", 2, "crimson", 0.3 },
	{ "granary", 2, "azure", 0.3 },
	{ "wall", 2, "crimson", 0.55 },
	{ "gate", 2, "crimson", 0.8 },
}
-- types whose damage depends on the order: reversing the numbers changes the parts chosen at some state
local ORDER_READ: { { any } } = {
	{ "wall", 2 },
	{ "gate", 2 },
	{ "house", 2 },
	{ "keep", 3 },
	{ "watchtower", 2 },
}

local function bodyParts(m: Model): { BasePart }
	local list: { BasePart } = {}
	for _, p in m:GetChildren() do
		if p:IsA("BasePart") and p ~= m.PrimaryPart and p:GetAttribute("KitDamage") ~= true then
			table.insert(list, p)
		end
	end
	return list
end

type Outcome = { kept: string, extras: { { any } } }

-- builds the model, names every part (SpecId), runs `prepare`, damages it, and returns which of its own parts are left and where
-- the damage parts lie (in the model's frame)
local function outcome(bt: string, lv: number, hue: string, d: number, prepare: ((Model, { BasePart }) -> ())?): Outcome
	local m = Kit.build(bt, lv, "complete", CANON[hue])
	local list = bodyParts(m)
	for i, p in list do
		p:SetAttribute("SpecId", i)
	end
	if prepare then
		prepare(m, list)
	end
	m:SetAttribute("Damage", d)
	Kit.applyDamage(m)
	local inv = pivotOf(m):Inverse()
	local kept: { number } = {}
	local extra: { { any } } = {}
	for _, p in m:GetChildren() do
		if p:IsA("BasePart") and p ~= m.PrimaryPart then
			if p:GetAttribute("KitDamage") == true then
				local c = inv * p.CFrame.Position
				table.insert(extra, { `{p.Name}|{p:GetAttribute("KitDamageKind")}`, c.X, c.Y, c.Z })
			else
				table.insert(kept, (p:GetAttribute("SpecId") or -1) :: number)
			end
		end
	end
	table.sort(kept)
	table.sort(extra, function(a, b)
		if a[1] ~= b[1] then
			return a[1] < b[1]
		elseif a[2] ~= b[2] then
			return a[2] < b[2]
		end
		return a[3] < b[3]
	end)
	return { kept = table.concat(kept, ","), extras = extra }
end

-- nil when both left the same parts and made the same damage parts (within 0.002), else what differs
local function outcomeDiff(a: Outcome, b: Outcome): string?
	if a.kept ~= b.kept then
		return "different parts left standing"
	elseif #a.extras ~= #b.extras then
		return `{#a.extras} damage parts here, {#b.extras} there`
	end
	for i, x in a.extras do
		local y = b.extras[i]
		if x[1] ~= y[1] then
			return `damage parts differ: {x[1]} / {y[1]}`
		end
		for j = 2, 4 do
			if math.abs(x[j] - y[j]) > 0.002 then
				return `{x[1]} lies at a different place`
			end
		end
	end
	return nil
end

CHECKS.order = function()
	local out: { string } = {}
	-- 1. every part but the Root carries its own place in the walk: an integer 1..n, each once
	for _, e in ORDER_BUILDS do
		local tag = `{e[1]} L{e[2]} {e[3]}`
		local m = Kit.build(e[1], e[2], "complete", CANON[e[3]])
		local list = bodyParts(m)
		local seen: { [number]: boolean } = {}
		for _, p in list do
			local n = p:GetAttribute("KitOrder")
			if type(n) ~= "number" or n ~= math.floor(n) or n < 1 or n > #list then
				table.insert(out, `{tag}: {p.Name} has KitOrder {n}, want an integer 1..{#list}`)
				break
			elseif seen[n] then
				table.insert(out, `{tag}: KitOrder {n} is on two parts`)
				break
			end
			seen[n] = true
		end
	end
	-- 2. float noise on the parts (what a turn or a move leaves) does not change a choice
	for _, e in ORDER_NOISE do
		local bt, lv, hue, d = e[1], e[2], e[3], e[4]
		local calm = outcome(bt, lv, hue, d)
		local noisy = outcome(bt, lv, hue, d, function(_, list)
			for i, p in list do
				p.CFrame = p.CFrame
					+ Vector3.new(
						math.sin(i * 12.9898) * 1e-4,
						math.sin(i * 78.233 + 1) * 1e-4,
						math.sin(i * 37.719 + 2) * 1e-4
					)
			end
		end)
		local why = outcomeDiff(calm, noisy)
		if why then
			table.insert(out, `{bt} L{lv} {hue} Damage {d}: nudging the parts by 1e-4 changes the damage ({why})`)
		end
	end
	-- 3. the damage walks the numbers: reversing them changes which parts are chosen (at some state, for each of these types)
	for _, e in ORDER_READ do
		local changed = false
		for _, d in { 0.3, 0.55, 0.8, 0.97 } do
			local same = outcome(e[1], e[2], "crimson", d)
			local reversed = outcome(e[1], e[2], "crimson", d, function(_, list)
				for _, p in list do
					local n = p:GetAttribute("KitOrder")
					if type(n) == "number" then
						p:SetAttribute("KitOrder", #list + 1 - n)
					end
				end
			end)
			if outcomeDiff(same, reversed) then
				changed = true
				break
			end
		end
		if not changed then
			table.insert(
				out,
				`{e[1]} L{e[2]}: reversing KitOrder changes no choice at any state (the numbers are not read)`
			)
		end
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
	it("works in the model's own frame: turned, moved and at any height, and every wall and gate level", function()
		expectClean(CHECKS.frames())
	end)
	it("damages a level the Kit does not have like the level it really is", function()
		expectClean(CHECKS.level())
	end)
	it(
		"walks the parts in the order Kit.build numbered them (KitOrder), whatever float noise a turn or a move leaves",
		function()
			expectClean(CHECKS.order())
		end
	)
end)

-- ------------------------------------------------------------------ mutants

describe("Damage mutants are caught", function()
	local original = {
		build = Kit.build,
		applyDamage = Kit.applyDamage,
		setKingdomColor = Kit.setKingdomColor,
		stashed = Damage.stashed,
		frameOf = Damage.frameOf,
		orderAttribute = Damage.ORDER_ATTRIBUTE,
	}
	local function restore()
		Kit.build = original.build
		Kit.applyDamage = original.applyDamage
		Kit.setKingdomColor = original.setKingdomColor
		Damage.stashed = original.stashed
		Damage.frameOf = original.frameOf
		Damage.ORDER_ATTRIBUTE = original.orderAttribute
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
		for _, name in { "damage", "level", "order" } do
			expectClean(CHECKS[name]())
		end
		expectClean(CHECKS.frames(true))
	end)

	caught("applyDamage does nothing", "damage", function()
		Kit.applyDamage = function() end
	end)
	caught("Damage 0 still adds a part", "damage", function()
		Kit.applyDamage = function(m)
			original.applyDamage(m)
			if Damage.stateOf(m:GetAttribute("Damage")) == 0 then
				local p = Instance.new("Part")
				p.Name = "Breach"
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
					p.Name = `Extra{i}`
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
	local function eachMark(m: Model, kinds: { string }, fn: (BasePart) -> ())
		for _, p in m:GetChildren() do
			if p:IsA("BasePart") and table.find(kinds, tostring(p:GetAttribute("KitDamageKind"))) then
				fn(p)
			end
		end
	end
	caught("a breach is a translucent ball again", "damage", function()
		Kit.applyDamage = function(m)
			original.applyDamage(m)
			eachMark(m, { "breach" }, function(p)
				local ball = p :: Part
				ball.Shape = Enum.PartType.Ball
				ball.Transparency = 0.5
			end)
		end
	end)
	caught("a breach is a pure black slab again (a hole)", "damage", function()
		Kit.applyDamage = function(m)
			original.applyDamage(m)
			eachMark(m, { "breach" }, function(p)
				p.Color = Color3.fromRGB(10, 8, 8)
			end)
		end
	end)
	caught("a breach is a dark-brown sticker, a third of the wall's value", "damage", function()
		Kit.applyDamage = function(m)
			original.applyDamage(m)
			eachMark(m, { "breach" }, function(p)
				p.Color = Color3.fromRGB(58, 46, 40)
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
	caught("a breach glows (Neon)", "damage", function()
		Kit.applyDamage = function(m)
			original.applyDamage(m)
			eachMark(m, { "breach" }, function(p)
				p.Material = Enum.Material.Neon
			end)
		end
	end)
	caught("a crack is a thick dark stick again", "damage", function()
		Kit.applyDamage = function(m)
			original.applyDamage(m)
			eachMark(m, { "crack" }, function(p)
				p.Size = Vector3.new(0.32, p.Size.Y, 0.1)
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
	caught(
		"the chips are as dark as the recess (a nail-like pale block is not stone either: no lighter than 1.6x)",
		"damage",
		function()
			Kit.applyDamage = function(m)
				original.applyDamage(m)
				eachMark(m, { "chip" }, function(p)
					p.Color = Color3.fromRGB(250, 246, 236)
				end)
			end
		end
	)
	caught("the chips are as dark as the wall's recess", "damage", function()
		Kit.applyDamage = function(m)
			original.applyDamage(m)
			eachMark(m, { "chip" }, function(p)
				p.Color = Color3.new(p.Color.R * 0.55, p.Color.G * 0.55, p.Color.B * 0.55)
			end)
		end
	end)
	caught("a pale wall's breach is the wall's own colour (it hides as 'within 0.06')", "damage", function()
		Kit.applyDamage = function(m)
			original.applyDamage(m)
			local wall: BasePart? = nil
			for _, p in m:GetChildren() do
				if p:IsA("BasePart") and (p.Name == "Curtain" or p.Name == "Walls") then
					wall = p
				end
			end
			if wall then
				eachMark(m, { "breach" }, function(p)
					p.Color = (wall :: BasePart).Color
				end)
			end
		end
	end)
	caught("the floor of the mark colours is lowered a little (41,38,34 on a dark post)", "damage", function()
		Kit.applyDamage = function(m)
			original.applyDamage(m)
			eachMark(m, { "breach", "crack" }, function(p)
				if p.Color.R * 255 < 47 and p.Color.R * 255 > 43.5 then
					p.Color = Color3.fromRGB(41, 38, 34)
				end
			end)
		end
	end)
	caught("a breach overhangs the wall's edge", "damage", function()
		Kit.applyDamage = function(m)
			original.applyDamage(m)
			eachMark(m, { "breach" }, function(p)
				p.CFrame = p.CFrame + Vector3.new(60, 0, 0)
			end)
		end
	end)
	caught("a breach is on the side face (turned a quarter)", "damage", function()
		Kit.applyDamage = function(m)
			original.applyDamage(m)
			eachMark(m, { "breach" }, function(p)
				p.CFrame = p.CFrame * CFrame.Angles(0, math.rad(90), 0)
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

	-- the frame rules: a building is damaged in its own frame, wherever it stands and however it is turned
	caught("the damage is worked out on the world axes (a turned building is damaged on its back)", "frames", function()
		Damage.frameOf = function()
			return CFrame.new()
		end
	end)
	caught("the parts it takes off wait at absolute CFrames (a move leaves them behind)", "frames", function()
		local at: { [BasePart]: CFrame } = {}
		Kit.applyDamage = function(m)
			original.applyDamage(m)
			for _, p in Damage.stashed(m) do
				if at[p] == nil then
					at[p] = p.CFrame
				end
			end
			for p, cf in at do
				if p.Parent == m then
					p.CFrame = cf
					at[p] = nil
				end
			end
		end
	end)
	caught(
		"the rubble lies at world y = size / 2 - 0.2 (a model standing at y 40 gets it underground)",
		"frames",
		function()
			Kit.applyDamage = function(m)
				original.applyDamage(m)
				for _, p in m:GetChildren() do
					if p:IsA("BasePart") and p:GetAttribute("KitDamageKind") == "rubble" then
						local cf = p.CFrame
						p.CFrame = CFrame.new(cf.X, p.Size.Y / 2 - 0.2, cf.Z) * (cf - cf.Position)
					end
				end
			end
		end
	)
	caught("every mark of the palisade sits on one log", "frames", function()
		Kit.applyDamage = function(m)
			original.applyDamage(m)
			local x0: number? = nil
			for _, p in m:GetChildren() do
				local kind = p:GetAttribute("KitDamageKind")
				if p:IsA("BasePart") and (kind == "breach" or kind == "crack" or kind == "chip") then
					x0 = x0 or p.CFrame.X
					p.CFrame = p.CFrame + Vector3.new((x0 :: number) - p.CFrame.X, 0, 0)
				end
			end
		end
	end)
	caught("a palisade mark pokes out above its log", "frames", function()
		Kit.applyDamage = function(m)
			original.applyDamage(m)
			for _, p in m:GetChildren() do
				if p:IsA("BasePart") and p:GetAttribute("KitDamageKind") == "breach" then
					p.CFrame = p.CFrame + Vector3.new(0, 30, 0)
				end
			end
		end
	end)
	caught(
		"KitLevel stores the level that was asked for (a wall asked for at level 5 is not a level 3 wall)",
		"level",
		function()
			Kit.build = function(bt, lv, ...)
				local m = original.build(bt, lv, ...)
				m:SetAttribute("KitLevel", lv)
				return m
			end
		end
	)

	-- the order rules: Kit.build numbers the parts and the damage walks the numbers
	caught("Kit.build does not number the parts (no KitOrder)", "order", function()
		Kit.build = function(...)
			local m = original.build(...)
			for _, p in m:GetChildren() do
				p:SetAttribute("KitOrder", nil)
			end
			return m
		end
	end)
	caught("every part is number 1 (KitOrder is not a walk order)", "order", function()
		Kit.build = function(...)
			local m = original.build(...)
			for _, p in m:GetChildren() do
				if p:GetAttribute("KitOrder") ~= nil then
					p:SetAttribute("KitOrder", 1)
				end
			end
			return m
		end
	end)
	caught("the damage ignores KitOrder and walks the position keys (float noise flips a choice)", "order", function()
		Kit.applyDamage = function(m)
			Damage.ORDER_ATTRIBUTE = "KitOrderIgnored"
			original.applyDamage(m)
			Damage.ORDER_ATTRIBUTE = original.orderAttribute
		end
	end)
end)
