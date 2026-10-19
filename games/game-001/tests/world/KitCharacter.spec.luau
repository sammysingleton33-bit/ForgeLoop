--[[
	Kit characters, looks and regalia (FL-0056, FL-0085; CONTRACTS G4 rendering, G10, G13.2; D-026, D-032):
	≤ Character.MAX_PARTS (9) rigs with an invisible anchored Root, Motor6Ds named after the moving part and matching
	Sim/Pose.JOINTS (Torso: Root → Torso at the hips), Hair welded to the Head, joint pivots where Pose expects
	them, a tool per job, citizen looks that are deterministic and never error, kingdom recolouring of pooled
	rigs, soldier kingdom crests (G13.2, D-033(3)), job silhouettes (hat, tool, outfit accent and body per
	working job, readable at gameplay and aerial distance), the one-part far LOD, regalia that fit R15 and R6
	avatars, and a Pose smoke test (walk and death fall).
]]

local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local Character = require("@game/ReplicatedStorage/Game/Kit/Character")
local Kit = require("@game/ReplicatedStorage/Game/Kit/Kit")

local KINDS = { "citizen", "soldier", "governor" }
local JOBS = { "idle", "farmer", "woodcutter", "miner", "builder", "hauler", "soldier" }
local CITIZEN_TOOLS =
	{ idle = false, farmer = "hoe", woodcutter = "axe", miner = "pick", builder = "hammer", hauler = "sack" }
local CRIMSON = Color3.fromRGB(190, 40, 50)
local AZURE = Color3.fromRGB(40, 110, 210)
local GOLD = Color3.fromRGB(235, 185, 16)
local EMERALD = Color3.fromRGB(35, 128, 95)
local R = Kit.LOOK_RANGES
local MAX_PARTS = Kit.CHARACTER_MAX_PARTS
local WORKING = { "farmer", "woodcutter", "miner", "builder" } -- jobs with a hat of their own
local WORKING_SET = { farmer = true, woodcutter = true, miner = true, builder = true }
-- G13.2 / D-033(3): a soldier's helmet crest follows its KingdomId, in the kingdom's tower style
local KINGDOM_IDS = { "crimson", "azure", "emerald", "gold" }
local KINGDOM_COLORS = { crimson = CRIMSON, azure = AZURE, emerald = EMERALD, gold = GOLD }
local CREST_NAMES = { crimson = "crest_spire", azure = "crest_square", emerald = "crest_plume", gold = "crest_dome" }

-- Sim/Pose (FORGE-04, on main) when this tree has it; otherwise the same joints and the walk / dead samples
-- of the 2026-10-12 version, so the smoke test runs on this branch too.
local POSE_JOINTS = { "Torso", "Head", "LeftArm", "RightArm", "LeftLeg", "RightLeg", "Tool" }
local poseOk, PoseModule = pcall(require, "@game/ReplicatedStorage/Game/Sim/Pose")
local function rad(d: number): number
	return math.rad(d)
end
local Pose = if poseOk and type(PoseModule) == "table"
	then PoseModule
	else {
		JOINTS = POSE_JOINTS,
		sample = function(action: string): { [string]: CFrame }
			if action == "dead" then
				return {
					Torso = CFrame.new(0, -1.7, 0) * CFrame.Angles(rad(90), 0, 0),
					Head = CFrame.new(),
					LeftArm = CFrame.Angles(0, 0, rad(-20)),
					RightArm = CFrame.Angles(0, 0, rad(20)),
					LeftLeg = CFrame.Angles(0, 0, rad(-8)),
					RightLeg = CFrame.Angles(0, 0, rad(8)),
					Tool = CFrame.new(),
				}
			end
			-- walk at phase 0.25, full speed
			return {
				Torso = CFrame.new(0, 0.1, 0) * CFrame.Angles(0, rad(4), 0),
				Head = CFrame.new(),
				LeftArm = CFrame.Angles(rad(-32), 0, 0),
				RightArm = CFrame.Angles(rad(32), 0, 0),
				LeftLeg = CFrame.Angles(rad(40), 0, 0),
				RightLeg = CFrame.Angles(rad(-40), 0, 0),
				Tool = CFrame.new(),
			}
		end,
	}

local function parts(model: Instance): { BasePart }
	local out = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(out, d)
		end
	end
	return out
end

local function pos(p: BasePart): Vector3
	return p.CFrame.Position
end

local function noYield<R>(fn: () -> R): R
	local co = coroutine.create(fn)
	local ok, result = coroutine.resume(co)
	assert(ok, result)
	assert(coroutine.status(co) == "dead", "Kit yielded")
	return result
end

-- world-space bounds of a part's box (conservative for Ball and Cylinder)
local function bounds(p: BasePart): (Vector3, Vector3)
	local mn = Vector3.new(math.huge, math.huge, math.huge)
	local mx = -mn
	local h = p.Size / 2
	for _, sx in { -1, 1 } do
		for _, sy in { -1, 1 } do
			for _, sz in { -1, 1 } do
				local w = p.CFrame * Vector3.new(sx * h.X, sy * h.Y, sz * h.Z)
				mn = mn:Min(w)
				mx = mx:Max(w)
			end
		end
	end
	return mn, mx
end

local function modelBounds(list: { BasePart }): (Vector3, Vector3)
	local mn = Vector3.new(math.huge, math.huge, math.huge)
	local mx = -mn
	for _, p in list do
		local a, b = bounds(p)
		mn = mn:Min(a)
		mx = mx:Max(b)
	end
	return mn, mx
end

local function motorOf(rig: Model, name: string): Motor6D
	for _, d in rig:GetDescendants() do
		if d:IsA("Motor6D") and d.Name == name then
			return d
		end
	end
	error(`no Motor6D {name}`)
end

local function jointWorld(m: Motor6D): CFrame
	return (m.Part0 :: BasePart).CFrame * m.C0
end

local function child(rig: Model, name: string): BasePart
	return rig:FindFirstChild(name) :: BasePart
end

-- every part's class, shape, size, CFrame, colour and material: equal signatures = identical rigs
local function signature(rig: Model): string
	local rows = {}
	for _, p in parts(rig) do
		local cf = { p.CFrame:GetComponents() }
		for i, v in cf do
			cf[i] = string.format("%.3f", v)
		end
		local shape = if p:IsA("Part") then p.Shape.Name else ""
		local size = string.format("%.3f,%.3f,%.3f", p.Size.X, p.Size.Y, p.Size.Z)
		table.insert(
			rows,
			`{p.Name}|{p.ClassName}|{shape}|{size}|{table.concat(cf, ",")}|{p.Color:ToHex()}|{p.Material.Name}`
		)
	end
	table.sort(rows)
	return table.concat(rows, "\n")
end

-- every look at the corners of the ranges (2^4 = 16)
local function cornerLooks(): { Character.CitizenLook }
	local out = {}
	for _, skin in { 1, R.skin } do
		for _, hair in { 1, R.hair } do
			for _, hairColor in { 1, R.hairColor } do
				for _, outfit in { 1, R.outfit } do
					table.insert(out, { skin = skin, hair = hair, hairColor = hairColor, outfit = outfit })
				end
			end
		end
	end
	return out
end

local function each(fn: (kind: string, job: string, rig: Model, look: Character.CitizenLook?, kingdom: string?) -> ())
	for _, kind in KINDS do
		for _, job in JOBS do
			fn(
				kind,
				job,
				noYield(function()
					return Kit.character(kind, job, AZURE)
				end),
				nil
			)
			for _, look in cornerLooks() do
				fn(kind, job, Kit.character(kind, job, AZURE, look), look)
			end
		end
	end
	-- with a kingdom (G13.2): soldiers and drafted citizens wear its crest; citizens and governors ignore it
	local roles = { { "soldier", "soldier" }, { "citizen", "soldier" }, { "soldier", "idle" } }
	table.insert(roles, { "citizen", "farmer" })
	table.insert(roles, { "governor", "idle" })
	local look = { skin = R.skin, hair = R.hair, hairColor = 1, outfit = R.outfit }
	for _, kingdom in KINGDOM_IDS do
		for _, role in roles do
			local kind, job = role[1], role[2]
			fn(
				kind,
				job,
				noYield(function()
					return Kit.character(kind, job, AZURE, nil, kingdom)
				end),
				nil,
				kingdom
			)
			fn(kind, job, Kit.character(kind, job, AZURE, look, kingdom), look, kingdom)
		end
	end
end

-- the soldier's kingdom crest (the welded Hair with a "crest_" KitHeadwear), if any
local function crestOf(rig: Model): BasePart?
	local hair = rig:FindFirstChild("Hair") :: BasePart?
	if hair and string.sub(tostring(hair:GetAttribute("KitHeadwear")), 1, 6) == "crest_" then
		return hair
	end
	return nil
end

-- Forward kinematics as the engine does it: Part1 = Part0 * C0 * Transform * C1:Inverse(); welds follow.
local function posed(rig: Model, joints: { [string]: CFrame }): { [BasePart]: CFrame }
	local root = rig.PrimaryPart :: BasePart
	local world: { [BasePart]: CFrame } = { [root] = root.CFrame }
	local motors = {}
	for _, d in rig:GetDescendants() do
		if d:IsA("Motor6D") then
			table.insert(motors, d)
		end
	end
	local moved = true
	while moved do
		moved = false
		for _, m in motors do
			local p0, p1 = m.Part0 :: BasePart, m.Part1 :: BasePart
			if world[p0] and not world[p1] then
				world[p1] = world[p0] * m.C0 * (joints[m.Name] or CFrame.new()) * m.C1:Inverse()
				moved = true
			end
		end
	end
	for _, d in rig:GetDescendants() do
		if d:IsA("Weld") and world[d.Part0 :: BasePart] then
			world[d.Part1 :: BasePart] = world[d.Part0 :: BasePart] * d.C0 * d.C1:Inverse()
		end
	end
	return world
end

-- D-048 detail parts: rigid, welded to the Head or the Tool, flagged KitDetail
local function isDetail(p: BasePart): boolean
	return p:GetAttribute("KitDetail") == true
end

local function detailsOf(rig: Model): { BasePart }
	local out = {}
	for _, p in parts(rig) do
		if isDetail(p) then
			table.insert(out, p)
		end
	end
	table.sort(out, function(a, b)
		return a.Name < b.Name
	end)
	return out
end

-- hat + the detail parts welded to the Head (lamp, visor, pompom, crown, velvet cap)
local function headGroup(rig: Model): { BasePart }
	local out = { child(rig, "Hair") }
	for _, d in detailsOf(rig) do
		local w = d:FindFirstChild("DetailWeld") :: Weld
		if w.Part0 == child(rig, "Head") then
			table.insert(out, d)
		end
	end
	return out
end

