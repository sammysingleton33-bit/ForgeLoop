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
	KitDamage = true and KitDamageKind = "crack" | "rubble" | "smoke" | "stump"; they are direct children of the model.

	States (cumulative; the numbers are the totals at that state)
		state  Damage   cracks  rubble  smoke  roof / merlon parts removed        collapse
		  0    < 0.25     0       0       0     0                                  none (the model is exactly as built)
		  1    >= 0.25    2       0       0     2
		  2    >= 0.5     4       0       1     5
		  3    >= 0.75    6       3       2     8                                  the top of one front corner
		  4    >= 0.95    7       3       3     10                                 the same, with more smoke
	At most MAX_EXTRA_PARTS (14) parts are added (13 at state 4, 14 with the stump below); none at state 0. Removed parts are the merlons, roof tiles,
	thatch, lean-to roofs and palisade logs of the model (never a banner, emblem, crest, door, window, throne or the
	kingdom caps outside the collapsed corner), picked by a deterministic shuffle seeded from the model's type, level
	and variant, so state 2 keeps what state 1 removed. The collapsed corner removes the caps, merlons and roof parts in
	the top half of the front-right corner (x >= right edge - 30 %, z <= front edge + 30 %).
	The removed number is min(table, the parts of the model that can go missing, Damage.MISSING, without the highest part);
	the collapsed corner (state 3 and 4) takes more on top.
	Cracks are thin dark wedges on the walls the player sees: at a spread of points of the model's box the outermost
	upright wall block there, and only where nothing (a turret, a porch, a banner) stands in front of it; the front face
	first (up to 4), then the right face; a crack that finds no such site goes on the biggest wall. Rubble is three blocks
	in the colour of the biggest wall at the corner's foot (with its tint, so a recolour follows); smoke is up to three
	translucent light-grey Balls rising from the corner, kept inside the model's bounding box (the client may tween them:
	they are anchored, non-colliding parts). The stump (state 3 and 4, only when a tower cap fell: Drum, Dome, Spire ...) is one
	tilted slab of broken masonry where the lowest cap part stood, so the bare top of the tower (flat, often flush with its
	corbel) does not show.

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
local SMOKE = Color3.fromRGB(150, 148, 146)
-- walls the cracks may sit on, then the parts that go missing and the parts of a collapsing corner
local BODY =
	{ Walls = true, Hall = true, Donjon = true, Shaft = true, Curtain = true, GateTower = true, BarnWalls = true }
local MISSING =
	{ Merlon = true, RoofTiles = true, Thatch = true, ThatchLayer = true, LeanToRoof = true, Palisade = true }
