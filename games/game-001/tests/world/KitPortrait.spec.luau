--[[
	Kit.portrait (FL-0098; CONTRACTS G13.8, D-036): the world rig of Kit.character, anchored for a UI
	ViewportFrame, with a PortraitFocus camera framing head and shoulders, and Kit.posePortrait for reaction
	poses. The portrait and the world rig must look identical, so every case is compared part for part.
]]

local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local Kit = require("@game/ReplicatedStorage/Game/Kit/Kit")
local Pose = require("@game/ReplicatedStorage/Game/Sim/Pose")

local IDS = { "crimson", "azure", "emerald", "gold" }
local COLORS = { -- config/Kingdoms.luau (D-033)
	crimson = Color3.fromRGB(190, 40, 50),
	azure = Color3.fromRGB(40, 110, 210),
	emerald = Color3.fromRGB(35, 128, 95),
	gold = Color3.fromRGB(235, 185, 16),
}
local CITIZEN_JOBS = { "idle", "farmer", "woodcutter", "miner", "builder", "hauler" }
local R = Kit.LOOK_RANGES

-- deterministic looks from a seed (Park–Miller), like a generated population
local function seededLook(seed: number): { [string]: number }
	local s = seed
	local function roll(n: number): number
		s = (s * 16807) % 2147483647
		return s % n + 1
	end
	return { skin = roll(R.skin), hair = roll(R.hair), hairColor = roll(R.hairColor), outfit = roll(R.outfit) }
end

type Case = { kind: string, job: string, color: Color3, look: any, kingdom: string?, label: string }

