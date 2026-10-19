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
	The contract of Kit.applyDamage(model) (FORGE-04's FeedbackController calls it on the placed building models WorldView builds):
		- Argument: one Model built by Kit.build (a finished building, KitStage "complete") with its PrimaryPart. Anything else is
		  ignored: a model without a PrimaryPart (nothing is built, no attribute is written), a construction stage (damage parts are
		  cleared and KitDamageState is removed). It reads only the attribute `Damage`; a value that is not a number is 0.
		- Idempotent: the same state again does nothing. Any order: the result depends on the state alone, never on the states the
		  model was in before, so 0.97 then 0.3 is exactly a fresh model at 0.3, and Damage 0 (or under 0.25) is the model as built,
		  part for part, bit for bit (repair).
		- It never touches the attributes Burning, Hp, MaxHp or Damage, the model's highest part, or anything outside the model.
		- It may be called whenever Damage changes, and need not be called when the model is moved or turned (see "Frame").
		- Attribute written on the model: KitDamageState (1..4; absent at state 0). Every added part carries the attribute
		  KitDamage = true and KitDamageKind = "breach" | "crack" | "chip" | "leaf" | "rubble" | "stump"; they are direct children of
		  the model, anchored, never collide or are touched or queried.

	Frame. Everything is worked out in the model's OWN frame: its pivot (the PrimaryPart's CFrame * PivotOffset), in which Kit
	models are built (the origin, the front facing -Z, the right +X, the base plane at y = 0) and which WorldView.placeModel and
	Model:PivotTo move. Which face is the front, which parts go, where marks and rubble lie and the order of it all are chosen there,
	and only turned into world CFrames when a part is made, so a building damages the same whatever its yaw and wherever it stands
	(spec: KitDamage "frames"). Rubble stands on the base plane (y = 0 of that frame), so it sits on terrain at any height. The
	order in which a model's parts are walked is fixed once, at build, as the part attribute KitOrder (Kit.build calls
	Damage.register), so float noise from a turn or a move cannot change a choice, nor can the order repairs leave the children in.
	Where the choice is between two parts the same distance away (a mirror pair, two blocks flush on a face), the earlier one in that
	order wins (comparisons lean 1e-3 towards equal).

	Moves. Damage parts are children of the model, so they move with it. The parts a damage took off are kept (weak, by model)
	with their CFrame RELATIVE to the PrimaryPart and come back at the PrimaryPart's CFrame as it is when they return, so a
	model moved or turned (WorldView.placeModel, PivotTo, the G13.9 move) while damaged is repaired exactly in place at its new
	spot; a gate leaf, band or portcullis returns in the pose the gate is in then (Kit.setGateOpen poses the parked ones too). A model
	that has not moved gets its parts back untouched. Moving a model by changing only its PrimaryPart is not supported (placeModel
	moves every part).

	States (cumulative; the numbers are the totals at that state)
		state  Damage   breaches  cracks  chips  rubble  crenellation / roof parts taken  gate leaves   collapse
		  0    < 0.25      0        0      0      0       0                                0             none (exactly as built)
		  1    >= 0.25     1        1      2      0       4                                1 (+ bands)
		  2    >= 0.5      1        2      3      2       7                                1
		  3    >= 0.75     2        2      4      3       10                               both gone, one broken leaf left   the top of the corner at +X and -Z
		  4    >= 0.95     2        2      5      3       13                               the same                          the same
	At most MAX_EXTRA_PARTS (14) parts are added (at most 12 breach marks, cracks, chips and rubble, one broken leaf on a gate,
	one stump slab when a tower cap fell); none at state 0. Real geometry goes missing from state 1, so 0.3 reads differently from 0 at the
	170-stud camera: a BITE of merlons (or roof tiles, thatch, lean-to roofs, palisade logs) is taken out of the crenellation
	or the roof edge, growing from a seed on the front (-Z) through the nearest parts (so state 2 keeps what state 1 took). A gate's
	bite starts at the middle of its span and is measured from there, mirror parts alternating, so its two towers wear down
	alike. A gate loses one leaf (with its iron bands) at state 1 and the other at state 3, but keeps a BROKEN LEAF (a short
	splintered board at the hinge, a damage part in the closed leaf's plane that setGateOpen never moves), so even at 0.9 it
	reads as a ruined gate, shut or open. The removed number is min(table, the parts that can go missing, without the highest
	part); the model's top never moves. The collapsed corner (state 3 and 4) takes the merlons, roof tiles and thatch in the top
	half of the corner at +X and -Z (x >= right edge - 30 %, z <= front edge + 30 %, in the model's frame) on top, and a tower CAP
	falls whole or not at all (when its lowest part stands in that corner: every part of that cap, never a half cone or a turned
	pyramid; a gate's caps stand in its middle and never fall, so its two roofs stay identical). Never removed: banners, emblems,
	crests, doors, windows, thrones or the kingdom caps outside the collapsed corner.
	Marks are BROKEN STONE, not stickers (the FL-0128 defect round B). They lie on the FRONT face (-Z) of the walls the player sees,
	wholly inside the wall block they sit on (so nothing overhangs a silhouette) and below the model's top, picked on the
	outermost upright wall block at a spread of points and only where nothing (a turret, a porch, a banner, a step) stands in
	front of it; a mark that finds no such site goes on the biggest wall. Every mark is the supporting wall's OWN stone, shaded,
	and tinted when the wall is (so a recolour follows): the spec KitDamage keeps each inside a band of the wall's value, never
	black and never Neon. A BREACH is a recess 2.2 to 3.2 wide and up to 4.2 high, 0.09 deep, at 0.64 of the wall (the band is
	0.5 to 0.9); a CRACK is a hairline (0.14 across, 0.07 deep, up to 3.8 long, tilted) at 0.8 of the wall (0.65 to 0.92); CHIPS
	are small stone blocks (0.8 to 1.4 by 0.6 to 1.0, 0.4 deep) at 1.25 of the wall (1.05 to 1.6) round the rim of the recesses,
	standing proud of the face, so the edges read as broken masonry. An untinted dark wall keeps its marks off black (the floor
	is (44,40,36) / 255). The L1 PALISADE has no wall block (logs 2.3 across, two posts 1.3 across): its marks are spread over the
	logs still standing and the two posts (the next free one of them for each breach and crack, so they sit on at least two when
	there are two marks), each narrower than its log or post (a recess 0.7 to 1.2 wide, chips 0.6 times the size, in wood), wholly
	inside it and below its top. Rubble is up to three blocks, 3.6/2.8/2.0 studs across, in the colour of the biggest wall at the
	corner's foot, in front of the model (with its tint, so a recolour follows). The stump (state 3 and 4, only when a tower cap
	fell) is one tilted slab of broken masonry seated on the highest box under where the lowest cap part stood.

	Compatibility
	- Burning (FORGE-04's FeedbackController reads the model attribute `Burning` and the model's bounding box top): this module
	  touches neither the attribute nor the top of the box (it never removes the highest part of the model, and no damage part rises
	  above the model's top), so a damaged model still burns, with the flames at the same roof. The breaches, cracks, chips and the
	  broken leaf lie inside the box of the model as built; the rubble does not: it lies at the foot of the corner up to 3.8 studs in
	  front of the front-most part (and up to 0.5 past a side), as does the stump (up to 0.5 past a side). The spec pins these bounds.
	- Kit.setKingdomColor recolours the removed parts too (they wait in a weak table until the damage is repaired) and also the damage
	  parts that carry a KitTint (marks, rubble and the stump copy the tint of the wall they came from, so a recolour follows); the
	  broken leaf and the marks on untinted wood (the palisade) keep their own colours.
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

-- Parts taken off a damaged model, by model: weak, so a destroyed model takes its stash with it. Each is kept with its CFrame
-- RELATIVE to the model's PrimaryPart (CFrame:ToObjectSpace), never as it stood in the world, so a model that is moved or turned
-- while it is damaged (WorldView.placeModel, Model:PivotTo, the G13.9 move) gets every part back exactly in place by a repair.
type Parked = { part: BasePart, rel: CFrame, at: CFrame }
local stash: { [Model]: { Parked } } = setmetatable({}, { __mode = "k" }) :: any

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

-- the parts waiting for a repair (Kit.setKingdomColor recolours them, Kit.setGateOpen poses them)
function Damage.stashed(model: Model): { BasePart }
	local out: { BasePart } = {}
	for _, e in stash[model] or {} do
		table.insert(out, e.part)
	end
	return out
end

-- The frame damage works in: the model's pivot (the PrimaryPart's CFrame * PivotOffset). Kit models are built in it (the identity
-- at the origin, the front facing -Z, the base plane at y = 0) and WorldView.placeModel / PivotTo move it, so every choice (which
-- face is the front, which parts go, where marks and rubble lie, the order of it all) is made in it and a building damages the
-- same whatever its yaw or its place in the world. It is a field so that a spec can swap it for the world frame (the old bug).
function Damage.frameOf(model: Model): CFrame
	local root = model.PrimaryPart :: BasePart
	return root.CFrame * root.PivotOffset
end

local function isDamage(inst: Instance): boolean
	return inst:GetAttribute(Damage.PART_ATTRIBUTE) == true
end

-- a part's CFrame in the damage frame
type At = (BasePart) -> CFrame

-- float noise (the matrices of a turned model) must not move a key across a rounding edge: snap to 1e-6 before rounding to 0.01
local function snap(v: number): number
	return math.floor(v * 1e6 + 0.5) / 1e6
end

-- Every comparison of two positions below leans 1e-3 towards "equal / inside": CFrames are 32-bit floats, so the same building
-- placed elsewhere or turned differs from the one at the origin in the last digits, and a part that stands exactly on a threshold
-- (half the height, 0.3 of the width, a mirror pair at the same distance, two blocks flush on one face) must not fall on the
-- other side of it because of that.
local EPS = 1e-3

local function sign(v: number): number
	return if math.abs(v) < EPS then 0 else math.sign(v)
end

-- the sort key of a part: what it is and where it stands in the damage frame
local function keyOf(part: BasePart, at: At): string
	local pos, s = at(part).Position, part.Size
	return string.format(
		"%s|%.2f,%.2f,%.2f|%.2f,%.2f,%.2f",
		part.Name,
		snap(pos.X),
		snap(pos.Y),
		snap(pos.Z),
		s.X,
		s.Y,
		s.Z
	)
end

-- The order of a model's parts AS BUILT: Kit.build writes every part's place in it as the number attribute KitOrder (the sort
-- keys of the model's own frame, taken once, when every part stands exactly where it was made, with no float noise from a turn or
-- a move yet; a number on the part, so it survives a clone and needs no table that could lose the part). Choosing parts (which
-- merlon, which leaf, which wall) walks this order, so a model damages the same wherever it was placed and however it was
-- turned, and whatever order repairs have left its children in.
Damage.ORDER_ATTRIBUTE = "KitOrder"

-- The model's own parts (not the Root, not the damage parts) in that order. Parts the build did not number (an emblem a recolour
-- re-formed) come last, in key order: a repair puts removed parts back at the end of the children, and the same Damage must
-- then pick the same parts as on a fresh model.
local function ownParts(model: Model, at: At): { BasePart }
	local list: { BasePart } = {}
	local rank: { [BasePart]: number } = {}
	local keys: { [BasePart]: string } = {}
	for _, p in model:GetChildren() do
		if p:IsA("BasePart") and p ~= model.PrimaryPart and not isDamage(p) then
			local part = p :: BasePart
			local n = part:GetAttribute(Damage.ORDER_ATTRIBUTE)
			if type(n) == "number" then
				rank[part] = n
			else
				keys[part] = keyOf(part, at)
			end
			table.insert(list, part)
		end
	end
	table.sort(list, function(a, b)
		local ra, rb = rank[a], rank[b]
		if ra and rb then
			return ra < rb
		elseif ra then
			return true
		elseif rb then
			return false
		end
		return keys[a] < keys[b]
	end)
	return list
end

-- Kit.build calls this once the model is finished: it numbers the parts in the order they sort in as built (see KitOrder)
function Damage.register(model: Model)
	local inverse = Damage.frameOf(model):Inverse()
	local at: At = function(p)
		return inverse * p.CFrame
	end
	local list: { BasePart } = {}
	local keys: { [BasePart]: string } = {}
	for _, p in model:GetChildren() do
		if p:IsA("BasePart") and p ~= model.PrimaryPart and not isDamage(p) then
			keys[p :: BasePart] = keyOf(p :: BasePart, at)
			table.insert(list, p :: BasePart)
		end
	end
	table.sort(list, function(a, b)
		return keys[a] < keys[b]
	end)
	for i, p in list do
		p:SetAttribute(Damage.ORDER_ATTRIBUTE, i)
	end
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

-- the half extents of a box of `size` turned by `cf`, along the axes of the frame `cf` is expressed in
local function halfOf(cf: CFrame, s: Vector3): Vector3
	local r, u, l = cf.RightVector, cf.UpVector, cf.LookVector
	return Vector3.new(
		(math.abs(r.X) * s.X + math.abs(u.X) * s.Y + math.abs(l.X) * s.Z) / 2,
		(math.abs(r.Y) * s.X + math.abs(u.Y) * s.Y + math.abs(l.Y) * s.Z) / 2,
		(math.abs(r.Z) * s.X + math.abs(u.Z) * s.Y + math.abs(l.Z) * s.Z) / 2
	)
end

local function visibleBounds(model: Model, at: At): (Vector3, Vector3)
	local lo, hi = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, p in model:GetChildren() do
		if p:IsA("BasePart") and p ~= model.PrimaryPart and p.Transparency < 1 and not isDamage(p) then
			local cf = at(p :: BasePart)
			local e = halfOf(cf, (p :: BasePart).Size)
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

local function sameCFrame(a: CFrame, b: CFrame): boolean
	local ca, cb = { a:GetComponents() }, { b:GetComponents() }
	for i = 1, 12 do
		if ca[i] ~= cb[i] then
			return false
		end
	end
	return true
end

-- Removes every damage part and puts the parts that were taken off back where they belong: relative to the PrimaryPart as it
-- stands NOW (so after a move or a turn too), and a gate leaf, band or portcullis in the pose the gate is in now. A model that
-- has not moved since they came off gets them back untouched, bit for bit.
local function clear(model: Model)
	for _, c in model:GetChildren() do
		if isDamage(c) then
			c:Destroy()
		end
	end
	local parked = stash[model]
	if parked then
		stash[model] = nil
		local root = model.PrimaryPart
		local poseKey = if model:GetAttribute("KitGateOpen") == true then "KitGateOpenCF" else "KitGateClosedCF"
		for _, e in parked do
			if root and not sameCFrame(root.CFrame, e.at) then
				local pose = e.part:GetAttribute(poseKey)
				e.part.CFrame = root.CFrame * (if typeof(pose) == "CFrame" then pose :: CFrame else e.rel)
			end
			e.part.Parent = model
		end
	end
end

-- a part's box in the damage frame (axis-aligned there)
type Box = { part: BasePart, cx: number, cy: number, cz: number, hx: number, hy: number, hz: number }

local function boxOf(p: BasePart, cf: CFrame): Box
	local h = halfOf(cf, p.Size)
	return { part = p, cx = cf.X, cy = cf.Y, cz = cf.Z, hx = h.X, hy = h.Y, hz = h.Z }
end

-- the model's visible parts as boxes, and which of them are wall blocks that can carry a mark: upright, axis-aligned in the
-- damage frame, big enough, not a thin panel or a plinth
local function boxesOf(model: Model, kids: { BasePart }, at: At): ({ Box }, { Box })
	local all: { Box } = {}
	local walls: { Box } = {}
	for _, p in kids do
		if p.Parent == model and p.Transparency < 1 then
			local cf = at(p)
			local box = boxOf(p, cf)
			table.insert(all, box)
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
	local root = model.PrimaryPart
	if root == nil then -- a model without a PrimaryPart is ignored: nothing is built and no attribute is written
		return
	end
	local raw = model:GetAttribute(Damage.ATTRIBUTE)
	local state = Damage.stateOf(raw)
	local last = model:GetAttribute(Damage.STATE_ATTRIBUTE)
	if state == (if type(last) == "number" then last else 0) then
		return
	end
	clear(model)
	model:SetAttribute(Damage.STATE_ATTRIBUTE, if state == 0 then nil else state)
	if state == 0 then
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
	-- everything below is worked out in the model's own frame (front -Z, right +X, up +Y, the base plane at y = 0) and only
	-- turned into world CFrames when a part is made, so a turned or moved model is damaged exactly like one at the origin
	local frame = Damage.frameOf(model)
	local toLocal = frame:Inverse()
	local framed: { [BasePart]: CFrame } = {}
	local function at(p: BasePart): CFrame
		local cf = framed[p]
		if cf == nil then
			cf = toLocal * p.CFrame
			framed[p] = cf
		end
		return cf :: CFrame
	end
	local lo, hi = visibleBounds(model, at)
	local width, depth, height = hi.X - lo.X, hi.Z - lo.Z, hi.Y - lo.Y

	-- 1. parts that go missing: a bite out of the crenellation or the roof edge that grows from a seed (on the front when
	-- there is one) through the nearest parts, so state 2 keeps what state 1 took; a gate loses a leaf at state 1 and both
	-- at state 3
	local kids = ownParts(model, at)
	local pool: { BasePart } = {}
	local topPart, topY = nil, -math.huge
	for _, p in kids do
		if at(p).Position.Y + p.Size.Y / 2 > topY + EPS then
			topPart, topY = p, at(p).Position.Y + p.Size.Y / 2
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
			if at(p).Position.Z <= lo.Z + 0.4 * depth + EPS then
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
				if math.abs(at(p).Position.X - middle) < math.abs(at(seed).Position.X - middle) - EPS then
					seed = p
				end
			end
		end
		local remaining = table.clone(pool)
		table.remove(remaining, table.find(remaining, seed) :: number)
		table.insert(order, seed)
		local sum = at(seed).Position
		local lastSide = sign(at(seed).Position.X - middle)
		-- a gate measures from the middle of its span (not from the drifting centroid of what is gone), so mirror parts come
		-- off together and its two towers wear down alike
		local gateCentre = Vector3.new(middle, at(seed).Position.Y, at(seed).Position.Z)
		while #remaining > 0 do
			local centroid = if isGate then gateCentre else sum / #order
			local bestAt, bestDistance = 1, math.huge
			for i, p in remaining do
				local d = (at(p).Position - centroid).Magnitude
				-- a gate takes equally distant parts from alternate sides, so its two towers wear down together
				local flips = isGate
					and math.abs(d - bestDistance) <= EPS
					and sign(at(p).Position.X - middle) ~= lastSide
				if d < bestDistance - EPS or flips then
					bestAt, bestDistance = i, d
				end
			end
			lastSide = sign(at(remaining[bestAt]).Position.X - middle)
			local chosen = table.remove(remaining, bestAt) :: BasePart
			table.insert(order, chosen)
			sum += at(chosen).Position
		end
	end
	local leaves: { BasePart } = {}
	for _, p in kids do
		if p.Name == "GateLeaf" then
			table.insert(leaves, p)
		end
	end
	local firstLeaf = if #leaves > 0 then math.floor(rand() * #leaves) + 1 else 0
	local parked: { Parked } = {}
	local broken: BasePart? = nil -- from state 3 the leaf that was still standing is a broken remnant, not gone
	local function take(p: BasePart)
		if p ~= topPart and p.Parent == model then
			table.insert(parked, { part = p, rel = root.CFrame:ToObjectSpace(p.CFrame), at = root.CFrame })
			p.Parent = nil
		end
	end
	local wantRemoved = Damage.REMOVED[state]
	for i = 1, math.min(wantRemoved, #order) do
		take(order[i])
	end
	for i, leaf in leaves do
		if i == firstLeaf or state >= 3 then
			local side = at(leaf).Position.X
			if i ~= firstLeaf then
				broken = leaf
			end
			take(leaf)
			for _, p in kids do -- its iron bands go with it
				if p.Name == "LeafBand" and at(p).Position.X * side > 0 then
					take(p)
				end
			end
		end
	end

	-- 2. the corner: the top of the corner at the model's +X and -Z edges falls (state 3 and 4): merlons, roof tiles and thatch
	-- one by one, and a tower cap whole (the lowest cap part standing in the corner anchors it, with everything of that cap)
	local cornerX = hi.X - 0.15 * width
	local stump: Box? = nil -- the lowest cap part that fell: the broken top of what stands under it
	if state >= 3 then
		local fallen = 0
		for _, p in kids do
			local c = at(p).Position
			if
				p.Parent == model
				and p ~= topPart
				and c.X >= hi.X - 0.3 * width - EPS
				and c.Z <= lo.Z + 0.3 * depth + EPS
			then
				if CORNER[p.Name] and fallen < 14 and c.Y >= lo.Y + 0.5 * height - EPS then
					take(p)
					fallen += 1
				elseif CAP[p.Name] and c.Y >= lo.Y + 0.5 * height - EPS then
					local box = boxOf(p, at(p))
					if stump == nil or box.cy - box.hy < stump.cy - stump.hy - EPS then
						stump = box
					end
				end
			end
		end
		if stump then
			local reach = math.max(stump.hx, stump.hz) + 1.0
			for _, p in kids do
				local c = at(p).Position
				if
					CAP_PARTS[p.Name]
					and p ~= topPart
					and p.Parent == model
					and math.abs(c.X - stump.cx) <= reach + EPS
					and math.abs(c.Z - stump.cz) <= reach + EPS
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
	-- wall, stone-coloured chips round its rim, a hairline crack or two), on the FRONT face (-Z of the model's own frame) of the
	-- walls the player sees and wholly inside the wall block they sit on, so nothing overhangs a silhouette. Sites are found on
	-- the outermost wall block at a spread of points (a facade that hides the biggest wall does not hide the mark); a site the
	-- walls do not offer falls back to the biggest wall. Colours are the supporting wall's own, shaded (and tinted when the
	-- wall is, so a recolour follows): never black, never Neon. The L1 palisade has no wall block: its marks are spread over its
	-- standing logs and its two posts (see `palisadeSupports`).
	local body = bodyOf(model, kids)
	if body then
		local boxes, walls = boxesOf(model, kids, at)
		local footX, footZ = root.Size.X / 2, root.Size.Z / 2 -- the footprint, in the model's frame (the Root is footprint-sized)
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
		-- is nothing (a turret, a porch, a banner, a step, a rail) standing in front of the spot (x, y) of the wall box `best`?
		local function exposed(best: Box, x: number, y: number, halfW: number, halfLen: number): boolean
			for _, b in boxes do
				if
					b ~= best
					and b.cz - b.hz < best.cz - best.hz - 0.15 + EPS
					and math.abs(x - b.cx) < b.hx + halfW + 0.2
					and math.abs(y - b.cy) < b.hy + halfLen
				then
					return false
				end
			end
			return true
		end
		-- a site on the front face at the point (u, v) of the model's box, v mapped into y0 .. y0 + ys of its height: on the
		-- outermost wall block there with halfW to spare on both sides (`only`: on that block, x spread across it), and only
		-- when nothing stands in front of it. Returns the frame on the face (in the model's frame), the mark's length and the
		-- wall block.
		local function site(
			u: number,
			v: number,
			y0: number,
			ys: number,
			longest: number,
			halfW: number,
			only: Box?,
			edge: number?
		): (CFrame?, number, BasePart?)
			local margin = edge or 0.4
			local best: Box? = nil
			local bestFace = math.huge
			local x, y = lo.X + (0.1 + 0.8 * u) * width, lo.Y + (y0 + ys * v) * height
			if only then
				x = only.cx + (2 * u - 1) * math.max(only.hx - margin - halfW, 0)
			end
			for _, w in if only then { only } else walls do
				local face = w.cz - w.hz
				if
					math.abs(x - w.cx) <= w.hx - margin - halfW + EPS
					and math.abs(y - w.cy) <= w.hy - 1 + EPS
					and face < bestFace - EPS
				then
					best, bestFace = w, face
				end
			end
			if best == nil then
				return nil, 0, nil
			end
			local len = math.min(longest, best.hy * 2 * 0.5)
			y = math.clamp(y, best.cy - best.hy + len / 2 + 0.7, best.cy + best.hy - len / 2 - 0.7) -- the mark (and its chips) stay on the wall
			if not exposed(best, x, y, halfW, len / 2 + 0.3) then
				return nil, 0, nil
			end
			return CFrame.new(x, y, best.cz - best.hz - 0.06), len, best.part
		end
		-- the frame of a mark when no exposed site was found: on the biggest wall as it is, kept inside it
		local function fallback(u: number, v: number, y0: number, ys: number, halfW: number): CFrame
			local cf, size = at(body), body.Size
			local reach = math.max(size.X / 2 - halfW - 0.3, 0)
			local su, sv = math.clamp((u * 0.74 - 0.37) * size.X, -reach, reach), y0 + ys * v
			return cf * CFrame.new(su, (sv - 0.5) * size.Y, -size.Z / 2 - 0.05)
		end

		-- the L1 palisade: logs and posts. The supports are the logs still standing and the two posts, left to right in the
		-- model's frame; each mark takes the next free one from a stride across them, so the marks are spread over the palisade
		-- (never all on one post), each sits wholly inside its log or post and below its top.
		local supports: { Box } = {}
		if #walls == 0 then
			for _, b in boxes do
				if b.part.Name == "Palisade" or b.part.Name == "PalisadePost" then
					table.insert(supports, b)
				end
			end
			table.sort(supports, function(a, b)
				return a.cx < b.cx
			end)
		end
		local palisade = #supports > 0
		local startAt = if palisade then math.floor(rand() * #supports) else 0
		local stride = math.max(1, math.floor(#supports / 4))
		local markNo = 0
		local used: { [Box]: boolean } = {}
		-- the site of a palisade mark on the next support: (frame, length, support, its width, the mark's width). A recess is
		-- `wide` at most and 0.55 of its support (a log is 2.3 across, a post 1.3); a hairline crack (`wide` nil) keeps the room
		-- its tilt needs. When no support has a free place the mark goes to the middle of its support, still inside it.
		local function palisadeSite(longest: number, wide: number?): (CFrame, number, Box, number)
			local n = #supports
			local want = (startAt + markNo * stride) % n
			markNo += 1
			local function widthOn(cand: Box): number
				return if wide then math.clamp(cand.hx * 2 * 0.55, 0.7, wide) else 0
			end
			local function room(cand: Box): number -- half the mark's width, plus what its tilt or its edge needs
				return if wide then widthOn(cand) / 2 + 0.15 else 0.55
			end
			for pass = 1, 2 do
				for j = 0, n - 1 do
					local cand = supports[1 + (want + j) % n]
					if pass == 2 or not used[cand] then
						for _ = 1, 24 do
							local u, v = rand(), rand()
							local cf, len = site(u, v, 0.3, 0.5, longest, room(cand), cand, if wide then 0.1 else 0.05)
							if cf then
								used[cand] = true
								return cf, len, cand, widthOn(cand)
							end
						end
					end
				end
			end
			local cand = supports[1 + want]
			return CFrame.new(cand.cx, cand.cy, cand.cz - cand.hz - 0.06),
				math.min(longest, cand.hy),
				cand,
				widthOn(cand)
		end

		-- the recesses (patches of broken stone), a shade under the wall
		-- (`reach` and `mid`: half the width and the middle x of the log or post the chips must stay within; nil on a wall)
		local patches: { { at: CFrame, w: number, h: number, wall: BasePart, reach: number?, mid: number } } = {}
		for _ = 1, Damage.BREACH[state] do
			if palisade then
				local cf, h, support, w = palisadeSite(3.4, 1.2)
				local wall = support.part
				table.insert(patches, { at = cf, w = w, h = h, wall = wall, reach = support.hx, mid = support.cx })
				local color, tint = stone(wall, Damage.BREACH_SHADE)
				make(
					"breach",
					Parts.block(ctx, "DamageBreach", Vector3.new(w, h, 0.09), frame * cf, color, M.Wood, tint)
				)
				continue
			end
			local w = 2.2 + 1.0 * rand()
			local cf: CFrame?, h: number, wall: BasePart? = nil, 0, nil
			local u, v = 0.5, 0.5
			for _ = 1, 24 do -- a fixed number of draws per attempt, so the result depends on the model alone
				u, v = 0.15 + 0.7 * rand(), rand()
				cf, h, wall = site(u, v, 0.3, 0.5, 4.2, w / 2 + 0.7)
				if cf then
					break
				end
			end
			if cf == nil then
				cf, h, wall = fallback(u, v, 0.4, 0.4, w / 2 + 0.7), math.min(4.2, body.Size.Y * 0.4), body
			end
			table.insert(patches, { at = cf :: CFrame, w = w, h = h, wall = wall :: BasePart, reach = nil, mid = 0 })
			local color, tint = stone(wall :: BasePart, Damage.BREACH_SHADE)
			make(
				"breach",
				Parts.block(ctx, "DamageBreach", Vector3.new(w, h, 0.09), frame * (cf :: CFrame), color, M.Slate, tint)
			)
		end
		-- hairline cracks, a little under the wall's value
		for _ = 1, Damage.CRACKS[state] do
			local cf: CFrame?, len: number, wall: BasePart?, tilt: number = nil, 0, nil, 0
			if palisade then
				local support: Box
				cf, len, support = palisadeSite(2.6, nil)
				wall = support.part
				tilt = (rand() - 0.5) * 0.7
			else
				local u, v = 0.5, 0.5
				for _ = 1, 24 do
					u, v = rand(), rand()
					tilt = (rand() - 0.5) * 0.7
					cf, len, wall = site(u, v, 0.2, 0.55, 3.8, 0.8)
					if cf then
						break
					end
				end
				if cf == nil then
					cf, len, wall = fallback(u, v, 0.3, 0.5, 0.8), math.min(3.8, body.Size.Y * 0.4), body
				end
			end
			local color, tint = stone(wall :: BasePart, Damage.CRACK_SHADE)
			make(
				"crack",
				Parts.block(
					ctx,
					"DamageCrack",
					Vector3.new(0.14, len, 0.07),
					frame * ((cf :: CFrame) * CFrame.Angles(0, 0, tilt)),
					color,
					if palisade then M.Wood else M.Slate,
					tint
				)
			)
		end
		-- chipped stone round the rim of the recesses (the foot, then the left and right edges): stone-coloured blocks a shade
		-- lighter than the wall, standing proud of the face, so the edges read as broken (smaller on a log or a post)
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
			local k = if p.reach then 0.6 else 1
			local cw, ch, turn = (0.8 + 0.6 * rand()) * k, (0.6 + 0.4 * rand()) * k, (rand() - 0.5) * 0.9
			if p.reach then -- on a log or a post the chip stays within it, whatever its turn
				local half = (cw * math.cos(turn) + ch * math.abs(math.sin(turn))) / 2
				local room = math.max(p.reach - 0.05 - half, 0)
				dx = math.clamp(p.at.X + dx, p.mid - room, p.mid + room) - p.at.X
			end
			local color, tint = stone(p.wall, Damage.CHIP_LIGHT)
			make(
				"chip",
				Parts.block(
					ctx,
					"DamageChip",
					Vector3.new(cw, ch, 0.4),
					frame * (p.at * CFrame.new(dx, dy, -0.2) * CFrame.Angles(0, 0, turn)),
					color,
					if p.reach then M.Wood else M.Slate,
					tint
				)
			)
		end
		-- 4. rubble at the corner's foot, in the wall's own colour, standing on the model's base plane (y = 0 of its own
		-- frame, wherever the model stands) and inside the model's footprint (the Root is footprint-sized): the sides and the back
		-- strictly, the front no more than 2 studs beyond it, as far as the Kit's own entrance steps may reach
		local bodyTint = body:GetAttribute("KitTint")
		for i = 1, Damage.RUBBLE[state] do
			local s = Vector3.new(4.4 - i * 0.8, 2.8 - i * 0.45, 3.8 - i * 0.7)
			local turn = rand() * math.pi
			local hx = (s.X * math.abs(math.cos(turn)) + s.Z * math.abs(math.sin(turn))) / 2
			local hz = (s.X * math.abs(math.sin(turn)) + s.Z * math.abs(math.cos(turn))) / 2
			local x = math.clamp(cornerX - (i - 1) * 2.6, -footX + hx, math.max(footX - hx, -footX + hx))
			local z = math.max(lo.Z - 0.2 - (i % 2) * 1.2, -footZ - 2 + hz)
			local rubble = Parts.block(
				ctx,
				"DamageRubble",
				s,
				frame * (CFrame.new(x, s.Y / 2 - 0.2, z) * CFrame.Angles(0, turn, 0)),
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
					if top <= stump.cy + EPS and top > supportY + EPS then
						supportY = top
					end
				end
			end
			if supportY > -math.huge then
				local w, d = math.min(2 * stump.hx, 7.5) * 0.95, math.min(2 * stump.hz, 7.5) * 0.95
				local tiltX, turn, tiltZ = (rand() - 0.5) * 0.2, rand() * math.pi, (rand() - 0.5) * 0.2
				-- the slab turned about Y reaches further than its sides: shrink it, and draw its centre in, until it is inside the
				-- footprint (a cap at a corner of the keep)
				local reachX = (w * math.abs(math.cos(turn)) + d * math.abs(math.sin(turn))) / 2 + 0.06
				local reachZ = (w * math.abs(math.sin(turn)) + d * math.abs(math.cos(turn))) / 2 + 0.06
				local fit = math.clamp(
					math.min((footX - math.abs(stump.cx)) / reachX, (footZ - math.abs(stump.cz)) / reachZ),
					0.5,
					1
				)
				local sx = math.sign(stump.cx) * math.min(math.abs(stump.cx), footX - reachX * fit)
				local sz = math.sign(stump.cz) * math.min(math.abs(stump.cz), footZ - reachZ * fit)
				local slab = Parts.block(
					ctx,
					"DamageStump",
					Vector3.new(w * fit, 1.0, d * fit),
					frame * (CFrame.new(sx, supportY + 0.5, sz) * CFrame.Angles(tiltX, turn, tiltZ)),
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
