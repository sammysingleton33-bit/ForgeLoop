--!nonstrict
--[[
	Mesh rigs under Sim/Pose and in the portrait (FL-0135, D-057): the segmented MeshPart rig of Kit/CharacterMesh must be
	animated by the unchanged procedural poses (FORGE-04) and framed by the unchanged Kit.portrait. HEADLESS and by
	BOUNDING BOX: a MeshPart is its bbox_center/size box here (like KitCharacter.spec's and PoseClearance's boxes for Wedge and
	Block parts), so a leaning tool is measured fatter than its mesh. Clearance numbers are conservative, never visual
	evidence. Runs on the placeholder kit and on the committed kit once it has pieces (see KitCharacterMesh.spec).

	Covers: forward kinematics through the rig's own motors (every action), the death fall, joints moving only their own
	parts; the tool and the head: the PoseClearance rules (>= 0.1 between a posed hand tool and the head, and no closer to the
	headwear than at rest) over every Pose action; Kit.portrait on a mesh rig (anchored, motors kept, PortraitFocus framing,
	Kit.posePortrait).
]]

local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect, afterEach = T.describe, T.it, T.expect, T.afterEach

local CharacterMesh = require("@game/ReplicatedStorage/Game/Kit/CharacterMesh")
local CommittedData = require("@game/ReplicatedStorage/Game/Kit/CharacterMeshData")
local Kit = require("@game/ReplicatedStorage/Game/Kit/Kit")
local Pose = require("@game/ReplicatedStorage/Game/Sim/Pose")

local MeshKit = require("./fixtures/CharacterMeshKit")

local AZURE = MeshKit.AZURE
local ACTIONS = { "idle", "walk", "carry", "work", "fight", "celebrate", "flee" }
local STEPS = 40 -- samples per cycle
local MIN_CLEARANCE = 0.1 -- studs of free space a posed hand tool keeps from the head (PoseClearance.spec)

afterEach(function()
	MeshKit.uninstall()
end)

local datasets: { { name: string, data: any } } = { { name = "placeholder kit", data = MeshKit.fixture() } }
if next(CommittedData.pieces) ~= nil then
	table.insert(datasets, { name = "committed kit", data = CommittedData })
end

local function meshRig(kind: string, job: string, color: Color3?, look: any?, kingdom: string?): Model
	local rig = Kit.character(kind, job, color or AZURE, look, kingdom)
	assert(
		rig:GetAttribute("KitMesh") == true,
		`{kind}/{job} fell back: {tostring(CharacterMesh.status().lastFallback)}`
	)
	return rig
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

-- the sampling Pose uses for an action: walking-like actions at full speed
local function sample(action: string, job: string, step: number, out: { [string]: CFrame }?)
	return Pose.sample(
		action,
		job,
		step / STEPS,
		if action == "walk" or action == "carry" or action == "flee" then 12 else 0,
		out
	)
end