local function cases(): { Case }
	local out: { Case } = {}
	local function add(kind: string, job: string, id: string, look: any, kingdom: string?)
		table.insert(out, {
			kind = kind,
			job = job,
			color = COLORS[id],
			look = look,
			kingdom = kingdom,
			label = `{kind} {job} {id} {if look then Kit.lookKey(look) else "default"} {kingdom or "-"}`,
		})
	end
	for seed = 1, 8 do
		local look = seededLook(seed)
		local id = IDS[(seed - 1) % #IDS + 1]
		for _, job in CITIZEN_JOBS do
			add("citizen", job, id, look, if seed % 2 == 0 then id else nil) -- citizens ignore the kingdom
		end
		add("governor", "idle", id, look, id)
	end
	for i, id in IDS do
		add("soldier", "soldier", id, nil, id) -- each kingdom's crest
		add("citizen", "soldier", id, seededLook(100 + i), id) -- drafted citizen
	end
	add("soldier", "soldier", "crimson", nil, nil) -- plain helm
	add("citizen", "farmer", "azure", nil, nil) -- default look
	for hair = 1, R.hair do -- every headwear style
		add("citizen", "builder", "gold", { skin = 1, hair = hair, hairColor = 1, outfit = 1 }, nil)
	end
	return out
end

local function build(c: Case): (Model, Model)
	return Kit.character(c.kind, c.job, c.color, c.look, c.kingdom),
		Kit.portrait(c.kind, c.job, c.color, c.look, c.kingdom)
end

local function byName(model: Model): { [string]: BasePart }
	local out = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			assert(out[d.Name] == nil, `duplicate part {d.Name}`)
			out[d.Name] = d
		end
	end
	return out
end

local function count(t: { [any]: any }): number
	local n = 0
	for _ in t do
		n += 1
	end
	return n
end

local function near(a: CFrame, b: CFrame, eps: number): boolean
	local ca, cb = { a:GetComponents() }, { b:GetComponents() }
	for i = 1, 12 do
		if math.abs(ca[i] - cb[i]) > eps then
			return false
		end
	end
	return true
end

-- every non-part instance as "class name < parent", PortraitFocus excluded
local function structure(model: Model): { string }
	local rows = {}
	for _, d in model:GetDescendants() do
		if d.Name ~= "PortraitFocus" then
			table.insert(rows, `{d.ClassName} {d.Name} < {(d.Parent :: Instance).Name}`)
		end
	end
	table.sort(rows)
	return rows
end

local function corners(p: BasePart): { Vector3 }
	local out = {}
	local h = p.Size / 2
	for _, sx in { -1, 1 } do
		for _, sy in { -1, 1 } do
			for _, sz in { -1, 1 } do
				table.insert(out, p.CFrame * Vector3.new(sx * h.X, sy * h.Y, sz * h.Z))
			end
		end
	end
	return out
end

-- screen position of a world point for a square view: (x, y) in [-1, 1] when visible, and the depth
local function project(cam: CFrame, fov: number, w: Vector3): (number, number, number)
	local p = cam:PointToObjectSpace(w)
	local depth = -p.Z
	local t = math.tan(math.rad(fov) / 2)
	return p.X / (depth * t), p.Y / (depth * t), depth
end

local function snapshot(model: Model): { [BasePart]: CFrame }
	local out = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			out[d] = d.CFrame
		end
	end
	return out
end

-- Forward kinematics as the engine does it (an independent copy of KitCharacter.spec's): Part1 = Part0 * C0 *
-- Transform * C1:Inverse(); welds follow.
local function engineFK(rig: Model, joints: { [string]: CFrame }): { [BasePart]: CFrame }
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

describe("Kit.portrait (CONTRACTS G13.8, D-036)", function()
	it("is Kit.character's rig for the same arguments, part for part", function()
		local n = 0
		for _, c in cases() do
			local char, portrait = build(c)
			local a, b = byName(char), byName(portrait)
			expect(count(b)).toBe(count(a))
			expect(count(b)).toBeLessThanOrEqual(9)
			local headA, headB = a.Head, b.Head
			for name, pa in a do
				local pb = b[name]
				assert(pb, `{c.label}: portrait has no {name}`)
				expect(pb.ClassName).toBe(pa.ClassName)
				if pa:IsA("Part") then
					expect((pb :: Part).Shape).toBe(pa.Shape)
				end
				expect(pb.Size).toEqual(pa.Size)
				expect(pb.Color:ToHex()).toBe(pa.Color:ToHex())
				expect(pb.Material).toBe(pa.Material)
				expect(pb.Transparency).toBe(pa.Transparency)
				expect(pb.CastShadow).toBe(pa.CastShadow)
				expect(pb.CanCollide or pb.CanTouch or pb.CanQuery).toBe(false)
				expect(pb:GetAttributes()).toEqual(pa:GetAttributes()) -- KitTint, KitHeadwear, KitTool
				expect(near(pb.CFrame, pa.CFrame, 1e-5)).toBe(true)
				expect(near(headB.CFrame:ToObjectSpace(pb.CFrame), headA.CFrame:ToObjectSpace(pa.CFrame), 1e-5)).toBe(
					true
				)
			end
			-- model attributes (KitKind, KitJob, KitLook, KitRootHeight), plus KitPortrait
			local attrs = char:GetAttributes()
			attrs.KitPortrait = true
			expect(portrait:GetAttributes()).toEqual(attrs)
			expect((portrait.PrimaryPart :: BasePart).Name).toBe("Root")
			expect(
				near((portrait.PrimaryPart :: BasePart).PivotOffset, (char.PrimaryPart :: BasePart).PivotOffset, 1e-6)
			).toBe(true)
			-- the same joints, weld and face decal, nothing else but the focus
			expect(structure(portrait)).toEqual(structure(char))
			local joints = {}
			for _, d in char:GetDescendants() do
				if d:IsA("Motor6D") or d:IsA("Weld") then
					joints[`{d.ClassName}:{d.Name}`] = d
				end
			end
			for _, d in portrait:GetDescendants() do
				if d:IsA("Motor6D") or d:IsA("Weld") then
					local j = joints[`{d.ClassName}:{d.Name}`]
					expect(j).never.toBeNil()
					expect((d.Part0 :: BasePart).Name).toBe((j.Part0 :: BasePart).Name)
					expect((d.Part1 :: BasePart).Name).toBe((j.Part1 :: BasePart).Name)
					expect(near(d.C0, j.C0, 1e-6) and near(d.C1, j.C1, 1e-6)).toBe(true)
				end
			end
			n += 1
		end
		expect(n).toBeGreaterThan(70)
	end)

	it("anchors every part and holds its pose without physics: no scripts, no Humanoid, motors kept", function()
		for _, c in cases() do
			local portrait = Kit.portrait(c.kind, c.job, c.color, c.look, c.kingdom)
			local nParts, nMotors, nWelds = 0, 0, 0
			for _, d in portrait:GetDescendants() do
				if d:IsA("BasePart") then
					nParts += 1
					expect(d.Anchored).toBe(true)
				elseif d:IsA("Motor6D") then
					nMotors += 1
				elseif d:IsA("Weld") then
					nWelds += 1
				end
				expect(d:IsA("LuaSourceContainer") or d:IsA("Humanoid") or d:IsA("Animator")).toBe(false)
			end
			expect(nMotors).toBe(nParts - 1 - nWelds) -- every part but the Root hangs off a joint
			expect(portrait:GetAttribute("KitPortrait")).toBe(true)
		end
	end)

	it("frames head, headwear and shoulders from the front at PortraitFov, with the focus as the camera", function()
		expect(Kit.PORTRAIT_FOV).toBe(30)
		local faceShare = math.huge
		for _, c in cases() do
			local portrait = Kit.portrait(c.kind, c.job, c.color, c.look, c.kingdom)
			local root = portrait.PrimaryPart :: BasePart
			local focus = root:FindFirstChild("PortraitFocus") :: Attachment
			assert(focus and focus:IsA("Attachment"), `{c.label}: no PortraitFocus attachment on the Root`)
			expect(focus:GetAttribute("PortraitFov")).toBe(Kit.PORTRAIT_FOV)
			local dist = focus:GetAttribute("PortraitDistance") :: number
			expect(type(dist)).toBe("number")
			local cam, fov = Kit.portraitCamera(portrait)
			expect(fov).toBe(Kit.PORTRAIT_FOV)
			expect(near(cam, root.CFrame * focus.CFrame, 1e-6)).toBe(true)
			-- in front of the face, looking at it (the rig faces -Z), level or slightly down, upright
			local parts = byName(portrait)
			local head, torso = parts.Head, parts.Torso
			expect(cam.LookVector.Z).toBeGreaterThan(0.95)
			expect(cam.LookVector.Y).toBeLessThanOrEqual(0)
			expect(cam.UpVector.Y).toBeGreaterThan(0.95)
			expect(cam.Position.Z).toBeLessThan(head.CFrame.Position.Z - head.Size.Z / 2 - 3)
			-- the head centre is near the middle of the frame, the framed centre PortraitDistance ahead
			local hx, hy = project(cam, fov, head.CFrame.Position)
			expect(math.abs(hx)).toBeLessThan(0.1)
			expect(math.abs(hy)).toBeLessThan(0.6)
			local centre = cam.Position + cam.LookVector * dist
			expect(math.abs(centre.X - root.CFrame.Position.X)).toBeLessThan(1e-3)
			-- head and headwear (crest, hat, crown) entirely in view
			local top = -math.huge
			for _, name in { "Head", "Hair" } do
				local p = parts[name]
				if p then
					for _, w in corners(p) do
						local x, y, depth = project(cam, fov, w)
						expect(depth).toBeGreaterThan(0)
						expect(math.abs(x)).toBeLessThanOrEqual(0.95)
						expect(math.abs(y)).toBeLessThanOrEqual(1)
						top = math.max(top, y)
					end
				end
			end
			-- headroom: nothing touches the top edge, and not much empty space above the head either
			expect(top).toBeLessThan(0.92)
			expect(top).toBeGreaterThan(0.6)
			-- shoulders: the torso's top corners and the tops of both arms are in view
			local torsoTop = torso.CFrame.Position.Y + torso.Size.Y / 2
			for _, w in
				{
					Vector3.new(-torso.Size.X / 2, torsoTop, -torso.Size.Z / 2),
					Vector3.new(torso.Size.X / 2, torsoTop, -torso.Size.Z / 2),
					parts.LeftArm.CFrame * Vector3.new(0, parts.LeftArm.Size.Y / 2, 0),
					parts.RightArm.CFrame * Vector3.new(0, parts.RightArm.Size.Y / 2, 0),
				}
			do
				local x, y = project(cam, fov, w)
				expect(math.abs(x)).toBeLessThanOrEqual(1)
				expect(math.abs(y)).toBeLessThanOrEqual(1)
			end
			-- a portrait, not a full figure: the feet are out of view and the head fills a good share
			local _, feetY = project(cam, fov, Vector3.new(0, 0.3, 0))
			expect(feetY).toBeLessThan(-1)
			local _, headTop = project(cam, fov, head.CFrame.Position + Vector3.new(0, head.Size.Y / 2, 0))
			local _, headBottom = project(cam, fov, head.CFrame.Position - Vector3.new(0, head.Size.Y / 2, 0))
			local share = (headTop - headBottom) / 2
			faceShare = math.min(faceShare, share)
		end
		expect(faceShare).toBeGreaterThan(0.25)
	end)

	it("keeps the camera with the portrait when the model is moved", function()
		local portrait = Kit.portrait("soldier", "soldier", COLORS.gold, nil, "gold")
		local before = Kit.portraitCamera(portrait)
		local move = CFrame.new(12, 4, -30) * CFrame.Angles(0, math.rad(130), 0)
		for _, d in portrait:GetDescendants() do
			if d:IsA("BasePart") then
				d.CFrame = move * d.CFrame
			end
		end
		expect(near(Kit.portraitCamera(portrait), move * before, 1e-4)).toBe(true)
		local plain = Kit.character("soldier", "soldier", COLORS.gold, nil, "gold")
		expect(pcall(Kit.portraitCamera, plain)).toBe(false) -- a world rig has no focus
	end)
end)

describe("Kit.posePortrait (reaction poses on an anchored portrait)", function()
	it("places the parts through the rig's motors like the engine, absolute and restorable, camera steady", function()
		for _, c in cases() do
			local portrait = Kit.portrait(c.kind, c.job, c.color, c.look, c.kingdom)
			local rest = snapshot(portrait)
			local camRest = Kit.portraitCamera(portrait)
			local parts = byName(portrait)
			for _, sample in
				{
					Pose.sample("walk", c.job, 0.25, 12),
					Pose.sample("dead", c.job, 0, 0),
					Pose.sample("work", c.job, 0.4, 0),
				}
			do
				local expected = engineFK(portrait, sample)
				Kit.posePortrait(portrait, sample)
				Kit.posePortrait(portrait, sample) -- twice: absolute, not cumulative
				for part, cf in expected do
					expect(near(part.CFrame, cf, 1e-4)).toBe(true)
					expect(part.Anchored).toBe(true)
				end
				expect(count(expected)).toBe(count(rest)) -- every part reached, the Hair through its weld
				expect(near(parts.Root.CFrame, rest[parts.Root], 1e-6)).toBe(true)
				expect(near(Kit.portraitCamera(portrait), camRest, 1e-6)).toBe(true)
				local hair = parts.Hair
				if hair then
					local keep = rest[parts.Head]:ToObjectSpace(rest[hair])
					expect(near(parts.Head.CFrame:ToObjectSpace(hair.CFrame), keep, 1e-4)).toBe(true)
				end
			end
			Kit.posePortrait(portrait, {})
			for part, cf in rest do
				expect(near(part.CFrame, cf, 1e-4)).toBe(true)
			end
		end
		-- the dead pose visibly moves the head (the pose really drives the anchored parts)
		local p = Kit.portrait("citizen", "farmer", COLORS.azure)
		local headY = (p:FindFirstChild("Head") :: BasePart).CFrame.Position.Y
		Kit.posePortrait(p, Pose.sample("dead", "farmer", 0, 0))
		expect((p:FindFirstChild("Head") :: BasePart).CFrame.Position.Y).toBeLessThan(headY - 2.5)
	end)
end)
