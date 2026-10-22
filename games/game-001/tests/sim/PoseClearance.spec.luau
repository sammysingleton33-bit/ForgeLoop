--[[
	Sim/Pose × Kit.character: a posed tool never goes through the head (B17: "tools clip the head in the
	keep-level-2 cheer", the polished jobs of #138 were held on it), and a work blow keeps it out of the torso
	and legs (D-059: the swings go overhead).

	Forward kinematics as the engine does it (Part1 = Part0 * C0 * Transform * C1:Inverse()), a rig built by
	Kit.character for each kind and job, every action sampled over its whole cycle. The tool means the Tool
	and every part welded to it (its head, blade, strap...); the head means the Head, and its headwear every
	other part welded to it (hair, hat, lamp...). The clearance between two parts is the separating-axis
	distance of their boxes (all 15 axes), or the distance to the surface when one is a Ball: positive = free
	space between them, negative = how far one sinks into the other. A Cylinder is a cylinder (sampled against exact
	surface distances); a Wedge counts as its bounding box, so the number is conservative for it. Headless only: nobody has looked at the cheer on
	screen.
]]

local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local Kit = require("@game/ReplicatedStorage/Game/Kit/Kit")
local Pose = require("@game/ReplicatedStorage/Game/Sim/Pose")

local CRIMSON = Color3.fromRGB(190, 40, 50)
local STEPS = 40 -- samples per cycle
local MIN_CLEARANCE = 0.1 -- studs of free space a posed tool must keep from the head
local MIN_BODY = 0.05 -- studs a work blow's tool keeps from the torso and legs (D-059)

-- { kind, job } of every rig that holds a tool in the right fist. The hauler's sack is not one: it hangs from the
-- torso at the shoulder blade and its box overlaps the head's in every action (a fixed Kit proportion, -0.70).
local RIGS = {
	{ "citizen", "farmer" },
	{ "citizen", "woodcutter" },
	{ "citizen", "miner" },
	{ "citizen", "builder" },
	{ "soldier", "soldier" },
	{ "governor", "governor" }, -- no sim job yet: an unknown job cheers with the tool arm lowered
}

local ACTIONS = { "idle", "walk", "carry", "work", "fight", "celebrate", "flee" }

local function motorsOf(rig: Model): { Motor6D }
	local out = {}
	for _, d in rig:GetDescendants() do
		if d:IsA("Motor6D") then
			table.insert(out, d)
		end
	end
	return out
end

-- Part1 = Part0 * C0 * Transform * C1:Inverse(); welds follow
local function posed(rig: Model, joints: { [string]: CFrame }): { [BasePart]: CFrame }
	local root = rig.PrimaryPart :: BasePart
	local world: { [BasePart]: CFrame } = { [root] = root.CFrame }
	local motors = motorsOf(rig)
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
	-- welds follow whichever side is placed (Kit welds a detail to its Head or Tool in either direction)
	local welds = {}
	for _, d in rig:GetDescendants() do
		if d:IsA("Weld") then
			table.insert(welds, d)
		end
	end
	moved = true
	while moved do
		moved = false
		for _, d in welds do
			local p0, p1 = d.Part0 :: BasePart, d.Part1 :: BasePart
			if world[p0] and not world[p1] then
				world[p1] = world[p0] * d.C0 * d.C1:Inverse()
				moved = true
			elseif world[p1] and not world[p0] then
				world[p0] = world[p1] * d.C1 * d.C0:Inverse()
				moved = true
			end
		end
	end
	return world
end

-- `root` and every part welded to it, directly or through other welds (never across a Motor6D): the tool with its
-- head and detail parts, the head with its hair, hat and details
local function assembly(rig: Model, root: BasePart): { BasePart }
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

local function isBall(part: BasePart): boolean
	return part:IsA("Part") and (part :: Part).Shape == Enum.PartType.Ball
end

-- separating-axis clearance of two boxes (cf, size): the largest separation over the 15 candidate axes
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

-- a box against a sphere of `radius` at `center`: the distance from the centre to the box's surface, less the
-- radius; with the centre inside the box, minus the radius and the depth of the centre below the nearest face
local function boxSphere(cf: CFrame, size: Vector3, center: Vector3, radius: number): number
	local local3 = cf:Inverse() * center
	local half = { size.X / 2, size.Y / 2, size.Z / 2 }
	local coords = { local3.X, local3.Y, local3.Z }
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

local function isCylinder(part: BasePart): boolean
	return part:IsA("Part") and (part :: Part).Shape == Enum.PartType.Cylinder
end

-- signed distance from `point` to the surface of a posed part (negative inside): exact for a Block, a Ball and a
-- Cylinder (Roblox cylinders run along local X)
local function signedDistance(part: BasePart, cf: CFrame, point: Vector3): number
	local q = cf:Inverse() * point
	local h = part.Size / 2
	if isBall(part) then
		return q.Magnitude - h.X
	elseif isCylinder(part) then
		local radial = math.sqrt(q.Y * q.Y + q.Z * q.Z) - math.min(h.Y, h.Z)
		local axial = math.abs(q.X) - h.X
		local outside = math.sqrt(math.max(radial, 0) ^ 2 + math.max(axial, 0) ^ 2)
		return math.min(math.max(radial, axial), 0) + outside
	end
	local dx, dy, dz = math.abs(q.X) - h.X, math.abs(q.Y) - h.Y, math.abs(q.Z) - h.Z
	local outside = math.sqrt(math.max(dx, 0) ^ 2 + math.max(dy, 0) ^ 2 + math.max(dz, 0) ^ 2)
	return math.min(math.max(dx, dy, dz), 0) + outside
end

-- points on and inside a posed part: its centre, corners, edge middles and face centres (a box), or two end
-- circles, a middle circle and the end centres (a cylinder), or the axis points and diagonals (a ball)
local function samplePoints(part: BasePart, cf: CFrame): { Vector3 }
	local h = part.Size / 2
	local out: { Vector3 } = { cf.Position }
	local function add(x: number, y: number, z: number)
		table.insert(out, cf * Vector3.new(x, y, z))
	end
	if isCylinder(part) then
		local r = math.min(h.Y, h.Z)
		for _, x in { -h.X, 0, h.X } do
			for step = 0, 11 do
				local a = step / 12 * 2 * math.pi
				add(x, math.cos(a) * r, math.sin(a) * r)
			end
		end
		add(-h.X, 0, 0)
		add(h.X, 0, 0)
	elseif isBall(part) then
		local r = h.X
		for _, axis in { Vector3.xAxis, Vector3.yAxis, Vector3.zAxis } do
			add(axis.X * r, axis.Y * r, axis.Z * r)
			add(-axis.X * r, -axis.Y * r, -axis.Z * r)
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

-- Clearance of two posed parts. Box with box: the separating-axis distance. Anything with a Cylinder: the smaller
-- of each part's sample points against the other's exact surface distance (positive: free space; negative: the
-- deepest sample inside). A Ball with a box or a Ball: the exact distances.
local function clearance(a: BasePart, cfA: CFrame, b: BasePart, cfB: CFrame): number
	if isCylinder(a) or isCylinder(b) then
		local best = math.huge
		for _, point in samplePoints(a, cfA) do
			best = math.min(best, signedDistance(b, cfB, point))
		end
		for _, point in samplePoints(b, cfB) do
			best = math.min(best, signedDistance(a, cfA, point))
		end
		return best
	end
	local ballA, ballB = isBall(a), isBall(b)
	if ballA and ballB then
		return (cfA.Position - cfB.Position).Magnitude - a.Size.X / 2 - b.Size.X / 2
	elseif ballA then
		return boxSphere(cfB, b.Size, cfA.Position, a.Size.X / 2)
	elseif ballB then
		return boxSphere(cfA, a.Size, cfB.Position, b.Size.X / 2)
	end
	return boxBox(cfA, a.Size, cfB, b.Size)
end

-- The smallest clearance between the tool assembly (the Tool and every part welded to it) and the Head, and
-- between the tool assembly and the headwear (every other part welded to the Head), over one action's cycle
-- (math.huge when the rig has no tool or no headwear).
local function worst(kind: string, job: string, action: string): (number, number)
	local rig = Kit.character(kind, job, CRIMSON, nil, if kind == "soldier" then "crimson" else nil) :: Model
	local tool = rig:FindFirstChild("Tool") :: BasePart?
	if tool == nil then
		return math.huge, math.huge
	end
	local head = rig:FindFirstChild("Head") :: BasePart
	local toolParts = assembly(rig, tool)
	local hatParts = assembly(rig, head)
	table.remove(hatParts, 1) -- the head itself
	local lowHead, lowHat = math.huge, math.huge
	local joints: { [string]: CFrame } = {}
	for i = 0, STEPS - 1 do
		Pose.sample(
			action,
			job,
			i / STEPS,
			if action == "walk" or action == "carry" or action == "flee" then 12 else 0,
			joints
		)
		local world = posed(rig, joints)
		for _, t in toolParts do
			lowHead = math.min(lowHead, clearance(t, world[t], head, world[head]))
			for _, hat in hatParts do
				lowHat = math.min(lowHat, clearance(t, world[t], hat, world[hat]))
			end
		end
	end
	return lowHead, lowHat
end

-- The smallest clearance between the tool assembly and the body below the shoulders (the Torso and both legs; the
-- arms hold the tool and are left out) over one action's cycle (math.huge without a tool). D-059.
local BODY = { "Torso", "LeftLeg", "RightLeg" }
local function worstBody(kind: string, job: string, action: string): number
	local rig = Kit.character(kind, job, CRIMSON, nil, if kind == "soldier" then "crimson" else nil) :: Model
	local tool = rig:FindFirstChild("Tool") :: BasePart?
	if tool == nil then
		return math.huge
	end
	local toolParts = assembly(rig, tool)
	local low = math.huge
	local joints: { [string]: CFrame } = {}
	for i = 0, STEPS - 1 do
		Pose.sample(
			action,
			job,
			i / STEPS,
			if action == "walk" or action == "carry" or action == "flee" then 12 else 0,
			joints
		)
		local world = posed(rig, joints)
		for _, name in BODY do
			local body = rig:FindFirstChild(name) :: BasePart?
			if body ~= nil then
				for _, t in toolParts do
					low = math.min(low, clearance(t, world[t], body, world[body]))
				end
			end
		end
	end
	return low
end
-- What a pose must keep from the headwear: MIN_CLEARANCE, or no less than the rig's own rest pose has. A
-- tool that already stands in its hat at rest (Kit proportions, FORGE-02's) is no pose's doing; a pose must
-- not push it any deeper.
local function hatFloor(kind: string, job: string): number
	local _, idleHat = worst(kind, job, "idle")
	return math.min(MIN_CLEARANCE, idleHat)
end

local function check(rig: { string }, action: string)
	local kind, job = rig[1], rig[2]
	local head, hat = worst(kind, job, action)
	if head < MIN_CLEARANCE then
		error(`{kind}/{job} {action}: only {string.format("%.2f", head)} studs between tool and head`)
	end
	local floor = hatFloor(kind, job)
	if hat < floor - 1e-6 then
		error(
			`{kind}/{job} {action}: {string.format("%.2f", hat)} studs between tool and headwear, below {string.format(
				"%.2f",
				floor
			)}`
		)
	end
end

local function part(shape: Enum.PartType, size: Vector3): Part
	local p = Instance.new("Part")
	p.Shape = shape
	p.Size = size
	return p
end

describe("PoseClearance: the rig walk", function()
	-- Root -Motor6D "Tool"-> Tool; Detail welded to the Tool the other way round (Part0 = Detail); Hat welded to Head
	local function rigWithDetail()
		local rig = Instance.new("Model")
		local function add(name: string, cf: CFrame): Part
			local p = Instance.new("Part")
			p.Name = name
			p.Size = Vector3.new(1, 1, 1)
			p.CFrame = cf
			p.Parent = rig
			return p
		end
		local root = add("Root", CFrame.new(0, 0, 0))
		local tool = add("Tool", CFrame.new(5, 0, 0))
		local detail = add("Detail", CFrame.new(5, 2, 0))
		local head = add("Head", CFrame.new(0, 3, 0))
		local hat = add("Hat", CFrame.new(0, 4, 0))
		rig.PrimaryPart = root
		local motor = Instance.new("Motor6D")
		motor.Name = "Tool"
		motor.Part0, motor.Part1 = root, tool
		motor.C0 = CFrame.new(5, 0, 0)
		motor.C1 = CFrame.new()
		motor.Parent = root
		local weld = Instance.new("Weld")
		weld.Name = "DetailWeld"
		weld.Part0, weld.Part1 = detail, tool -- the detail is Part0: the tool is placed first, the weld runs backwards
		weld.C0 = CFrame.new(0, -2, 0)
		weld.C1 = CFrame.new()
		weld.Parent = detail
		local hatWeld = Instance.new("Weld")
		hatWeld.Part0, hatWeld.Part1 = head, hat
		hatWeld.C0 = CFrame.new(0, 1, 0)
		hatWeld.C1 = CFrame.new()
		hatWeld.Parent = head
		-- the head hangs off the root by a motor too
		local neck = Instance.new("Motor6D")
		neck.Name = "Head"
		neck.Part0, neck.Part1 = root, head
		neck.C0 = CFrame.new(0, 3, 0)
		neck.C1 = CFrame.new()
		neck.Parent = root
		return rig, root, tool, detail, head, hat
	end

	it("collects a part's welded assembly through welds in either direction, and stops at a motor", function()
		local rig, root, tool, detail, head = rigWithDetail()
		local function names(list: { BasePart }): { string }
			local out = {}
			for _, p in list do
				table.insert(out, p.Name)
			end
			table.sort(out)
			return out
		end
		expect(names(assembly(rig, tool))).toEqual({ "Detail", "Tool" })
		expect(names(assembly(rig, head))).toEqual({ "Hat", "Head" })
		expect(names(assembly(rig, root))).toEqual({ "Root" }) -- motors are not welds
		expect(assembly(rig, tool)[1]).toBe(tool)
		expect(assembly(rig, detail)[1]).toBe(detail)
	end)

	it("places a part welded the wrong way round from its placed side", function()
		local rig, _, tool, detail, _, hat = rigWithDetail()
		local world = posed(rig, {})
		expect((world[tool].Position - Vector3.new(5, 0, 0)).Magnitude < 1e-6).toBe(true)
		-- Part1 = Part0 * C0 * C1:Inverse() runs from the detail; placed from the tool it is Part0 = Part1 * C1 * C0:Inverse()
		expect((world[detail].Position - Vector3.new(5, 2, 0)).Magnitude < 1e-6).toBe(true)
		expect((world[hat].Position - Vector3.new(0, 4, 0)).Magnitude < 1e-6).toBe(true)
	end)
end)

describe("PoseClearance: the measure itself", function()
	local block = Enum.PartType.Block
	local ball = Enum.PartType.Ball
	local at = function(x: number, y: number?)
		return CFrame.new(x, y or 0, 0)
	end

	it("is the gap between two boxes, and minus the depth when they overlap", function()
		local a, b = part(block, Vector3.new(2, 2, 2)), part(block, Vector3.new(2, 2, 2))
		expect(math.abs(clearance(a, at(0), b, at(3)) - 1) < 1e-9).toBe(true)
		expect(math.abs(clearance(a, at(0), b, at(1.5)) + 0.5) < 1e-9).toBe(true)
		-- turned 45 degrees about Y the box reaches 1.414 from its centre: 3 - 1 - 1.414
		local turned = at(3) * CFrame.Angles(0, math.rad(45), 0)
		expect(math.abs(clearance(a, at(0), b, turned) - (3 - 1 - math.sqrt(2))) < 1e-6).toBe(true)
	end)

	it("treats a Ball as a sphere: the corner of its bounding box is free space", function()
		local box, sphere = part(block, Vector3.new(2, 2, 2)), part(ball, Vector3.new(2, 2, 2))
		expect(math.abs(clearance(box, at(0), sphere, at(3)) - 1) < 1e-9).toBe(true) -- 3 - 1 - 1
		expect(math.abs(clearance(sphere, at(3), box, at(0)) - 1) < 1e-9).toBe(true) -- either order
		-- diagonally off a corner: the sphere centre is sqrt(2) from the corner edge, less its radius
		local diagonal = CFrame.new(2, 2, 0)
		expect(math.abs(clearance(box, at(0), sphere, diagonal) - (math.sqrt(2) - 1)) < 1e-9).toBe(true)
		-- centre inside the box: minus the radius and the depth below the nearest face
		expect(math.abs(clearance(box, at(0), sphere, at(0.25)) + (1 + 0.75)) < 1e-9).toBe(true)
		local other = part(ball, Vector3.new(2, 2, 2))
		expect(math.abs(clearance(sphere, at(0), other, at(3)) - 1) < 1e-9).toBe(true)
		expect(math.abs(clearance(sphere, at(0), other, at(1)) + 1) < 1e-9).toBe(true)
	end)

	it("treats a Cylinder as a cylinder (along X): its bounding box's corner is free space", function()
		local pot = part(Enum.PartType.Cylinder, Vector3.new(2, 2, 2)) -- length 2 along X, radius 1
		local box = part(block, Vector3.new(2, 2, 2))
		expect(math.abs(clearance(pot, at(0), box, at(3)) - 1) < 1e-6).toBe(true) -- end to face: 2 - 1
		expect(math.abs(clearance(pot, at(0), box, at(0, 2.5)) - 0.5) < 1e-6).toBe(true) -- side: 1.5 - 1
		expect(math.abs(clearance(box, at(0, 2.5), pot, at(0)) - 0.5) < 1e-6).toBe(true) -- either order
		expect(math.abs(clearance(pot, at(0), box, at(0, 1.5)) + 0.5) < 1e-6).toBe(true) -- sunk in by 0.5
		-- the box sits off the bounding box's corner (y and z both 2): the edge is sqrt(2) - 1 from the surface
		local corner = CFrame.new(0, 2, 2)
		expect(math.abs(clearance(pot, at(0), box, corner) - (math.sqrt(2) - 1)) < 1e-6).toBe(true)
	end)
end)

describe("Sim/Pose × Kit.character: a posed tool keeps clear of the head", function()
	it("measures a rig at all (a tool and a head to measure)", function()
		local head = worst("citizen", "farmer", "celebrate")
		expect(head < math.huge).toBe(true)
		expect(head == head).toBe(true)
	end)

	it("celebrate: every tool keeps clear of the head, and no closer to the headwear than at rest", function()
		for _, rig in RIGS do
			check(rig, "celebrate")
		end
	end)

	it("a work blow keeps every tool out of the torso and the legs (D-059: the swings go overhead now)", function()
		for _, rig in RIGS do
			local kind, job = rig[1], rig[2]
			local floor = math.min(MIN_BODY, worstBody(kind, job, "idle")) -- a tool resting on the body is Kit's
			local low = worstBody(kind, job, "work")
			if low < floor - 1e-6 then
				error(`{kind}/{job} work: {string.format("%.2f", low)} studs between tool and body, below {floor}`)
			end
		end
	end)

	it("no other action brings a tool close to the head or deeper into the headwear either", function()
		for _, rig in RIGS do
			for _, action in ACTIONS do
				if action ~= "celebrate" then
					check(rig, action)
				end
			end
		end
	end)
end)