for _, ds in datasets do
	local data = ds.data

	describe(`mesh rig under Sim/Pose ({ds.name})`, function()
		local assets = MeshKit.assets(data)

		it(
			"places every part through the rig's own motors: walk moves head and legs, rest is the built pose",
			function()
				MeshKit.install(data, assets)
				for _, c in MeshKit.cases() do
					local rig = meshRig(c.kind, c.job, c.color, c.look, c.kingdom)
					local head, leg = MeshKit.child(rig, "Head"), MeshKit.child(rig, "LeftLeg")
					local rest = MeshKit.posed(rig, {})
					for _, p in MeshKit.parts(rig) do
						expect(near(rest[p], p.CFrame, 1e-4)).toBe(true) -- the template is posed as built
					end
					local walk = MeshKit.posed(rig, Pose.sample("walk", c.job, 0.25, 12))
					expect((walk[head].Position - head.CFrame.Position).Magnitude).toBeGreaterThan(0.05)
					expect(math.abs(walk[leg].Position.Z - leg.CFrame.Position.Z)).toBeGreaterThan(0.3)
					for _, p in MeshKit.parts(rig) do
						expect(walk[p]).never.toBeNil() -- every part is reached by a motor or a weld
					end
				end
			end
		)

		it("lays the body down in the death fall with hair, hats and welded extras attached", function()
			MeshKit.install(data, assets)
			for _, c in MeshKit.cases() do
				local rig = meshRig(c.kind, c.job, c.color, c.look, c.kingdom)
				local head, torso = MeshKit.child(rig, "Head"), MeshKit.child(rig, "Torso")
				local dead = MeshKit.posed(rig, Pose.sample("dead", c.job, 0, 0))
				expect(dead[head].Position.Y).toBeLessThan(head.CFrame.Position.Y - 2.5)
				expect(math.abs(dead[torso].UpVector.Y)).toBeLessThan(0.05) -- lying flat
				local lowest = math.huge
				for _, corner in MeshKit.corners(torso, dead[torso]) do
					lowest = math.min(lowest, corner.Y)
				end
				expect(lowest).toBeGreaterThan(-0.25) -- on the ground, not sunk into it
				-- everything welded to the head stays where it was on it
				for _, p in MeshKit.assembly(rig, head) do
					local keep = head.CFrame:ToObjectSpace(p.CFrame)
					local now = dead[head]:ToObjectSpace(dead[p])
					expect((keep.Position - now.Position).Magnitude).toBeLessThan(1e-3)
				end
			end
		end)

		it("moves only its own parts: a joint's piece and what is welded to it, nothing else", function()
			MeshKit.install(data, assets)
			local rig = meshRig("citizen", "farmer", AZURE, MeshKit.seededLook(4))
			local rest = MeshKit.posed(rig, {})
			for _, joint in { "Head", "LeftArm", "RightArm", "LeftLeg", "RightLeg", "Tool" } do
				local base = MeshKit.child(rig, joint)
				local mine = {}
				for _, p in MeshKit.assembly(rig, base) do
					mine[p] = true
				end
				if joint == "RightArm" then
					for _, p in MeshKit.assembly(rig, MeshKit.child(rig, "Tool")) do
						mine[p] = true -- the Tool joint hangs off the RightArm
					end
				end
				local moved = MeshKit.posed(rig, { [joint] = CFrame.Angles(math.rad(50), 0, 0) })
				for p, cf in moved do
					local changed = not near(cf, rest[p], 1e-4)
					expect(changed).toBe(mine[p] == true)
				end
			end
		end)

		it("keeps every joint within the limits Pose sets, and the Motor6D names equal Pose.JOINTS", function()
			MeshKit.install(data, assets)
			local rig = meshRig("citizen", "miner", AZURE, nil)
			local names = {}
			for _, m in MeshKit.motors(rig) do
				names[m.Name] = true
			end
			for _, joint in Pose.JOINTS do
				expect(names[joint]).toBe(true) -- a miner carries a tool: all seven joints
			end
			for _, action in ACTIONS do
				for step = 0, STEPS - 1 do
					for joint, cf in sample(action, "miner", step) do
						local x, y, z = cf:ToEulerAnglesXYZ()
						local limit = math.rad(Pose.LIMITS[joint]) + 1e-6
						expect(math.max(math.abs(x), math.abs(y), math.abs(z)) <= limit).toBe(true)
					end
				end
			end
		end)
	end)

	describe(`mesh rig clearance ({ds.name}): hand tools keep clear of the head (bounding boxes)`, function()
		local assets = MeshKit.assets(data)

		-- smallest box-to-box distance between the tool assembly and the Head, and the headwear (every other part welded to it)
		local function worst(rig: Model, job: string, action: string): (number, number)
			local tool = rig:FindFirstChild("Tool") :: BasePart?
			if tool == nil then
				return math.huge, math.huge
			end
			local head = MeshKit.child(rig, "Head")
			local toolParts = MeshKit.assembly(rig, tool)
			local hatParts = MeshKit.assembly(rig, head)
			table.remove(hatParts, 1)
			local lowHead, lowHat = math.huge, math.huge
			local joints: { [string]: CFrame } = {}
			for step = 0, STEPS - 1 do
				sample(action, job, step, joints)
				local world = MeshKit.posed(rig, joints)
				for _, t in toolParts do
					lowHead = math.min(lowHead, MeshKit.boxBox(world[t], t.Size, world[head], head.Size))
					for _, hat in hatParts do
						lowHat = math.min(lowHat, MeshKit.boxBox(world[t], t.Size, world[hat], hat.Size))
					end
				end
			end
			return lowHead, lowHat
		end

		-- rigs with a tool in the right fist (the hauler's sack hangs from the torso and is not one)
		local function handToolRigs(): { { label: string, rig: Model, job: string } }
			local out = {}
			local function add(kind: string, job: string, look: any, kingdom: string?)
				local color = if kingdom then MeshKit.KINGDOM_COLORS[kingdom] else AZURE
				local rig = meshRig(kind, job, color, look, kingdom)
				local tool = rig:FindFirstChild("Tool") :: BasePart?
				if tool and (MeshKit.motorOf(rig, "Tool").Part0 :: BasePart).Name == "RightArm" then
					table.insert(out, { label = `{kind}/{job} {Kit.lookKey(look, kingdom)}`, rig = rig, job = job })
				end
			end
			for _, job in { "farmer", "woodcutter", "miner", "builder" } do
				add("citizen", job, nil, nil)
				for seed = 1, 6 do -- hat variants follow the look
					add("citizen", job, MeshKit.seededLook(seed), nil)
				end
			end
			for _, id in MeshKit.KINGDOM_IDS do
				add("soldier", "soldier", nil, id)
				add("soldier", "soldier", MeshKit.seededLook(7), id)
				add("governor", "governor", nil, id)
			end
			return out
		end

		it("finds hand tools to measure on this kit (the check is not vacuous)", function()
			MeshKit.install(data, assets)
			local rigs = handToolRigs()
			expect(#rigs).toBeGreaterThanOrEqual(10)
			local head = worst(rigs[1].rig, rigs[1].job, "celebrate")
			expect(head < math.huge).toBe(true)
			expect(head == head).toBe(true)
		end)

		it(
			"keeps every posed tool 0.1 from the head, and no closer to the headwear than at rest, in every action",
			function()
				MeshKit.install(data, assets)
				for _, entry in handToolRigs() do
					local _, idleHat = worst(entry.rig, entry.job, "idle")
					local floor = math.min(MIN_CLEARANCE, idleHat)
					for _, action in ACTIONS do
						local head, hat = worst(entry.rig, entry.job, action)
						if head < MIN_CLEARANCE then
							error(
								`{entry.label} {action}: only {string.format("%.2f", head)} studs between tool and head`
							)
						end
						if hat < floor - 1e-6 then
							error(
								`{entry.label} {action}: {string.format("%.2f", hat)} studs between tool and headwear, below {string.format(
									"%.2f",
									floor
								)}`
							)
						end
					end
				end
			end
		)

		it("measures as it says: a tool pushed into the head is caught", function()
			MeshKit.install(data, assets)
			local rig = meshRig("citizen", "farmer", AZURE)
			local tool, head = MeshKit.child(rig, "Tool"), MeshKit.child(rig, "Head")
			local world = MeshKit.posed(rig, {})
			expect(MeshKit.boxBox(world[tool], tool.Size, world[head], head.Size)).toBeGreaterThan(MIN_CLEARANCE)
			-- the tool joint swung 90 degrees about Y at the shoulder puts the handle across the face: the measure must see it
			local pushed = world[tool] * CFrame.new(-1.5, 1.5, 0)
			expect(MeshKit.boxBox(pushed, tool.Size, world[head], head.Size)).toBeLessThan(MIN_CLEARANCE)
		end)
	end)
end

-- ------------------------------------------------------------------ portraits

describe("Kit.portrait on a mesh rig (G13.8, D-036)", function()
	local data = MeshKit.fixture()
	local assets = MeshKit.assets(data)

	local function cases()
		local out = {}
		for _, c in MeshKit.cases() do
			if c.kind == "citizen" and (c.look == nil or MeshKit.CITIZEN_JOBS[1]) then
				table.insert(out, c)
			end
		end
		return out
	end

	local function byName(model: Model): { [string]: BasePart }
		local out = {}
		for _, p in MeshKit.parts(model) do
			out[p.Name] = p
		end
		return out
	end

	local function project(cam: CFrame, fov: number, w: Vector3): (number, number, number)
		local p = cam:PointToObjectSpace(w)
		local depth = -p.Z
		local t = math.tan(math.rad(fov) / 2)
		return p.X / (depth * t), p.Y / (depth * t), depth
	end

	it("is the world rig for the same arguments, part for part, anchored, with the motors and welds kept", function()
		MeshKit.install(data, assets)
		for _, c in MeshKit.cases() do
			local char = meshRig(c.kind, c.job, c.color, c.look, c.kingdom)
			local portrait = Kit.portrait(c.kind, c.job, c.color, c.look, c.kingdom)
			expect(portrait:GetAttribute("KitMesh")).toBe(true)
			expect(portrait:GetAttribute("KitPortrait")).toBe(true)
			local a, b = byName(char), byName(portrait)
			local na, nb = 0, 0
			for name, pa in a do
				na += 1
				local pb = b[name]
				assert(pb, `{c.label}: the portrait has no {name}`)
				expect(pb.ClassName).toBe(pa.ClassName)
				expect(pb.Size).toEqual(pa.Size)
				expect(pb.Color:ToHex()).toBe(pa.Color:ToHex())
				expect(pb:GetAttributes()).toEqual(pa:GetAttributes())
				expect(near(pb.CFrame, pa.CFrame, 1e-5)).toBe(true)
				expect(pb.Anchored).toBe(true)
			end
			for _ in b do
				nb += 1
			end
			expect(nb).toBe(na)
			local motors, welds = 0, 0
			for _, d in portrait:GetDescendants() do
				if d:IsA("Motor6D") then
					motors += 1
				elseif d:IsA("Weld") then
					welds += 1
				end
				expect(d:IsA("LuaSourceContainer") or d:IsA("Humanoid") or d:IsA("Animator")).toBe(false)
			end
			expect(motors + welds).toBe(nb - 1)
			expect(#MeshKit.motors(portrait)).toBe(#MeshKit.motors(char))
		end
	end)

	it("frames head, headwear and shoulders from the front at PortraitFov, the focus being the camera", function()
		MeshKit.install(data, assets)
		local faceShare = math.huge
		for _, c in MeshKit.cases() do
			local portrait = Kit.portrait(c.kind, c.job, c.color, c.look, c.kingdom)
			local root = portrait.PrimaryPart :: BasePart
			local focus = root:FindFirstChild("PortraitFocus") :: Attachment
			assert(focus and focus:IsA("Attachment"), `{c.label}: no PortraitFocus attachment on the Root`)
			expect(focus:GetAttribute("PortraitFov")).toBe(Kit.PORTRAIT_FOV)
			local dist = focus:GetAttribute("PortraitDistance") :: number
			local cam, fov = Kit.portraitCamera(portrait)
			expect(fov).toBe(Kit.PORTRAIT_FOV)
			expect(near(cam, root.CFrame * focus.CFrame, 1e-6)).toBe(true)
			local parts = byName(portrait)
			local head, torso = parts.Head, parts.Torso
			expect(cam.LookVector.Z).toBeGreaterThan(0.95)
			expect(cam.LookVector.Y).toBeLessThanOrEqual(0)
			expect(cam.UpVector.Y).toBeGreaterThan(0.95)
			expect(cam.Position.Z).toBeLessThan(head.CFrame.Position.Z - head.Size.Z / 2 - 3)
			local hx, hy = project(cam, fov, head.CFrame.Position)
			expect(math.abs(hx)).toBeLessThan(0.1)
			expect(math.abs(hy)).toBeLessThan(0.6)
			expect(math.abs((cam.Position + cam.LookVector * dist).X - root.CFrame.Position.X)).toBeLessThan(1e-3)
			-- the head and everything worn on it (the Hair piece, crowns, crests, hat details, even those welded to the hat) in view
			local top = -math.huge
			for _, p in MeshKit.assembly(portrait, head) do -- welded to the head directly or through its hat
				for _, w in MeshKit.corners(p) do
					local x, y, depth = project(cam, fov, w)
					expect(depth).toBeGreaterThan(0)
					expect(math.abs(x)).toBeLessThanOrEqual(0.95)
					expect(math.abs(y)).toBeLessThanOrEqual(1)
					top = math.max(top, y)
				end
			end
			expect(top).toBeLessThan(0.92)
			expect(top).toBeGreaterThan(0.6)
			-- shoulders: the torso's top corners and the top of both arms in view
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
			faceShare = math.min(faceShare, (headTop - headBottom) / 2)
		end
		expect(faceShare).toBeGreaterThan(0.25)
	end)

	it("poses with Kit.posePortrait like the engine does, absolute and restorable, the camera steady", function()
		MeshKit.install(data, assets)
		for _, c in MeshKit.cases() do
			local portrait = Kit.portrait(c.kind, c.job, c.color, c.look, c.kingdom)
			local rest = {}
			for _, p in MeshKit.parts(portrait) do
				rest[p] = p.CFrame
			end
			local camRest = Kit.portraitCamera(portrait)
			for _, joints in
				{
					Pose.sample("walk", c.job, 0.25, 12),
					Pose.sample("dead", c.job, 0, 0),
					Pose.sample("work", c.job, 0.4, 0),
				}
			do
				local expected = MeshKit.posed(portrait, joints)
				Kit.posePortrait(portrait, joints)
				Kit.posePortrait(portrait, joints) -- twice: absolute, not cumulative
				for part, cf in expected do
					expect(near(part.CFrame, cf, 1e-4)).toBe(true)
				end
				expect(near(Kit.portraitCamera(portrait), camRest, 1e-6)).toBe(true)
			end
			Kit.posePortrait(portrait, {})
			for part, cf in rest do
				expect(near(part.CFrame, cf, 1e-4)).toBe(true)
			end
		end
	end)

	it("falls back to the part-built portrait when the kit is not there (the same Kit.portrait call)", function()
		MeshKit.install(data, nil)
		local portrait = Kit.portrait("citizen", "farmer", AZURE)
		expect(portrait:GetAttribute("KitMesh")).toBeNil()
		expect(portrait:GetAttribute("KitPortrait")).toBe(true)
		for _, p in MeshKit.parts(portrait) do
			expect(p:IsA("MeshPart")).toBe(false)
		end
		local cam = Kit.portraitCamera(portrait)
		expect(cam.Position.Z).toBeLessThan(-5) -- in front of the face (the rig faces -Z)
	end)
end)
