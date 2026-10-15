--!strict
--[[
	Sim/Pose — procedural animation maths for Kit.character rigs (CONTRACTS G4 rendering, D-026).
	Pure: CFrame maths only, no instances, deterministic.

	Joints are the Motor6Ds Kit.character creates, named after the moving part:
		Torso (Root -> Torso, at the hips), Head, LeftArm, RightArm, LeftLeg, RightLeg (Torso -> part),
		Tool (RightArm -> Tool; absent on idle rigs).
	Each value is a Motor6D.Transform: a rotation (plus a small lift for Torso) in the joint frame.
	Kit builds every joint axis-aligned, so X = right, Y = up, Z = back (the rig faces -Z):
		Rx(+a) swings an arm or leg forward and tilts the head up; Rx(-a) leans the torso forward.
	The legs hang off the torso, so a torso lean is cancelled on the legs to keep them upright.

	API
		Pose.sample(action, job, phase, speed, out?): { [joint]: CFrame }
			action  SnapshotCodec.ACTIONS (unknown -> idle); job G2 JobId (unknown -> generic work)
			phase   cycles; every pose is periodic with period 1 in phase
			speed   horizontal studs/s (walk, carry and flee legs swing with it; 0 = standing)
			out     optional table to fill (no allocation per frame); returned
		Pose.rate(action, job, speed): number   -- cycles per second; the caller advances
		                                           phase += dt * rate, so speed changes never jump
		Pose.blend(from, to, alpha, out?)       -- per-joint CFrame:Lerp (e.g. falling into "dead")
		Pose.workStyle(job): "chop" | "mine" | "hammer" | "harvest" | "generic"
		Pose.JOINTS, Pose.LIMITS (max rotation per joint, degrees), Pose.WALK_REF_SPEED, Pose.STRIDE
	Bounds: every rotation stays within Pose.LIMITS. Arms reach 150° only in "celebrate" (arms up);
	every other joint and action stays within 90°. Torso lift stays within ±2 studs.
	Celebrate: both arms up for rigs with nothing in the right fist (idle citizens) or a sack on the back
	(hauler). Every other job keeps the tool arm lower (120° + the pump) and tips the tool back to the Tool
	joint's limit, so no tool goes through the head: tests/sim/PoseClearance.spec measures it on Kit rigs.
]]

local Pose = {}

Pose.JOINTS = table.freeze({ "Torso", "Head", "LeftArm", "RightArm", "LeftLeg", "RightLeg", "Tool" })
Pose.LIMITS = table.freeze({
	Torso = 90,
	Head = 30,
	LeftArm = 150,
	RightArm = 150,
	LeftLeg = 90,
	RightLeg = 90,
	Tool = 45,
})
Pose.WALK_REF_SPEED = 12 -- studs/s at which the walk swing is full
Pose.STRIDE = 6 -- studs travelled per walk cycle (two steps)
Pose.MAX_WALK_RATE = 3 -- cycles/s

export type Joints = { [string]: CFrame }

local TAU = 2 * math.pi
local rad = math.rad
local IDENTITY = CFrame.new()
local DEAD_LIFT = -1.7 -- hips (2.2 studs up) down to a body lying on its back

local WORK_STYLE: { [string]: string } = {
	woodcutter = "chop",
	miner = "mine",
	builder = "hammer",
	farmer = "harvest",
}
local WORK_RATE: { [string]: number } = { chop = 0.9, mine = 0.8, hammer = 1.6, harvest = 0.6, generic = 0.7 }
local FIXED_RATE: { [string]: number } = { idle = 1 / 3.5, fight = 1.4, celebrate = 1.2, dead = 0 }

local function rx(deg: number): CFrame
	return CFrame.Angles(rad(deg), 0, 0)
end

local function ry(deg: number): CFrame
	return CFrame.Angles(0, rad(deg), 0)
end

local function rz(deg: number): CFrame
	return CFrame.Angles(0, 0, rad(deg))
end

local function clamp01(x: number): number
	return math.clamp(x, 0, 1)
end

function Pose.workStyle(job: string): string
	return WORK_STYLE[job] or "generic"
end

-- Walk swing amplitude factor: 0 standing, 1 at WALK_REF_SPEED and above.
local function stride(speed: number): number
	return clamp01((if speed == speed then speed else 0) / Pose.WALK_REF_SPEED)
end

function Pose.rate(action: string, job: string, speed: number): number
	if action == "walk" or action == "carry" or action == "flee" then
		local s = if speed == speed then math.max(speed, 0) else 0
		return math.min(s / Pose.STRIDE, Pose.MAX_WALK_RATE)
	elseif action == "work" then
		return WORK_RATE[Pose.workStyle(job)]
	end
	return FIXED_RATE[action] or FIXED_RATE.idle
end

-- Torso: lean forward (degrees, + = forward), twist (yaw) and lift (studs).
local function torso(lean: number, twist: number, lift: number): CFrame
	return CFrame.new(0, lift, 0) * ry(twist) * rx(-lean)
end

-- Legs swing opposite each other and cancel the torso lean so the feet stay under the body.
local function legs(out: Joints, swing: number, lean: number, spread: number?)
	local s = spread or 0
	out.LeftLeg = rx(swing + lean) * rz(-s)
	out.RightLeg = rx(-swing + lean) * rz(s)
end