describe("Kit.character rig (CONTRACTS G4, G10, D-026, D-032, D-048)", function()
	it(
		"has ≤ MAX_PARTS (11 = 9 + 2 detail parts) non-colliding, massless parts, only the Root anchored, no Humanoid or Animator",
		function()
			-- The caps are pinned here on purpose (D-048: 9 base parts + at most 2 rigid detail parts): changing one is a
			-- deliberate change to this line, to Character.MAX_PARTS and to the rig tests' expected part counts together.
			expect(MAX_PARTS).toBe(11)
			expect(Character.MAX_PARTS).toBe(MAX_PARTS)
			expect(Character.BASE_PARTS).toBe(9)
			expect(Character.MAX_DETAIL).toBe(2)
			each(function(kind, job, rig, look, kingdom)
				local ps = parts(rig)
				local hasTool = rig:FindFirstChild("Tool") ~= nil
				local hasHair = rig:FindFirstChild("Hair") ~= nil
				-- idle citizens carry nothing, so their free 9th part may be one Accessory (headband or scarf)
				local hasAccessory = rig:FindFirstChild("Accessory") ~= nil
				expect(hasAccessory and not (kind == "citizen" and job == "idle")).toBe(false)
				expect(hasTool).toBe(not (kind == "citizen" and job == "idle"))
				local nDetail = #detailsOf(rig)
				expect(#ps).toBe(
					7
						+ (if hasTool then 1 else 0)
						+ (if hasHair then 1 else 0)
						+ (if hasAccessory then 1 else 0)
						+ nDetail
				)
				expect(#ps).toBeLessThanOrEqual(MAX_PARTS)
				expect(nDetail).toBeLessThanOrEqual(Character.MAX_DETAIL)
				expect(#ps - nDetail).toBeLessThanOrEqual(Character.BASE_PARTS) -- the base rig is still D-032's 9
				-- soldiers: the helm is the Head (8 parts, 9 with a kingdom crest); governors: crown (9);
				-- working citizens: their job hat (9); other citizens: per hair style
				expect(hasHair).toBe(
					if kind == "governor"
						then true
						elseif kind == "soldier" or job == "soldier" then kingdom ~= nil
						elseif WORKING_SET[job] then true
						else Kit.LOOK_PALETTES.hair[Kit.normalizeLook(look).hair] ~= "bald"
				)
				if look == nil and kind == "citizen" and job ~= "soldier" then
					expect(hasHair).toBe(true) -- the default look has short hair
				end
				for _, p in ps do
					expect(p.CanCollide).toBe(false)
					expect(p.CanTouch).toBe(false)
					expect(p.CanQuery).toBe(false)
					expect(p.Massless).toBe(true)
					expect(p.Anchored).toBe(p == rig.PrimaryPart)
				end
				for _, d in rig:GetDescendants() do
					expect(d:IsA("Humanoid") or d:IsA("Animator") or d:IsA("WeldConstraint")).toBe(false)
					if d:IsA("Weld") and not d:IsA("Motor6D") then
						expect(d.Name == "HairWeld" or d.Name == "AccessoryWeld" or d.Name == "DetailWeld").toBe(true)
					end
				end
			end)
		end
	)

	it("joins the moving parts with Motor6Ds named after them, all among Pose.JOINTS, Torso off the Root", function()
		local known = {}
		for _, j in Pose.JOINTS do
			known[j] = true
		end
		each(function(_, _, rig)
			local torso = child(rig, "Torso")
			local seen = {}
			for _, d in rig:GetDescendants() do
				if d:IsA("Motor6D") then
					local p1 = d.Part1 :: BasePart
					expect(d.Name).toBe(p1.Name)
					expect(known[d.Name]).toBe(true)
					expect(d.Parent).toBe(d.Part0)
					expect(seen[p1.Name]).toBeNil()
					seen[p1.Name] = true
					-- C0 and C1 describe the same world point (the template is posed as built)
					local a, b = jointWorld(d), p1.CFrame * d.C1
					expect((a.Position - b.Position).Magnitude).toBeLessThan(1e-3)
				end
			end
			for _, p in parts(rig) do
				expect(seen[p.Name] == true).toBe(
					p ~= rig.PrimaryPart and p.Name ~= "Hair" and p.Name ~= "Accessory" and not isDetail(p)
				)
			end
			expect(motorOf(rig, "Torso").Part0).toBe(rig.PrimaryPart)
			for _, n in { "Head", "LeftArm", "RightArm", "LeftLeg", "RightLeg" } do
				expect(motorOf(rig, n).Part0).toBe(torso)
			end
		end)
	end)

	it("welds Hair to the Head (never a Motor6D)", function()
		local withHair = 0
		each(function(_, _, rig)
			local hair = rig:FindFirstChild("Hair") :: BasePart?
			if hair == nil then
				return
			end
			withHair += 1
			local weld = hair:FindFirstChild("HairWeld") :: Weld
			expect(weld).never.toBeNil()
			expect(weld.ClassName).toBe("Weld")
			expect(weld.Part0).toBe(child(rig, "Head"))
			expect(weld.Part1).toBe(hair)
			local cf = child(rig, "Head").CFrame * weld.C0 * weld.C1:Inverse()
			expect((cf.Position - pos(hair)).Magnitude).toBeLessThan(1e-3)
			for _, d in rig:GetDescendants() do
				if d:IsA("Motor6D") then
					expect(d.Part1 ~= hair).toBe(true)
				end
			end
		end)
		expect(withHair).toBeGreaterThan(0)
	end)

	it("keeps the Root invisible and non-colliding, 3.2 above the feet, with the pivot at the feet", function()
		expect(Character.ROOT_HEIGHT).toBe(3.2)
		expect(Kit.CHARACTER_ROOT_HEIGHT).toBe(3.2)
		each(function(_, _, rig)
			local root = rig.PrimaryPart :: BasePart
			expect(root.Name).toBe("Root")
			expect(root.Transparency).toBe(1)
			expect(root.CanCollide or root.CanTouch or root.CanQuery).toBe(false)
			expect(pos(root).Y).toBeNear(Kit.CHARACTER_ROOT_HEIGHT, 1e-4) -- CFrames are float32
			expect(root.CFrame.UpVector.Y).toBeNear(1, 1e-6)
			local pivot = root.CFrame * root.PivotOffset
			expect(pivot.Position.Y).toBeNear(0, 1e-6)
			-- placing the pivot at the feet puts the Root centre 3.2 above them (EntityController's rootOffset)
			local feet = CFrame.new(10, 4, -7) * CFrame.Angles(0, 1.1, 0)
			local placed = feet * root.PivotOffset:Inverse()
			expect((placed.Position - (feet.Position + Vector3.new(0, 3.2, 0))).Magnitude).toBeLessThan(1e-4)
			expect(rig:GetAttribute("KitRootHeight")).toBe(Character.ROOT_HEIGHT)
		end)
	end)

	it("stands about 5.5 studs tall with the feet on y = 0 (tool and headwear excluded), for every look", function()
		each(function(_, _, rig)
			local body = {}
			local crest = crestOf(rig)
			for _, p in parts(rig) do
				if p.Name ~= "Tool" and p.Name ~= "Hair" and not isDetail(p) and p ~= rig.PrimaryPart then
					table.insert(body, p)
				end
			end
			local mn, mx = modelBounds(body)
			expect(mn.Y).toBeNear(0, 1e-3)
			expect(mx.Y).toBeNear(5.5, 0.25)
			expect(mx.X - mn.X).toBeLessThan(4.5)
			if crest then -- rises clearly above the helm, still under the spear tip
				local _, top = bounds(crest)
				local _, spearTop = bounds(child(rig, "Tool"))
				expect(top.Y).toBeGreaterThan(mx.Y + 0.3)
				expect(top.Y).toBeLessThan(spearTop.Y)
			end
		end)
	end)

	it("puts joint pivots at the hips, neck and shoulders, with axis-aligned joint frames", function()
		each(function(_, _, rig)
			for _, m in rig:GetDescendants() do
				if m:IsA("Motor6D") then
					local j = jointWorld(m)
					expect(j.UpVector.Y).toBeNear(1, 1e-6)
					expect(j.LookVector.Z).toBeNear(-1, 1e-6)
				end
			end
			local torso = child(rig, "Torso")
			local torsoBottom, torsoTop = bounds(torso)
			expect(jointWorld(motorOf(rig, "Torso")).Position.Y).toBeNear(torsoBottom.Y, 1e-3)
			expect(torsoBottom.Y).toBeNear(2.2, 1e-3) -- Pose's death fall assumes hips 2.2 up
			for _, side in { "Left", "Right" } do
				local leg = child(rig, `{side}Leg`)
				local _, legTop = bounds(leg)
				local hip = jointWorld(motorOf(rig, `{side}Leg`)).Position
				expect(hip.Y).toBeNear(legTop.Y, 1e-3)
				expect(hip.X).toBeNear(pos(leg).X, 1e-3)
				local shoulder = jointWorld(motorOf(rig, `{side}Arm`)).Position
				expect(shoulder.Y).toBeGreaterThan(torsoTop.Y - 0.6)
				expect(shoulder.Y).toBeLessThan(torsoTop.Y)
				-- the arm pivots sit outside the torso's side, on the arm's centre line (the cheer swings the arm about it, B18)
				expect(math.abs(shoulder.X)).toBeNear(torso.Size.X / 2 + Character.SHOULDER_OUT, 1e-3)
			end
			local neck = jointWorld(motorOf(rig, "Head")).Position
			expect(neck.Y).toBeNear(torsoTop.Y, 1e-3)
			local headBottom = bounds(child(rig, "Head"))
			expect(math.abs(headBottom.Y - neck.Y)).toBeLessThan(0.15)
		end)
	end)

	it("survives Pose: walking moves the head, the death fall lays the body down with the hair attached", function()
		each(function(_, job, rig)
			local head = child(rig, "Head")
			local rest = posed(rig, {})
			expect((rest[head].Position - pos(head)).Magnitude).toBeLessThan(1e-4)

			local walk = posed(rig, Pose.sample("walk", job, 0.25, 12))
			expect((walk[head].Position - pos(head)).Magnitude).toBeGreaterThan(0.05)
			local leftLeg = child(rig, "LeftLeg")
			expect(math.abs(walk[leftLeg].Position.Z - pos(leftLeg).Z)).toBeGreaterThan(0.3)

			local dead = posed(rig, Pose.sample("dead", job, 0, 0))
			expect(dead[head].Position.Y).toBeLessThan(pos(head).Y - 2.5)
			local torso = child(rig, "Torso")
			expect(math.abs(dead[torso].UpVector.Y)).toBeLessThan(0.05) -- lying flat
			local h = torso.Size / 2
			local lowest = math.huge
			for _, sx in { -1, 1 } do
				for _, sy in { -1, 1 } do
					for _, sz in { -1, 1 } do
						lowest = math.min(lowest, (dead[torso] * Vector3.new(sx * h.X, sy * h.Y, sz * h.Z)).Y)
					end
				end
			end
			expect(lowest).toBeGreaterThan(-0.25) -- on the ground, not sunk into it
			local hair = rig:FindFirstChild("Hair") :: BasePart?
			if hair then
				local keep = head.CFrame:ToObjectSpace(hair.CFrame)
				local now = dead[head]:ToObjectSpace(dead[hair])
				expect((keep.Position - now.Position).Magnitude).toBeLessThan(1e-3)
			end
			for _, p in parts(rig) do
				expect(dead[p]).never.toBeNil()
			end
		end)
	end)
end)

describe("Kit.character jobs and tools", function()
	it("gives each citizen job its own tool, jointed in the right fist (the hauler's sack on the back)", function()
		local signatures = {}
		for job, tool in CITIZEN_TOOLS do
			local rig = Kit.character("citizen", job, CRIMSON)
			local part = rig:FindFirstChild("Tool") :: BasePart?
			if tool == false then
				expect(part).toBeNil()
				continue
			end
			assert(part, `citizen {job} has no Tool`)
			expect(part:GetAttribute("KitTool")).toBe(tool)
			local m = motorOf(rig, "Tool")
			local joint = jointWorld(m).Position
			if tool == "sack" then
				expect(m.Part0).toBe(child(rig, "Torso"))
				expect(pos(part).Z).toBeGreaterThan(0.5) -- behind the back (front is -Z)
			else
				local arm = child(rig, "RightArm")
				expect(m.Part0).toBe(arm)
				-- the hand: inside the arm, within its lowest 0.4 studs
				local localJoint = arm.CFrame:PointToObjectSpace(joint)
				expect(math.abs(localJoint.X)).toBeLessThan(arm.Size.X / 2)
				expect(math.abs(localJoint.Z)).toBeLessThan(arm.Size.Z / 2)
				expect(localJoint.Y).toBeLessThan(-arm.Size.Y / 2 + 0.4)
			end
			local sig = `{part.ClassName}/{if part:IsA("Part") then part.Shape.Name else ""}/{part.Color:ToHex()}`
			expect(signatures[sig]).toBeNil()
			signatures[sig] = job
		end
	end)

	it("arms soldiers with a spear that towers over the helm and governors with a gold staff", function()
		for _, kind in { "soldier", "governor" } do
			for _, job in JOBS do
				local rig = Kit.character(kind, job, CRIMSON)
				local tool = child(rig, "Tool")
				expect(tool:GetAttribute("KitTool")).toBe(if kind == "soldier" then "spear" else "staff")
				expect(motorOf(rig, "Tool").Part0).toBe(child(rig, "RightArm"))
				local _, top = bounds(tool)
				expect(top.Y).toBeGreaterThan(if kind == "soldier" then 7.5 else 5.5)
				if kind == "soldier" then
					expect(rig:FindFirstChild("Hair")).toBeNil()
					expect(child(rig, "Head").Material).toBe(Enum.Material.Metal)
				else
					local crown = child(rig, "Hair")
					expect(crown:GetAttribute("KitHeadwear")).toBe("crown")
					expect(crown.Color:ToHex()).toBe(Color3.fromRGB(229, 181, 58):ToHex())
					expect((crown:FindFirstChild("HairWeld") :: Weld).Part0).toBe(child(rig, "Head"))
				end
			end
		end
		-- a citizen drafted as a soldier wears the soldier look
		local drafted = Kit.character("citizen", "soldier", CRIMSON)
		expect(child(drafted, "Tool"):GetAttribute("KitTool")).toBe("spear")
	end)

	it("dresses soldiers in full kingdom colour under a steel helm and citizens in a muted kingdom tunic", function()
		local soldier = Kit.character("soldier", "soldier", CRIMSON)
		local citizen = Kit.character("citizen", "farmer", CRIMSON)
		expect(child(soldier, "Torso").Color).toEqual(CRIMSON)
		expect(child(soldier, "Head").Material).toBe(Enum.Material.Metal)
		expect(child(soldier, "Head"):FindFirstChild("Face")).toBeNil()
		expect(child(citizen, "Torso"):GetAttribute("KitTint")).toBeLessThan(1)
		local face = child(citizen, "Head"):FindFirstChild("Face")
		expect(face).never.toBeNil()
		expect((face :: Decal).Texture).toBe("rbxasset://textures/face.png")
	end)

	it("recolours a pooled rig with Kit.setKingdomColor exactly like a fresh build", function()
		each(function(kind, job, rig, look, kingdom)
			Kit.setKingdomColor(rig, GOLD)
			expect(signature(rig)).toBe(signature(Kit.character(kind, job, GOLD, look, kingdom)))
			expect(
				child(rig, "Torso"):GetAttribute("KitTint") ~= nil
					or child(rig, "LeftArm"):GetAttribute("KitTint") ~= nil
			).toBe(true)
		end)
	end)
end)

describe("Kit.character looks (CONTRACTS G13.2)", function()
	it("exports look ranges with palettes behind them", function()
		expect(R.skin).toBe(#Kit.LOOK_PALETTES.skin)
		expect(R.hairColor).toBe(#Kit.LOOK_PALETTES.hairColor)
		expect(R.hair).toBe(#Kit.LOOK_PALETTES.hair)
		expect(R.outfit).toBe(#Kit.LOOK_PALETTES.outfit)
		-- exact ranges: FORGE-01's population generator samples these (CONTRACTS G13.2)
		expect(R).toEqual({ skin = 6, hair = 6, hairColor = 8, outfit = 6 })
		-- skin runs light to dark: 1 is the default (the lightest but one), 6 the darkest
		local function luminance(c: Color3): number
			return 0.2126 * c.R + 0.7152 * c.G + 0.0722 * c.B
		end
		local skin = Kit.LOOK_PALETTES.skin
		expect(skin[1]:ToHex()).toBe(Color3.fromRGB(242, 201, 160):ToHex())
		expect(luminance(skin[2])).toBeGreaterThan(luminance(skin[1]))
		expect(luminance(skin[1])).toBeGreaterThan(luminance(skin[3]))
		for i = 3, R.skin do
			expect(luminance(skin[i - 1])).toBeGreaterThan(luminance(skin[i]))
		end
		for _, palette in { Kit.LOOK_PALETTES.skin, Kit.LOOK_PALETTES.hairColor } do
			local seen = {}
			for _, c in palette do
				expect(typeof(c)).toBe("Color3")
				expect(seen[c:ToHex()]).toBeNil()
				seen[c:ToHex()] = true
			end
		end
	end)

	it("builds the default look when the look is omitted, and the same rig for the same look", function()
		for _, kind in KINDS do
			for _, job in JOBS do
				local default = signature(Kit.character(kind, job, CRIMSON))
				expect(signature(Kit.character(kind, job, CRIMSON, Kit.DEFAULT_LOOK))).toBe(default)
				expect(signature(Kit.character(kind, job, CRIMSON, {} :: any))).toBe(default)
				local look = { skin = 5, hair = 2, hairColor = 4, outfit = 3 }
				expect(signature(Kit.character(kind, job, CRIMSON, look))).toBe(
					signature(Kit.character(kind, job, CRIMSON, table.clone(look)))
				)
			end
		end
		expect(Kit.lookKey(nil)).toBe(Kit.lookKey(Kit.DEFAULT_LOOK))
	end)

	it("changes colours or shapes along every look axis", function()
		local base = { skin = 1, hair = 1, hairColor = 1, outfit = 1 } -- short hair, so hair colour shows
		for axis, n in R do
			-- a hat hides the hair colour (see "job silhouettes"), so that axis is judged on an idle citizen
			local job = if axis == "hairColor" then "idle" else "farmer"
			local seen = {}
			for i = 1, n do
				local look = table.clone(base)
				look[axis] = i
				local sig = signature(Kit.character("citizen", job, CRIMSON, look :: any))
				expect(seen[sig]).toBeNil()
				seen[sig] = i
				expect(Character.lookKey(look)).toBe(`{look.skin}.{look.hair}.{look.hairColor}.{look.outfit}`)
			end
		end
		-- governors take the skin tone and keep their robe; soldiers (helm as Head) ignore the look
		local a = Kit.character("governor", "idle", CRIMSON, { skin = 5, hair = 3, hairColor = 2, outfit = 4 })
		local b = Kit.character("governor", "idle", CRIMSON, { skin = 5, hair = 5, hairColor = 6, outfit = 2 })
		expect(signature(a)).toBe(signature(b))
		expect(child(a, "Head").Color:ToHex()).toBe(Kit.LOOK_PALETTES.skin[5]:ToHex())
		local s1 = Kit.character("soldier", "soldier", CRIMSON, { skin = 2, hair = 3, hairColor = 2, outfit = 4 })
		expect(signature(s1)).toBe(signature(Kit.character("soldier", "soldier", CRIMSON)))
	end)

	it("never errors on out-of-range or malformed looks; wraps numbers deterministically", function()
		local n = R.skin
		local function sig(look: any): string
			local rig = noYield(function()
				return Kit.character("citizen", "builder", AZURE, look)
			end)
			expect(#parts(rig)).toBeLessThanOrEqual(MAX_PARTS)
			return signature(rig)
		end
		local default = sig(nil)
		for _, bad in
			{
				42,
				"look",
				true,
				{ skin = 0 / 0, hair = math.huge, hairColor = -math.huge, outfit = "x" },
				{ skin = {}, hair = false },
			}
		do
			expect(sig(bad)).toBe(default)
		end
		expect(sig({ skin = n + 1, hair = 1, hairColor = 1, outfit = 1 })).toBe(sig({ skin = 1 }))
		expect(sig({ skin = 0 })).toBe(sig({ skin = n }))
		expect(sig({ skin = -n })).toBe(sig({ skin = n }))
		expect(sig({ skin = 2.9, hair = 2.1 })).toBe(sig({ skin = 2, hair = 2 }))
		expect(sig({ skin = 1e12, hair = -7, hairColor = 1e300, outfit = 2 ^ 53 })).toBe(
			sig(Kit.normalizeLook({ skin = 1e12, hair = -7, hairColor = 1e300, outfit = 2 ^ 53 }))
		)
		for _, v in { -1e300, -3, 0, 0.5, 1e9, 2 ^ 60 } do
			local l = Kit.normalizeLook({ skin = v, hair = v, hairColor = v, outfit = v })
			for axis, range in R do
				expect(l[axis] >= 1 and l[axis] <= range and l[axis] % 1 == 0).toBe(true)
			end
		end
	end)

	it(
		"keeps the kingdom colour on the torso, the sleeves or the hood of every outfit (readable from above)",
		function()
			for outfit = 1, R.outfit do
				for hair = 1, R.hair do
					local rig = Kit.character("citizen", "idle", CRIMSON, { outfit = outfit, hair = hair } :: any)
					local tinted = 0
					for _, name in { "Torso", "LeftArm", "Hair" } do
						local part = rig:FindFirstChild(name)
						if part and part:GetAttribute("KitTint") then
							tinted += 1
						end
					end
					expect(tinted).toBeGreaterThanOrEqual(1)
				end
			end
		end
	)
end)

describe("Kit.character job silhouettes (readable jobs at gameplay and aerial distance)", function()
	local function lum(c: Color3): number
		return 0.2126 * c.R + 0.7152 * c.G + 0.0722 * c.B
	end
	local function dist255(a: Color3, b: Color3): number
		return 255 * math.sqrt((a.R - b.R) ^ 2 + (a.G - b.G) ^ 2 + (a.B - b.B) ^ 2)
	end
	local function lookOf(hair: number, hairColor: number?, outfit: number?, skin: number?): any
		return { skin = skin or 1, hair = hair, hairColor = hairColor or 1, outfit = outfit or 1 }
	end
	local function primitive(p: BasePart): string
		return if p:IsA("Part") then `Part/{p.Shape.Name}` else p.ClassName
	end
	-- Aerial readability, measured on the shipped rigs (rest pose, axis-aligned boxes): the smallest job hat is the
	-- woodcutter's beanie, 1.5 studs across (the first pass had a 1.9 x 2.0 slab that the fresh review called
	-- oversized); then the miner's pot and the builder's cap at 1.9. The smallest tool is the axe blade, 2.40 at its
	-- longest. Before the art pass the hat slot held a 1.66 hair ball and the tools were 1.7 (axe), 2.1 (sack,
	-- hammer) and 3.0 (pick). The overview camera (50° down, 170 studs, Roblox 70° FOV on a 720 px frame) shows
	-- about 3 px per stud, so 1.45 studs of hat is about 4 px, 2.3 studs of tool about 7 px and a 6.5 stud
	-- signature box about 20 px (the hat is small by design; the dark beanie is the hat, the axe the signature).
	local N_HAT, N_TOOL, N_BOX = 1.45, 2.3, 6.3 -- box: hat + handle + head details; the smallest job measures 6.46
	local function span(p: BasePart): (Vector3, Vector3)
		return bounds(p)
	end
	local function horizontal(p: BasePart): number
		local a, b = span(p)
		return math.max(b.X - a.X, b.Z - a.Z)
	end
	local function longest(p: BasePart): number
		local a, b = span(p)
		local d = b - a
		return math.max(d.X, d.Y, d.Z)
	end

	it("gives each working job its own headwear (KitHeadwear), whatever the look", function()
		expect(Kit.JOB_HEADWEAR).toEqual({
			farmer = "strawhat",
			woodcutter = "knitcap",
			miner = "hardhat",
			builder = "buildercap",
		})
		for _, job in WORKING do
			for _, look in cornerLooks() do
				for hair = 1, R.hair do
					local rig =
						Kit.character("citizen", job, AZURE, lookOf(hair, look.hairColor, look.outfit, look.skin))
					local hat = child(rig, "Hair")
					expect(hat).never.toBeNil()
					expect(hat:GetAttribute("KitHeadwear")).toBe(Kit.JOB_HEADWEAR[job])
					expect(primitive(hat)).toBe(
						primitive(child(Kit.character("citizen", job, AZURE, lookOf(1)), "Hair"))
					)
					expect((hat:FindFirstChild("HairWeld") :: Weld).Part0).toBe(child(rig, "Head"))
				end
			end
		end
	end)

	it("tells the four hats apart by outline (primitive or width) and by value (disjoint luminance)", function()
		local rows = {}
		for _, job in WORKING do
			local lo, hi = math.huge, -math.huge
			for hair = 1, R.hair do
				local l = lum(child(Kit.character("citizen", job, AZURE, lookOf(hair)), "Hair").Color)
				lo, hi = math.min(lo, l), math.max(hi, l)
			end
			local rig1 = Kit.character("citizen", job, AZURE, lookOf(1))
			local hat = child(rig1, "Hair")
			local hMin, hMax = bounds(hat)
			-- the hat with its head details (lamp, visor, pompom, crown): the outline seen from the side
			local gMin, gMax = modelBounds(headGroup(rig1))
			rows[job] = {
				kind = primitive(hat),
				width = horizontal(hat),
				height = hMax.Y - hMin.Y,
				depth = gMax.Z - gMin.Z,
				lo = lo,
				hi = hi,
			}
		end
		for i, a in WORKING do
			for j = i + 1, #WORKING do
				local b = WORKING[j]
				local A, B = rows[a], rows[b]
				-- (the two wedge caps differ in height: a tall dark tail against a low pale peak)
				expect(
					A.kind ~= B.kind
						or math.abs(A.width - B.width) >= 0.8
						or math.abs(A.height - B.height) >= 0.5
						or math.abs(A.depth - B.depth) >= 0.3 -- the builder's visor against the miner's lamp
				).toBe(true)
				-- shaded variants of one hat never reach the value range of another's (grayscale groups)
				expect(A.lo > B.hi + 0.08 or B.lo > A.hi + 0.08).toBe(true)
			end
		end
		-- the shapes: a wide flat disc, a slouched tall wedge cap, a squat drum, a low peaked wedge cap
		expect(rows.farmer.kind).toBe("Part/Cylinder")
		expect(rows.farmer.width).toBeGreaterThan(3)
		expect(rows.woodcutter.kind).toBe("Part/Ball")
		expect(rows.miner.kind).toBe("Part/Cylinder")
		expect(rows.builder.kind).toBe("Part/Cylinder")
		-- the woodcutter's beanie is the only ball: small, and never in a hair colour (every variant)
		expect(rows.woodcutter.width).toBeLessThanOrEqual(1.6)
		for hair = 1, R.hair do
			local c = child(Kit.character("citizen", "woodcutter", AZURE, lookOf(hair)), "Hair").Color
			for _, h in Kit.LOOK_PALETTES.hairColor do
				expect(dist255(c, h)).toBeGreaterThan(15)
			end
		end
		-- the miner's pot is clearly smaller and darker than the farmer's disc
		expect(rows.miner.width).toBeLessThanOrEqual(rows.farmer.width * 0.65)
		expect(rows.miner.hi).toBeLessThan(rows.farmer.lo - 0.1)
	end)

	it("keeps the hat on the head: the face stays clear and nothing grows past the spear", function()
		for _, job in WORKING do
			for hair = 1, R.hair do
				local rig = Kit.character("citizen", job, AZURE, lookOf(hair))
				local head, hat = child(rig, "Head"), child(rig, "Hair")
				local lo, hi = bounds(hat)
				-- level hats clear the face (head centre + 0.33); rolled ones may dip at the rim, away from it. A
				-- ball beanie has no lower face: its rim is checked by the clearance spec (above the eyes, 35°+)
				if primitive(hat) ~= "Part/Ball" then
					expect(lo.Y).toBeGreaterThan(pos(head).Y + (if hair == 1 then 0.3 else 0.1))
				end
				expect(hi.Y).toBeGreaterThan(5.4) -- reads above the head from every side
				expect(hi.Y).toBeLessThan(7.0)
				expect(math.abs(pos(hat).X - pos(head).X)).toBeLessThan(0.7)
			end
		end
	end)

	it("makes look.hair pick a variant of the job hat; the hidden hair colour dyes the clothes instead", function()
		for _, job in WORKING do
			local seen = {}
			for hair = 1, R.hair do
				local sig = signature(Kit.character("citizen", job, AZURE, lookOf(hair)))
				expect(seen[sig]).toBeNil()
				seen[sig] = hair
			end
			local base = Kit.character("citizen", job, AZURE, lookOf(1, 1))
			local baseHat = child(base, "Hair")
			for hairColor = 2, R.hairColor do
				local rig = Kit.character("citizen", job, AZURE, lookOf(1, hairColor))
				local hat = child(rig, "Hair")
				expect(hat.Color:ToHex()).toBe(baseHat.Color:ToHex()) -- the hat does not change with the hair colour
				expect(tostring(hat.CFrame)).toBe(tostring(baseHat.CFrame))
				expect(signature(rig) ~= signature(base)).toBe(true) -- the shirt and trousers do
			end
		end
	end)

	it("lets idle and hauler citizens keep every hair style, and never gives them a job hat", function()
		local jobHats = {}
		for _, name in Kit.JOB_HEADWEAR do
			jobHats[name] = true
		end
		for _, job in { "idle", "hauler" } do
			local sigs = {}
			for hair = 1, R.hair do
				local rig = Kit.character("citizen", job, AZURE, lookOf(hair))
				local hat = rig:FindFirstChild("Hair") :: BasePart?
				local name = if hat then hat:GetAttribute("KitHeadwear") else nil
				expect(if name then jobHats[name] else nil).toBeNil()
				expect(name).toBe(if Kit.LOOK_PALETTES.hair[hair] == "bald" then nil else Kit.LOOK_PALETTES.hair[hair])
				sigs[signature(rig)] = true
			end
			expect(#Kit.LOOK_PALETTES.hair).toBe(R.hair)
			local n = 0
			for _ in sigs do
				n += 1
			end
			expect(n).toBe(R.hair)
			-- hair colour shows on short hair
			expect(
				signature(Kit.character("citizen", job, AZURE, lookOf(1, 1)))
					~= signature(Kit.character("citizen", job, AZURE, lookOf(1, 4)))
			).toBe(true)
		end
	end)

	it("dresses each job in its accent over every outfit: trousers plus the neutral torso or sleeve panel", function()
		local legs, panels = {}, {}
		for _, job in { "farmer", "woodcutter", "miner", "builder", "hauler" } do
			local legHex
			for outfit = 1, R.outfit do
				local rig = Kit.character("citizen", job, CRIMSON, lookOf(1, 1, outfit))
				local torso, larm, rarm = child(rig, "Torso"), child(rig, "LeftArm"), child(rig, "RightArm")
				-- the trousers carry the accent in every outfit, in one colour per job
				for _, name in { "LeftLeg", "RightLeg" } do
					expect(child(rig, name):GetAttribute("KitAccent")).toBe(job)
					expect(child(rig, name):GetAttribute("KitTint")).toBeNil()
				end
				legHex = legHex or child(rig, "LeftLeg").Color:ToHex()
				expect(child(rig, "LeftLeg").Color:ToHex()).toBe(legHex)
				-- the kingdom tint stays on the torso or the sleeves (readable from above), the accent on the rest
				expect(torso:GetAttribute("KitTint") ~= nil or larm:GetAttribute("KitTint") ~= nil).toBe(true)
				for _, part in { torso, larm, rarm } do
					if part:GetAttribute("KitAccent") then
						expect(part:GetAttribute("KitAccent")).toBe(job)
						expect(part:GetAttribute("KitTint")).toBeNil()
						panels[job] = panels[job] or part.Color
					end
				end
				expect(larm:GetAttribute("KitAccent")).toBe(rarm:GetAttribute("KitAccent"))
			end
			legs[job] = child(Kit.character("citizen", job, CRIMSON), "LeftLeg").Color
			expect(panels[job]).never.toBeNil() -- some outfit leaves a neutral panel to take the accent
		end
		local jobs = { "farmer", "woodcutter", "miner", "builder", "hauler" }
		for i, a in jobs do
			for j = i + 1, #jobs do
				expect(dist255(legs[a], legs[jobs[j]])).toBeGreaterThan(25)
				expect(dist255(panels[a], panels[jobs[j]])).toBeGreaterThan(25)
			end
		end
		-- idle citizens and other kinds carry no accent
		for _, rig in { Kit.character("citizen", "idle", CRIMSON), Kit.character("soldier", "soldier", CRIMSON) } do
			for _, p in parts(rig) do
				expect(p:GetAttribute("KitAccent")).toBeNil()
			end
		end
	end)

	it("keeps a job's signature across looks while skin, hair and outfit still differ", function()
		for _, job in { "farmer", "woodcutter", "miner", "builder", "hauler" } do
			local a = Kit.character("citizen", job, AZURE, lookOf(1, 1, 1, 1))
			local b = Kit.character("citizen", job, AZURE, lookOf(3, 5, 4, 5))
			expect(child(a, "Head").Color:ToHex() ~= child(b, "Head").Color:ToHex()).toBe(true) -- skin
			expect(child(a, "Torso").Color:ToHex() ~= child(b, "Torso").Color:ToHex()).toBe(true) -- outfit
			expect(signature(a) ~= signature(b)).toBe(true)
			-- the signature: tool, trousers, hat (for the hatted jobs) and the pooling kind/job
			expect(child(a, "Tool"):GetAttribute("KitTool")).toBe(Kit.JOB_TOOLS[job])
			expect(child(b, "Tool"):GetAttribute("KitTool")).toBe(Kit.JOB_TOOLS[job])
			expect(child(a, "Tool").Size).toEqual(child(b, "Tool").Size)
			-- trousers: the same job colour, dyed a little differently per individual
			expect(dist255(child(a, "LeftLeg").Color, child(b, "LeftLeg").Color)).toBeLessThan(40)
			expect(child(a, "LeftLeg"):GetAttribute("KitAccent")).toBe(job)
			expect(child(b, "LeftLeg"):GetAttribute("KitAccent")).toBe(job)
			if WORKING_SET[job] then
				expect(child(a, "Hair"):GetAttribute("KitHeadwear")).toBe(child(b, "Hair"):GetAttribute("KitHeadwear"))
			end
			expect(a:GetAttribute("KitJob")).toBe(job)
			expect(a:GetAttribute("KitLook")).toBe(Kit.lookKey(lookOf(1, 1, 1, 1)))
		end
	end)

	it("builds stocky jobs wide and idle and farming citizens lean", function()
		local width = {}
		for _, job in { "idle", "farmer", "woodcutter", "miner", "builder", "hauler" } do
			width[job] = child(Kit.character("citizen", job, AZURE), "Torso").Size.X
		end
		expect(width.idle).toBeLessThanOrEqual(2.0)
		expect(width.farmer).toBeLessThanOrEqual(2.05)
		for _, job in { "woodcutter", "miner", "builder", "hauler" } do
			expect(width[job]).toBeGreaterThanOrEqual(2.15)
			expect(width[job]).toBeGreaterThan(width.farmer + 0.1)
		end
	end)

	it(
		"gives each tool a handle and a head (D-048): hoe blade, axe head, pick bar, mallet, spearhead, strap and tie",
		function()
			local function tool(job: string): (BasePart, { BasePart })
				local rig = Kit.character("citizen", job, AZURE)
				local heads = {}
				for _, d in detailsOf(rig) do
					if (d:FindFirstChild("DetailWeld") :: Weld).Part0 == child(rig, "Tool") then
						table.insert(heads, d)
					end
				end
				return child(rig, "Tool"), heads
			end
			-- handles: cylinders of different lengths and woods; the head is the Tool's own detail part
			local expectations = {
				farmer = { handle = 5.0, head = "WedgePart", metal = true },
				woodcutter = { handle = 3.7, head = "WedgePart", metal = true },
				miner = { handle = 3.5, head = "WedgePart", metal = true, tines = 2 }, -- a pickaxe: two drooping wedges
				builder = { handle = 2.8, head = "Part/Block", metal = false },
			}
			local handleColours = {}
			for job, want in expectations do
				local handle, heads = tool(job)
				expect(primitive(handle)).toBe("Part/Cylinder")
				expect(handle.Size.X).toBeGreaterThanOrEqual(want.handle) -- the cylinder's length is its X
				expect(handle.Size.Y).toBeLessThanOrEqual(0.45)
				expect(#heads).toBe(want.tines or 1)
				expect(primitive(heads[1])).toBe(want.head)
				expect(
					if want.metal
						then heads[1].Material == Enum.Material.Metal
						else heads[1].Material == Enum.Material.Wood
				).toBe(true)
				-- the head rises to the handle's top end, beside the body: it reads above the shoulders
				local _, headTop = bounds(heads[1])
				expect(headTop.Y).toBeGreaterThan(4.4)
				expect(handleColours[handle.Color:ToHex()]).toBeNil() -- four different handles
				handleColours[handle.Color:ToHex()] = job
			end
			-- sizes of the heads: a hoe blade, a bearded axe head, two long pick tines, a fat mallet
			local _, hoeHeads = tool("farmer")
			expect(math.max(hoeHeads[1].Size.X, hoeHeads[1].Size.Z)).toBeGreaterThanOrEqual(1.1)
			local _, axeHeads = tool("woodcutter")
			expect(math.max(axeHeads[1].Size.Y, axeHeads[1].Size.Z)).toBeGreaterThanOrEqual(1.7)
			local _, pickHeads = tool("miner")
			expect(#pickHeads).toBe(2) -- a pickaxe: two long thin tines on either side of the handle's top, drooped into an arch
			for _, tine in pickHeads do
				expect(tine.Size.Z).toBeGreaterThanOrEqual(2.4)
				expect(tine.Size.Z).toBeGreaterThan(2.5 * tine.Size.Y)
			end
			expect((pos(pickHeads[1]) - pos(pickHeads[2])).Magnitude).toBeGreaterThanOrEqual(2.3) -- the arch spans ~4.7 studs tip to tip
			local pickHandle = tool("miner")
			local _, pickHandleTop = bounds(pickHandle)
			for _, tine in pickHeads do
				expect(pos(tine).Y).toBeLessThan(pickHandleTop.Y - 0.4) -- the tines droop below the hub, they are not a T
			end
			local _, mallet = tool("builder")
			expect(math.min(mallet[1].Size.X, mallet[1].Size.Y)).toBeGreaterThanOrEqual(1.1) -- a fat head
			expect(mallet[1].Size.Z).toBeGreaterThanOrEqual(1.9)
			-- the head leans outwards with the handle: the tool shows from the front as well as the side
			for _, job in { "woodcutter", "miner", "builder" } do
				local handle, heads = tool(job)
				expect(handle.CFrame.RightVector.Y).never.toBeNil() -- (the handle's axis is its X: it leans out)
				expect(math.abs(handle.CFrame.RightVector.X)).toBeGreaterThan(0.05)
				expect(heads[1]).never.toBeNil()
			end
			-- the hauler's sack carries a kingdom strap across the chest and a tied neck
			local hauler = Kit.character("citizen", "hauler", AZURE)
			local sack, strap, tie = child(hauler, "Tool"), child(hauler, "Detail1"), child(hauler, "Detail2")
			expect(primitive(sack)).toBe("Part/Ball")
			expect(sack.Size.X).toBeGreaterThanOrEqual(2.6)
			expect(strap:GetAttribute("KitTint")).never.toBeNil()
			expect(strap.Size.Y).toBeGreaterThanOrEqual(2.4)
			expect(pos(strap).Z).toBeLessThan(-0.55) -- in front of the chest (the torso's front face is at -0.575)
			expect(primitive(tie)).toBe("Part/Ball")
			expect(pos(tie).Y).toBeGreaterThan(pos(sack).Y + 1.0) -- at the sack's top
			-- the soldier's spear: 9 long, pale, with a steel spearhead and a kingdom pennant
			local soldier = Kit.character("soldier", "soldier", CRIMSON, nil, "crimson")
			local spear, head, pennant = child(soldier, "Tool"), child(soldier, "Detail1"), child(soldier, "Detail2")
			expect(spear.Size.X).toBeGreaterThanOrEqual(8.5)
			expect(lum(spear.Color)).toBeGreaterThan(0.6)
			expect(primitive(head)).toBe("CornerWedgePart")
			expect(lum(head.Color)).toBeGreaterThan(0.6) -- a pale steel head
			expect(head.Material).toBe(Enum.Material.Metal)
			local _, spearTop = bounds(spear)
			local _, headTop = bounds(head)
			expect(headTop.Y).toBeGreaterThan(spearTop.Y - 0.5) -- on the shaft's tip
			expect(pennant:GetAttribute("KitTint")).never.toBeNil()
			-- the governor's staff ends in a gold orb
			local gov = Kit.character("governor", "idle", CRIMSON)
			local orb = child(gov, "Detail2")
			expect(primitive(orb)).toBe("Part/Ball")
			expect(orb.Material).toBe(Enum.Material.Metal)
		end
	)

	it("makes every job's signature (hat + tool) big enough for the overview camera", function()
		for _, job in { "farmer", "woodcutter", "miner", "builder", "hauler" } do
			for _, look in cornerLooks() do
				local rig = Kit.character("citizen", job, AZURE, look)
				local tool = child(rig, "Tool")
				expect(longest(tool)).toBeGreaterThanOrEqual(N_TOOL)
				if WORKING_SET[job] then
					local hat = child(rig, "Hair")
					expect(horizontal(hat)).toBeGreaterThanOrEqual(N_HAT)
					local group = { hat, tool }
					for _, d in detailsOf(rig) do
						table.insert(group, d)
					end
					local gMin, gMax = modelBounds(group)
					expect((gMax - gMin).Magnitude).toBeGreaterThanOrEqual(N_BOX)
				end
			end
		end
	end)
end)

describe("Kit.character clearance: hats sit on the head, the sack and tools clear it (no visible clipping)", function()
	local HEAD_R = 0.8
	local SEAT_MAX = 0.4 -- the head enters a hat's lower face by at most this
	local EPS = 0.012
	local ACTIONS = { "idle", "walk", "work", "carry", "fight", "flee", "celebrate" } -- celebrate too since FORGE-01's #158 (Sim/Pose on main)

	-- points on the head sphere (a lat-long grid, 24 x 12) in world space
	local function headSamples(head: BasePart): { Vector3 }
		local out = {}
		local c, r = head.CFrame.Position, head.Size.X / 2
		for i = 0, 11 do
			local phi = math.pi * (i + 0.5) / 12
			for j = 0, 23 do
				local theta = 2 * math.pi * j / 24
				table.insert(
					out,
					c + r * Vector3.new(math.sin(phi) * math.cos(theta), math.cos(phi), math.sin(phi) * math.sin(theta))
				)
			end
		end
		return out
	end

	-- is the world point inside the part's solid (Block, Wedge, Cylinder or Ball)?
	local function insideSolid(p: BasePart, w: Vector3): boolean
		local l = p.CFrame:PointToObjectSpace(w)
		local h = p.Size / 2
		if p:IsA("WedgePart") then
			return math.abs(l.X) <= h.X + EPS
				and l.Y >= -h.Y - EPS
				and l.Y <= h.Y + EPS
				and math.abs(l.Z) <= h.Z + EPS
				and (l.Y + h.Y) <= p.Size.Y * (l.Z + h.Z) / p.Size.Z + EPS
		elseif p:IsA("Part") and p.Shape == Enum.PartType.Cylinder then
			return math.abs(l.X) <= h.X + EPS and math.sqrt(l.Y * l.Y + l.Z * l.Z) <= h.Y + EPS
		elseif p:IsA("Part") and p.Shape == Enum.PartType.Ball then
			return l.Magnitude <= h.X + EPS
		end
		return math.abs(l.X) <= h.X + EPS and math.abs(l.Y) <= h.Y + EPS and math.abs(l.Z) <= h.Z + EPS
	end

	-- distance of a world point above the part's lower face (the cylinder's axis is its X)
	local function aboveBottom(p: BasePart, w: Vector3): number
		local up, half = p.CFrame.UpVector, p.Size.Y / 2
		if p:IsA("Part") and p.Shape == Enum.PartType.Cylinder then
			up, half = p.CFrame.RightVector, p.Size.X / 2
		end
		return (w - p.CFrame.Position):Dot(up) + half
	end

	-- distance from a point to a part's box (0 inside)
	local function boxDistance(p: BasePart, cf: CFrame, w: Vector3): number
		local l = cf:PointToObjectSpace(w)
		local h = p.Size / 2
		return Vector3.new(
			math.max(math.abs(l.X) - h.X, 0),
			math.max(math.abs(l.Y) - h.Y, 0),
			math.max(math.abs(l.Z) - h.Z, 0)
		).Magnitude
	end

	local function checkHat(label: string, rig: Model)
		local head, hat = child(rig, "Head"), child(rig, "Hair")
		if hat:IsA("Part") and hat.Shape == Enum.PartType.Ball then
			-- a ball beanie: the head leaves it through a rim. The rim stays above the eyes on the face side and the
			-- two surfaces meet at 35° or more (a clean line, not a grazing, jagged one)
			local c, hr = pos(head), head.Size.X / 2
			local bc, br = pos(hat), hat.Size.X / 2
			local d = (bc - c).Magnitude
			expect((hr * hr + br * br - d * d) / (2 * hr * br)).toBeLessThanOrEqual(math.cos(math.rad(35)))
			local covered = 0
			for _, w in headSamples(head) do
				if (w - bc).Magnitude <= br then
					covered += 1
					local l = head.CFrame:PointToObjectSpace(w)
					if l.Z < -0.1 then
						expect(l.Y).toBeGreaterThanOrEqual(0.33 - EPS)
					end
				end
			end
			expect(covered).toBeGreaterThan(40) -- it covers the crown, not just touches it
			return
		end
		local seat = -math.huge
		for _, w in headSamples(head) do
			local d = aboveBottom(hat, w)
			seat = math.max(seat, d)
			if d > EPS and not insideSolid(hat, w) then
				error(`{label}: the head pokes through the hat at {w} ({d} above its lower face)`)
			end
		end
		expect(seat).toBeLessThanOrEqual(SEAT_MAX + EPS) -- sits ON the head, not wrapped round it
		expect(seat).toBeGreaterThanOrEqual(0.15) -- and rests on it (the head enters it a little), not floating
	end

	it("seats every job hat on the head: nothing of the head shows through the hat, whatever the look", function()
		for _, job in WORKING do
			for hair = 1, R.hair do
				checkHat(
					`{job} hair {hair}`,
					Kit.character("citizen", job, AZURE, { skin = 1, hair = hair, hairColor = 1, outfit = 1 } :: any)
				)
			end
		end
	end)

	it("covers the governor's head with the crown (the head used to poke through the circlet's top)", function()
		for _, kingdom in { "crimson", "gold" } do
			checkHat(`governor {kingdom}`, Kit.character("governor", "idle", CRIMSON, nil, kingdom))
		end
	end)

	it("keeps the hauler's sack clear of the head and both arms at rest and in every pose", function()
		local rig = Kit.character("citizen", "hauler", AZURE)
		local head, sack = child(rig, "Head"), child(rig, "Tool")
		local r = sack.Size.X / 2
		local arms = { child(rig, "LeftArm"), child(rig, "RightArm") }
		local restGap = (pos(sack) - pos(head)).Magnitude - r - HEAD_R
		expect(restGap).toBeGreaterThanOrEqual(0.2) -- a visible gap, not touching, at rest
		local minHead, minArm, minLeg = math.huge, math.huge, math.huge
		for _, action in ACTIONS do
			for _, speed in { 0, 6, 12 } do
				for i = 0, 7 do
					local w = posed(rig, Pose.sample(action, "hauler", i / 8, speed))
					minHead = math.min(minHead, (w[sack].Position - w[head].Position).Magnitude - r - HEAD_R)
					for _, arm in arms do
						minArm = math.min(minArm, boxDistance(arm, w[arm], w[sack].Position) - r)
					end
					for _, name in { "LeftLeg", "RightLeg" } do
						local leg = child(rig, name)
						minLeg = math.min(minLeg, boxDistance(leg, w[leg], w[sack].Position) - r)
					end
				end
			end
		end
		expect(minLeg).toBeGreaterThanOrEqual(0.02) -- the walking legs never enter the sack
		-- low and behind: its top just above the shoulders (3.9), so from the front it is a bag behind the body, not
		-- a bun beside the head
		local sackTop, sackBottom = pos(sack).Y + r, pos(sack).Y - r
		expect(sackTop).toBeLessThanOrEqual(4.3)
		expect(sackBottom).toBeGreaterThanOrEqual(1.3)
		expect(minHead).toBeGreaterThanOrEqual(0.1) -- through walking, working, carrying, fighting, fleeing
		expect(minArm).toBeGreaterThanOrEqual(0.03) -- the swinging arms never enter the sack
		-- the sack sits behind the back, not through the torso
		local torso = child(rig, "Torso")
		expect(boxDistance(torso, torso.CFrame, pos(sack)) - r).toBeGreaterThanOrEqual(-0.1)
	end)

	it("keeps the hand tools and their heads clear of the head in every pose (box vs sphere)", function()
		local cases = {
			{ "citizen", "farmer", nil },
			{ "citizen", "woodcutter", nil },
			{ "citizen", "miner", nil },
			{ "citizen", "builder", nil },
			{ "soldier", "soldier", "crimson" },
			{ "governor", "idle", "crimson" },
		}
		for _, c in cases do
			local rig = Kit.character(c[1], c[2], AZURE, nil, c[3])
			local head, tool = child(rig, "Head"), child(rig, "Tool")
			local onTool = { tool } -- the handle and every detail part welded to it (the hoe blade, the axe head, ...)
			for _, d in detailsOf(rig) do
				if (d:FindFirstChild("DetailWeld") :: Weld).Part0 == tool then
					table.insert(onTool, d)
				end
			end
			local minGap = math.huge
			for _, action in ACTIONS do
				for _, speed in { 0, 6, 12 } do
					for i = 0, 7 do
						local w = posed(rig, Pose.sample(action, c[2], i / 8, speed))
						for _, p in onTool do
							minGap = math.min(minGap, boxDistance(p, w[p], w[head].Position) - HEAD_R)
						end
					end
				end
			end
			if minGap < 0.1 then
				error(`{c[2]}: a tool part comes within {minGap} of the head sphere (needs 0.1)`)
			end
		end
	end)

	-- ===== exact clearance between the tool assembly and the head assembly, every Pose action (FL-0118 phase 2) =====
	-- The tool assembly is the Tool and every part welded to it (the hoe blade, the pick bar, the mallet, the spearhead,
	-- the sack's strap and tie ...); the head assembly is the Head and every part welded to it (hair or hat, lamp, visor,
	-- pompom, crown, velvet cap, accessory). The clearance of two posed parts: boxes (Block, Wedge as its bounding box)
	-- by the separating axis over all 15 axes; a Ball against a box or a Ball exactly; anything with a Cylinder by
	-- sample points on each part against the exact signed distance to the other. Positive = free space, negative = how
	-- far one sinks into the other.
	-- a box against a sphere: the distance from the centre to the box's surface less the radius (negative inside)
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

	local function shapeOf(p: BasePart): string
		if p:IsA("Part") and (p :: Part).Shape == Enum.PartType.Ball then
			return "ball"
		elseif p:IsA("Part") and (p :: Part).Shape == Enum.PartType.Cylinder then
			return "cylinder"
		end
		return "box"
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

	-- signed distance from `point` to the surface of a posed part (negative inside); a Cylinder runs along its local X
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

	-- the centre, the corners, the edge middles and face centres of a box, two end circles and a middle circle of a
	-- cylinder (12 points each), the axis points of a ball
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

	-- `root` and every part welded to it (a Weld in either direction; never across a Motor6D)
	local function assemblyOf(rig: Model, root: BasePart): { BasePart }
		local out: { BasePart } = { root }
		local seen: { [BasePart]: boolean } = { [root] = true }
		local i = 1
		while i <= #out do
			local part = out[i]
			i += 1
			for _, d in rig:GetDescendants() do
				if d:IsA("Weld") then
					local a, b = d.Part0 :: BasePart, d.Part1 :: BasePart
					local other = if a == part then b elseif b == part then a else nil
					if other and not seen[other] then
						seen[other] = true
						table.insert(out, other)
					end
				end
			end
		end
		return out
	end

	-- The smallest clearance over every pair (tool part, head part) in every Pose action (idle, walk, work, carry,
	-- fight, flee, celebrate; walk, carry and flee at speeds 0, 6 and 12; 24 phases per cycle) of one rig, as
	-- { exact clearance, bounding-box clearance, "tool part | head part, action" of the exact minimum, the same of the box minimum }.
	-- The bounding-box clearance takes every part as its oriented box (a Ball as its cube, a Cylinder as its box).
	local TOOL_ACTIONS = { "idle", "walk", "work", "carry", "fight", "flee", "celebrate" }
	local function toolHeadClearance(rig: Model, job: string): (number, number, string, string)
		local head, tool = child(rig, "Head"), child(rig, "Tool")
		local toolParts, headParts = assemblyOf(rig, tool), assemblyOf(rig, head)
		local lowExact, lowBox, where, whereBox = math.huge, math.huge, "", ""
		for _, action in TOOL_ACTIONS do
			local speeds = if action == "walk" or action == "carry" or action == "flee" then { 0, 6, 12 } else { 0 }
			for _, speed in speeds do
				for i = 0, 23 do
					local w = posed(rig, Pose.sample(action, job, i / 24, speed))
					for _, t in toolParts do
						for _, h in headParts do
							local c = exactClearance(t, w[t], h, w[h])
							if c < lowExact then
								lowExact, where = c, `{t.Name} | {h.Name}, {action}`
							end
							local b = boxBox(w[t], t.Size, w[h], h.Size)
							if b < lowBox then
								lowBox, whereBox = b, `{t.Name} | {h.Name}, {action}`
							end
						end
					end
				end
			end
		end
		return lowExact, lowBox, where, whereBox
	end

	local TOOL_RIGS = {
		{ "citizen", "farmer", nil },
		{ "citizen", "woodcutter", nil },
		{ "citizen", "miner", nil },
		{ "citizen", "builder", nil },
		{ "citizen", "hauler", nil },
		{ "soldier", "soldier", "crimson" },
		{ "governor", "idle", "crimson" },
	}
	local TOOL_HEAD_EXACT = 0.1 -- studs of free space between every tool part and every head part, exact shapes
	local TOOL_HEAD_BOX = 0.03 -- and between their bounding boxes (the hauler's ball sack excepted)

	it(
		"keeps every part welded to the tool clear of the head and everything welded to it in every Pose action",
		function()
			for _, c in TOOL_RIGS do
				-- the three hat rolls (look.hair 1..3: 0 and +-9 degrees tilt the hat, its lamp, visor or crown about the head)
				for hair = 1, 3 do
					local look = if c[1] == "citizen" then { skin = 1, hair = hair, hairColor = 1, outfit = 1 } else nil
					local rig = Kit.character(c[1], c[2], AZURE, look :: any, c[3])
					local job = if c[1] == "governor" then "governor" else c[2]
					local exact, box, where, whereBox = toolHeadClearance(rig, job)
					if exact < TOOL_HEAD_EXACT then
						error(
							`{c[1]}/{c[2]} hair {hair}: {string.format("%.3f", exact)} studs at {where} (needs {TOOL_HEAD_EXACT})`
						)
					end
					if c[2] ~= "hauler" and box < TOOL_HEAD_BOX then
						error(
							`{c[1]}/{c[2]} hair {hair}: bounding boxes only {string.format("%.3f", box)} studs apart at {whereBox} (needs {TOOL_HEAD_BOX})`
						)
					end
				end
			end
		end
	)

	it("measures clearance as it says: gap, overlap, and the exact shapes", function()
		local function part(shape: Enum.PartType, size: Vector3): Part
			local p = Instance.new("Part")
			p.Shape, p.Size = shape, size
			return p
		end
		local block, ball, cyl = Enum.PartType.Block, Enum.PartType.Ball, Enum.PartType.Cylinder
		local a, b = part(block, Vector3.new(2, 2, 2)), part(block, Vector3.new(2, 2, 2))
		expect(exactClearance(a, CFrame.new(0, 0, 0), b, CFrame.new(3, 0, 0))).toBeNear(1, 1e-6)
		expect(exactClearance(a, CFrame.new(0, 0, 0), b, CFrame.new(1.5, 0, 0))).toBeNear(-0.5, 1e-6)
		local s = part(ball, Vector3.new(2, 2, 2))
		expect(exactClearance(s, CFrame.new(0, 0, 0), a, CFrame.new(3, 0, 0))).toBeNear(1, 1e-6) -- a ball: radius 1
		expect(exactClearance(s, CFrame.new(0, 0, 0), a, CFrame.new(1.5, 1.5, 0))).toBeNear(
			math.sqrt(0.5 ^ 2 * 2) - 1,
			1e-6
		)
		local cylinder = part(cyl, Vector3.new(1, 2, 2)) -- a disc along X, radius 1
		expect(exactClearance(cylinder, CFrame.new(0, 0, 0), a, CFrame.new(0, 3, 0))).toBeNear(1, 1e-6)
		expect(exactClearance(cylinder, CFrame.new(0, 0, 0), a, CFrame.new(0, 1.5, 0))).toBeNear(-0.5, 0.05)
		-- a box corner the cylinder's own box would hit but the cylinder does not
		expect(exactClearance(cylinder, CFrame.new(0, 0, 0), a, CFrame.new(0, 2.2, 2.2))).toBeGreaterThan(0.5)
		expect(boxBox(CFrame.new(0, 0, 0), cylinder.Size, CFrame.new(0, 2.2, 2.2), a.Size)).toBeLessThan(0.3)
	end)
end)

describe("Kit.character individuals, idle accessories, governor and low crest (art pass 1b)", function()
	local function dist255(a: Color3, b: Color3): number
		return 255 * math.sqrt((a.R - b.R) ^ 2 + (a.G - b.G) ^ 2 + (a.B - b.B) ^ 2)
	end
	local function lookOf(hair: number, hairColor: number, outfit: number, skin: number): any
		return { skin = skin, hair = hair, hairColor = hairColor, outfit = outfit }
	end
	local ALL = { "idle", "farmer", "woodcutter", "miner", "builder", "hauler" }

	it(
		"varies shirt tone, trousers and panel per individual from the look alone, and still recolours exactly",
		function()
			for _, job in ALL do
				local shirts, legs = {}, {}
				for hairColor = 1, R.hairColor do
					local rig = Kit.character("citizen", job, CRIMSON, lookOf(1, hairColor, 1, 1))
					shirts[child(rig, "Torso").Color:ToHex()] = true
					legs[child(rig, "LeftLeg").Color:ToHex()] = true
					Kit.setKingdomColor(rig, GOLD)
					expect(signature(rig)).toBe(
						signature(Kit.character("citizen", job, GOLD, lookOf(1, hairColor, 1, 1)))
					)
				end
				local n, m = 0, 0
				for _ in shirts do
					n += 1
				end
				for _ in legs do
					m += 1
				end
				expect(n).toBe(R.hairColor) -- eight shirt tones (the kingdom tint factor moves a little)
				if WORKING_SET[job] or job == "hauler" then
					expect(m).toBe(R.hairColor) -- and eight trouser dyes
				end
			end
			-- the default look keeps the outfit's own tint exactly
			expect(child(Kit.character("citizen", "farmer", CRIMSON), "Torso"):GetAttribute("KitTint")).toBe(0.8)
			-- different jobs' trousers stay apart under every dye
			local minDist = math.huge
			for i, a in ALL do
				for j = i + 1, #ALL do
					local b = ALL[j]
					if a ~= "idle" then
						for dyeA = 1, R.hairColor do
							for dyeB = 1, R.hairColor do
								local ca =
									child(Kit.character("citizen", a, CRIMSON, lookOf(1, dyeA, 1, 1)), "LeftLeg").Color
								local cb =
									child(Kit.character("citizen", b, CRIMSON, lookOf(1, dyeB, 1, 1)), "LeftLeg").Color
								minDist = math.min(minDist, dist255(ca, cb))
							end
						end
					end
				end
			end
			expect(minDist).toBeGreaterThan(10)
		end
	)

	it("gives each working job three hat colours and varied panels (per individual)", function()
		for _, job in WORKING do
			local hats = {}
			for hair = 1, R.hair do
				local rig = Kit.character("citizen", job, CRIMSON, lookOf(hair, 1, 1, 1))
				hats[child(rig, "Hair").Color:ToHex()] = true
			end
			local n = 0
			for _ in hats do
				n += 1
			end
			expect(n).toBe(3) -- three palette colours, each worn by two of the six hair styles
			local panels = {}
			for hairColor = 1, R.hairColor do
				-- outfit 4 (apron) has a neutral torso, which takes the dyed job panel
				local rig = Kit.character("citizen", job, CRIMSON, lookOf(1, hairColor, 4, 1))
				expect(child(rig, "Torso"):GetAttribute("KitAccent")).toBe(job)
				panels[child(rig, "Torso").Color:ToHex()] = true
			end
			local m = 0
			for _ in panels do
				m += 1
			end
			expect(m).toBeGreaterThanOrEqual(6)
			-- the three palette picks differ in hue, not only in brightness (the dye): (R - B) / (R + G + B)
			local function chroma(c: Color3): number
				return (c.R - c.B) / (c.R + c.G + c.B)
			end
			local lo, hi, llo, lhi = math.huge, -math.huge, math.huge, -math.huge
			for hairColor = 1, 3 do
				local rig = Kit.character("citizen", job, CRIMSON, lookOf(1, hairColor, 4, 1))
				lo, hi =
					math.min(lo, chroma(child(rig, "Torso").Color)), math.max(hi, chroma(child(rig, "Torso").Color))
				local leg = chroma(child(rig, "LeftLeg").Color)
				llo, lhi = math.min(llo, leg), math.max(lhi, leg)
			end
			expect(hi - lo).toBeGreaterThanOrEqual(0.03)
			expect(lhi - llo).toBeGreaterThanOrEqual(0.03)
		end
	end)

	it(
		"gives working citizens kingdom-red sleeves (red shoulders from above) or the job panel, by hair colour",
		function()
			for _, job in WORKING do
				for _, outfit in { 1, 6 } do -- tunic and jerkin have neutral sleeves
					local odd = Kit.character("citizen", job, CRIMSON, lookOf(1, 1, outfit, 1))
					local even = Kit.character("citizen", job, CRIMSON, lookOf(1, 2, outfit, 1))
					expect(child(odd, "LeftArm"):GetAttribute("KitAccent")).toBe(job) -- odd: the job panel
					expect(child(odd, "LeftArm"):GetAttribute("KitTint")).toBeNil()
					expect(child(even, "LeftArm"):GetAttribute("KitAccent")).toBeNil() -- even: the kingdom tint
					local tint = child(even, "LeftArm"):GetAttribute("KitTint")
					expect(type(tint)).toBe("number")
					expect(tint).toBeGreaterThanOrEqual(0.6)
					expect(tint).toBeLessThanOrEqual(0.9)
					expect(child(even, "RightArm"):GetAttribute("KitTint")).toBe(tint)
					-- the trousers carry the accent either way
					expect(child(even, "LeftLeg"):GetAttribute("KitAccent")).toBe(job)
				end
			end
			-- kingdom-tinted area seen from above (top faces of torso and arms): more with red sleeves
			local function tintedTop(rig: Model): number
				local area = 0
				for _, name in { "Torso", "LeftArm", "RightArm" } do
					local p = child(rig, name)
					if p:GetAttribute("KitTint") then
						area += p.Size.X * p.Size.Z
					end
				end
				return area
			end
			for _, job in WORKING do
				local a = tintedTop(Kit.character("citizen", job, CRIMSON, lookOf(1, 1, 1, 1)))
				local b = tintedTop(Kit.character("citizen", job, CRIMSON, lookOf(1, 2, 1, 1)))
				expect(b).toBeGreaterThan(a + 1.0)
			end
		end
	)

	it(
		"gives idle citizens a headband or scarf about two looks in three, as the 9th part welded to the Head",
		function()
			local with, total, kinds = 0, 0, {}
			for skin = 1, R.skin do
				for hair = 1, R.hair do
					for outfit = 1, R.outfit do
						local rig = Kit.character("citizen", "idle", CRIMSON, lookOf(hair, 1, outfit, skin))
						total += 1
						local acc = rig:FindFirstChild("Accessory") :: BasePart?
						expect(#parts(rig)).toBeLessThanOrEqual(MAX_PARTS)
						if acc then
							with += 1
							local kind = acc:GetAttribute("KitAccessory")
							kinds[kind] = true
							local head = child(rig, "Head")
							local weld = acc:FindFirstChild("AccessoryWeld") :: Weld
							expect(weld.ClassName).toBe("Weld")
							expect(weld.Part0).toBe(head)
							expect(weld.Part1).toBe(acc)
							for _, prop in { "CanCollide", "CanTouch", "CanQuery" } do
								expect((acc :: any)[prop]).toBe(false)
							end
							expect(acc.Massless).toBe(true)
							-- clear of the face: a headband above the eyes, a scarf below the chin line
							local lo, hi = bounds(acc)
							local rel = pos(head).Y
							if kind == "headband" then
								expect(lo.Y).toBeGreaterThanOrEqual(rel + 0.28)
								expect(hi.Y).toBeLessThanOrEqual(rel + 0.62)
							else
								expect(hi.Y).toBeLessThanOrEqual(rel - 0.4)
							end
						end
					end
				end
			end
			expect(with / total).toBeGreaterThan(0.55)
			expect(with / total).toBeLessThan(0.8)
			expect(kinds.headband).toBe(true)
			expect(kinds.scarf).toBe(true)
			-- the default look wears none, and no other job or kind ever does
			expect(Kit.character("citizen", "idle", CRIMSON):FindFirstChild("Accessory")).toBeNil()
			for _, job in { "farmer", "woodcutter", "miner", "builder", "hauler", "soldier" } do
				for _, look in cornerLooks() do
					expect(Kit.character("citizen", job, CRIMSON, look):FindFirstChild("Accessory")).toBeNil()
				end
			end
			for _, kind in { "governor", "soldier" } do
				expect(Kit.character(kind, "idle", CRIMSON, lookOf(2, 1, 2, 2)):FindFirstChild("Accessory")).toBeNil()
			end
		end
	)

	it("makes the governor's crown a wide gold disc and the staff thick and long (readable from the air)", function()
		local rig = Kit.character("governor", "idle", CRIMSON)
		local crown, staff = child(rig, "Hair"), child(rig, "Tool")
		local lo, hi = bounds(crown)
		expect(math.max(hi.X - lo.X, hi.Z - lo.Z)).toBeGreaterThanOrEqual(1.85)
		expect(hi.Y - lo.Y).toBeGreaterThanOrEqual(0.55)
		expect(staff.Size.Y).toBeGreaterThanOrEqual(0.45)
		local _, top = bounds(staff)
		expect(top.Y).toBeGreaterThan(6.4)
		expect(child(rig, "Torso").Size.X).toBeGreaterThanOrEqual(2.35)
	end)

	it("keeps the soldier's kingdom crest low: no taller than the helm, so it is not a gnome's hat", function()
		for _, kingdom in KINGDOM_IDS do
			local rig = Kit.character("soldier", "soldier", KINGDOM_COLORS[kingdom], nil, kingdom)
			local crest = crestOf(rig) :: BasePart
			local _, top = bounds(crest)
			local helmHeight = child(rig, "Head").Size.Y
			expect(top.Y - 5.5).toBeLessThanOrEqual(helmHeight) -- at most the helm's own height above it
			expect(top.Y - 5.5).toBeGreaterThanOrEqual(0.4) -- still a crest
		end
		local spire = crestOf(Kit.character("soldier", "soldier", CRIMSON, nil, "crimson")) :: BasePart
		local _, top = bounds(spire)
		expect(top.Y - 5.5).toBeLessThanOrEqual(1.7)
	end)
end)

describe("Kit.character detail parts (D-048): 11 parts, rigid, welded, flagged, no new joints", function()
	-- what each rig wears as detail parts: Detail1, Detail2 as { KitDetailKind, welded to }
	local WANT = {
		farmer = { { "strawcrown", "Head" }, { "hoeblade", "Tool" } },
		woodcutter = { { "pompom", "Head" }, { "axehead", "Tool" } },
		miner = { { "pickhead", "Tool" }, { "pickpoint", "Tool" } }, -- both on the pick: the arch reads as a pickaxe, not a hammer
		builder = { { "visor", "Head" }, { "mallet", "Tool" } },
		hauler = { { "strap", "Tool" }, { "tie", "Tool" } },
	}

	it("leaves Sim/Pose.JOINTS and the Motor6D set unchanged: a detail part never has a joint", function()
		expect(Pose.JOINTS).toEqual(POSE_JOINTS)
		each(function(_, _, rig)
			for _, d in rig:GetDescendants() do
				if d:IsA("Motor6D") then
					expect(table.find(POSE_JOINTS, d.Name)).never.toBeNil()
					expect(isDetail(d.Part1 :: BasePart)).toBe(false)
					expect(isDetail(d.Part0 :: BasePart)).toBe(false)
				end
			end
		end)
	end)

	it("flags every detail part KitDetail, names it Detail<n>, and welds it rigidly to the Head or the Tool", function()
		local total = 0
		each(function(_, _, rig)
			local names = {}
			for _, p in parts(rig) do
				local isD = isDetail(p)
				expect(p:GetAttribute("KitDetail") == true or p:GetAttribute("KitDetail") == nil).toBe(true)
				expect(string.match(p.Name, "^Detail%d$") ~= nil).toBe(isD)
				if not isD then
					continue
				end
				total += 1
				expect(names[p.Name]).toBeNil()
				names[p.Name] = true
				expect(type(p:GetAttribute("KitDetailKind"))).toBe("string")
				local weld = p:FindFirstChild("DetailWeld") :: Weld
				expect(weld).never.toBeNil()
				expect(weld.ClassName).toBe("Weld") -- never a Motor6D, never a WeldConstraint
				expect(weld.Part1).toBe(p)
				expect(weld.Part0 == child(rig, "Head") or weld.Part0 == child(rig, "Tool")).toBe(true)
				local cf = (weld.Part0 :: BasePart).CFrame * weld.C0 * weld.C1:Inverse()
				expect((cf.Position - pos(p)).Magnitude).toBeLessThan(1e-3)
				for _, prop in { "CanCollide", "CanTouch", "CanQuery", "Anchored" } do
					expect((p :: any)[prop]).toBe(false)
				end
				expect(p.Massless).toBe(true)
			end
		end)
		expect(total).toBeGreaterThan(100)
	end)

	it("gives each job its two detail parts, derived from kind and job alone (no new look field)", function()
		for job, want in WANT do
			-- the same two details for every look
			for _, look in cornerLooks() do
				local rig = Kit.character("citizen", job, AZURE, look)
				local ds = detailsOf(rig)
				expect(#ds).toBe(2)
				for i, w in want do
					expect(ds[i]:GetAttribute("KitDetailKind")).toBe(w[1])
					expect((ds[i]:FindFirstChild("DetailWeld") :: Weld).Part0).toBe(child(rig, w[2]))
				end
			end
		end
		-- soldiers (with or without a kingdom, drafted citizens too): spearhead and pennant on the spear
		for _, role in { { "soldier", "soldier" }, { "citizen", "soldier" }, { "soldier", "farmer" } } do
			for _, kingdom in { "crimson", "azure", "emerald", "gold" } do
				local ds = detailsOf(Kit.character(role[1], role[2], CRIMSON, nil, kingdom))
				expect(#ds).toBe(2)
				expect(ds[1]:GetAttribute("KitDetailKind")).toBe("spearhead")
				expect(ds[2]:GetAttribute("KitDetailKind")).toBe("pennant")
			end
		end
		-- governors: a velvet cap on the head and an orb on the staff
		local gov = detailsOf(Kit.character("governor", "idle", CRIMSON))
		expect(#gov).toBe(2)
		expect(gov[1]:GetAttribute("KitDetailKind")).toBe("velvetcap")
		expect(gov[2]:GetAttribute("KitDetailKind")).toBe("orb")
		-- idle citizens carry nothing and have no detail parts (their free part is the Accessory)
		for _, look in cornerLooks() do
			expect(#detailsOf(Kit.character("citizen", "idle", CRIMSON, look))).toBe(0)
		end
	end)

	it("keeps every head detail clear of the face and on the hat, following its tilt", function()
		for _, job in WORKING do
			if job == "miner" then
				continue -- the miner's two details are the pick's tines (Tool), not a head detail
			end
			local ref
			for hair = 1, R.hair do
				local rig =
					Kit.character("citizen", job, AZURE, { skin = 1, hair = hair, hairColor = 1, outfit = 1 } :: any)
				local head, hat = child(rig, "Head"), child(rig, "Hair")
				local d = detailsOf(rig)[1]
				local lo = bounds(d)
				expect(lo.Y).toBeGreaterThanOrEqual(pos(head).Y + 0.3) -- above the eyes
				-- the detail keeps its place on the hat whatever the hat's tilt
				local gap = (pos(d) - pos(hat)).Magnitude
				ref = ref or gap
				expect(gap).toBeNear(ref, 1e-3)
			end
		end
		-- kingdom-coloured head details (crown, pompom, velvet cap) recolour with the kingdom
		for _, job in { "farmer", "woodcutter" } do
			local rig = Kit.character("citizen", job, CRIMSON)
			local d = detailsOf(rig)[1]
			expect(d:GetAttribute("KitTint")).never.toBeNil()
			Kit.setKingdomColor(rig, GOLD)
			expect(d.Color:ToHex()).toBe(detailsOf(Kit.character("citizen", job, GOLD))[1].Color:ToHex())
		end
	end)

	-- signed distance from a world point to a part's box: > 0 outside, <= 0 inside (depth to the nearest face)
	local function boxSigned(p: BasePart, cf: CFrame, w: Vector3): number
		local l = cf:PointToObjectSpace(w)
		local h = p.Size / 2
		local q = Vector3.new(math.abs(l.X) - h.X, math.abs(l.Y) - h.Y, math.abs(l.Z) - h.Z)
		local outside = Vector3.new(math.max(q.X, 0), math.max(q.Y, 0), math.max(q.Z, 0)).Magnitude
		if outside > 0 then
			return outside
		end
		return math.max(q.X, q.Y, q.Z)
	end

	-- points on the head's surface (a ball: a lat-long grid; the soldier's helm is a box: a grid on its faces)
	local function headSurface(head: BasePart, cf: CFrame): { Vector3 }
		local out = {}
		if head:IsA("Part") and head.Shape == Enum.PartType.Ball then
			local r = head.Size.X / 2
			for i = 0, 11 do
				local phi = math.pi * (i + 0.5) / 12
				for j = 0, 23 do
					local th = 2 * math.pi * j / 24
					table.insert(
						out,
						cf
							* Vector3.new(
								r * math.sin(phi) * math.cos(th),
								r * math.cos(phi),
								r * math.sin(phi) * math.sin(th)
							)
					)
				end
			end
		else
			local h = head.Size / 2
			for ix = -4, 4 do
				for iy = -4, 4 do
					for iz = -4, 4 do
						if math.abs(ix) == 4 or math.abs(iy) == 4 or math.abs(iz) == 4 then
							table.insert(out, cf * Vector3.new(ix / 4 * h.X, iy / 4 * h.Y, iz / 4 * h.Z))
						end
					end
				end
			end
		end
		return out
	end

	it(
		"keeps both arms clear of the head in every pose, the arms-up cheer included (the pivots sit outside the torso)",
		function()
			local rigs = {
				{ "citizen", "farmer" },
				{ "citizen", "woodcutter" },
				{ "citizen", "miner" },
				{ "citizen", "builder" },
				{ "citizen", "hauler" },
				{ "citizen", "idle" },
				{ "soldier", "soldier" },
				{ "governor", "idle" },
			}
			for _, r in rigs do
				local rig = Kit.character(r[1], r[2], AZURE)
				local head = child(rig, "Head")
				local arms = { child(rig, "LeftArm"), child(rig, "RightArm") }
				for _, action in { "celebrate", "idle", "walk", "work", "carry", "fight", "flee" } do
					local minGap = math.huge
					for _, speed in { 0, 6, 12 } do
						for i = 0, 11 do
							local w = posed(rig, Pose.sample(action, r[2], i / 12, speed))
							local points = headSurface(head, w[head])
							for _, arm in arms do
								for _, p in points do
									minGap = math.min(minGap, boxSigned(arm, w[arm], p))
								end
							end
						end
					end
					-- before the pivots moved out the raised arm sank 0.10-0.32 studs into the head in the cheer
					expect(`{r[1]}/{r[2]} {action} {minGap >= (if action == "celebrate" then 0.3 else 0.2)}`).toBe(
						`{r[1]}/{r[2]} {action} true`
					)
				end
			end
		end
	)

	it(
		"moves only the arm pivots: the arms hang exactly where they did at rest, flush against the torso's sides",
		function()
			-- FORGE-01's pose analysis (#166): about 0.4 studs; any more floats the raised arm off the shoulder (D-051 (b))
			expect(Character.SHOULDER_OUT).toBeGreaterThanOrEqual(0.4)
			expect(Character.SHOULDER_OUT).toBeLessThanOrEqual(0.45)
			each(function(_, _, rig)
				local torso = child(rig, "Torso")
				for _, side in { "Left", "Right" } do
					local arm = child(rig, `{side}Arm`)
					-- the arm's inner top edge is the torso's side (a 0.02 stud seam), whatever the pivot
					local pivot = jointWorld(motorOf(rig, `{side}Arm`)).Position
					local sign = if side == "Left" then -1 else 1
					local top = arm.CFrame * Vector3.new(-sign * arm.Size.X / 2, arm.Size.Y / 2, 0)
					expect(math.abs(top.X) - torso.Size.X / 2).toBeLessThan(0.1)
					expect(math.abs(top.X) - torso.Size.X / 2).toBeGreaterThan(-0.05)
					-- and the pivot is outside it, on the arm's centre line: the raised arm stays attached to the torso
					expect(math.abs(pivot.X) - torso.Size.X / 2).toBeNear(Character.SHOULDER_OUT, 1e-3)
					local topCentre = arm.CFrame * Vector3.new(0, arm.Size.Y / 2, 0)
					expect(math.abs(math.abs(pivot.X) - math.abs(topCentre.X))).toBeLessThan(0.1)
				end
			end)
		end
	)
end)

describe("Kit.character individuals, idle accessories, governor and low crest (art pass 1b)", function()
	local function dist255(a: Color3, b: Color3): number
		return 255 * math.sqrt((a.R - b.R) ^ 2 + (a.G - b.G) ^ 2 + (a.B - b.B) ^ 2)
	end
	local function lookOf(hair: number, hairColor: number, outfit: number, skin: number): any
		return { skin = skin, hair = hair, hairColor = hairColor, outfit = outfit }
	end
	local ALL = { "idle", "farmer", "woodcutter", "miner", "builder", "hauler" }

	it(
		"varies shirt tone, trousers and panel per individual from the look alone, and still recolours exactly",
		function()
			for _, job in ALL do
				local shirts, legs = {}, {}
				for hairColor = 1, R.hairColor do
					local rig = Kit.character("citizen", job, CRIMSON, lookOf(1, hairColor, 1, 1))
					shirts[child(rig, "Torso").Color:ToHex()] = true
					legs[child(rig, "LeftLeg").Color:ToHex()] = true
					Kit.setKingdomColor(rig, GOLD)
					expect(signature(rig)).toBe(
						signature(Kit.character("citizen", job, GOLD, lookOf(1, hairColor, 1, 1)))
					)
				end
				local n, m = 0, 0
				for _ in shirts do
					n += 1
				end
				for _ in legs do
					m += 1
				end
				expect(n).toBe(R.hairColor) -- eight shirt tones (the kingdom tint factor moves a little)
				if WORKING_SET[job] or job == "hauler" then
					expect(m).toBe(R.hairColor) -- and eight trouser dyes
				end
			end
			-- the default look keeps the outfit's own tint exactly
			expect(child(Kit.character("citizen", "farmer", CRIMSON), "Torso"):GetAttribute("KitTint")).toBe(0.8)
			-- different jobs' trousers stay apart under every dye
			local minDist = math.huge
			for i, a in ALL do
				for j = i + 1, #ALL do
					local b = ALL[j]
					if a ~= "idle" then
						for dyeA = 1, R.hairColor do
							for dyeB = 1, R.hairColor do
								local ca =
									child(Kit.character("citizen", a, CRIMSON, lookOf(1, dyeA, 1, 1)), "LeftLeg").Color
								local cb =
									child(Kit.character("citizen", b, CRIMSON, lookOf(1, dyeB, 1, 1)), "LeftLeg").Color
								minDist = math.min(minDist, dist255(ca, cb))
							end
						end
					end
				end
			end
			expect(minDist).toBeGreaterThan(10)
		end
	)

	it("gives each working job three hat colours and varied panels (per individual)", function()
		for _, job in WORKING do
			local hats = {}
			for hair = 1, R.hair do
				local rig = Kit.character("citizen", job, CRIMSON, lookOf(hair, 1, 1, 1))
				hats[child(rig, "Hair").Color:ToHex()] = true
			end
			local n = 0
			for _ in hats do
				n += 1
			end
			expect(n).toBe(3) -- three palette colours, each worn by two of the six hair styles
			local panels = {}
			for hairColor = 1, R.hairColor do
				-- outfit 4 (apron) has a neutral torso, which takes the dyed job panel
				local rig = Kit.character("citizen", job, CRIMSON, lookOf(1, hairColor, 4, 1))
				expect(child(rig, "Torso"):GetAttribute("KitAccent")).toBe(job)
				panels[child(rig, "Torso").Color:ToHex()] = true
			end
			local m = 0
			for _ in panels do
				m += 1
			end
			expect(m).toBeGreaterThanOrEqual(6)
			-- the three palette picks differ in hue, not only in brightness (the dye): (R - B) / (R + G + B)
			local function chroma(c: Color3): number
				return (c.R - c.B) / (c.R + c.G + c.B)
			end
			local lo, hi, llo, lhi = math.huge, -math.huge, math.huge, -math.huge
			for hairColor = 1, 3 do
				local rig = Kit.character("citizen", job, CRIMSON, lookOf(1, hairColor, 4, 1))
				lo, hi =
					math.min(lo, chroma(child(rig, "Torso").Color)), math.max(hi, chroma(child(rig, "Torso").Color))
				local leg = chroma(child(rig, "LeftLeg").Color)
				llo, lhi = math.min(llo, leg), math.max(lhi, leg)
			end
			expect(hi - lo).toBeGreaterThanOrEqual(0.03)
			expect(lhi - llo).toBeGreaterThanOrEqual(0.03)
		end
	end)

	it(
		"gives working citizens kingdom-red sleeves (red shoulders from above) or the job panel, by hair colour",
		function()
			for _, job in WORKING do
				for _, outfit in { 1, 6 } do -- tunic and jerkin have neutral sleeves
					local odd = Kit.character("citizen", job, CRIMSON, lookOf(1, 1, outfit, 1))
					local even = Kit.character("citizen", job, CRIMSON, lookOf(1, 2, outfit, 1))
					expect(child(odd, "LeftArm"):GetAttribute("KitAccent")).toBe(job) -- odd: the job panel
					expect(child(odd, "LeftArm"):GetAttribute("KitTint")).toBeNil()
					expect(child(even, "LeftArm"):GetAttribute("KitAccent")).toBeNil() -- even: the kingdom tint
					local tint = child(even, "LeftArm"):GetAttribute("KitTint")
					expect(type(tint)).toBe("number")
					expect(tint).toBeGreaterThanOrEqual(0.6)
					expect(tint).toBeLessThanOrEqual(0.9)
					expect(child(even, "RightArm"):GetAttribute("KitTint")).toBe(tint)
					-- the trousers carry the accent either way
					expect(child(even, "LeftLeg"):GetAttribute("KitAccent")).toBe(job)
				end
			end
			-- kingdom-tinted area seen from above (top faces of torso and arms): more with red sleeves
			local function tintedTop(rig: Model): number
				local area = 0
				for _, name in { "Torso", "LeftArm", "RightArm" } do
					local p = child(rig, name)
					if p:GetAttribute("KitTint") then
						area += p.Size.X * p.Size.Z
					end
				end
				return area
			end
			for _, job in WORKING do
				local a = tintedTop(Kit.character("citizen", job, CRIMSON, lookOf(1, 1, 1, 1)))
				local b = tintedTop(Kit.character("citizen", job, CRIMSON, lookOf(1, 2, 1, 1)))
				expect(b).toBeGreaterThan(a + 1.0)
			end
		end
	)

	it(
		"gives idle citizens a headband or scarf about two looks in three, as the 9th part welded to the Head",
		function()
			local with, total, kinds = 0, 0, {}
			for skin = 1, R.skin do
				for hair = 1, R.hair do
					for outfit = 1, R.outfit do
						local rig = Kit.character("citizen", "idle", CRIMSON, lookOf(hair, 1, outfit, skin))
						total += 1
						local acc = rig:FindFirstChild("Accessory") :: BasePart?
						expect(#parts(rig)).toBeLessThanOrEqual(MAX_PARTS)
						if acc then
							with += 1
							local kind = acc:GetAttribute("KitAccessory")
							kinds[kind] = true
							local head = child(rig, "Head")
							local weld = acc:FindFirstChild("AccessoryWeld") :: Weld
							expect(weld.ClassName).toBe("Weld")
							expect(weld.Part0).toBe(head)
							expect(weld.Part1).toBe(acc)
							for _, prop in { "CanCollide", "CanTouch", "CanQuery" } do
								expect((acc :: any)[prop]).toBe(false)
							end
							expect(acc.Massless).toBe(true)
							-- clear of the face: a headband above the eyes, a scarf below the chin line
							local lo, hi = bounds(acc)
							local rel = pos(head).Y
							if kind == "headband" then
								expect(lo.Y).toBeGreaterThanOrEqual(rel + 0.28)
								expect(hi.Y).toBeLessThanOrEqual(rel + 0.62)
							else
								expect(hi.Y).toBeLessThanOrEqual(rel - 0.4)
							end
						end
					end
				end
			end
			expect(with / total).toBeGreaterThan(0.55)
			expect(with / total).toBeLessThan(0.8)
			expect(kinds.headband).toBe(true)
			expect(kinds.scarf).toBe(true)
			-- the default look wears none, and no other job or kind ever does
			expect(Kit.character("citizen", "idle", CRIMSON):FindFirstChild("Accessory")).toBeNil()
			for _, job in { "farmer", "woodcutter", "miner", "builder", "hauler", "soldier" } do
				for _, look in cornerLooks() do
					expect(Kit.character("citizen", job, CRIMSON, look):FindFirstChild("Accessory")).toBeNil()
				end
			end
			for _, kind in { "governor", "soldier" } do
				expect(Kit.character(kind, "idle", CRIMSON, lookOf(2, 1, 2, 2)):FindFirstChild("Accessory")).toBeNil()
			end
		end
	)

	it("makes the governor's crown a wide gold disc and the staff thick and long (readable from the air)", function()
		local rig = Kit.character("governor", "idle", CRIMSON)
		local crown, staff = child(rig, "Hair"), child(rig, "Tool")
		local lo, hi = bounds(crown)
		expect(math.max(hi.X - lo.X, hi.Z - lo.Z)).toBeGreaterThanOrEqual(1.85)
		expect(hi.Y - lo.Y).toBeGreaterThanOrEqual(0.55)
		expect(staff.Size.Y).toBeGreaterThanOrEqual(0.45)
		local _, top = bounds(staff)
		expect(top.Y).toBeGreaterThan(6.4)
		expect(child(rig, "Torso").Size.X).toBeGreaterThanOrEqual(2.35)
	end)

	it("keeps the soldier's kingdom crest low: no taller than the helm, so it is not a gnome's hat", function()
		for _, kingdom in KINGDOM_IDS do
			local rig = Kit.character("soldier", "soldier", KINGDOM_COLORS[kingdom], nil, kingdom)
			local crest = crestOf(rig) :: BasePart
			local _, top = bounds(crest)
			local helmHeight = child(rig, "Head").Size.Y
			expect(top.Y - 5.5).toBeLessThanOrEqual(helmHeight) -- at most the helm's own height above it
			expect(top.Y - 5.5).toBeGreaterThanOrEqual(0.4) -- still a crest
		end
		local spire = crestOf(Kit.character("soldier", "soldier", CRIMSON, nil, "crimson")) :: BasePart
		local _, top = bounds(spire)
		expect(top.Y - 5.5).toBeLessThanOrEqual(1.7)
	end)
end)

describe("Kit.character soldier kingdom crest (CONTRACTS G13.2, D-033(3))", function()
	local HELM_TOP = 5.5 -- top of today's great helm (the soldier's Head)

	-- primitive kind and the crest's outline above the helm: height over the helm top, width (X), depth (Z)
	local function outline(crest: BasePart): (string, number, number, number)
		local kind = if crest:IsA("Part") then `Part/{crest.Shape.Name}` else crest.ClassName
		local mn, mx = bounds(crest)
		return kind, mx.Y - HELM_TOP, mx.X - mn.X, mx.Z - mn.Z
	end

	it("gives each kingdom's soldier an 11-part rig whose 9th part is the kingdom crest welded to the helm", function()
		local crown = child(Kit.character("governor", "idle", CRIMSON), "Hair") -- existing welded headwear
		local plainMotors = {}
		for _, d in Kit.character("soldier", "soldier", CRIMSON):GetDescendants() do
			if d:IsA("Motor6D") then
				plainMotors[d.Name] = true
			end
		end
		for _, kingdom in KINGDOM_IDS do
			expect(Kit.SOLDIER_CRESTS[kingdom]).toBe(CREST_NAMES[kingdom])
			for _, role in { { "soldier", "soldier" }, { "citizen", "soldier" }, { "soldier", "farmer" } } do
				local color = KINGDOM_COLORS[kingdom]
				local rig = noYield(function()
					return Kit.character(role[1], role[2], color, nil, kingdom)
				end)
				expect(#parts(rig)).toBe(11) -- 9 + the spearhead and the pennant (D-048)
				local crest = crestOf(rig)
				assert(crest, `{role[1]} {role[2]} {kingdom} has no crest`)
				expect(crest.Name).toBe("Hair")
				expect(crest:GetAttribute("KitHeadwear")).toBe(CREST_NAMES[kingdom])
				-- the helm is still today's steel great helm, and the crest sits on it
				local head = child(rig, "Head")
				expect(head.Material).toBe(Enum.Material.Metal)
				local _, helmTop = bounds(head)
				expect(helmTop.Y).toBeNear(HELM_TOP, 1e-3)
				local cMin, cMax = bounds(crest)
				expect(cMin.Y).toBeLessThan(HELM_TOP + 0.01) -- seated on (into) the helm, not floating
				expect(cMax.Y).toBeGreaterThan(HELM_TOP + 0.3)
				-- welded to the Head (Weld "HairWeld"), never a Motor6D; the motors are the plain soldier's
				local weld = crest:FindFirstChild("HairWeld") :: Weld
				expect(weld).never.toBeNil()
				expect(weld.ClassName).toBe("Weld")
				expect(weld.Part0).toBe(head)
				expect(weld.Part1).toBe(crest)
				local cf = head.CFrame * weld.C0 * weld.C1:Inverse()
				expect((cf.Position - pos(crest)).Magnitude).toBeLessThan(1e-3)
				local motors = {}
				for _, d in rig:GetDescendants() do
					if d:IsA("Motor6D") then
						expect(d.Part1 ~= crest).toBe(true)
						motors[d.Name] = true
					end
				end
				expect(motors).toEqual(plainMotors)
				-- same physics flags as the other welded headwear (the governor's crown)
				for _, prop in { "CanCollide", "CanTouch", "CanQuery", "Massless", "Anchored", "CastShadow" } do
					expect((crest :: any)[prop]).toBe((crown :: any)[prop])
				end
				-- the kingdom colour, recoloured by Kit.setKingdomColor
				expect(crest:GetAttribute("KitTint")).toBe(1)
				expect(crest.Color:ToHex()).toBe(color:ToHex())
				expect(rig:GetAttribute("KitLook")).toBe(Kit.lookKey(nil, kingdom))
			end
		end
	end)

	it("gives the four crests different silhouettes, so kingdoms read apart without colour", function()
		local rows = {}
		for _, kingdom in KINGDOM_IDS do
			local crest = crestOf(Kit.character("soldier", "soldier", AZURE, nil, kingdom)) :: BasePart
			local kind, h, w, d = outline(crest)
			rows[kingdom] = { kind = kind, h = h, w = w, d = d, crest = crest }
		end
		-- pairwise: another primitive AND an outline at least 0.3 studs apart from the front (height or
		-- width) and from the side (height or depth)
		for i, a in KINGDOM_IDS do
			for j = i + 1, #KINGDOM_IDS do
				local b = KINGDOM_IDS[j]
				local A, B = rows[a], rows[b]
				expect(A.kind ~= B.kind).toBe(true)
				local dh = math.abs(A.h - B.h)
				expect(math.max(dh, math.abs(A.w - B.w))).toBeGreaterThanOrEqual(0.3)
				expect(math.max(dh, math.abs(A.d - B.d))).toBeGreaterThanOrEqual(0.3)
			end
		end
		-- each in its tower style: the spire is the tallest and a pointed wedge, taller than wide
		local spire, square, plume, dome = rows.crimson, rows.azure, rows.emerald, rows.gold
		expect(spire.kind == "CornerWedgePart" or spire.kind == "WedgePart").toBe(true)
		for _, other in { square, plume, dome } do
			expect(spire.h).toBeGreaterThan(other.h + 0.3)
		end
		expect(spire.h).toBeGreaterThan(spire.w)
		-- the square is a level, flat-topped block, wider than the helm and lower than it is wide
		expect(square.kind).toBe("Part/Block")
		expect(square.crest.CFrame.UpVector.Y).toBeNear(1, 1e-6)
		expect(square.w).toBeGreaterThan(1.45 + 0.3)
		expect(square.h).toBeLessThan(square.w / 2)
		-- the plume is narrow and swept back past the helm's back face (+Z is the back)
		local _, plumeMax = bounds(plume.crest)
		expect(plumeMax.Z).toBeGreaterThan(1.45 / 2 + 0.3)
		expect(plume.w).toBeLessThan(1.45 / 2)
		-- the dome is round, and wider than its seat on the helm (it bulges)
		expect(dome.kind).toBe("Part/Ball")
		local r = dome.crest.Size.X / 2
		local over = pos(dome.crest).Y - HELM_TOP -- ball centre above the helm top
		expect(over).toBeGreaterThan(0)
		expect(over).toBeLessThan(r)
		expect(2 * math.sqrt(r * r - over * over)).toBeLessThan(dome.w - 0.2)
	end)

	it("keeps today's plain helm (10 parts with its spear details) with no kingdom or an unknown one", function()
		local plain = Kit.character("soldier", "soldier", CRIMSON)
		expect(#parts(plain)).toBe(10) -- 8 + the spearhead and the pennant (D-048)
		expect(plain:FindFirstChild("Hair")).toBeNil()
		local head = child(plain, "Head")
		expect(head.ClassName).toBe("Part")
		expect((head :: Part).Shape).toBe(Enum.PartType.Block)
		expect((head.Size - Vector3.new(1.45, 1.6, 1.45)).Magnitude).toBeLessThan(1e-4) -- float32 sizes
		expect(head.Material).toBe(Enum.Material.Metal)
		expect(plain:GetAttribute("KitLook")).toBe(Kit.lookKey(nil))
		local sig = signature(plain)
		for _, bad in { "", "Crimson", "purple", "neutral", "crest_spire", 42, true, {} } do
			local rig = Kit.character("soldier", "soldier", CRIMSON, nil, bad :: any)
			expect(signature(rig)).toBe(sig)
			expect(rig:GetAttribute("KitLook")).toBe(Kit.lookKey(nil))
		end
		expect(signature(Kit.character("soldier", "soldier", CRIMSON, nil, nil))).toBe(sig)
	end)

	it("leaves citizens and governors unchanged by the kingdom", function()
		local looks: { any } = { nil, { skin = 3, hair = 5, hairColor = 2, outfit = 4 }, { hair = 2 } }
		for _, kind in { "citizen", "governor" } do
			for _, job in { "idle", "farmer", "woodcutter", "miner", "builder", "hauler" } do
				for i = 1, 3 do
					local look = looks[i]
					local base = Kit.character(kind, job, CRIMSON, look)
					for _, kingdom in KINGDOM_IDS do
						local rig = Kit.character(kind, job, CRIMSON, look, kingdom)
						expect(signature(rig)).toBe(signature(base))
						expect(crestOf(rig)).toBeNil()
						expect(rig:GetAttribute("KitLook")).toBe(base:GetAttribute("KitLook"))
						local hair = rig:FindFirstChild("Hair")
						expect(if hair then hair:GetAttribute("KitHeadwear") else nil).toBe(
							if base:FindFirstChild("Hair")
								then (base:FindFirstChild("Hair") :: Instance):GetAttribute("KitHeadwear")
								else nil
						)
					end
				end
			end
		end
	end)

	it("puts the kingdom in the soldier pool key, since recolouring cannot change a crest", function()
		local look = { skin = 2, hair = 3, hairColor = 4, outfit = 5 }
		expect(Kit.lookKey(look)).toBe("2.3.4.5") -- unchanged without a kingdom
		expect(Kit.lookKey(look, "bogus")).toBe("2.3.4.5")
		local keys = {}
		for _, kingdom in KINGDOM_IDS do
			local key = Kit.lookKey(look, kingdom)
			expect(key).toBe(`2.3.4.5.{kingdom}`)
			expect(keys[key]).toBeNil()
			keys[key] = true
			local rig = Kit.character("soldier", "soldier", KINGDOM_COLORS[kingdom], look, kingdom)
			expect(rig:GetAttribute("KitLook")).toBe(key)
		end
		-- two soldiers of different kingdoms never share a key, and a pooled crimson soldier recoloured
		-- azure is still not an azure soldier
		local crimson = Kit.character("soldier", "soldier", CRIMSON, nil, "crimson")
		local azure = Kit.character("soldier", "soldier", AZURE, nil, "azure")
		expect(crimson:GetAttribute("KitLook") ~= azure:GetAttribute("KitLook")).toBe(true)
		Kit.setKingdomColor(crimson, AZURE)
		expect(signature(crimson) ~= signature(azure)).toBe(true)
	end)
end)

describe("Character.lod (one-part stand-in beyond 150 studs)", function()
	it("is one anchored, non-colliding, kingdom-tinted part with the rig's Root height (3.2) and pivot", function()
		expect(Kit.characterLod).toBe(Character.lod)
		for _, kind in KINDS do
			local m = noYield(function()
				return Kit.characterLod(kind, AZURE)
			end)
			local ps = parts(m)
			expect(#ps).toBe(1)
			local p = ps[1]
			expect(m.PrimaryPart).toBe(p)
			expect(p.Anchored).toBe(true)
			expect(p.CanCollide or p.CanTouch or p.CanQuery).toBe(false)
			expect(p:GetAttribute("KitTint")).never.toBeNil()
			local mn, mx = bounds(p)
			expect(mn.Y).toBeNear(0, 1e-3) -- feet on the ground, centre at the rig's Root height
			expect(mx.Y).toBeNear(2 * Kit.CHARACTER_ROOT_HEIGHT, 1e-3)
			expect(pos(p).Y).toBeNear(Kit.CHARACTER_ROOT_HEIGHT, 1e-4)
			expect(p.CFrame.UpVector.Y).toBeNear(1, 1e-6)
			expect(m:GetAttribute("KitRootHeight")).toBe(Kit.CHARACTER_ROOT_HEIGHT)
			expect((p.CFrame * p.PivotOffset).Position.Y).toBeNear(0, 1e-6)
			Kit.setKingdomColor(m, GOLD)
			expect(p.Color:ToHex()).toBe((Character.lod(kind, GOLD).PrimaryPart :: BasePart).Color:ToHex())
		end
	end)
end)

-- Stand-in R15 and R6 avatars: attachment names as Roblox rigs carry them, approximate positions.
local function avatar(rigType: string): (Model, { [string]: Attachment }, { [string]: BasePart })
	local m = Instance.new("Model")
	local atts: { [string]: Attachment } = {}
	local byRole: { [string]: BasePart } = {}
	local function part(name: string, role: string?, size: Vector3, at: Vector3): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = CFrame.new(at)
		p.Parent = m
		if role then
			byRole[role] = p
		end
		return p
	end
	local function att(p: Part, name: string, at: Vector3)
		local a = Instance.new("Attachment")
		a.Name = name
		a.CFrame = CFrame.new(at)
		a.Parent = p
		atts[name] = a
	end
	if rigType == "R15" then
		local upper = part("UpperTorso", "torso", Vector3.new(2, 1.6, 1), Vector3.new(0, 3.2, 0))
		part("LowerTorso", nil, Vector3.new(2, 0.4, 1), Vector3.new(0, 2.2, 0))
		local head = part("Head", "head", Vector3.new(1.2, 1.2, 1.2), Vector3.new(0, 4.6, 0))
		att(upper, "BodyBackAttachment", Vector3.new(0, 0.2, 0.5))
		att(head, "HatAttachment", Vector3.new(0, 0.6, 0))
	else
		local torso = part("Torso", "torso", Vector3.new(2, 2, 1), Vector3.new(0, 3, 0))
		local head = part("Head", "head", Vector3.new(2, 1, 1), Vector3.new(0, 4.5, 0))
		att(torso, "BodyBackAttachment", Vector3.new(0, 0, 0.5))
		att(head, "HatAttachment", Vector3.new(0, 0.6, 0))
	end
	return m, atts, byRole
end

-- Humanoid:AddAccessory: Handle.CFrame = body attachment (world) * accessory attachment:Inverse(); welded parts follow.
local function wear(acc: Accessory, atts: { [string]: Attachment }): string?
	local handle = acc:FindFirstChild("Handle") :: BasePart
	for _, a in handle:GetChildren() do
		if a:IsA("Attachment") and atts[a.Name] then
			local body = atts[a.Name]
			local target = (body.Parent :: BasePart).CFrame * body.CFrame * a.CFrame:Inverse()
			local delta = target * handle.CFrame:Inverse()
			for _, p in acc:GetDescendants() do
				if p:IsA("BasePart") and p ~= handle then
					p.CFrame = delta * p.CFrame
				end
			end
			handle.CFrame = target
			return a.Name
		end
	end
	return nil
end

describe("Kit.regalia (crown + cape, R15 and R6)", function()
	it("builds a crown on HatAttachment and a cape on BodyBackAttachment with welded, non-colliding parts", function()
		local acc = noYield(function()
			return Kit.regalia(CRIMSON)
		end)
		expect(#acc).toBe(2)
		local want = { KitCrown = "HatAttachment", KitCape = "BodyBackAttachment" }
		for _, a in acc do
			expect(a.ClassName).toBe("Accessory")
			local handle = a:FindFirstChild("Handle") :: BasePart
			expect(handle).never.toBeNil()
			expect(handle:FindFirstChild(want[a.Name])).never.toBeNil()
			expect(handle:FindFirstChild(want[a.Name]):IsA("Attachment")).toBe(true)
			local tinted = 0
			for _, p in parts(a) do
				expect(p.Anchored).toBe(false)
				expect(p.CanCollide or p.CanTouch or p.CanQuery).toBe(false)
				expect(p.Massless).toBe(true)
				if p ~= handle then
					local w = p:FindFirstChildOfClass("WeldConstraint")
					expect(w).never.toBeNil()
					expect((w :: WeldConstraint).Part0).toBe(handle)
					expect((w :: WeldConstraint).Part1).toBe(p)
				end
				if p:GetAttribute("KitTint") then
					tinted += 1
				end
			end
			expect(tinted).toBeGreaterThanOrEqual(1)
			expect(#parts(a)).toBeLessThanOrEqual(10)
		end
	end)

	for _, rigType in { "R15", "R6" } do
		it(`fits a {rigType} avatar: crown on top of the head, cape hanging behind the back`, function()
			local _, atts, body = avatar(rigType)
			local acc = Kit.regalia(AZURE)
			local used = {}
			for _, a in acc do
				used[a.Name] = wear(a, atts)
			end
			expect(used.KitCrown).toBe("HatAttachment")
			expect(used.KitCape).toBe("BodyBackAttachment")

			local head = body.head
			local headTop = pos(head).Y + 0.6 -- the HatAttachment height
			local crown = acc[1]
			local band = crown:FindFirstChild("Handle") :: BasePart
			local bandMin, bandMax = bounds(band)
			expect(bandMin.Y).toBeGreaterThan(headTop - 0.35)
			expect(bandMin.Y).toBeLessThan(headTop + 0.05)
			expect(pos(band).X).toBeNear(pos(head).X, 1e-3)
			expect(pos(band).Z).toBeNear(pos(head).Z, 1e-3)
			expect(bandMax.X - bandMin.X).toBeGreaterThan(1.25) -- wider than the head, so it rests on it
			local _, crownMax = modelBounds(parts(crown))
			expect(crownMax.Y).toBeLessThan(headTop + 1.2)

			local torso = body.torso
			local back = pos(torso).Z + torso.Size.Z / 2
			local shoulders = pos(torso).Y + torso.Size.Y / 2
			local capeMin, capeMax = modelBounds(parts(acc[2]))
			expect(capeMin.Z).toBeGreaterThan(back - 0.1) -- behind the back, not through the torso
			expect(capeMax.Z).toBeLessThan(back + 1.2)
			expect(capeMax.Y).toBeGreaterThan(shoulders - 0.3)
			expect(capeMax.Y).toBeLessThan(shoulders + 0.45)
			expect(capeMin.Y).toBeGreaterThan(0.3) -- clears the ground
			expect(capeMin.Y).toBeLessThan(2.0) -- reaches below the hips
			expect(capeMax.X - capeMin.X).toBeGreaterThan(torso.Size.X)
			expect(capeMax.X - capeMin.X).toBeLessThan(torso.Size.X + 1)
		end)
	end
end)
