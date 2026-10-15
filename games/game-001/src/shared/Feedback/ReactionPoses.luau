--!strict
--[[
	Feedback/ReactionPoses (game-001, FORGE-04, FL-0100 (2/2); CONTRACTS G13.8): what a citizen's body
	does for a reaction, on the conversation portrait and on the world rig. Pure CFrame maths in the
	Sim/Pose joint format ({ [joint]: CFrame }, Motor6D.Transform values), so one sample poses both:
		portrait   Kit.posePortrait(portrait, ReactionPoses.sample(name, t))     (FORGE-02, G13.8)
		world rig  EntityController:playPose(entityId, name) samples it over its own pose (FORGE-01,
		           proposed; CitizenBubbleController already asks for it on every reaction and cue)

	Names: the reaction poses of Bubbles.POSE (tone → cheer, grumble, slump, salute) and the gesture
	cues of config Vfx.cues (bow, cower; celebrate → cheer, strike_placard → grumble). The work cues
	(work_fast, hammer, rest) are actions of EntityController's own loop, not reactions: has() is false.

	API
		ReactionPoses.NAMES                         every reaction pose, sorted
		ReactionPoses.has(name) -> boolean
		ReactionPoses.forTone(tone) -> string       Bubbles.POSE (an unknown tone → neutral's pose)
		ReactionPoses.DURATION[name] -> seconds     the whole gesture, easing in and out included (≤ 4 s,
		                                            well inside the hold after Choose: until EndConversation,
		                                            at most 12 s, CONTRACTS v0.4-g9f)
		ReactionPoses.sample(name, t, out?) -> Joints?
		    t = seconds since the gesture started. Rest (every joint identity) at t ≤ 0 and t ≥
		    DURATION; eases in over EASE_IN and out over EASE_OUT. nil for an unknown name.
		ReactionPoses.still(name, out?) -> Joints?  the held key pose with no movement (reduced motion)
		ReactionPoses.rest(out?) -> Joints          every joint at identity (the end of a gesture)
	Bounds: every joint stays within Sim/Pose LIMITS, and the torso lift within ±2 studs (spec).
	Joint frame (Sim/Pose): X right, Y up, Z back; Rx(+a) swings a limb forward and tilts the head up,
	Rx(-a) leans the torso forward; Rz(-a) raises the left arm sideways, Rz(+a) the right one. A torso
	lean is cancelled on the legs, so the feet stay planted.
]]

local Bubbles = require("./Bubbles")

local ReactionPoses = {}

export type Joints = { [string]: CFrame }

ReactionPoses.EASE_IN = 0.25
ReactionPoses.EASE_OUT = 0.35
ReactionPoses.DURATION = table.freeze({
	cheer = 1.8,
	grumble = 1.6,
	slump = 2.0,
	salute = 1.4,
	bow = 1.6,
	cower = 1.8,
})

local IDENTITY = CFrame.new()
local TAU = 2 * math.pi
local rad = math.rad

local function rx(deg: number): CFrame
	return CFrame.Angles(rad(deg), 0, 0)
end

local function ry(deg: number): CFrame
	return CFrame.Angles(0, rad(deg), 0)
end

local function rz(deg: number): CFrame
	return CFrame.Angles(0, 0, rad(deg))
end

-- A torso lean (degrees forward) with the legs straightened back under it.
local function lean(out: Joints, forward: number, lift: number?)
	out.Torso = CFrame.new(0, lift or 0, 0) * rx(-forward)
	out.LeftLeg = rx(forward)
	out.RightLeg = rx(forward)
end

-- Key poses at time t (seconds); `motion` 0 freezes the periodic part (reduced motion).
local KEYS: { [string]: (out: Joints, t: number, motion: number) -> () } = {
	-- both arms up and waving, a small hop
	cheer = function(out, t, motion)
		local wave = motion * math.sin(TAU * 1.5 * t)
		lean(out, 0, 0.15 * motion * math.max(0, math.sin(TAU * 1.5 * t)))
		out.Head = rx(12)
		out.LeftArm = rz(-(132 + 10 * wave))
		out.RightArm = rz(132 - 10 * wave)
	end,
	-- arms folded in front, head shaking
	grumble = function(out, t, motion)
		lean(out, -4) -- leans back a little
		out.Head = rx(-6) * ry(14 * motion * math.sin(TAU * 1.8 * t))
		out.LeftArm = rx(55) * rz(28)
		out.RightArm = rx(55) * rz(-28)
	end,
	-- shoulders drop, head hangs, a slow sigh
	slump = function(out, t, motion)
		local sigh = motion * 0.5 * (1 - math.cos(TAU * 0.5 * t))
		lean(out, 14 + 4 * sigh)
		out.Head = rx(-24 - 4 * sigh)
		out.LeftArm = rx(6) * rz(4)
		out.RightArm = rx(6) * rz(-4)
	end,
	-- right hand to the brow, standing straight
	salute = function(out, _t, _motion)
		lean(out, -2)
		out.Head = rx(4)
		out.LeftArm = IDENTITY
		out.RightArm = rx(140) * rz(-32)
	end,
	-- a bow from the hips, down and back up
	bow = function(out, t, motion)
		local depth = if motion > 0 then math.sin(math.pi * math.clamp(t / ReactionPoses.DURATION.bow, 0, 1)) else 1
		lean(out, 38 * depth)
		out.Head = rx(-12 * depth)
		out.LeftArm = rx(8 * depth)
		out.RightArm = rx(8 * depth)
	end,
	-- crouched, arms over the face, trembling
	cower = function(out, t, motion)
		local shake = motion * math.sin(TAU * 7 * t)
		lean(out, 22, -0.25)
		out.Torso = out.Torso * rz(2 * shake)
		out.Head = rx(-22)
		out.LeftArm = rx(128) * rz(26)
		out.RightArm = rx(128) * rz(-26)
	end,
}

ReactionPoses.NAMES = (function()
	local names = {}
	for name in KEYS do
		table.insert(names, name)
	end
	table.sort(names)
	return table.freeze(names)
end)()

function ReactionPoses.has(name: any): boolean
	return type(name) == "string" and KEYS[name] ~= nil
end

function ReactionPoses.forTone(tone: any): string
	return (if type(tone) == "string" then Bubbles.POSE[tone] else nil) or Bubbles.POSE.neutral
end

local function smooth(x: number): number
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

local function rest(out: Joints): Joints
	out.Torso, out.Head, out.LeftArm, out.RightArm = IDENTITY, IDENTITY, IDENTITY, IDENTITY
	out.LeftLeg, out.RightLeg = IDENTITY, IDENTITY
	return out
end

function ReactionPoses.rest(out: Joints?): Joints
	return rest(out or {})
end

function ReactionPoses.sample(name: string, t: number, out: Joints?): Joints?
	local key = KEYS[name]
	if key == nil then
		return nil
	end
	local target = rest(out or {})
	local duration = ReactionPoses.DURATION[name]
	if t ~= t or t <= 0 or t >= duration then
		return target
	end
	local weight = math.min(smooth(t / ReactionPoses.EASE_IN), smooth((duration - t) / ReactionPoses.EASE_OUT))
	key(target, t, 1)
	if weight < 1 then
		for joint, cf in target do
			target[joint] = IDENTITY:Lerp(cf, weight)
		end
	end
	return target
end

function ReactionPoses.still(name: string, out: Joints?): Joints?
	local key = KEYS[name]
	if key == nil then
		return nil
	end
	local target = rest(out or {})
	key(target, ReactionPoses.DURATION[name] / 2, 0)
	return target
end

return table.freeze(ReactionPoses)
