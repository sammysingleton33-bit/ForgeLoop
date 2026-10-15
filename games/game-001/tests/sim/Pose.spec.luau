--[[
	Sim/Pose (CONTRACTS G4 rendering, D-026): procedural animation maths for Kit.character rigs.
]]

local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local Kit = require("@game/ReplicatedStorage/Game/Kit/Kit")
local Pose = require("@game/ReplicatedStorage/Game/Sim/Pose")
local SnapshotCodec = require("@game/ReplicatedStorage/Game/Sim/SnapshotCodec")
local Types = require("@game/ReplicatedStorage/Game/Kingdom/Types")

local PHASES = { 0, 0.1, 0.25, 0.37, 0.5, 0.63, 0.75, 0.9 }
local SPEEDS = { 0, 4, 12, 20 }

local function finite(n: number): boolean
	return n == n and math.abs(n) < math.huge
end

-- rotation angle of a CFrame in degrees (from the trace of its rotation matrix)
local function angleOf(cf: CFrame): number
	local _, _, _, r00, _, _, _, r11, _, _, _, r22 = cf:GetComponents()
	local cosine = math.clamp((r00 + r11 + r22 - 1) / 2, -1, 1)
	return math.deg(math.acos(cosine))
end

local function near(a: CFrame, b: CFrame, tolerance: number): boolean
	local ca, cb = { a:GetComponents() }, { b:GetComponents() }
	for i = 1, 12 do
		if math.abs(ca[i] - cb[i]) > tolerance then
			return false
		end
	end
	return true
end

local function legSwing(action: string, speed: number, phase: number): number
	return angleOf(Pose.sample(action, "idle", phase, speed).LeftLeg)
end

