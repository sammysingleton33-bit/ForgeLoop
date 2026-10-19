--!strict
--[[
	Kit/Damage — visible damage on building models (FL-0128 war kit, Operation Crownfall). Part-built, deterministic,
	primitives only (D-026). A model's number attribute `Damage` (0..1; the client sets it, for example 1 - Hp / MaxHp
	from the Hp and MaxHp attributes WorldView already puts on every building) is turned into parts by `Kit.applyDamage`.

	API
		Kit.applyDamage(model)            reads the attribute `Damage` and builds or removes the damage; idempotent
		Kit.damageState(damage) -> 0..4   the state a damage value is in
		Kit.damageFromHp(hp, maxHp) -> number   1 - hp / maxHp, clamped
		Kit.DAMAGE_THRESHOLDS = { 0.25, 0.5, 0.75, 0.95 }
	Model attribute written: KitDamageState (1..4; absent at state 0). Every added part carries the attribute
	KitDamage = true and KitDamageKind = "breach" | "crack" | "chip" | "leaf" | "rubble" | "stump"; they are direct children of
	the model.

	States (cumulative; the numbers are the totals at that state)
		state  Damage   breaches  cracks  chips  rubble  crenellation / roof parts taken  gate leaves   collapse
		  0    < 0.25      0        0      0      0       0                                0             none (exactly as built)
		  1    >= 0.25     1        1      2      0       4                                1 (+ bands)
		  2    >= 0.5      1        2      3      2       7                                1
		  3    >= 0.75     2        2      4      3       10                               both gone, one broken leaf left   the top of the front-right corner
		  4    >= 0.95     2        2      5      3       13                               the same                          the same
	At most MAX_EXTRA_PARTS (14) parts are added (at most 12 breach marks, cracks, chips and rubble, one broken leaf on a gate,
	one stump slab when a tower cap fell); none at state 0. Real geometry goes missing from state 1, so 0.3 reads differently from 0 at the
	170-stud camera: a BITE of merlons (or roof tiles, thatch, lean-to roofs, palisade logs) is taken out of the crenellation
	or the roof edge, growing from a seed on the front through the nearest parts (so state 2 keeps what state 1 took). A gate's
	bite starts at the middle of its span and is measured from there, mirror parts alternating, so its two towers wear down
	alike. A gate loses one leaf (with its iron bands) at state 1 and the other at state 3, but keeps a BROKEN LEAF (a short
	splintered board at the hinge, a damage part in the closed leaf's plane that setGateOpen never moves), so even at 0.9 it
	reads as a ruined gate, shut or open. The removed number is min(table, the parts that can go missing, without the highest
	part); the model's top never moves. The collapsed corner (state 3 and 4) takes the merlons, roof tiles and thatch in the top
	half of the front-right corner (x >= right edge - 30 %, z <= front edge + 30 %) on top, and a tower CAP falls whole or not at
	all (when its lowest part stands in that corner: every part of that cap, never a half cone or a turned pyramid; a gate's
	caps stand in its middle and never fall, so its two roofs stay identical). Never removed: banners, emblems, crests, doors,
	windows, thrones or the kingdom caps outside the collapsed corner.
	Marks are BROKEN STONE, not stickers (the FL-0128 defect round B). They lie on the FRONT face of the walls the player sees,
	wholly inside the wall block they sit on (so nothing overhangs a silhouette) and below the model's top, picked on the
	outermost upright wall block at a spread of points and only where nothing (a turret, a porch, a banner, a step) stands in
	front of it; a mark that finds no such site goes on the biggest wall. Every mark is the supporting wall's OWN stone, shaded,
	and tinted when the wall is (so a recolour follows): the spec KitDamage keeps each inside a band of the wall's value, never
	black and never Neon. A BREACH is a recess 2.2 to 3.2 wide and up to 4.2 high, 0.09 deep, at 0.64 of the wall (the band is
	0.5 to 0.9); a CRACK is a hairline (0.14 across, 0.07 deep, up to 3.8 long, tilted) at 0.8 of the wall (0.65 to 0.92); CHIPS
	are small stone blocks (0.8 to 1.4 by 0.6 to 1.0, 0.4 deep) at 1.25 of the wall (1.05 to 1.6) round the rim of the recesses,
	standing proud of the face, so the edges read as broken masonry. An untinted dark wall keeps its marks off black (the floor
	is (44,40,36) / 255). Rubble is up to three blocks, 3.6/2.8/2.0 studs across, in the colour of the biggest wall at the
	corner's foot (with its tint, so a recolour follows). The stump (state 3 and 4, only when a tower cap fell) is one tilted
	slab of broken masonry seated on the highest box under where the lowest cap part stood.

	Compatibility
	- Burning (FORGE-04's FeedbackController reads the model attribute `Burning` and the model's bounding box top): this module
	  touches neither the attribute nor the box's top (it never removes the highest part of the model and every mark
	  lies inside the box), so a damaged model still burns, with the flames at the same roof.
	- Kit.setKingdomColor recolours the removed parts too (they wait in a weak table until the damage is repaired) and
	  never touches the damage parts (they are not kingdom-coloured).
	- Repair: set Damage lower and call applyDamage again; the removed parts come back where they were.
	- Construction stages (KitStage ~= "complete") and models without a PrimaryPart ignore Damage.
]]

