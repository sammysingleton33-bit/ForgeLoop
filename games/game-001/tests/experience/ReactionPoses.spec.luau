local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect, beforeEach = T.describe, T.it, T.expect, T.beforeEach

local MockEnv = require("../../../../roblox/tests/mocks/MockEnv")
local Loader = require("@game/ReplicatedStorage/Forge/Contracts/Loader")
local Signal = require("@game/ReplicatedStorage/Forge/Core/Signal")
local Bubbles = require("@game/ReplicatedStorage/Game/Feedback/Bubbles")
local ReactionPoses = require("@game/ReplicatedStorage/Game/Feedback/ReactionPoses")
local Pose = require("@game/ReplicatedStorage/Game/Sim/Pose")
local Vfx = require("@game/ReplicatedStorage/Forge/Config/Vfx")
local FeedbackPoseDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/FeedbackPoseController")

-- degrees a joint transform rotates by (axis-angle; 260° about one axis is 100° about the other way)
local function degrees(cf: CFrame): number
	local _, angle = cf:ToAxisAngle()
	local a = math.deg(math.abs(angle)) % 360
	return math.min(a, 360 - a)
end

local function largest(joints): number
	local most = 0
	for _, cf in joints do
		most = math.max(most, degrees(cf), cf.Position.Magnitude * 10)
	end
	return most
end

local WORK_ACTIONS = { work_fast = true, hammer = true, rest = true } -- EntityController's own loop

describe("Feedback/ReactionPoses (FL-0100, G13.8)", function()
	it("every pose stays within Sim/Pose limits and lifts the torso at most 2 studs, moving or held", function()
		for _, name in ReactionPoses.NAMES do
			local function check(joints, at)
				for joint, cf in joints do
					local limit = Pose.LIMITS[joint]
					expect(limit).never.toBeNil()
					if degrees(cf) > limit + 0.5 then
						error(`{name} {joint} at {at}: {degrees(cf)}° > {limit}°`)
					end
				end
				expect(math.abs(joints.Torso.Position.Y) <= 2).toBe(true)
			end
			local t = -0.1
			while t <= ReactionPoses.DURATION[name] + 0.2 do
				check(ReactionPoses.sample(name, t), t)
				t += 0.02
			end
			check(ReactionPoses.still(name), "still")
		end
	end)

	it("a gesture starts and ends at rest, eases in, and moves in between", function()
		for _, name in ReactionPoses.NAMES do
			local duration = ReactionPoses.DURATION[name]
			expect(largest(ReactionPoses.sample(name, 0))).toBe(0)
			expect(largest(ReactionPoses.sample(name, duration))).toBe(0)
			local middle = largest(ReactionPoses.sample(name, duration / 2))
			expect(middle > 5).toBe(true)
			expect(largest(ReactionPoses.sample(name, ReactionPoses.EASE_IN / 4)) < middle).toBe(true)
			expect(largest(ReactionPoses.still(name)) > 5).toBe(true)
			expect(duration <= 4).toBe(true) -- G13.8: the server holds the citizen at most 4 s after Choose
		end
	end)

	it("tones map to Bubbles.POSE, and every pose the game asks for is a reaction or a work action", function()
		for tone, pose in Bubbles.POSE do
			expect(ReactionPoses.forTone(tone)).toBe(pose)
			expect(ReactionPoses.has(pose)).toBe(true)
		end
		expect(ReactionPoses.forTone("ecstatic")).toBe(Bubbles.POSE.neutral)
		expect(ReactionPoses.forTone(nil)).toBe(Bubbles.POSE.neutral)
		for cue, spec in Vfx.cues do
			if spec.pose and not ReactionPoses.has(spec.pose) and not WORK_ACTIONS[spec.pose] then
				error(`cue {cue}: pose {spec.pose} is neither a reaction pose nor a work action`)
			end
		end
	end)

	it("unknown names give nil, a NaN time rests, and `out` is filled in place", function()
		expect(ReactionPoses.sample("dance", 1)).toBeNil()
		expect(ReactionPoses.still("dance")).toBeNil()
		expect(ReactionPoses.has(42)).toBe(false)
		expect(largest(ReactionPoses.sample("cheer", 0 / 0))).toBe(0)
		local out = {}
		expect(ReactionPoses.sample("bow", 0.8, out)).toBe(out)
		expect(largest(out) > 5).toBe(true)
		expect(ReactionPoses.rest(out)).toBe(out)
		expect(largest(out)).toBe(0)
	end)
end)