Damage.MISSING = MISSING -- the part names that can go missing (tests read it)
-- the parts of a tower cap (the stump marks where the lowest of them stood)
local CAP =
	{ Drum = true, DrumBand = true, Dome = true, Spire = true, SpireEave = true, CapEave = true, Hoarding = true }
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
	part.CastShadow = kind == "rubble" or kind == "stump"
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
	local cornerX, cornerZ, cornerY = hi.X - 0.15 * width, lo.Z + 0.15 * depth, lo.Y + 0.72 * height
	local stump: Box? = nil -- the lowest tower cap part that fell: the broken top of what stands under it
	if state >= 3 then
		local fallen = 0
		for _, p in kids do
			if fallen >= 14 then
				break
			end
			if CORNER[p.Name] and p ~= topPart and p.Parent == model then
				local c = p.CFrame.Position
				if c.X >= hi.X - 0.3 * width and c.Z <= lo.Z + 0.3 * depth and c.Y >= lo.Y + 0.5 * height then
					if CAP[p.Name] then
						local box = boxOf(p)
						if stump == nil or box.cy - box.hy < stump.cy - stump.hy then
							stump = box
						end
					end
					take(p)
					fallen += 1
				end
			end
		end
	end
	if #parked > 0 then
		stash[model] = parked
	end

	-- 3. cracks: thin dark wedges on the walls the player sees, the front face first, then the right face. Sites are found
	-- on the outermost wall block at a spread of points (a facade that hides the biggest wall does not hide the crack);
	-- a site the walls do not offer falls back to the biggest wall.
	local body = bodyOf(model, kids)
	if body then
		local boxes, walls = boxesOf(model, kids)
		-- a crack site on the front (onFront) or right face at the point (u, v) of the model's box: on the outermost wall
		-- block there, and only when nothing (a turret, a porch, a banner, a step) stands in front of it
		local function site(onFront: boolean, u: number, v: number): (CFrame?, number)
			local best: Box? = nil
			local bestFace = math.huge
			local x, y, z =
				lo.X + (0.1 + 0.8 * u) * width, lo.Y + (0.2 + 0.55 * v) * height, lo.Z + (0.1 + 0.8 * u) * depth
			for _, w in walls do
				local face, inside
				if onFront then
					face, inside = w.cz - w.hz, math.abs(x - w.cx) <= w.hx - 0.4
				else
					face, inside = -(w.cx + w.hx), math.abs(z - w.cz) <= w.hz - 0.4
				end
				if inside and math.abs(y - w.cy) <= w.hy - 1 and face < bestFace then
					best, bestFace = w, face
				end
			end
			if best == nil then
				return nil, 0
			end
			local len = math.min(4.2, best.hy * 2 * 0.55)
			local halfLen = len / 2 + 0.3
			for _, b in boxes do
				if b ~= best then
					if onFront then
						if
							b.cz - b.hz < best.cz - best.hz - 0.15
							and math.abs(x - b.cx) < b.hx + 0.5
							and math.abs(y - b.cy) < b.hy + halfLen
						then
							return nil, 0
						end
					elseif
						b.cx + b.hx > best.cx + best.hx + 0.15
						and math.abs(z - b.cz) < b.hz + 0.5
						and math.abs(y - b.cy) < b.hy + halfLen
					then
						return nil, 0
					end
				end
			end
			if onFront then
				return CFrame.new(x, y, best.cz - best.hz - 0.06), len
			end
			return CFrame.new(best.cx + best.hx + 0.06, y, z) * CFrame.Angles(0, -math.pi / 2, 0), len
		end
		local function place(at: CFrame, len: number, tilt: number)
			local crack = Parts.wedge(
				ctx,
				"DamageCrack",
				Vector3.new(0.12, len, 0.6),
				at * CFrame.Angles(0, 0, tilt) * CFrame.Angles(0, math.pi / 2, 0),
				CRACK,
				M.SmoothPlastic
			)
			make("crack", crack)
		end
		local want = Damage.CRACKS[state]
		for i = 1, want do
			local onFront = i <= 4
			local at, len, tilt = nil, 0, 0
			for _ = 1, 24 do -- a fixed number of draws per attempt, so the result depends on the model alone
				local u, v = rand(), rand()
				tilt = (rand() - 0.5) * 0.7
				at, len = site(onFront, u, v)
				if at then
					break
				end
			end
			if at == nil then -- nothing exposed was found: the biggest wall, as it is
				local cf, size = body.CFrame, body.Size
				local su, sv = rand() * 0.74 - 0.37, 0.28 + rand() * 0.5
				len = math.min(4.2, size.Y * 0.55)
				at = if onFront
					then cf * CFrame.new(su * size.X, (sv - 0.5) * size.Y, -size.Z / 2 - 0.05)
					else cf * CFrame.new(size.X / 2 + 0.05, (sv - 0.5) * size.Y, su * size.Z) * CFrame.Angles(
						0,
						-math.pi / 2,
						0
					)
			end
			place(at :: CFrame, len, tilt)
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
					Parts.shade(body.Color, 0.7),
					M.Slate,
					if type(bodyTint) == "number" then bodyTint * 0.7 else nil
				)
				make("stump", slab)
			end
		end
	end

	-- 5. smoke: translucent grey Balls rising from the corner, inside the model's bounding box
	for i = 1, Damage.SMOKE[state] do
		local d = 3.2 + i * 1.4
		local y = math.min(cornerY + (i - 1) * 2.4, hi.Y - d / 2)
		local puff = Parts.ball(
			ctx,
			"DamageSmoke",
			d,
			Vector3.new(cornerX - i * 0.6, y, cornerZ + i * 0.5),
			SMOKE,
			M.SmoothPlastic
		)
		puff.Transparency = 0.45 + 0.1 * i
		make("smoke", puff)
	end
end

return Damage
