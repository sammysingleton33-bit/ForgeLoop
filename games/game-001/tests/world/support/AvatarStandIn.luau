--[[
	Stand-in R15 and R6 avatars for the Kit gear specs and the arena preview dump (FL-0072, FORGE-02): blocky limbs and the
	attachment names Roblox rigs carry (HatAttachment, BodyFrontAttachment, BodyBackAttachment, LeftCollarAttachment,
	RightCollarAttachment, RightGripAttachment), at approximate positions. This is NOT a Studio check: it follows the
	Roblox attachment reference; nobody has seen the gear on a real rig yet.

	Avatar.wear(accessory, avatar) does what Humanoid:AddAccessory does: Handle.CFrame = body attachment (world) *
	accessory attachment:Inverse(), the welded parts follow. Avatar.hold(tool, avatar) puts a Tool's Handle in the right
	hand with the arm forward (Handle at hand * Grip:Inverse(): blade up, front -Z for Kit weapons), the pose an equipped Tool gets.
]]

export type Avatar = {
	rigType: string,
	model: Model,
	attachments: { [string]: Attachment },
	parts: { [string]: BasePart },
	hand: Vector3, -- where the right fist is when the arm points forward
}

local Avatar = {}

local SKIN = Color3.fromRGB(242, 201, 160)
local CLOTH = Color3.fromRGB(86, 94, 108)
local TROUSERS = Color3.fromRGB(60, 64, 72)

function Avatar.build(rigType: string, at: CFrame?): Avatar
	local origin = at or CFrame.new()
	local m = Instance.new("Model")
	m.Name = rigType
	local atts: { [string]: Attachment } = {}
	local byRole: { [string]: BasePart } = {}
	local function part(name: string, role: string?, size: Vector3, pos: Vector3, color: Color3?): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = origin * CFrame.new(pos)
		p.Color = color or CLOTH
		p.Anchored = true
		p.Parent = m
		if role then
			byRole[role] = p
		end
		return p
	end
	local function att(p: Part, name: string, at_: Vector3)
		local a = Instance.new("Attachment")
		a.Name = name
		a.CFrame = CFrame.new(at_)
		a.Parent = p
		atts[name] = a
	end
	local hand: Vector3
	if rigType == "R15" then
		part("LeftLeg", nil, Vector3.new(0.95, 2.0, 1), Vector3.new(-0.5, 1.0, 0), TROUSERS)
		part("RightLeg", nil, Vector3.new(0.95, 2.0, 1), Vector3.new(0.5, 1.0, 0), TROUSERS)
		part("LowerTorso", nil, Vector3.new(2, 0.4, 1), Vector3.new(0, 2.2, 0), TROUSERS)
		local upper = part("UpperTorso", "torso", Vector3.new(2, 1.6, 1), Vector3.new(0, 3.2, 0))
		local head = part("Head", "head", Vector3.new(1.2, 1.2, 1.2), Vector3.new(0, 4.6, 0), SKIN)
		part("LeftArm", "leftArm", Vector3.new(0.95, 2.0, 0.95), Vector3.new(-1.5, 3.1, 0), CLOTH)
		-- the right arm points forward (an equipped Tool's pose): shoulder at (1.5, 3.9), hand 2 studs ahead
		local arm = part("RightArm", "rightArm", Vector3.new(0.95, 0.95, 2.0), Vector3.new(1.5, 3.9, -1.0), CLOTH)
		att(upper, "BodyBackAttachment", Vector3.new(0, 0.2, 0.5))
		att(upper, "BodyFrontAttachment", Vector3.new(0, 0.2, -0.5))
		att(upper, "LeftCollarAttachment", Vector3.new(-1, 0.8, 0))
		att(upper, "RightCollarAttachment", Vector3.new(1, 0.8, 0))
		att(head, "HatAttachment", Vector3.new(0, 0.6, 0))
		att(arm, "RightGripAttachment", Vector3.new(0, 0, -1.0))
		hand = Vector3.new(1.5, 3.9, -2.0)
	else
		part("LeftLeg", nil, Vector3.new(1, 2, 1), Vector3.new(-0.5, 1, 0), TROUSERS)
		part("RightLeg", nil, Vector3.new(1, 2, 1), Vector3.new(0.5, 1, 0), TROUSERS)
		local torso = part("Torso", "torso", Vector3.new(2, 2, 1), Vector3.new(0, 3, 0))
		local head = part("Head", "head", Vector3.new(2, 1, 1), Vector3.new(0, 4.5, 0), SKIN)
		part("Left Arm", "leftArm", Vector3.new(1, 2, 1), Vector3.new(-1.5, 3, 0), CLOTH)
		local arm = part("Right Arm", "rightArm", Vector3.new(1, 1, 2), Vector3.new(1.5, 3.5, -1.0), CLOTH)
		att(torso, "BodyBackAttachment", Vector3.new(0, 0, 0.5))
		att(torso, "BodyFrontAttachment", Vector3.new(0, 0, -0.5))
		att(torso, "LeftCollarAttachment", Vector3.new(-1, 1, 0))
		att(torso, "RightCollarAttachment", Vector3.new(1, 1, 0))
		att(head, "HatAttachment", Vector3.new(0, 0.6, 0))
		att(arm, "RightGripAttachment", Vector3.new(0, 0, -1.0))
		hand = Vector3.new(1.5, 3.5, -2.0)
	end
	return { rigType = rigType, model = m, attachments = atts, parts = byRole, hand = origin:PointToWorldSpace(hand) }
end

-- Humanoid:AddAccessory: returns the body attachment name it used (nil when the avatar has none of the accessory's).
function Avatar.wear(acc: Accessory, avatar: Avatar): string?
	local handle = acc:FindFirstChild("Handle") :: BasePart
	for _, a in handle:GetChildren() do
		if a:IsA("Attachment") and avatar.attachments[a.Name] then
			local body = avatar.attachments[a.Name]
			local target = (body.Parent :: BasePart).CFrame * body.CFrame * a.CFrame:Inverse()
			local delta = target * handle.CFrame:Inverse()
			for _, p in acc:GetDescendants() do
				if p:IsA("BasePart") and p ~= handle then
					p.CFrame = delta * p.CFrame
				end
			end
			handle.CFrame = target
			acc.Parent = avatar.model
			return a.Name
		end
	end
	return nil
end

-- An equipped Tool: the Handle sits at hand * Grip:Inverse() (the grip frame of the forward-raised arm is +Y up, -Z forward).
function Avatar.hold(tool: Tool, avatar: Avatar)
	local handle = tool:FindFirstChild("Handle") :: BasePart
	local target = CFrame.new(avatar.hand) * tool.Grip:Inverse()
	local delta = target * handle.CFrame:Inverse()
	for _, p in tool:GetDescendants() do
		if p:IsA("BasePart") then
			p.CFrame = delta * p.CFrame
		end
	end
	tool.Parent = avatar.model
end

return Avatar