describe("Sim/Pose", function()
	it("names exactly the Motor6Ds Kit.character creates", function()
		local seen = {}
		for _, job in Types.JOB_IDS do
			for _, d in Kit.character("citizen", job, Kit.NEUTRAL_COLOR):GetDescendants() do
				if d:IsA("Motor6D") then
					seen[d.Name] = true
				end
			end
		end
		local names = {}
		for name in seen do
			table.insert(names, name)
		end
		table.sort(names)
		local joints = table.clone(Pose.JOINTS)
		table.sort(joints)
		expect(names).toEqual(joints)
	end)

	it("returns a finite CFrame for every joint, action and job, within the joint limits", function()
		for _, action in SnapshotCodec.ACTIONS do
			for _, job in Types.JOB_IDS do
				for _, speed in SPEEDS do
					for _, phase in PHASES do
						local pose = Pose.sample(action, job, phase, speed)
						for _, joint in Pose.JOINTS do
							local cf = pose[joint]
							expect(typeof(cf)).toBe("CFrame")
							for _, n in { cf:GetComponents() } do
								if not finite(n) then
									error(`{action}/{job} {joint}: non-finite component`)
								end
							end
							local angle = angleOf(cf)
							if angle > Pose.LIMITS[joint] + 1e-3 then
								error(`{action}/{job} {joint}: {angle}° > {Pose.LIMITS[joint]}°`)
							end
							if action ~= "celebrate" and angle > 90 + 1e-3 then
								error(`{action}/{job} {joint}: {angle}° > 90° outside celebrate`)
							end
							expect(cf.Position.Magnitude).toBeLessThanOrEqual(2)
						end
					end
				end
			end
		end
	end)

	it("keeps every limit within 150° and only arms above 90°", function()
		for joint, limit in Pose.LIMITS do
			expect(limit).toBeLessThanOrEqual(if joint == "LeftArm" or joint == "RightArm" then 150 else 90)
		end
	end)

	it("swings the legs more as walking speeds up, and not at all standing still", function()
		for _, action in { "walk", "flee", "carry" } do
			local previous = -1
			for _, speed in { 0, 2, 5, 8, 11 } do
				local swing = legSwing(action, speed, 0.25) -- sin peak
				if speed == 0 then
					expect(swing).toBeNear(0, 1e-4)
				else
					expect(swing).toBeGreaterThan(previous)
				end
				previous = swing
			end
		end
		local standing = Pose.sample("walk", "farmer", 0.25, 0)
		for _, joint in Pose.JOINTS do
			expect(angleOf(standing[joint])).toBeNear(0, 1e-4)
		end
		expect(Pose.rate("walk", "farmer", 0)).toBe(0)
		expect(Pose.rate("walk", "farmer", 12)).toBeGreaterThan(Pose.rate("walk", "farmer", 6))
		expect(Pose.rate("walk", "farmer", 1000)).toBe(Pose.MAX_WALK_RATE)
	end)

	it("swings the legs in opposite directions and the arms against the legs", function()
		local pose = Pose.sample("walk", "farmer", 0.25, 12)
		expect(pose.LeftLeg.LookVector.Y).toBeGreaterThan(0.1) -- forward: the leg's front tips up
		expect(pose.RightLeg.LookVector.Y).toBeLessThan(-0.1)
		expect(pose.LeftArm.LookVector.Y).toBeLessThan(-0.1)
		expect(pose.RightArm.LookVector.Y).toBeGreaterThan(0.1)
	end)

	it("is periodic in phase", function()
		for _, action in SnapshotCodec.ACTIONS do
			for _, job in Types.JOB_IDS do
				for _, phase in PHASES do
					local a = Pose.sample(action, job, phase, 7)
					local b = Pose.sample(action, job, phase + 1, 7)
					local c = Pose.sample(action, job, phase - 3, 7)
					for _, joint in Pose.JOINTS do
						expect(near(a[joint], b[joint], 1e-4)).toBe(true)
						expect(near(a[joint], c[joint], 1e-4)).toBe(true)
					end
				end
			end
		end
	end)

	it("is deterministic and fills the table it is given", function()
		local out = {}
		local result = Pose.sample("work", "miner", 0.3, 0, out)
		expect(result).toBe(out)
		local again = Pose.sample("work", "miner", 0.3, 0)
		for _, joint in Pose.JOINTS do
			expect(near(out[joint], again[joint], 0)).toBe(true)
		end
	end)

	it("animates work by job: chop, mine, hammer, harvest, generic", function()
		expect(Pose.workStyle("woodcutter")).toBe("chop")
		expect(Pose.workStyle("miner")).toBe("mine")
		expect(Pose.workStyle("builder")).toBe("hammer")
		expect(Pose.workStyle("farmer")).toBe("harvest")
		expect(Pose.workStyle("hauler")).toBe("generic")
		expect(Pose.workStyle("nonsense")).toBe("generic")
		-- the right arm moves over a work cycle, and differently per job
		local function armTravel(job: string): number
			local low, high = math.huge, -math.huge
			for _, phase in PHASES do
				local angle = angleOf(Pose.sample("work", job, phase, 0).RightArm)
				low, high = math.min(low, angle), math.max(high, angle)
			end
			return high - low
		end
		for _, job in { "woodcutter", "miner", "builder", "farmer", "hauler" } do
			expect(armTravel(job)).toBeGreaterThan(10)
		end
		local chop = Pose.sample("work", "woodcutter", 0.5, 0)
		local harvest = Pose.sample("work", "farmer", 0.5, 0)
		expect(near(chop.RightArm, harvest.RightArm, 1e-3)).toBe(false)
		-- harvesting bends forward: the torso's top tips toward -Z
		expect(harvest.Torso.UpVector.Z).toBeLessThan(-0.2)
	end)

	it("carries with both arms forward, raises the arms to celebrate and lies down dead", function()
		local carry = Pose.sample("carry", "hauler", 0, 8)
		expect(angleOf(carry.LeftArm)).toBeGreaterThan(60)
		expect(carry.LeftArm.LookVector.Y).toBeGreaterThan(0.8) -- arm forward: its front points up
		local cheer = Pose.sample("celebrate", "farmer", 0.4, 0)
		expect(angleOf(cheer.LeftArm)).toBeGreaterThan(120)
		expect(cheer.LeftArm.UpVector.Y).toBeLessThan(-0.5) -- the arm hangs from its top: up flips when raised
		local dead = Pose.sample("dead", "farmer", 0.4, 0)
		expect(dead.Torso.UpVector.Y).toBeNear(0, 1e-4) -- horizontal
		expect(dead.Torso.Position.Y).toBeLessThan(-1)
		expect(Pose.rate("dead", "farmer", 5)).toBe(0)
		local fight = Pose.sample("fight", "soldier", 0.25, 0)
		expect(angleOf(fight.RightArm)).toBeNear(90, 1e-3)
	end)

	it(
		"celebrates with both arms up when nothing is held, with the tool arm lower and the tool tipped back when one is",
		function()
			for _, phase in PHASES do
				for _, job in { "idle", "hauler" } do
					local cheer = Pose.sample("celebrate", job, phase, 0)
					expect(angleOf(cheer.RightArm)).toBeNear(angleOf(cheer.LeftArm), 1e-3) -- both arms up
					expect(near(cheer.Tool, CFrame.new(), 0)).toBe(true)
				end
				for _, job in { "farmer", "woodcutter", "miner", "builder", "soldier", "juggler" } do
					local cheer = Pose.sample("celebrate", job, phase, 0)
					expect(angleOf(cheer.RightArm) < angleOf(cheer.LeftArm) - 15).toBe(true) -- the tool arm stays lower
					expect(angleOf(cheer.RightArm)).toBeGreaterThan(60) -- but is out to the side, not hanging
					expect(angleOf(cheer.Tool)).toBeNear(Pose.LIMITS.Tool, 1e-3) -- tipped back to the joint's limit
					expect(cheer.Tool.UpVector.Z < 0).toBe(true) -- back: the tool's top leans away from the front (-Z)
				end
			end
		end
	)

	it("falls back to idle for an unknown action", function()
		for _, phase in PHASES do
			local unknown = Pose.sample("juggle", "farmer", phase, 5)
			local idle = Pose.sample("idle", "farmer", phase, 5)
			for _, joint in Pose.JOINTS do
				expect(near(unknown[joint], idle[joint], 0)).toBe(true)
			end
		end
		expect(Pose.rate("juggle", "farmer", 5)).toBe(Pose.rate("idle", "farmer", 5))
		-- non-finite phase or speed never produce NaN
		local pose = Pose.sample("walk", "farmer", 0 / 0, 0 / 0)
		for _, joint in Pose.JOINTS do
			for _, n in { pose[joint]:GetComponents() } do
				expect(finite(n)).toBe(true)
			end
		end
	end)

	it("blends joint by joint", function()
		local idle = Pose.sample("idle", "farmer", 0, 0)
		local dead = Pose.sample("dead", "farmer", 0, 0)
		local half = Pose.blend(idle, dead, 0.5)
		expect(half.Torso.Position.Y).toBeNear(dead.Torso.Position.Y / 2, 1e-4)
		local full = Pose.blend(idle, dead, 7) -- clamped
		for _, joint in Pose.JOINTS do
			expect(near(full[joint], dead[joint], 1e-5)).toBe(true)
		end
	end)
end)
