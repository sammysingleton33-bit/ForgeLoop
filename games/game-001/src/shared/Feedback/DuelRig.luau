--!strict
--[[
	Feedback/DuelRig (game-001, FORGE-04, FL-0141): writes a Feedback/DuelPoses sample to a champion's
	joints. Client only (FeedbackDuelController); a joint's Transform is not replicated, so every client
	poses both champions itself.

	Rigs, found by the part each joint moves (Motor6D.Part1, or AnimationConstraint.Attachment1's part):
		kit   Kit.character and its mesh rig (no Humanoid): Torso, Head, LeftArm, RightArm, LeftLeg,
		      RightLeg, Tool (Sim/Pose.JOINTS). The rig is ours: Root and Waist both go to its Torso joint,
		      every joint is written every frame, and the base is the rest pose.
		r15   a Roblox avatar: Root (LowerTorso), Waist (UpperTorso), Neck, the shoulders, the hips and
		      RightWrist (Tool: the held weapon's angle).
		r6    a Roblox avatar: RootJoint (Torso, which takes Root and Waist), Neck, shoulders and hips. R6
		      has no wrist, so its weapon keeps the arm's angle.
		R15 avatars may carry AnimationConstraints instead of Motor6Ds (the Avatar Joint Upgrade); both
		have a Transform, and both are found the same way (unverified in Studio: E21 step 1 prints the
		rig).
	On an avatar the Animator writes the joints every frame before RunService.PreSimulation; the
	controller calls apply in PreSimulation, so the pose is laid over the Animator's: each joint becomes
	base:Lerp(pose, weight), where base is the Animator's value this frame. `body` weighs Root and the
	legs: 0 keeps the avatar's own walk on its legs (an upper-body swing), 1 poses them too (a dodge, a
	stagger, the kneel). When a joint still holds what we wrote last frame (within 1e-4), nothing
	else writes it, and the base is the rest pose instead.
	The legs hang from the hips, which Root moves, so each leg is written as Root's rotation undone, then
	its own pose: the feet stay planted under a lean (kit and r6 undo Root and Waist together).
	Each joint's own rest rotation (Motor6D.C0, or Attachment0's) frames the pose, so R6's turned joints
	move the same way as R15's. Root's offsets (lift, sidestep) scale with the rig's leg length
	(Humanoid.HipHeight on R15; 2 studs on R6; Kit's hips are 2.2 studs up).

	API
		DuelRig.scan(model) -> Rig?          nil when the model has none of these joints
		DuelRig.apply(rig, out, adapter?)    out = DuelPoses track:sample's { pose, weight, body }
		DuelRig.release(rig, adapter?)       an avatar's joints back to the Animator; a Kit rig at rest
		DuelRig.leftShield(model) -> boolean the model wears Kit.shield (an Accessory carrying KitShield) on the
		                                     left hand; a shield on the weapon (Kit.weapon's default Tool) is not
		Rig = { kind: "kit" | "r15" | "r6", joints: { [name]: { joint, rest } }, scale, model, class, count }
		    class: "Motor6D" or "AnimationConstraint" (the joints' kind); count: the joints found
		adapter = { get(joint) -> CFrame, set(joint, CFrame) } (specs); default: joint.Transform
]]

local DuelRig = {}

export type Joint = { joint: any, rest: CFrame, last: CFrame? }
export type Rig = { kind: string, joints: { [string]: Joint }, scale: number, model: any, class: string, count: number }
export type Adapter = { get: (joint: any) -> CFrame, set: (joint: any, value: CFrame) -> () }

DuelRig.KIT_HIP = 2.2 -- studs: Kit's Torso joint above the ground (Kit/Character HIP_Y)
DuelRig.R6_LEG = 2 -- studs: an R6 leg

-- the moving part's name -> our joint
DuelRig.PARTS = table.freeze({
	-- Kit (Motor6Ds named after the moving part, Sim/Pose.JOINTS) and R6 (Torso is RootJoint's part)
	Torso = "Torso",
	Head = "Head",
	LeftArm = "LeftArm",
	RightArm = "RightArm",
	LeftLeg = "LeftLeg",
	RightLeg = "RightLeg",
	Tool = "Tool",
	-- R15
	LowerTorso = "Root",
	UpperTorso = "Waist",
	LeftUpperArm = "LeftArm",
	RightUpperArm = "RightArm",
	LeftUpperLeg = "LeftLeg",
	RightUpperLeg = "RightLeg",
	RightHand = "Tool", -- RightWrist: the held weapon's angle (the Tool's RightGrip rides the hand)
	-- R6
	["Left Arm"] = "LeftArm",
	["Right Arm"] = "RightArm",
	["Left Leg"] = "LeftLeg",
	["Right Leg"] = "RightLeg",
})

local IDENTITY = CFrame.new()

local DEFAULT_ADAPTER: Adapter = {
	get = function(joint: any): CFrame
		return joint.Transform
	end,
	set = function(joint: any, value: CFrame)
		joint.Transform = value
	end,
}

local function isA(instance: any, class: string): boolean
	local ok, result = pcall(function()
		return instance:IsA(class)
	end)
	return ok and result == true
end

-- The joint's moving part and its rest rotation, for a Motor6D or an AnimationConstraint; nil otherwise.
local function describe(instance: any): (any, CFrame?)
	if isA(instance, "Motor6D") then
		local ok, part, c0 = pcall(function()
			return instance.Part1, instance.C0
		end)
		if ok and part ~= nil and typeof(c0) == "CFrame" then
			return part, c0.Rotation
		end
	elseif isA(instance, "AnimationConstraint") then
		local ok, part, frame = pcall(function()
			local a0, a1 = instance.Attachment0, instance.Attachment1
			return a1 and a1.Parent, a0 and a0.CFrame
		end)
		if ok and part ~= nil then
			return part, if typeof(frame) == "CFrame" then frame.Rotation else IDENTITY
		end
	end
	return nil, nil
end

function DuelRig.scan(model: any): Rig?
	if model == nil then
		return nil
	end
	local ok, descendants = pcall(function()
		return model:GetDescendants()
	end)
	if not ok or type(descendants) ~= "table" then
		return nil
	end
	local joints: { [string]: Joint } = {}
	local humanoid = nil
	local class, count = "", 0
	for _, instance in descendants do
		if isA(instance, "Humanoid") then
			humanoid = instance
		else
			local part, rest = describe(instance)
			local name = if part ~= nil then DuelRig.PARTS[part.Name] else nil
			if name ~= nil and joints[name] == nil then
				joints[name] = { joint = instance, rest = rest :: CFrame }
				count += 1
				class = if isA(instance, "AnimationConstraint") then "AnimationConstraint" else "Motor6D"
			end
		end
	end
	if next(joints) == nil then
		return nil
	end
	local kind = if joints.Waist ~= nil or joints.Root ~= nil then "r15" elseif humanoid ~= nil then "r6" else "kit"
	local scale = 1
	if kind == "r15" then
		local hip = if humanoid ~= nil then humanoid.HipHeight else 0
		scale = if type(hip) == "number" and hip > 0 then hip / DuelRig.KIT_HIP else 1
	elseif kind == "r6" then
		scale = DuelRig.R6_LEG / DuelRig.KIT_HIP
	end
	return { kind = kind, joints = joints, scale = scale, model = model, class = class, count = count }
end

-- Our own last write, read back? Within 1e-4 (studs, radians): an engine may store a Transform at a
-- lower precision than the value written (Lune does), so exact equality would never match.
local function same(a: CFrame, b: CFrame?): boolean
	if b == nil then
		return false
	end
	local d = a:Inverse() * b
	local _, turned = d:ToAxisAngle()
	return d.Position.Magnitude < 1e-4 and math.abs(turned) < 1e-4
end
DuelRig.same = same

local function scaled(cframe: CFrame, scale: number): CFrame
	if scale == 1 then
		return cframe
	end
	return CFrame.new(cframe.Position * scale) * cframe.Rotation
end

local function write(entry: Joint?, value: CFrame, weight: number, owned: boolean, adapter: Adapter)
	if entry == nil then
		return
	end
	if not owned and weight <= 0 then
		entry.last = nil -- the Animator's alone: never write over it, even its own value
		return
	end
	local framed = entry.rest:Inverse() * value * entry.rest
	local base = IDENTITY
	if not owned then
		local ok, current = pcall(adapter.get, entry.joint)
		if ok and typeof(current) == "CFrame" and not same(current, entry.last) then
			base = current -- the Animator's value this frame
		end
	end
	local result = if weight >= 1 then framed else base:Lerp(framed, math.clamp(weight, 0, 1))
	pcall(adapter.set, entry.joint, result)
	entry.last = result
end

-- Kit.shield worn on the left hand (FL-0141 follow-up 3): an Accessory carrying KitShield, wherever it is
-- parented (an avatar's AddAccessory puts it on the character; the AI figure may weld it under a part). The
-- sword-and-shield's default Tool also carries KitShield, but a Tool is the right hand's: not counted. No
-- model (nil) wears none.
function DuelRig.leftShield(model: any): boolean
	local ok, found = pcall(function()
		for _, d in model:GetDescendants() do
			if d:IsA("Accessory") and d:GetAttribute("KitShield") ~= nil then
				return true
			end
		end
		return false
	end)
	return ok and found == true
end

function DuelRig.apply(rig: Rig, out: any, adapter: Adapter?)
	local io = adapter or DEFAULT_ADAPTER
	local pose, weight, body = out.pose, out.weight or 0, out.body or 0
	if pose == nil then
		return
	end
	local joints = rig.joints
	local root = scaled(pose.Root, rig.scale)
	if rig.kind == "kit" then
		-- ours alone: every joint, over the rest pose
		local torso = root * pose.Waist
		local undo = torso.Rotation:Inverse()
		write(joints.Torso, torso, weight, true, io)
		write(joints.LeftLeg, undo * pose.LeftLeg, weight, true, io)
		write(joints.RightLeg, undo * pose.RightLeg, weight, true, io)
		write(joints.Tool, pose.Tool, weight, true, io)
	elseif rig.kind == "r15" then
		local undo = root.Rotation:Inverse()
		write(joints.Root, root, weight * body, false, io)
		write(joints.Waist, pose.Waist, weight, false, io)
		write(joints.Tool, pose.Tool, weight, false, io)
		write(joints.LeftLeg, undo * pose.LeftLeg, weight * body, false, io)
		write(joints.RightLeg, undo * pose.RightLeg, weight * body, false, io)
	else -- r6: no waist; the torso moves only in a whole-body animation
		local torso = root * pose.Waist
		local undo = torso.Rotation:Inverse()
		write(joints.Torso, torso, weight * body, false, io)
		write(joints.LeftLeg, undo * pose.LeftLeg, weight * body, false, io)
		write(joints.RightLeg, undo * pose.RightLeg, weight * body, false, io)
	end
	local owned = rig.kind == "kit"
	write(joints.Head, pose.Head, weight, owned, io)
	write(joints.LeftArm, pose.LeftArm, weight, owned, io)
	write(joints.RightArm, pose.RightArm, weight, owned, io)
end

-- Done with the rig: a Kit rig goes back to rest; an avatar's joints are left to its Animator (a joint
-- nothing else writes, still holding our last value, goes back to rest).
function DuelRig.release(rig: Rig, adapter: Adapter?)
	local io = adapter or DEFAULT_ADAPTER
	for _, entry in rig.joints do
		if entry.last ~= nil then
			local ok, current = pcall(io.get, entry.joint)
			if rig.kind == "kit" or (ok and typeof(current) == "CFrame" and same(current, entry.last)) then
				pcall(io.set, entry.joint, IDENTITY)
			end
			entry.last = nil
		end
	end
end

return DuelRig
