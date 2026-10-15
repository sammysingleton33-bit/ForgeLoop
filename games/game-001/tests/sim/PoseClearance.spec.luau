--[[
	Sim/Pose × Kit.character: a posed tool never goes through the head (B17: "tools clip the head in the
	keep-level-2 cheer", the polished jobs of #138 were held on it).

	Forward kinematics as the engine does it (Part1 = Part0 * C0 * Transform * C1:Inverse()), a rig built by
	Kit.character for each kind and job, every action sampled over its whole cycle. The clearance between
	two parts is the separating-axis distance of their boxes (all 15 axes): positive = free space between
	them, negative = how far one box sinks into the other. Ball, Cylinder and Wedge parts count as their
	bounding boxes, so the number is conservative. Headless only: nobody has looked at the cheer on screen.
]]

local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local Kit = require("@game/ReplicatedStorage/Game/Kit/Kit")
local Pose = require("@game/ReplicatedStorage/Game/Sim/Pose")

local CRIMSON = Color3.fromRGB(190, 40, 50)
local STEPS = 40 -- samples per cycle
local MIN_CLEARANCE = 0.1 -- studs of free space a posed tool must keep from the head

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
	for _, d in rig:GetDescendants() do
		if d:IsA("Weld") and world[d.Part0 :: BasePart] then
			world[d.Part1 :: BasePart] = world[d.Part0 :: BasePart] * d.C0 * d.C1:Inverse()
		end
	end
	return world
end

-- separating-axis clearance of two boxes (cf, size): the largest separation over the 15 candidate axes
local function clearance(cfA: CFrame, sizeA: Vector3, cfB: CFrame, sizeB: Vector3): number
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

-- the worst (smallest) clearance between the tool and the head or its headwear over one action's cycle
local function worst(kind: string, job: string, action: string): (number, number)
	local rig = Kit.character(kind, job, CRIMSON, nil, if kind == "soldier" then "crimson" else nil) :: Model
	local tool = rig:FindFirstChild("Tool") :: BasePart?
	if tool == nil then
		return math.huge, 0
	end
	local head = rig:FindFirstChild("Head") :: BasePart
	local hair = rig:FindFirstChild("Hair") :: BasePart?
	local low, at = math.huge, 0
	local joints: { [string]: CFrame } = {}
	for i = 0, STEPS - 1 do
		local phase = i / STEPS
		Pose.sample(
			action,
			job,
			phase,
			if action == "walk" or action == "carry" or action == "flee" then 12 else 0,
			joints
		)
		local world = posed(rig, joints)
		for _, other in { head, hair } do
			local c = clearance(world[tool], tool.Size, world[other], other.Size)
			if c < low then
				low, at = c, phase
			end
		end
	end
	return low, at
end

describe("Sim/Pose × Kit.character: a posed tool keeps clear of the head", function()
	it("measures a rig at all (a tool and a head to measure)", function()
		local low = worst("citizen", "farmer", "celebrate")
		expect(low < math.huge).toBe(true)
		expect(low == low).toBe(true)
	end)

	it("celebrate: every tool keeps clear of the head and its headwear", function()
		for _, rig in RIGS do
			local low, at = worst(rig[1], rig[2], "celebrate")
			if low < 0 then
				error(
					`{rig[1]}/{rig[2]} celebrate: tool sinks {string.format("%.2f", -low)} studs into the head (phase {at})`
				)
			end
		end
	end)

	it("no other action brings a tool close to the head either", function()
		for _, rig in RIGS do
			for _, action in ACTIONS do
				if action ~= "celebrate" then
					local low, at = worst(rig[1], rig[2], action)
					if low < MIN_CLEARANCE then
						error(
							`{rig[1]}/{rig[2]} {action}: only {string.format("%.2f", low)} studs between tool and head (phase {at})`
						)
					end
				end
			end
		end
	end)
end)