describe("FeedbackPoseController (FL-0100, G13.8 portrait)", function()
	local env, calls, logs

	local function load(extra)
		local defs = extra or {}
		table.insert(defs, FeedbackPoseDef)
		local poses = Loader.load(env, defs):get("FeedbackPoseController")
		poses.posePortrait = function(portrait, joints)
			table.insert(calls, { portrait = portrait, size = largest(joints) })
		end
		return poses
	end

	beforeEach(function()
		env = MockEnv.new({ seed = 100, isServer = false, localPlayer = { userId = 1001 } })
		calls = {}
		logs = env.mock.logs
	end)

	it("plays a tone's pose on the portrait, frame by frame, then rests", function()
		local poses = load()
		local portrait = { name = "portrait" }
		expect(poses:playPortrait(portrait, "happy")).toBe(true)
		expect(poses.playing[portrait].name).toBe("cheer")
		poses:step(0.6)
		expect(calls[#calls].size > 5).toBe(true)
		poses:step(0.6)
		poses:step(1)
		expect(poses.playing[portrait]).toBeNil()
		expect(calls[#calls].size).toBe(0) -- back to rest
		local count = #calls
		poses:step(1)
		expect(#calls).toBe(count) -- nothing more once it ended
		expect(poses:playPortrait(portrait, "bow")).toBe(true) -- a pose name works too
		expect(poses.playing[portrait].name).toBe("bow")
	end)

	it("reduced motion holds the key pose without movement until it is stopped", function()
		local poses = load({
			{
				name = "SettingsController",
				new = function()
					return {
						reducedMotion = function()
							return true
						end,
					}
				end,
			},
		})
		local portrait = {}
		poses:playPortrait(portrait, "sad")
		expect(poses.playing[portrait].held).toBe(true)
		expect(calls[1].size > 5).toBe(true) -- the key pose at once
		poses:step(5)
		expect(#calls).toBe(1) -- no movement
		poses:stopPortrait(portrait)
		expect(calls[2].size).toBe(0)
		expect(poses.playing[portrait]).toBeNil()
	end)

	it(
		"follows the talking citizen: its reaction tone and pose cues play on FORGE-03's portrait; closing rests it",
		function()
			local model = { name = "stage portrait" }
			local conversation =
				{ opened = Signal.new(), closed = Signal.new(), stage = { portrait = { model = model } } }
			local entities = { event = Signal.new() }
			local poses = load({
				{
					name = "ConversationController",
					new = function()
						return conversation
					end,
				},
				{
					name = "EntityController",
					new = function()
						return entities
					end,
				},
			})
			entities.event:fire(7, "reaction", { text = "Hm.", tone = "angry" })
			expect(next(poses.playing)).toBeNil() -- no conversation open: the world rig's business only
			conversation.opened:fire(7, Vector3.zero)
			entities.event:fire(8, "reaction", { text = "Hooray", tone = "happy" }) -- another citizen
			expect(next(poses.playing)).toBeNil()
			entities.event:fire(7, "reaction", { text = "Hm.", tone = "angry" })
			expect(poses.playing[model].name).toBe("grumble")
			entities.event:fire(nil, "bow", { entityIds = { 3, 7 } }) -- a consequence cue naming them
			expect(poses.playing[model].name).toBe("bow")
			entities.event:fire(7, "hammer", {}) -- a work cue: not a reaction pose
			expect(poses.playing[model].name).toBe("bow")
			conversation.closed:fire(7)
			expect(next(poses.playing)).toBeNil()
			expect(calls[#calls].size).toBe(0) -- rested
			expect(poses.talking).toBeNil()
			env.RunService.Heartbeat:Fire(0.5) -- live frames reach step(): nothing is left to play
			expect(next(poses.playing)).toBeNil()
		end
	)

	it("without FORGE-02's Kit.posePortrait it plays nothing and warns once", function()
		local poses = load()
		poses.posePortrait = nil
		expect(poses:playPortrait({}, "happy")).toBe(false)
		expect(poses:playPortrait({}, "angry")).toBe(false)
		local warned = 0
		for _, entry in logs do
			if entry.level == "warn" and string.find(entry.message, "posePortrait", 1, true) then
				warned += 1
			end
		end
		expect(warned).toBe(1)
		expect(next(poses.playing)).toBeNil()
	end)
end)