local Parts = require("./Parts")

local M = Enum.Material

local Damage = {}

Damage.THRESHOLDS = table.freeze({ 0.25, 0.5, 0.75, 0.95 })
Damage.MAX_EXTRA_PARTS = 14
Damage.ATTRIBUTE = "Damage"
Damage.STATE_ATTRIBUTE = "KitDamageState"
Damage.PART_ATTRIBUTE = "KitDamage"
-- per state 1..4 (state 0 adds and removes nothing)
Damage.BREACH = table.freeze({ 1, 1, 2, 2 })
Damage.CRACKS = table.freeze({ 1, 2, 2, 2 })
Damage.CHIPS = table.freeze({ 2, 3, 4, 5 })
Damage.RUBBLE = table.freeze({ 0, 2, 3, 3 })
Damage.REMOVED = table.freeze({ 4, 7, 10, 13 })

-- breach marks are the supporting wall's OWN stone, shaded: a recess a shade under the wall, a hairline crack a little under it,
-- chips a shade lighter (the spec keeps each within a band of the wall's value, luminance above 0.1 and never Neon)
Damage.BREACH_SHADE = 0.64
Damage.CRACK_SHADE = 0.8
Damage.CHIP_LIGHT = 1.25
-- walls the cracks may sit on, then the parts that go missing and the parts of a collapsing corner
local BODY =
	{ Walls = true, Hall = true, Donjon = true, Shaft = true, Curtain = true, GateTower = true, BarnWalls = true }
local MISSING =
	{ Merlon = true, RoofTiles = true, Thatch = true, ThatchLayer = true, LeanToRoof = true, Palisade = true }
Damage.MISSING = MISSING -- the part names that can go missing (tests read it)
-- the parts of a tower cap (the stump marks where the lowest of them stood)
local CAP =
	{ Drum = true, DrumBand = true, Dome = true, Spire = true, SpireEave = true, CapEave = true, Hoarding = true }
-- the parts of the collapsed corner that go one by one (a cap never goes in pieces: see CAP_PARTS)
local CORNER = {
	Merlon = true,
	RoofTiles = true,
	Thatch = true,
	ThatchLayer = true,
	LeanToRoof = true,
	Palisade = true,
}
-- everything a tower cap is made of: when a cap falls ALL of it falls (a half cone or a turned pyramid never shows), and
-- only a cap whose anchor stands in the collapsed corner falls
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

-- parts taken off a damaged model, by model: weak, so a destroyed model takes its stash with it
local stash: { [Model]: { BasePart } } = setmetatable({}, { __mode = "k" }) :: any

function Damage.stateOf(d: any): number
	if type(d) ~= "number" or d ~= d then
		return 0
	end
	local state = 0
	for i, t in Damage.THRESHOLDS do
		if d >= t then
			state = i
		end
	end
	return state
end

function Damage.fromHp(hp: number, maxHp: number): number
	if type(hp) ~= "number" or type(maxHp) ~= "number" or maxHp <= 0 or hp ~= hp then
		return 0
	end
	return math.clamp(1 - hp / maxHp, 0, 1)
end

-- the parts waiting for a repair (Kit.setKingdomColor recolours them)
function Damage.stashed(model: Model): { BasePart }
	return stash[model] or {}
end

local function isDamage(inst: Instance): boolean
	return inst:GetAttribute(Damage.PART_ATTRIBUTE) == true
end

-- The model's own parts (not the Root, not the damage parts) in an order that depends only on what they are, never on
-- the order they were parented in: a repair puts removed parts back at the end of the children, and the same Damage must
-- then pick the same parts as on a fresh model.
local function ownParts(model: Model): { BasePart }
	local list: { BasePart } = {}
	local keys: { [BasePart]: string } = {}
	for _, p in model:GetChildren() do
		if p:IsA("BasePart") and p ~= model.PrimaryPart and not isDamage(p) then
			local part = p :: BasePart
			local at, s = part.CFrame.Position, part.Size
			keys[part] = string.format("%s|%.2f,%.2f,%.2f|%.2f,%.2f,%.2f", part.Name, at.X, at.Y, at.Z, s.X, s.Y, s.Z)
			table.insert(list, part)
		end
	end
	table.sort(list, function(a, b)
		return keys[a] < keys[b]
	end)
	return list
end

-- Deterministic pseudo-random numbers in [0, 1) from a string seed (a Park-Miller generator, exact in doubles).
local function rng(seed: string)
	local h = 7
	for i = 1, #seed do
		h = (h * 31 + string.byte(seed, i)) % 2147483629
	end
	local state = h % 2147483646 + 1
	return function(): number
		state = (state * 16807) % 2147483647
		return (state - 1) / 2147483646
	end
end

local function visibleBounds(model: Model): (Vector3, Vector3)
	local lo, hi = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, p in model:GetChildren() do
		if p:IsA("BasePart") and p ~= model.PrimaryPart and p.Transparency < 1 and not isDamage(p) then
			local cf, s = p.CFrame, p.Size
			local e = Vector3.new(
				(math.abs(cf.RightVector.X) * s.X + math.abs(cf.UpVector.X) * s.Y + math.abs(cf.LookVector.X) * s.Z) / 2,
				(math.abs(cf.RightVector.Y) * s.X + math.abs(cf.UpVector.Y) * s.Y + math.abs(cf.LookVector.Y) * s.Z) / 2,
				(math.abs(cf.RightVector.Z) * s.X + math.abs(cf.UpVector.Z) * s.Y + math.abs(cf.LookVector.Z) * s.Z) / 2
			)
			lo = lo:Min(cf.Position - e)
			hi = hi:Max(cf.Position + e)
		end
	end
	return lo, hi
end

local function isBlock(p: BasePart): boolean
	return (p.ClassName == "Part" and (p :: Part).Shape == Enum.PartType.Block)
end

-- the wall the cracks go on: the biggest named wall block, else the biggest tall block that is not the ground
local function bodyOf(model: Model, kids: { BasePart }): BasePart?
	local best, bestVol, fallback, fallbackVol = nil, 0, nil, 0
	for _, part in kids do
		if part.Parent == model and isBlock(part) then
			local vol = part.Size.X * part.Size.Y * part.Size.Z
			if BODY[part.Name] and vol > bestVol then
				best, bestVol = part, vol
			elseif part.Size.Y >= 3 and vol > fallbackVol and part.Name ~= "Plinth" then
				fallback, fallbackVol = part, vol
			end
		end
	end
	return best or fallback
end

local function make(kind: string, part: BasePart): BasePart
	part:SetAttribute(Damage.PART_ATTRIBUTE, true)
	part:SetAttribute("KitDamageKind", kind)
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = kind == "rubble" or kind == "stump" or kind == "chip" or kind == "leaf"
	return part
end

-- Removes every damage part and returns the parts that were taken off to where they were.
local function clear(model: Model)
	for _, c in model:GetChildren() do
		if isDamage(c) then
			c:Destroy()
		end
	end
	local parked = stash[model]
	if parked then
		for _, p in parked do
			p.Parent = model
		end
		stash[model] = nil
	end
end

-- a part's axis-aligned world box
type Box = { part: BasePart, cx: number, cy: number, cz: number, hx: number, hy: number, hz: number }

local function boxOf(p: BasePart): Box
	local cf, s = p.CFrame, p.Size
	local r, u, l = cf.RightVector, cf.UpVector, cf.LookVector
	return {
		part = p,
		cx = cf.X,
		cy = cf.Y,
		cz = cf.Z,
		hx = (math.abs(r.X) * s.X + math.abs(u.X) * s.Y + math.abs(l.X) * s.Z) / 2,
		hy = (math.abs(r.Y) * s.X + math.abs(u.Y) * s.Y + math.abs(l.Y) * s.Z) / 2,
		hz = (math.abs(r.Z) * s.X + math.abs(u.Z) * s.Y + math.abs(l.Z) * s.Z) / 2,
	}
end

-- the model's visible parts as boxes, and which of them are wall blocks that can carry a crack: upright, axis-aligned,
-- big enough, not a thin panel or a plinth
local function boxesOf(model: Model, kids: { BasePart }): ({ Box }, { Box })
	local all: { Box } = {}
	local walls: { Box } = {}
	for _, p in kids do
		if p.Parent == model and p.Transparency < 1 then
			local box = boxOf(p)
			table.insert(all, box)
			local cf = p.CFrame
			if isBlock(p) and p.Name ~= "Plinth" and p.Size.Y >= 3 and cf.UpVector.Y > 0.99 then
				local alongZ, alongX = math.abs(cf.LookVector.Z) > 0.99, math.abs(cf.LookVector.X) > 0.99
				if (alongZ or alongX) and math.max(box.hx, box.hz) >= 1.5 and math.min(box.hx, box.hz) >= 0.45 then
					table.insert(walls, box)
				end
			end
		end
	end
	return all, walls
end

function Damage.apply(model: Model)
	local raw = model:GetAttribute(Damage.ATTRIBUTE)
	local state = Damage.stateOf(raw)
	local last = model:GetAttribute(Damage.STATE_ATTRIBUTE)
	if state == (if type(last) == "number" then last else 0) then
		return
	end
	clear(model)
	model:SetAttribute(Damage.STATE_ATTRIBUTE, if state == 0 then nil else state)
	local root = model.PrimaryPart
	if state == 0 or root == nil then
		return
	end
	local stage = model:GetAttribute("KitStage")
	if stage ~= nil and stage ~= "complete" then
		model:SetAttribute(Damage.STATE_ATTRIBUTE, nil)
		return
	end
	local ctx = { model = model, root = root, count = 0 }
	local rand =
		rng(`{model:GetAttribute("KitType")}|{model:GetAttribute("KitLevel")}|{model:GetAttribute("KitVariant")}`)
	local lo, hi = visibleBounds(model)
	local width, depth, height = hi.X - lo.X, hi.Z - lo.Z, hi.Y - lo.Y

	-- 1. parts that go missing: a bite out of the crenellation or the roof edge that grows from a seed (on the front when
	-- there is one) through the nearest parts, so state 2 keeps what state 1 took; a gate loses a leaf at state 1 and both
	-- at state 3
	local kids = ownParts(model)
	local pool: { BasePart } = {}
	local topPart, topY = nil, -math.huge
	for _, p in kids do
		if p.CFrame.Position.Y + p.Size.Y / 2 > topY then
			topPart, topY = p, p.CFrame.Position.Y + p.Size.Y / 2
		end
	end
	for _, p in kids do
		if MISSING[p.Name] and p ~= topPart then -- the highest part stays: the Burning look reads the model's top
			table.insert(pool, p)
		end
	end
	local order: { BasePart } = {}
	if #pool > 0 then
		local front: { BasePart } = {}
		for _, p in pool do
			if p.CFrame.Position.Z <= lo.Z + 0.4 * depth then
				table.insert(front, p)
			end
		end
		local seeds = if #front > 0 then front else pool
		local seed = seeds[1 + math.floor(rand() * #seeds)]
		-- a gate's bite starts at the middle of its span and spreads outward, so both tower roofs keep (or lose) their
		-- parapets alike: the two never look different
		local isGate = false
		for _, p in kids do
			isGate = isGate or p.Name == "GateLeaf"
		end
		local middle = (lo.X + hi.X) / 2
		if isGate then
			for _, p in seeds do
				if math.abs(p.CFrame.Position.X - middle) < math.abs(seed.CFrame.Position.X - middle) - 1e-6 then
					seed = p
				end
			end
		end
		local remaining = table.clone(pool)
		table.remove(remaining, table.find(remaining, seed) :: number)
		table.insert(order, seed)
		local sum = seed.CFrame.Position
		local lastSide = math.sign(seed.CFrame.Position.X - middle)
		-- a gate measures from the middle of its span (not from the drifting centroid of what is gone), so mirror parts come
		-- off together and its two towers wear down alike
		local gateCentre = Vector3.new(middle, seed.CFrame.Position.Y, seed.CFrame.Position.Z)
		while #remaining > 0 do
			local centroid = if isGate then gateCentre else sum / #order
			local bestAt, bestDistance = 1, math.huge
			for i, p in remaining do
				local d = (p.CFrame.Position - centroid).Magnitude
				-- a gate takes equally distant parts from alternate sides, so its two towers wear down together
				local flips = isGate
					and math.abs(d - bestDistance) <= 1e-6
					and math.sign(p.CFrame.Position.X - middle) ~= lastSide
				if d < bestDistance - 1e-6 or flips then
					bestAt, bestDistance = i, d
				end
			end
			lastSide = math.sign(remaining[bestAt].CFrame.Position.X - middle)
			local chosen = table.remove(remaining, bestAt) :: BasePart
			table.insert(order, chosen)
			sum += chosen.CFrame.Position
		end
	end
	local leaves: { BasePart } = {}
	for _, p in kids do
		if p.Name == "GateLeaf" then
			table.insert(leaves, p)
		end
	end
	local firstLeaf = if #leaves > 0 then math.floor(rand() * #leaves) + 1 else 0
	local parked: { BasePart } = {}
	local broken: BasePart? = nil -- from state 3 the leaf that was still standing is a broken remnant, not gone
	local function take(p: BasePart)
		if p ~= topPart and p.Parent == model then
			p.Parent = nil
			table.insert(parked, p)
		end
	end
	local wantRemoved = Damage.REMOVED[state]
	for i = 1, math.min(wantRemoved, #order) do
		take(order[i])
	end
	for i, leaf in leaves do
		if i == firstLeaf or state >= 3 then
			local side = root.CFrame:ToObjectSpace(leaf.CFrame).X
			if i ~= firstLeaf then
				broken = leaf
			end
			take(leaf)
			for _, p in kids do -- its iron bands go with it
				if p.Name == "LeafBand" and root.CFrame:ToObjectSpace(p.CFrame).X * side > 0 then
					take(p)
				end
			end
		end
	end

	-- 2. the corner: the top of the front-right corner falls (state 3 and 4): merlons, roof tiles and thatch one by one,
	-- and a tower cap whole (the lowest cap part standing in the corner anchors it, with everything of that cap)
	local cornerX = hi.X - 0.15 * width
	local stump: Box? = nil -- the lowest cap part that fell: the broken top of what stands under it
	if state >= 3 then
		local fallen = 0
		for _, p in kids do
			local c = p.CFrame.Position
			if p.Parent == model and p ~= topPart and c.X >= hi.X - 0.3 * width and c.Z <= lo.Z + 0.3 * depth then
				if CORNER[p.Name] and fallen < 14 and c.Y >= lo.Y + 0.5 * height then
					take(p)
					fallen += 1
				elseif CAP[p.Name] and c.Y >= lo.Y + 0.5 * height then
					local box = boxOf(p)
					if stump == nil or box.cy - box.hy < stump.cy - stump.hy then
						stump = box
					end
				end
			end
		end
		if stump then
			local reach = math.max(stump.hx, stump.hz) + 1.0
			for _, p in kids do
				local c = p.CFrame.Position
				if
					CAP_PARTS[p.Name]
					and p ~= topPart
					and p.Parent == model
					and math.abs(c.X - stump.cx) <= reach
					and math.abs(c.Z - stump.cz) <= reach
					and c.Y >= stump.cy - stump.hy - 0.01
				then
					take(p)
				end
			end
		end
	end
	if #parked > 0 then
		stash[model] = parked
	end
	if state >= 3 and broken then
		-- the broken leaf: a short splintered board hanging at the hinge, in the closed leaf's plane, so the gate still reads as
		-- a ruined gate whether it stands open or shut (setGateOpen moves leaves and bands only, never this)
		local leaf = broken :: BasePart
		local closedAt = leaf:GetAttribute("KitGateClosedCF")
		local leafCF = if typeof(closedAt) == "CFrame" then root.CFrame * (closedAt :: CFrame) else leaf.CFrame
		local side = if root.CFrame:ToObjectSpace(leafCF).X < 0 then -1 else 1
		make(
			"leaf",
			Parts.block(
				ctx,
				"DamageLeaf",
				Vector3.new(2.4, 6.2, 0.5),
				leafCF
					* CFrame.new(side * (leaf.Size.X / 2 - 1.2), -(leaf.Size.Y - 6.2) / 2, 0.15)
					* CFrame.Angles(0, side * 0.45, side * 0.1),
				Parts.shade(leaf.Color, 0.8),
				M.WoodPlanks
			)
		)
	end

	-- 3. breaches: broken stone, not stickers. Pale-ish patches of the wall's OWN stone (a shadowed recess a shade under the
	-- wall, stone-coloured chips round its rim, a hairline crack or two), on the FRONT face of the walls the player sees and
	-- wholly inside the wall block they sit on, so nothing overhangs a silhouette. Sites are found on the outermost wall block
	-- at a spread of points (a facade that hides the biggest wall does not hide the mark); a site the walls do not offer falls
	-- back to the biggest wall. Colours are the supporting wall's own, shaded (and tinted when the wall is, so a recolour
	-- follows): never black, never Neon.
	local body = bodyOf(model, kids)
	if body then
		local boxes, walls = boxesOf(model, kids)
		-- the mark's colour and tint: the wall block it sits on, shaded
		local function stone(wall: BasePart, factor: number): (Color3, number?)
			local tint = wall:GetAttribute("KitTint")
			local c = Parts.shade(wall.Color, factor)
			if type(tint) == "number" then
				return c, tint * factor
			end
			-- an untinted dark wall keeps its marks off black
			return Color3.new(math.max(c.R, 44 / 255), math.max(c.G, 40 / 255), math.max(c.B, 36 / 255)), nil
		end
		-- a site on the front face at the point (u, v) of the model's box, v mapped into y0 .. y0 + ys of its height: on the
		-- outermost wall block there with halfW to spare on both sides, and only when nothing (a turret, a porch, a banner, a
		-- step) stands in front of it. Returns the frame on the face, the mark's length and the wall block.
		local function site(
			u: number,
			v: number,
			y0: number,
			ys: number,
			longest: number,
			halfW: number
		): (CFrame?, number, BasePart?)
			local best: Box? = nil
			local bestFace = math.huge
			local x, y = lo.X + (0.1 + 0.8 * u) * width, lo.Y + (y0 + ys * v) * height
			for _, w in walls do
				local face = w.cz - w.hz
				if math.abs(x - w.cx) <= w.hx - 0.4 - halfW and math.abs(y - w.cy) <= w.hy - 1 and face < bestFace then
					best, bestFace = w, face
				end
			end
			if best == nil then
				return nil, 0, nil
			end
			local len = math.min(longest, best.hy * 2 * 0.5)
			y = math.clamp(y, best.cy - best.hy + len / 2 + 0.7, best.cy + best.hy - len / 2 - 0.7) -- the mark (and its chips) stay on the wall
			local halfLen = len / 2 + 0.3
			for _, b in boxes do
				if
					b ~= best
					and b.cz - b.hz < best.cz - best.hz - 0.15
					and math.abs(x - b.cx) < b.hx + halfW + 0.2
					and math.abs(y - b.cy) < b.hy + halfLen
				then
					return nil, 0, nil
				end
			end
			return CFrame.new(x, y, best.cz - best.hz - 0.06), len, best.part
		end
		-- the frame of a mark when no exposed site was found: on the biggest wall as it is, kept inside it
		local function fallback(u: number, v: number, y0: number, ys: number, halfW: number): CFrame
			local cf, size = body.CFrame, body.Size
			local reach = math.max(size.X / 2 - halfW - 0.3, 0)
			local su, sv = math.clamp((u * 0.74 - 0.37) * size.X, -reach, reach), y0 + ys * v
			return cf * CFrame.new(su, (sv - 0.5) * size.Y, -size.Z / 2 - 0.05)
		end
		-- the recesses (patches of broken stone), a shade under the wall
		local patches: { { at: CFrame, w: number, h: number, wall: BasePart } } = {}
		for _ = 1, Damage.BREACH[state] do
			local w = 2.2 + 1.0 * rand()
			local at, h, wall = nil, 0, nil
			local u, v = 0.5, 0.5
			for _ = 1, 24 do -- a fixed number of draws per attempt, so the result depends on the model alone
				u, v = 0.15 + 0.7 * rand(), rand()
				at, h, wall = site(u, v, 0.3, 0.5, 4.2, w / 2 + 0.7)
				if at then
					break
				end
			end
			if at == nil then
				at, h, wall = fallback(u, v, 0.4, 0.4, w / 2 + 0.7), math.min(4.2, body.Size.Y * 0.4), body
			end
			table.insert(patches, { at = at :: CFrame, w = w, h = h, wall = wall :: BasePart })
			local color, tint = stone(wall :: BasePart, Damage.BREACH_SHADE)
			make(
				"breach",
				Parts.block(ctx, "DamageBreach", Vector3.new(w, h, 0.09), at :: CFrame, color, M.Slate, tint)
			)
		end
		-- hairline cracks, a little under the wall's value
		for _ = 1, Damage.CRACKS[state] do
			local at, len, wall, tilt = nil, 0, nil, 0
			local u, v = 0.5, 0.5
			for _ = 1, 24 do
				u, v = rand(), rand()
				tilt = (rand() - 0.5) * 0.7
				at, len, wall = site(u, v, 0.2, 0.55, 3.8, 0.8)
				if at then
					break
				end
			end
			if at == nil then
				at, len, wall = fallback(u, v, 0.3, 0.5, 0.8), math.min(3.8, body.Size.Y * 0.4), body
			end
			local color, tint = stone(wall :: BasePart, Damage.CRACK_SHADE)
			make(
				"crack",
				Parts.block(
					ctx,
					"DamageCrack",
					Vector3.new(0.14, len, 0.07),
					(at :: CFrame) * CFrame.Angles(0, 0, tilt),
					color,
					M.Slate,
					tint
				)
			)
		end
		-- chipped stone round the rim of the recesses (the foot, then the left and right edges): stone-coloured blocks a shade
		-- lighter than the wall, standing proud of the face, so the edges read as broken
		for i = 1, Damage.CHIPS[state] do
			local p = patches[1 + (i - 1) % #patches]
			local edge = i % 3
			local dx, dy
			if edge == 1 then
				dx, dy = (rand() - 0.5) * p.w * 0.8, -p.h / 2 + 0.15
			elseif edge == 2 then
				dx, dy = -p.w / 2 + 0.1, (rand() - 0.5) * p.h * 0.8
			else
				dx, dy = p.w / 2 - 0.1, (rand() - 0.5) * p.h * 0.8
			end
			local color, tint = stone(p.wall, Damage.CHIP_LIGHT)
			make(
				"chip",
				Parts.block(
					ctx,
					"DamageChip",
					Vector3.new(0.8 + 0.6 * rand(), 0.6 + 0.4 * rand(), 0.4),
					p.at * CFrame.new(dx, dy, -0.2) * CFrame.Angles(0, 0, (rand() - 0.5) * 0.9),
					color,
					M.Slate,
					tint
				)
			)
		end
		-- 4. rubble at the corner's foot, in the wall's own colour
		local bodyTint = body:GetAttribute("KitTint")
		for i = 1, Damage.RUBBLE[state] do
			local s = Vector3.new(4.4 - i * 0.8, 2.8 - i * 0.45, 3.8 - i * 0.7)
			local rubble = Parts.block(
				ctx,
				"DamageRubble",
				s,
				CFrame.new(cornerX - (i - 1) * 2.6, s.Y / 2 - 0.2, lo.Z - 0.2 - (i % 2) * 1.2)
					* CFrame.Angles(0, rand() * math.pi, 0),
				Parts.shade(body.Color, 0.78),
				M.Slate,
				if type(bodyTint) == "number" then bodyTint * 0.78 else nil -- a tinted wall's rubble recolours with it
			)
			make("rubble", rubble)
		end
		-- 4b. the stump: a tilted slab of broken masonry on the top of what stands under the cap that fell (the highest
		-- part below the lowest cap part's centre that spans it), so the bare top (flat, often flush with its corbel) does
		-- not show
		if stump then
			local supportY = -math.huge
			for _, b in boxes do
				if math.abs(stump.cx - b.cx) < b.hx and math.abs(stump.cz - b.cz) < b.hz then
					local top = b.cy + b.hy
					if top <= stump.cy and top > supportY then
						supportY = top
					end
				end
			end
			if supportY > -math.huge then
				local w, d = math.min(2 * stump.hx, 7.5) * 0.95, math.min(2 * stump.hz, 7.5) * 0.95
				local slab = Parts.block(
					ctx,
					"DamageStump",
					Vector3.new(w, 1.0, d),
					CFrame.new(stump.cx, supportY + 0.5, stump.cz)
						* CFrame.Angles((rand() - 0.5) * 0.2, rand() * math.pi, (rand() - 0.5) * 0.2),
					Parts.shade(body.Color, 0.92),
					M.Slate,
					if type(bodyTint) == "number" then bodyTint * 0.92 else nil
				)
				make("stump", slab)
			end
		end
	end
end

return Damage
