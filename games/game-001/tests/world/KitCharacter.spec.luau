--[[
	Kit characters, looks and regalia (FL-0056, FL-0085; CONTRACTS G4 rendering, G10, G13.2; D-026, D-032):
	≤ 9-part rigs with an invisible anchored Root, Motor6Ds named after the moving part and matching
	Sim/Pose.JOINTS (Torso: Root → Torso at the hips), Hair welded to the Head, joint pivots where Pose expects
	them, a tool per job, citizen looks that are deterministic and never error, kingdom recolouring of pooled
	rigs, the one-part far LOD, regalia that fit R15 and R6 avatars, and a Pose smoke test (walk and death fall).
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
local R = Kit.LOOK_RANGES

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

local function each(fn: (kind: string, job: string, rig: Model, look: Character.CitizenLook?) -> ())
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

describe("Kit.character rig (CONTRACTS G4, G10, D-026, D-032)", function()
	it("has ≤ 9 non-colliding, massless parts, only the Root anchored, no Humanoid or Animator", function()
		each(function(kind, job, rig, look)
			local ps = parts(rig)
			local hasTool = rig:FindFirstChild("Tool") ~= nil
			local hasHair = rig:FindFirstChild("Hair") ~= nil
			expect(hasTool).toBe(not (kind == "citizen" and job == "idle"))
			expect(#ps).toBe(7 + (if hasTool then 1 else 0) + (if hasHair then 1 else 0))
			expect(#ps).toBeLessThanOrEqual(9)
			-- soldiers: the helm is the Head (8 parts); governors: crown (9); citizens: per hair style
			expect(hasHair).toBe(
				if kind == "governor"
					then true
					elseif kind == "soldier" or job == "soldier" then false
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
					expect(d.Name).toBe("HairWeld")
				end
			end
		end)
	end)

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
				expect(seen[p.Name] == true).toBe(p ~= rig.PrimaryPart and p.Name ~= "Hair")
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

	it("stands about 5.5 studs tall with the feet on y = 0 (tool excluded), for every look", function()
		each(function(_, _, rig)
			local body = {}
			for _, p in parts(rig) do
				if p.Name ~= "Tool" and p ~= rig.PrimaryPart then
					table.insert(body, p)
				end
			end
			local mn, mx = modelBounds(body)
			expect(mn.Y).toBeNear(0, 1e-3)
			expect(mx.Y).toBeNear(5.5, 0.25)
			expect(mx.X - mn.X).toBeLessThan(4.5)
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
				expect(math.abs(shoulder.X)).toBeNear(torso.Size.X / 2, 1e-3)
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
		each(function(kind, job, rig, look)
			Kit.setKingdomColor(rig, GOLD)
			expect(signature(rig)).toBe(signature(Kit.character(kind, job, GOLD, look)))
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
			local seen = {}
			for i = 1, n do
				local look = table.clone(base)
				look[axis] = i
				local sig = signature(Kit.character("citizen", "farmer", CRIMSON, look :: any))
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
			expect(#parts(rig)).toBeLessThanOrEqual(9)
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