local function idle(out: Joints, s: number, c: number)
	out.Torso = IDENTITY
	out.Head = ry(6 * s) * rx(2 * c)
	out.LeftArm = rz(-(3 + 2 * s))
	out.RightArm = rz(3 + 2 * s)
	legs(out, 0, 0)
	out.Tool = IDENTITY
end

local function walk(out: Joints, s: number, c2: number, speed: number, maxSwing: number, lean: number)
	local k = stride(speed)
	local swing = maxSwing * k * s
	out.Torso = torso(lean * k, 4 * k * s, 0.1 * k * (1 - c2) / 2)
	out.Head = rx(lean * k * 0.5)
	out.LeftArm = rx(-0.8 * swing)
	out.RightArm = rx(0.8 * swing)
	legs(out, swing, lean * k)
	out.Tool = IDENTITY
end

local function carry(out: Joints, s: number, c2: number, speed: number)
	local k = stride(speed)
	local swing = 35 * k * s
	out.Torso = torso(0, 0, 0.08 * k * (1 - c2) / 2)
	out.Head = IDENTITY
	out.LeftArm = rx(70) * rz(10)
	out.RightArm = rx(70) * rz(-10)
	legs(out, swing, 0)
	out.Tool = IDENTITY
end

local function work(out: Joints, style: string, s: number, c: number)
	local lean, twist = 0, 0
	if style == "chop" then
		lean, twist = 5 + 5 * c, -10 * s
		out.RightArm = rx(55 + 35 * c)
		out.LeftArm = rx(40 + 25 * c)
		out.Tool = rx(15 * c)
	elseif style == "mine" then
		lean = 10 - 8 * c
		out.RightArm = rx(60 + 30 * c)
		out.LeftArm = rx(60 + 30 * c)
		out.Tool = IDENTITY
	elseif style == "hammer" then
		lean = 8
		out.RightArm = rx(50 + 30 * c)
		out.LeftArm = rx(25)
		out.Tool = rx(10 * c)
	elseif style == "harvest" then
		lean = 25 + 8 * s
		out.RightArm = rx(45 + 15 * c)
		out.LeftArm = rx(45 + 15 * c)
		out.Tool = IDENTITY
	else
		lean = 5
		out.RightArm = rx(30 + 10 * s)
		out.LeftArm = rx(30 - 10 * s)
		out.Tool = IDENTITY
	end
	out.Torso = torso(lean, twist, 0)
	out.Head = rx(-0.3 * lean)
	legs(out, 0, lean)
end

local function fight(out: Joints, s: number)
	out.Torso = torso(5, 15 * s, 0)
	out.Head = IDENTITY
	out.RightArm = rx(45 + 45 * s)
	out.LeftArm = rx(30)
	legs(out, 0, 5, 8)
	out.Tool = IDENTITY
end

-- Jobs that cheer with both arms straight up: no tool in the right fist (idle), or a sack on the back (hauler).
local CHEERS_EMPTY_HANDED: { [string]: boolean } = { idle = true, hauler = true }
local TOOL_CHEER_RAISE = 120 -- the tool arm's raise (degrees, plus the same 10 * s pump); the free arm stays at 140

local function celebrate(out: Joints, job: string, s: number, c: number)
	local raise = 140 + 10 * s
	out.Torso = torso(0, 0, 0.3 * (1 - c) / 2)
	out.Head = rx(10)
	out.LeftArm = rz(-raise)
	if CHEERS_EMPTY_HANDED[job] then
		out.RightArm = rz(raise)
		out.Tool = IDENTITY
	else
		-- a hoe, axe, pick, hammer or spear held up beside the head would go through it (B17: Sim/PoseClearance
		-- measures it): the tool arm stays lower and the tool tips back as far as its joint allows
		out.RightArm = rz(TOOL_CHEER_RAISE + 10 * s)
		out.Tool = rx(-Pose.LIMITS.Tool)
	end
	legs(out, 0, 0)
end

local function dead(out: Joints)
	out.Torso = CFrame.new(0, DEAD_LIFT, 0) * rx(90) -- on its back, face up
	out.Head = IDENTITY
	out.LeftArm = rz(-20)
	out.RightArm = rz(20)
	out.LeftLeg = rz(-8)
	out.RightLeg = rz(8)
	out.Tool = IDENTITY
end

function Pose.sample(action: string, job: string, phase: number, speed: number, out: Joints?): Joints
	local o: Joints = out or {}
	local p = if phase == phase and math.abs(phase) < math.huge then phase % 1 else 0
	local angle = TAU * p
	local s, c = math.sin(angle), math.cos(angle)
	local c2 = math.cos(2 * angle)
	if action == "walk" then
		walk(o, s, c2, speed, 40, 0)
	elseif action == "flee" then
		walk(o, s, c2, speed, 50, 12)
	elseif action == "carry" then
		carry(o, s, c2, speed)
	elseif action == "work" then
		work(o, Pose.workStyle(job), s, c)
	elseif action == "fight" then
		fight(o, s)
	elseif action == "celebrate" then
		celebrate(o, job, s, c)
	elseif action == "dead" then
		dead(o)
	else
		idle(o, s, c)
	end
	return o
end

function Pose.blend(from: Joints, to: Joints, alpha: number, out: Joints?): Joints
	local o: Joints = out or {}
	local a = clamp01(alpha)
	for _, joint in Pose.JOINTS do
		local a0, b0 = from[joint] or IDENTITY, to[joint] or IDENTITY
		o[joint] = a0:Lerp(b0, a)
	end
	return o
end

return table.freeze(Pose)
