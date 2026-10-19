--[[
	The soldier unit kinds (FL-0128, FORGE-02, Operation Crownfall): Kit.character("soldier", job, ...) builds the spear
	soldier (a 5.4 spear planted at the fist), the knight (bulky, a sword held at the ready, a large shield with the kingdom's
	mark, a broad great helm and a tall plume) or the archer (a curved three-part bow with a visible string, round head, cap,
	no helm) by unit kind (job = unit kind, the same convention as CharacterMesh's soldier_<job>). This spec pins:

	  1. units      the three kinds differ (weapon, shield, helm or bare head, width, torso colour, crest height, outline),
	                stay within the 11-part rig with the kingdom crest (D-033), keep the Pose joints and the rig conventions,
	                recolour like a fresh build, and unknown jobs are the spear soldier; the spear tip stands about 1.3 x the
	                body's height, carried at the fist with its butt off the ground and a pennant HANGING under the head; the
	                sword rises from the fist outward and forward, clear of the arm and torso; the bow is held at the fist, curved
	                (two limbs and a string in front) and ends under the chin; the plume stands up, the dome caps the helm, no
	                shield mark is dark or round (flat marks only);
	  2. clearance  the shield, bow and sword keep clear of the head, torso, legs and arms in every Pose action;
	  3. mutants    the key rules above are caught when broken.
]]

local T = require("../../../../roblox/tests/harness/Test")
local describe, it = T.describe, T.it

local Kit = require("@game/ReplicatedStorage/Game/Kit/Kit")
local Pose = require("@game/ReplicatedStorage/Game/Sim/Pose")
local KingdomsConfig = require("@game/ReplicatedStorage/Forge/Config/Kingdoms")

local CANON: { [string]: Color3 } = {}
for _, identity in KingdomsConfig.identities do
	local c = identity.color
	CANON[identity.id] = Color3.fromRGB(c[1], c[2], c[3])
end
local HUES = { "crimson", "azure", "emerald", "gold" }

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

local function motors(model: Instance): { Motor6D }
	local out = {}
	for _, d in model:GetDescendants() do
		if d:IsA("Motor6D") then
			table.insert(out, d)
		end
	end
	return out
end

local function noYield<R>(fn: () -> R): R
	local co = coroutine.create(fn)
	local ok, result = coroutine.resume(co)
	assert(ok, result)
	assert(coroutine.status(co) == "dead", "Kit yielded")
	return result
end

type Check = () -> { string }
local CHECKS: { [string]: Check } = {}

-- Forward kinematics as the engine does it: Part1 = Part0 * C0 * Transform * C1:Inverse(); welds follow.
local function posed(rig: Model, joints: { [string]: CFrame }): { [BasePart]: CFrame }
	local root = rig.PrimaryPart :: BasePart
	local world: { [BasePart]: CFrame } = { [root] = root.CFrame }
	local list = motors(rig)
	local moved = true
	while moved do
		moved = false
		for _, m in list do
			local p0, p1 = m.Part0 :: BasePart, m.Part1 :: BasePart
			if world[p0] and not world[p1] then
				world[p1] = world[p0] * m.C0 * (joints[m.Name] or CFrame.new()) * m.C1:Inverse()
				moved = true
			end
		end
	end
	for _ = 1, 3 do -- welds chain (a part welded to a welded part)
		for _, d in rig:GetDescendants() do
			if d:IsA("Weld") and world[d.Part0 :: BasePart] and not world[d.Part1 :: BasePart] then
				world[d.Part1 :: BasePart] = world[d.Part0 :: BasePart] * d.C0 * d.C1:Inverse()
			end
		end
	end
	return world
end

-- ------------------------------------------------------------------ 5. soldier kinds

local UNIT_KINDS = { "soldier", "knight", "archer" }
local TOOL_OF = { soldier = "spear", knight = "sword", archer = "bow" }
local DETAILS = {
	soldier = { pennant = "Tool", spearhead = "Tool" },
	knight = { shield = "LeftArm", shieldmark = "LeftArm" },
	archer = { bowlimb = "Tool", bowstring = "Tool" },
}
local POSE_JOINTS = { "Torso", "Head", "LeftArm", "RightArm", "LeftLeg", "RightLeg", "Tool" }

local function unit(kind: string, hue: string?): Model
	return Kit.character("soldier", kind, if hue then CANON[hue] else CANON.crimson, nil, hue)
end

-- half extents along the world axes of a part's box
local function halfY(p: BasePart): number
	local cf, sz = p.CFrame, p.Size
	return (math.abs(cf.RightVector.Y) * sz.X + math.abs(cf.UpVector.Y) * sz.Y + math.abs(cf.LookVector.Y) * sz.Z) / 2
end
local function halfX(p: BasePart): number
	local cf, sz = p.CFrame, p.Size
	return (math.abs(cf.RightVector.X) * sz.X + math.abs(cf.UpVector.X) * sz.Y + math.abs(cf.LookVector.X) * sz.Z) / 2
end

local function shapeOfPart(p: BasePart): string
	if p:IsA("Part") and (p :: Part).Shape == Enum.PartType.Ball then
		return "ball"
	elseif p:IsA("Part") and (p :: Part).Shape == Enum.PartType.Cylinder then
		return "cylinder"
	end
	return "box"
end

local function crestOf(rig: Model): BasePart?
	local hair = rig:FindFirstChild("Hair") :: BasePart?
	if hair and string.sub(tostring(hair:GetAttribute("KitHeadwear")), 1, 6) == "crest_" then
		return hair
	end
	return nil
end

local function detailKinds(rig: Model): { [string]: string }
	local out = {}
	for _, p in parts(rig) do
		if p:GetAttribute("KitDetail") == true then
			local w = p:FindFirstChild("DetailWeld") :: Weld?
			out[tostring(p:GetAttribute("KitDetailKind"))] = if w and w.Part0 then w.Part0.Name else "?"
		end
	end
	return out
end

CHECKS.units = function()
	local out: { string } = {}
	local sigs: { [string]: string } = {}
	for _, hue in HUES do
		local rigs: { [string]: Model } = {}
		for _, kind in UNIT_KINDS do
			local tag = `{kind} {hue}`
			local rig = noYield(function()
				return unit(kind, hue)
			end)
			rigs[kind] = rig
			local n = count(rig)
			if n > Kit.CHARACTER_MAX_PARTS or n ~= 11 then
				table.insert(out, `{tag}: {n} parts (the crest rig is 11, cap {Kit.CHARACTER_MAX_PARTS})`)
			end
			local names: { string } = {}
			for _, m in motors(rig) do
				table.insert(names, m.Name)
			end
			table.sort(names)
			local want = table.clone(POSE_JOINTS)
			table.sort(want)
			if table.concat(names, ",") ~= table.concat(want, ",") then
				table.insert(out, `{tag}: joints {table.concat(names, ",")} are not Pose.JOINTS`)
			end
			if crestOf(rig) == nil then
				table.insert(out, `{tag}: no kingdom crest (D-033)`)
			end
			local tool = rig:FindFirstChild("Tool")
			if tool == nil or tool:GetAttribute("KitTool") ~= TOOL_OF[kind] then
				table.insert(out, `{tag}: tool is {tool and tool:GetAttribute("KitTool")}, want {TOOL_OF[kind]}`)
			end
			local got = detailKinds(rig)
			for name, parent in DETAILS[kind] do
				if got[name] ~= parent then
					table.insert(out, `{tag}: detail {name} welded to {got[name]}, want {parent}`)
				end
			end
			for name in got do
				if not DETAILS[kind][name] then
					table.insert(out, `{tag}: unexpected detail {name}`)
				end
			end
			for _, p in parts(rig) do
				if p ~= rig.PrimaryPart and (p.Anchored or p.CanCollide or not p.Massless) then
					table.insert(out, `{tag}: {p.Name} must be unanchored, Massless and non-colliding`)
				end
			end
			local root = rig.PrimaryPart :: BasePart
			if not root.Anchored or root.Transparency ~= 1 then
				table.insert(out, `{tag}: Root must be anchored and invisible`)
			end
			sigs[tag] = signature(rig)
			-- the kingdom colour reaches the rig (recolour equals a fresh build)
			local other = if hue == "crimson" then Color3.fromRGB(230, 70, 70) else CANON[hue]
			Kit.setKingdomColor(rig, other)
			local fresh = Kit.character("soldier", kind, other, nil, hue)
			if signature(rig) ~= signature(fresh) then
				table.insert(out, `{tag}: recolour differs from a fresh build`)
			end
			if signature(unit(kind, hue)) ~= sigs[tag] then
				table.insert(out, `{tag}: not deterministic`)
			end
		end
		-- the kinds differ
		local s, k, a = rigs.soldier, rigs.knight, rigs.archer
		if signature(s) == signature(k) or signature(k) == signature(a) or signature(s) == signature(a) then
			table.insert(out, `{hue}: two unit kinds build the same rig`)
		end
		local function width(r: Model): number
			return (r:FindFirstChild("Torso") :: BasePart).Size.X
		end
		if not (width(k) > width(s) + 0.2 and width(s) > width(a) + 0.1) then
			table.insert(out, `{hue}: widths knight {width(k)} > soldier {width(s)} > archer {width(a)} expected`)
		end
		local function torsoColor(r: Model): string
			return (r:FindFirstChild("Torso") :: BasePart).Color:ToHex()
		end
		if torsoColor(s) == torsoColor(k) or torsoColor(k) == torsoColor(a) or torsoColor(s) == torsoColor(a) then
			table.insert(out, `{hue}: two unit kinds share a torso colour`)
		end
		local function head(r: Model): BasePart
			return r:FindFirstChild("Head") :: BasePart
		end
		if (head(a) :: Part).Shape ~= Enum.PartType.Ball then
			table.insert(out, `{hue}: the archer wears a helm (a bare head with a cap is wanted)`)
		end
		for _, helmed in { s, k } do
			if (head(helmed) :: Part).Shape == Enum.PartType.Ball then
				table.insert(out, `{hue}: a {helmed.Name} has a bare head, not a helm`)
			end
		end
		local cs, ck, ca = crestOf(s), crestOf(k), crestOf(a)
		if cs and ck and ca then
			if ck.Size.Y < cs.Size.Y * 1.3 then
				table.insert(
					out,
					`{hue}: the knight's plume ({r3(ck.Size.Y)}) is not 1.3x the soldier's ({r3(cs.Size.Y)})`
				)
			end
			if ca.Size.Y > cs.Size.Y then
				table.insert(out, `{hue}: the archer's cap is taller than the soldier's crest`)
			end
		end
		-- bulk: the knight's helm is broader than the soldier's, the shield is large and kingdom-coloured
		if head(k).Size.X < head(s).Size.X + 0.4 then
			table.insert(out, `{hue}: the knight's helm ({r3(head(k).Size.X)}) is not broader than the soldier's`)
		end
		local shield, mark
		for _, p in parts(k) do
			if p:GetAttribute("KitDetailKind") == "shield" then
				shield = p
			elseif p:GetAttribute("KitDetailKind") == "shieldmark" then
				mark = p
			end
		end
		if shield == nil or shield.Size.X < 1.8 or shield.Size.Y < 2.4 then
			table.insert(out, `{hue}: the knight's shield is not large (1.8 x 2.4 at least)`)
		elseif shield:GetAttribute("KitTint") ~= 1 then
			table.insert(out, `{hue}: the knight's shield is not in the kingdom colour`)
		end
		if mark and mark.Color.R * 0.3 + mark.Color.G * 0.59 + mark.Color.B * 0.11 < 0.5 then
			table.insert(out, `{hue}: the shield mark is dark (it reads as a hole)`)
		end
		-- flat marks only: a round boss shone like glass; every mark is a thin plate (never a ball) in the same metal as the others
		if mark and (shapeOfPart(mark) == "ball" or math.min(mark.Size.X, mark.Size.Y, mark.Size.Z) > 0.2) then
			table.insert(out, `{hue}: the shield mark is a round boss ({shapeOfPart(mark)}), not a flat plate`)
		end
		if mark and mark.Material ~= Enum.Material.Metal then
			table.insert(
				out,
				`{hue}: the shield mark is {mark.Material.Name}, not the same material as the other kingdoms'`
			)
		end
		-- the spear: its tip about 1.3 x the body's height, planted near the ground, held at the fist
		local spear = s:FindFirstChild("Tool") :: BasePart
		local arm = s:FindFirstChild("RightArm") :: BasePart
		local tip = -math.huge
		for _, p in parts(s) do
			if p == spear or p:GetAttribute("KitDetailKind") == "spearhead" then
				tip = math.max(tip, p.CFrame.Position.Y + halfY(p))
			end
		end
		if tip < 7.0 or tip > 7.8 then
			table.insert(out, `{hue}: the spear tip is at {r3(tip)} (about 7.3, 1.3 x the body's 5.5)`)
		end
		-- carried, not planted: the butt stands 0.4 to 1.8 off the ground, and the spear leans forward
		local butt = spear.CFrame.Position.Y - halfY(spear)
		if butt < 0.4 or butt > 1.8 or spear.Size.X > 6.2 then
			table.insert(out, `{hue}: the spear's butt is {r3(butt)} off the ground (carried at the fist: 0.4 to 1.8)`)
		end
		local shaftAxis = spear.CFrame.RightVector
		shaftAxis = if shaftAxis.Y > 0 then shaftAxis else -shaftAxis
		if shaftAxis.Z > -0.12 then
			table.insert(out, `{hue}: the spear does not lean forward (axis {shaftAxis})`)
		end
		-- the pennant HANGS (taller than wide, a cloth under the head), never a horizontal stick that reads as a second weapon
		for _, p in parts(s) do
			if p:GetAttribute("KitDetailKind") == "pennant" then
				local w, h = halfX(p) * 2, halfY(p) * 2
				if h < 1.2 or h < w * 1.4 then
					table.insert(
						out,
						`{hue}: the pennant is {r3(w)} wide and {r3(h)} tall (it must hang, taller than wide)`
					)
				end
				local top = p.CFrame.Position.Y + halfY(p)
				if top > spear.CFrame.Position.Y + halfY(spear) then
					table.insert(out, `{hue}: the pennant is above the shaft's end`)
				end
			end
		end
		if
			math.abs(spear.CFrame.Position.X - arm.CFrame.Position.X) > 0.8
			or math.abs(spear.CFrame.Position.Z - arm.CFrame.Position.Z) > 0.8
		then
			table.insert(out, `{hue}: the spear is not at the fist`)
		end
		-- the sword rises from the fist outward, forward and up, its lower end at the fist: beside the arm, never across the arm
		-- and the torso
		local sword, swordArm = k:FindFirstChild("Tool") :: BasePart, k:FindFirstChild("RightArm") :: BasePart
		local swordUp = sword.CFrame.UpVector
		if swordUp.Z > -0.15 or swordUp.Y < 0.6 or swordUp.X < 0.3 then
			table.insert(out, `{hue}: the sword is not held outward, forward and up (up vector {swordUp})`)
		end
		local swordTip = sword.CFrame.Position + swordUp * (sword.Size.Y / 2)
		local kTorso = k:FindFirstChild("Torso") :: BasePart
		if
			swordTip.X < swordArm.CFrame.Position.X + 0.9
			or swordTip.X < kTorso.CFrame.Position.X + kTorso.Size.X / 2 + 1.0
		then
			table.insert(out, `{hue}: the sword's tip ({r3(swordTip.X)}) crosses over the arm or the torso`)
		end
		local lowEnd = sword.CFrame.Position - sword.CFrame.UpVector * (sword.Size.Y / 2)
		local fist = swordArm.CFrame.Position - Vector3.new(0, swordArm.Size.Y / 2 - 0.2, 0)
		if (lowEnd - fist).Magnitude > 1.1 then
			table.insert(out, `{hue}: the sword's lower end is {r3((lowEnd - fist).Magnitude)} from the fist`)
		end
		-- the bow: two limbs and a string, curved: the limbs' tips and the string lie in front of the grip
		local bow, limb, stringPart = a:FindFirstChild("Tool") :: BasePart, nil, nil
		for _, p in parts(a) do
			if p:GetAttribute("KitDetailKind") == "bowlimb" then
				limb = p
			elseif p:GetAttribute("KitDetailKind") == "bowstring" then
				stringPart = p
			end
		end
		if limb == nil or stringPart == nil then
			table.insert(out, `{hue}: the bow is not limb, limb and string`)
		else
			-- the upper limb runs from the grip (its lower end) up to its tip; both are on the limb's own axis (a cylinder's X)
			local axis = bow.CFrame.RightVector
			axis = if axis.Y > 0 then axis else -axis
			local tipZ = (bow.CFrame.Position + axis * (bow.Size.X / 2)).Z
			local grip = bow.CFrame.Position - axis * (bow.Size.X / 2)
			if grip.Z - tipZ < 0.6 then
				table.insert(
					out,
					`{hue}: the bow is not curved (the upper tip is only {r3(grip.Z - tipZ)} in front of the grip)`
				)
			end
			if (stringPart :: BasePart).Size.X < 2.0 or (stringPart :: BasePart).CFrame.Position.Z > grip.Z - 0.6 then
				table.insert(out, `{hue}: the bowstring is short or not in front of the limbs`)
			end
			-- held away from the face: the whole bow ends under the chin (the head's lowest point) in the standing pose
			local archerHead = a:FindFirstChild("Head") :: BasePart
			local function axisTop(
				p: BasePart
			): number -- the highest point of a cylinder along its own axis (X), plus its radius
				return p.CFrame.Position.Y + math.abs(p.CFrame.RightVector.Y) * p.Size.X / 2 + p.Size.Y / 2
			end
			local bowTop = math.max(axisTop(bow), axisTop(limb :: BasePart), axisTop(stringPart :: BasePart))
			if bowTop > archerHead.CFrame.Position.Y - archerHead.Size.Y / 2 + 0.05 then
				table.insert(out, `{hue}: the bow reaches {r3(bowTop)}, up to the archer's face`)
			end
		end
		-- outline at a distance: each kind's front silhouette (width x height of the whole figure) differs from the others'
		local function outline(r: Model): (number, number)
			local lo = Vector3.new(math.huge, math.huge, math.huge)
			local hi = -lo
			for _, p in parts(r) do
				if p ~= r.PrimaryPart then
					local e = Vector3.new(halfX(p), halfY(p), 0)
					lo = lo:Min(p.CFrame.Position - e)
					hi = hi:Max(p.CFrame.Position + e)
				end
			end
			return hi.X - lo.X, hi.Y - lo.Y
		end
		local sw, sh = outline(s)
		local kw, kh = outline(k)
		local aw, ah = outline(a)
		if math.abs(sw - kw) < 0.4 and math.abs(sh - kh) < 0.4 then
			table.insert(out, `{hue}: soldier and knight have the same outline ({r3(sw)} x {r3(sh)})`)
		end
		if math.abs(sw - aw) < 0.3 and math.abs(sh - ah) < 0.4 then
			table.insert(out, `{hue}: soldier and archer have the same outline`)
		end
		if math.abs(kw - aw) < 0.4 and math.abs(kh - ah) < 0.4 then
			table.insert(out, `{hue}: knight and archer have the same outline`)
		end
		-- the crests: the plume stands up, the dome caps the helm
		if hue == "emerald" and cs then
			if cs.CFrame.UpVector.Y < 0.99 or cs.Size.Y < 1.0 or cs.Size.X > 0.6 then
				table.insert(out, `{hue}: the plume does not stand up as a thin fin`)
			end
		elseif hue == "gold" and cs then
			if
				(cs :: Part).Shape ~= Enum.PartType.Ball
				or cs.Size.X < head(s).Size.X + 0.3
				or cs.CFrame.Position.Y - head(s).CFrame.Position.Y > head(s).Size.Y / 2
			then
				table.insert(out, `{hue}: the dome is not a cap over the helm`)
			end
		end
	end
	-- the four kingdoms' shield marks differ
	local markSigs: { [string]: boolean } = {}
	for _, hue in HUES do
		for _, p in parts(unit("knight", hue)) do
			if p:GetAttribute("KitDetailKind") == "shieldmark" then
				markSigs[`{if p:IsA("Part") then (p :: Part).Shape.Name else p.ClassName}|{r3(p.Size.X)}|{r3(p.Size.Y)}`] =
					true
			end
		end
	end
	local distinct = 0
	for _ in markSigs do
		distinct += 1
	end
	if distinct < 4 then
		table.insert(out, `only {distinct} different shield marks over four kingdoms`)
	end
	-- without a kingdom: no crest and no mark, still within the cap
	for _, kind in UNIT_KINDS do
		local rig = Kit.character("soldier", kind, CANON.crimson)
		if count(rig) > 11 or crestOf(rig) ~= nil then
			table.insert(out, `{kind} without a kingdom: {count(rig)} parts, crest {crestOf(rig)}`)
		end
		for _, p in parts(rig) do
			if p:GetAttribute("KitDetailKind") == "shieldmark" then
				table.insert(out, `{kind} without a kingdom has a shield mark`)
			end
		end
	end
	-- unknown jobs are the spear soldier; a plain soldier job too; citizens never carry the unit kit
	local base = signature(unit("soldier", "azure"))
	for _, job in { "soldier", "champion", "" } do
		if signature(Kit.character("soldier", job, CANON.azure, nil, "azure")) ~= base then
			table.insert(out, `job "{job}" is not the spear soldier`)
		end
	end
	local drafted = Kit.character("citizen", "knight", CANON.azure, nil, "azure")
	if
		drafted:FindFirstChild("Tool")
		and (drafted:FindFirstChild("Tool") :: Instance):GetAttribute("KitTool") == "sword"
	then
		table.insert(out, "a citizen with job knight carries the knight's sword")
	end
	return out
end

-- ------------------------------------------------------------------ 5b. unit pose clearance (exact shapes)

-- Same maths as KitCharacter.spec's tool/head clearance: a box against a sphere, a sphere against a sphere, two boxes by
-- the separating axis, anything with a Cylinder by sample points on each against the other's exact signed distance.
local function shapeOf(p: BasePart): string
	if p:IsA("Part") and (p :: Part).Shape == Enum.PartType.Ball then
		return "ball"
	elseif p:IsA("Part") and (p :: Part).Shape == Enum.PartType.Cylinder then
		return "cylinder"
	end
	return "box"
end

local function boxSphereDistance(cf: CFrame, size: Vector3, center: Vector3, radius: number): number
	local l = cf:Inverse() * center
	local half = { size.X / 2, size.Y / 2, size.Z / 2 }
	local coords = { l.X, l.Y, l.Z }
	local outside, depth = 0, math.huge
	for i = 1, 3 do
		local over = math.abs(coords[i]) - half[i]
		if over > 0 then
			outside += over * over
		end
		depth = math.min(depth, -over)
	end
	if outside > 0 then
		return math.sqrt(outside) - radius
	end
	return -(radius + depth)
end

local function boxBox(cfA: CFrame, sizeA: Vector3, cfB: CFrame, sizeB: Vector3): number
	local axesA = { cfA.RightVector, cfA.UpVector, cfA.LookVector }
	local axesB = { cfB.RightVector, cfB.UpVector, cfB.LookVector }
	local halfA = { sizeA.X / 2, sizeA.Y / 2, sizeA.Z / 2 }
	local halfB = { sizeB.X / 2, sizeB.Y / 2, sizeB.Z / 2 }
	local d = cfB.Position - cfA.Position
	local candidates = {}
	for _, a in axesA do
		table.insert(candidates, a)
	end
	for _, b in axesB do
		table.insert(candidates, b)
	end
	for _, a in axesA do
		for _, b in axesB do
			local c = a:Cross(b)
			if c.Magnitude > 1e-6 then
				table.insert(candidates, c.Unit)
			end
		end
	end
	local best = -math.huge
	for _, axis in candidates do
		local ra, rb = 0, 0
		for i = 1, 3 do
			ra += halfA[i] * math.abs(axesA[i]:Dot(axis))
			rb += halfB[i] * math.abs(axesB[i]:Dot(axis))
		end
		best = math.max(best, math.abs(d:Dot(axis)) - ra - rb)
	end
	return best
end

local function signedDistance(p: BasePart, cf: CFrame, point: Vector3): number
	local q = cf:Inverse() * point
	local h = p.Size / 2
	local shape = shapeOf(p)
	if shape == "ball" then
		return q.Magnitude - h.X
	elseif shape == "cylinder" then
		local radial = math.sqrt(q.Y * q.Y + q.Z * q.Z) - math.min(h.Y, h.Z)
		local axial = math.abs(q.X) - h.X
		return math.min(math.max(radial, axial), 0) + math.sqrt(math.max(radial, 0) ^ 2 + math.max(axial, 0) ^ 2)
	end
	local dx, dy, dz = math.abs(q.X) - h.X, math.abs(q.Y) - h.Y, math.abs(q.Z) - h.Z
	return math.min(math.max(dx, dy, dz), 0)
		+ math.sqrt(math.max(dx, 0) ^ 2 + math.max(dy, 0) ^ 2 + math.max(dz, 0) ^ 2)
end

local function samplePoints(p: BasePart, cf: CFrame): { Vector3 }
	local h = p.Size / 2
	local out: { Vector3 } = { cf.Position }
	local shape = shapeOf(p)
	local function add(x: number, y: number, z: number)
		table.insert(out, cf * Vector3.new(x, y, z))
	end
	if shape == "cylinder" then
		local r = math.min(h.Y, h.Z)
		for _, x in { -h.X, 0, h.X } do
			for step = 0, 11 do
				local a = step / 12 * 2 * math.pi
				add(x, math.cos(a) * r, math.sin(a) * r)
			end
		end
	elseif shape == "ball" then
		for _, sign in { -1, 1 } do
			add(sign * h.X, 0, 0)
			add(0, sign * h.X, 0)
			add(0, 0, sign * h.X)
		end
	else
		for _, sx in { -1, 0, 1 } do
			for _, sy in { -1, 0, 1 } do
				for _, sz in { -1, 0, 1 } do
					if sx ~= 0 or sy ~= 0 or sz ~= 0 then
						add(sx * h.X, sy * h.Y, sz * h.Z)
					end
				end
			end
		end
	end
	return out
end

local function exactClearance(a: BasePart, cfA: CFrame, b: BasePart, cfB: CFrame): number
	local sa, sb = shapeOf(a), shapeOf(b)
	if sa == "cylinder" or sb == "cylinder" then
		local best = math.huge
		for _, point in samplePoints(a, cfA) do
			best = math.min(best, signedDistance(b, cfB, point))
		end
		for _, point in samplePoints(b, cfB) do
			best = math.min(best, signedDistance(a, cfA, point))
		end
		return best
	elseif sa == "ball" and sb == "ball" then
		return (cfA.Position - cfB.Position).Magnitude - a.Size.X / 2 - b.Size.X / 2
	elseif sa == "ball" then
		return boxSphereDistance(cfB, b.Size, cfA.Position, a.Size.X / 2)
	elseif sb == "ball" then
		return boxSphereDistance(cfA, a.Size, cfB.Position, b.Size.X / 2)
	end
	return boxBox(cfA, a.Size, cfB, b.Size)
end

local ACTIONS = { "idle", "walk", "work", "carry", "fight", "flee", "celebrate" }

-- Every Pose action (walk, carry and flee at speeds 0, 6 and 12; 12 phases per cycle) posed once for a rig.
local function poseSet(rig: Model, job: string): { { world: { [BasePart]: CFrame }, label: string } }
	local out = {}
	for _, action in ACTIONS do
		local speeds = if action == "walk" or action == "carry" or action == "flee" then { 0, 6, 12 } else { 0 }
		for _, speed in speeds do
			for i = 0, 11 do
				table.insert(out, {
					world = posed(rig, Pose.sample(action, job, i / 12, speed)),
					label = `{action} speed {speed} phase {i}/12`,
				})
			end
		end
	end
	return out
end

-- The smallest clearance between two groups of rig parts (by Name or KitDetailKind) over a rig's poses, and where it was.
local function groupClearance(
	rig: Model,
	poses: { { world: { [BasePart]: CFrame }, label: string } },
	groupA: { string },
	groupB: { string }
): (number, string)
	local function named(names: { string }): { BasePart }
		local out = {}
		for _, p in parts(rig) do
			if table.find(names, p.Name) or table.find(names, tostring(p:GetAttribute("KitDetailKind"))) then
				table.insert(out, p)
			end
		end
		return out
	end
	local A, B = named(groupA), named(groupB)
	local low, where = math.huge, ""
	for _, pose in poses do
		for _, a in A do
			for _, b in B do
				local c = exactClearance(a, pose.world[a], b, pose.world[b])
				if c < low then
					low, where = c, `{a.Name}|{b.Name} {pose.label}`
				end
			end
		end
	end
	return low, where
end

-- shield and mark (on the left arm) vs the head assembly, torso, legs and the right arm; the sword and the bow (limb, limb and
-- string) vs the head assembly, torso and legs
local CLEARANCES = {
	{ "knight", { "shield", "shieldmark" }, { "Head", "Hair" }, 0.1 },
	{ "knight", { "shield", "shieldmark" }, { "Torso" }, 0.0 },
	{ "knight", { "shield", "shieldmark" }, { "LeftLeg", "RightLeg" }, 0.1 },
	{ "knight", { "shield", "shieldmark" }, { "RightArm", "Tool" }, 0.1 },
	{ "knight", { "Tool" }, { "Torso", "LeftLeg", "RightLeg", "Head", "Hair" }, 0.0 },
	{ "archer", { "Tool", "bowlimb", "bowstring" }, { "Torso", "LeftLeg", "RightLeg" }, 0.0 },
	{ "archer", { "Tool", "bowlimb", "bowstring" }, { "Head", "Hair" }, 0.05 },
}

CHECKS.clearance = function()
	local out: { string } = {}
	for _, hue in { "crimson", "gold" } do
		for _, kind in { "knight", "archer" } do
			local rig = unit(kind, hue)
			local poses = poseSet(rig, kind)
			for _, c in CLEARANCES do
				if c[1] == kind then
					local low, where = groupClearance(rig, poses, c[2], c[3])
					if low < c[4] then
						table.insert(
							out,
							`{kind} {hue}: {table.concat(c[2], "+")} vs {table.concat(c[3], "+")} only {r3(low)} apart ({where}, needs {c[4]})`
						)
					end
				end
			end
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

describe("Soldier unit kinds (FL-0128)", function()
	it("makes soldier, knight and archer distinct, in 11 parts with the crest, on the Pose joints", function()
		expectClean(CHECKS.units())
	end)
	it("keeps the shield, quiver, bow and sword clear of the body in every Pose action", function()
		expectClean(CHECKS.clearance())
	end)
end)

-- ------------------------------------------------------------------ mutants

describe("Unit kind mutants are caught", function()
	local original = {
		character = Kit.character,
	}
	local function restore()
		Kit.character = original.character
	end
	local function caught(name: string, by: string, mutate: () -> ())
		it(`catches: {name} (by {by})`, function()
			mutate()
			local ok, list = pcall(CHECKS[by])
			restore()
			if not ok then
				error(`the mutant crashed instead of failing a check: {list}`)
			end
			if #(list :: { string }) == 0 then
				error(`mutant not caught: {name}`)
			end
		end)
	end
	local function addParts(m: Model, n: number)
		for i = 1, n do
			local p = Instance.new("Part")
			p.Name = `Extra{i}`
			p.Size = Vector3.new(1, 1, 1)
			p.CFrame = (m.PrimaryPart :: BasePart).CFrame
			p.Parent = m
		end
	end

	it("passes unmutated (the baseline)", function()
		for _, name in { "units", "clearance" } do
			expectClean(CHECKS[name]())
		end
	end)

	caught("every unit kind is the spear soldier", "units", function()
		Kit.character = function(kind, job, ...)
			return original.character(kind, if job == "knight" or job == "archer" then "soldier" else job, ...)
		end
	end)
	caught("the knight has a twelfth part", "units", function()
		Kit.character = function(kind, job, ...)
			local m = original.character(kind, job, ...)
			if job == "knight" then
				addParts(m, 1)
			end
			return m
		end
	end)
	caught("the archer lost the kingdom crest", "units", function()
		Kit.character = function(kind, job, ...)
			local m = original.character(kind, job, ...)
			if job == "archer" and m:FindFirstChild("Hair") then
				(m:FindFirstChild("Hair") :: Instance):Destroy()
			end
			return m
		end
	end)
	caught("the knight is as slim as the archer", "units", function()
		Kit.character = function(kind, job, ...)
			local m = original.character(kind, job, ...)
			if job == "knight" then
				local t = m:FindFirstChild("Torso") :: BasePart
				t.Size = Vector3.new(1.9, t.Size.Y, t.Size.Z)
			end
			return m
		end
	end)
	caught("the shield mark is the same for every kingdom", "units", function()
		Kit.character = function(kind, job, color, look, kingdom)
			return original.character(kind, job, color, look, if job == "knight" then "crimson" else kingdom)
		end
	end)
	caught("a weapon gets a new joint", "units", function()
		Kit.character = function(kind, job, ...)
			local m = original.character(kind, job, ...)
			if job == "archer" then
				local q = m:FindFirstChild("Tool") :: BasePart
				local extra = Instance.new("Motor6D")
				extra.Name = "Quiver"
				extra.Part0 = m:FindFirstChild("Torso") :: BasePart
				extra.Part1 = q
				extra.Parent = q
			end
			return m
		end
	end)
	local function pivotAbout(m: Model, tool: BasePart, point: Vector3, rotation: CFrame)
		for _, p in parts(m) do
			if
				p == tool or (p:FindFirstChild("DetailWeld") and (p:FindFirstChild("DetailWeld") :: Weld).Part0 == tool)
			then
				p.CFrame = CFrame.new(point) * rotation * CFrame.new(-point) * p.CFrame
			end
		end
	end
	caught("the sword lies across the arm and the torso again", "units", function()
		Kit.character = function(kind, job, ...)
			local m = original.character(kind, job, ...)
			if kind == "soldier" and job == "knight" then
				local tool = m:FindFirstChild("Tool") :: BasePart
				local grip = tool.CFrame.Position - tool.CFrame.UpVector * (tool.Size.Y / 2)
				pivotAbout(m, tool, grip, CFrame.Angles(0, 0, math.rad(55)))
			end
			return m
		end
	end)
	caught("the pennant is a flat horizontal stick again", "units", function()
		Kit.character = function(kind, job, ...)
			local m = original.character(kind, job, ...)
			if kind == "soldier" and (job == "soldier" or job == "champion" or job == "") then
				for _, p in parts(m) do
					if p:GetAttribute("KitDetailKind") == "pennant" then
						p.Size = Vector3.new(1.2, 0.1, 0.8)
					end
				end
			end
			return m
		end
	end)
	caught("the spear is planted in the ground again", "units", function()
		Kit.character = function(kind, job, ...)
			local m = original.character(kind, job, ...)
			if kind == "soldier" and (job == "soldier" or job == "champion" or job == "") then
				local tool = m:FindFirstChild("Tool") :: BasePart
				for _, p in parts(m) do
					if
						p == tool
						or (p:FindFirstChild("DetailWeld") and (p:FindFirstChild("DetailWeld") :: Weld).Part0 == tool)
					then
						p.CFrame = p.CFrame - Vector3.new(0, 1.2, 0)
					end
				end
			end
			return m
		end
	end)
	caught("a shield mark is a glossy round boss again", "units", function()
		Kit.character = function(kind, job, color, look, kingdom)
			local m = original.character(kind, job, color, look, kingdom)
			if job == "knight" then
				for _, p in parts(m) do
					if p:GetAttribute("KitDetailKind") == "shieldmark" and p:IsA("Part") then
						(p :: Part).Shape = Enum.PartType.Ball
						p.Size = Vector3.new(1.15, 1.15, 1.15)
					end
				end
			end
			return m
		end
	end)
	caught("the bow crosses the archer's face", "units", function()
		Kit.character = function(kind, job, ...)
			local m = original.character(kind, job, ...)
			if kind == "soldier" and job == "archer" then
				local tool = m:FindFirstChild("Tool") :: BasePart
				for _, p in parts(m) do
					if
						p == tool
						or (p:FindFirstChild("DetailWeld") and (p:FindFirstChild("DetailWeld") :: Weld).Part0 == tool)
					then
						p.CFrame = p.CFrame + Vector3.new(0, 1.4, 0)
					end
				end
			end
			return m
		end
	end)
	caught("the shield swings into the head", "clearance", function()
		Kit.character = function(kind, job, ...)
			local m = original.character(kind, job, ...)
			if job == "knight" then
				for _, p in parts(m) do
					if p:GetAttribute("KitDetailKind") == "shield" then
						local w = p:FindFirstChild("DetailWeld") :: Weld
						w.C0 = w.C0 * CFrame.new(1.3, 1.2, 0)
					end
				end
			end
			return m
		end
	end)
end)
