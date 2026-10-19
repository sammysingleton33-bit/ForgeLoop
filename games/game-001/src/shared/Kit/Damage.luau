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
	KitDamage = true and KitDamageKind = "crack" | "rubble" | "smoke"; they are direct children of the model.

	States (cumulative; the numbers are the totals at that state)
		state  Damage   cracks  rubble  smoke  roof / merlon parts removed        collapse
		  0    < 0.25     0       0       0     0                                  none (the model is exactly as built)
		  1    >= 0.25    2       0       0     2
		  2    >= 0.5     4       0       1     5
		  3    >= 0.75    6       3       2     8                                  the top of one front corner
		  4    >= 0.95    7       3       3     10                                 the same, with more smoke
	At most MAX_EXTRA_PARTS (14) parts are added (13 at state 4); none at state 0. Removed parts are the merlons, roof tiles,
	thatch, lean-to roofs and palisade logs of the model (never a banner, emblem, crest, door, window, throne or the
	kingdom caps outside the collapsed corner), picked by a deterministic shuffle seeded from the model's type, level
	and variant, so state 2 keeps what state 1 removed. The collapsed corner removes the caps, merlons and roof parts in
	the top half of the front-right corner (x >= right edge - 30 %, z <= front edge + 30 %).
	Cracks are thin dark wedges on the building's biggest wall (front face first, then its right face); rubble is three
	blocks in the colour of that wall at the corner's foot; smoke is up to three translucent grey Balls rising from the
	corner, kept inside the model's bounding box (the client may tween them: they are anchored, non-colliding parts).

	Compatibility
	- Burning (FORGE-04's FeedbackController reads the model attribute `Burning` and the model's bounding box top): this module
	  touches neither the attribute nor the box's top (it never removes the highest part of the model and puts the smoke
	  inside the box), so a damaged model still burns, with the flames at the same roof.
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
Damage.CRACKS = table.freeze({ 2, 4, 6, 7 })
Damage.RUBBLE = table.freeze({ 0, 0, 3, 3 })
Damage.SMOKE = table.freeze({ 0, 1, 2, 3 })
Damage.REMOVED = table.freeze({ 2, 5, 8, 10 })

local CRACK = Color3.fromRGB(30, 26, 24)
local SMOKE = Color3.fromRGB(118, 116, 114)
-- walls the cracks may sit on, then the parts that go missing and the parts of a collapsing corner
local BODY =
	{ Walls = true, Hall = true, Donjon = true, Shaft = true, Curtain = true, GateTower = true, BarnWalls = true }
local MISSING =
	{ Merlon = true, RoofTiles = true, Thatch = true, ThatchLayer = true, LeanToRoof = true, Palisade = true }
Damage.MISSING = MISSING -- the part names that can go missing (tests read it)
local CORNER = {
	Merlon = true,
	RoofTiles = true,
	RoofCorner = true,
	Thatch = true,
	ThatchLayer = true,
	LeanToRoof = true,
	Spire = true,
	SpireEave = true,
	CapEave = true,
	Hoarding = true,
	HoardingBeam = true,
	Drum = true,
	DrumBand = true,
	Dome = true,
	DomeTip = true,
	Finial = true,
	FinialBall = true,
	Palisade = true,
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
	part.CastShadow = kind == "rubble"
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

	-- 1. parts that go missing (a deterministic shuffle: state 2 keeps what state 1 took)
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
	for i = #pool, 2, -1 do
		local j = 1 + math.floor(rand() * i)
		pool[i], pool[j] = pool[j], pool[i]
	end
	local parked: { BasePart } = {}
	local function take(p: BasePart)
		if p ~= topPart and p.Parent == model then
			p.Parent = nil
			table.insert(parked, p)
		end
	end
	local wantRemoved = Damage.REMOVED[state]
	for i = 1, math.min(wantRemoved, #pool) do
		take(pool[i])
	end

	-- 2. the corner: the top of the front-right corner falls (state 3 and 4)
	local cornerX, cornerZ, cornerY = hi.X - 0.15 * width, lo.Z + 0.15 * depth, lo.Y + 0.55 * height
	if state >= 3 then
		local fallen = 0
		for _, p in kids do
			if fallen >= 14 then
				break
			end
			if CORNER[p.Name] and p ~= topPart and p.Parent == model then
				local c = p.CFrame.Position
				if c.X >= hi.X - 0.3 * width and c.Z <= lo.Z + 0.3 * depth and c.Y >= lo.Y + 0.5 * height then
					take(p)
					fallen += 1
				end
			end
		end
	end
	if #parked > 0 then
		stash[model] = parked
	end

	-- 3. cracks: thin dark wedges on the biggest wall, the front face first, then the right face
	local body = bodyOf(model, kids)
	if body then
		local cf, size = body.CFrame, body.Size
		for i = 1, Damage.CRACKS[state] do
			local onFront = i <= 4
			local u, v, tilt = rand() * 0.74 - 0.37, 0.28 + rand() * 0.5, (rand() - 0.5) * 0.7
			local len = math.min(4.2, size.Y * 0.55)
			local face = if onFront
				then cf * CFrame.new(u * size.X, (v - 0.5) * size.Y, -size.Z / 2 - 0.05)
				else cf * CFrame.new(size.X / 2 + 0.05, (v - 0.5) * size.Y, u * size.Z) * CFrame.Angles(
					0,
					-math.pi / 2,
					0
				)
			local crack = Parts.wedge(
				ctx,
				"DamageCrack",
				Vector3.new(0.12, len, 0.6),
				face * CFrame.Angles(0, 0, tilt) * CFrame.Angles(0, math.pi / 2, 0),
				CRACK,
				M.SmoothPlastic
			)
			make("crack", crack)
		end
		-- 4. rubble at the corner's foot, in the wall's own colour
		local bodyTint = body:GetAttribute("KitTint")
		for i = 1, Damage.RUBBLE[state] do
			local s = Vector3.new(2.6 - i * 0.5, 1.8 - i * 0.3, 2.2 - i * 0.4)
			local rubble = Parts.block(
				ctx,
				"DamageRubble",
				s,
				CFrame.new(cornerX - (i - 1) * 1.9, s.Y / 2 - 0.2, lo.Z - 0.2 - (i % 2) * 0.9)
					* CFrame.Angles(0, rand() * math.pi, 0),
				Parts.shade(body.Color, 0.78),
				M.Slate,
				if type(bodyTint) == "number" then bodyTint * 0.78 else nil -- a tinted wall's rubble recolours with it
			)
			make("rubble", rubble)
		end
	end

	-- 5. smoke: translucent grey Balls rising from the corner, inside the model's bounding box
	for i = 1, Damage.SMOKE[state] do
		local d = 2.6 + i * 1.1
		local y = math.min(cornerY + (i - 1) * 2.4, hi.Y - d / 2)
		local puff = Parts.ball(
			ctx,
			"DamageSmoke",
			d,
			Vector3.new(cornerX - i * 0.6, y, cornerZ + i * 0.5),
			SMOKE,
			M.SmoothPlastic
		)
		puff.Transparency = 0.5 + 0.1 * i
		make("smoke", puff)
	end
end

return Damage
