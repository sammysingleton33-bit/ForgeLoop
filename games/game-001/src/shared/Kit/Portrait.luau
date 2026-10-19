--!strict
--[[
	Kit/Portrait — Kit.portrait: a character rig for a UI ViewportFrame (CONTRACTS G13.8, D-036; FL-0098).

	Portrait.portrait(kind, job, kingdomColor, look?, kingdom?) -> Model
		Calls Kit.character's builder (CharacterMesh.character: the imported-mesh rig when the kit is imported, else
		Character.character) with the same arguments (never a copy of the rig code), so the portrait and
		the world rig look identical: the same parts (the part-built rig's ≤ 11, or the mesh rig's ≤ 16) with the same names, classes, sizes, colours,
		materials, CFrames, look and soldier crest, and the same attributes (KitKind, KitJob, KitLook,
		KitRootHeight; KitTint, KitHeadwear, KitTool). Portrait-only changes:
		- every part is Anchored: a still pose needs no WorldModel and no physics;
		- the Motor6Ds and the HairWeld stay as built (names, Part0/Part1, C0/C1), so poses still use them;
		- an Attachment "PortraitFocus" on the Root, and the model attribute KitPortrait = true.
		No scripts; nothing yields.

	Focus contract. PortraitFocus IS the camera: its world CFrame (Attachment.WorldCFrame, i.e. Root.CFrame *
	PortraitFocus.CFrame) is a camera pose in front of the face, looking at it (the rig faces -Z) from a
	little above, framing head and shoulders with the hair, hat, crown or crest uncropped. The framing is for a
	square ViewportFrame at the vertical field of view in the attachment attribute PortraitFov (Portrait.FOV =
	30, for Camera.FieldOfView); a wider frame shows more of the arms, a taller one crops their outer edges.
	PortraitDistance (attachment attribute) is the distance from the camera to the framed centre: move the
	camera along its LookVector to zoom. Tall or wide headwear (the crimson spire, the woodcutter's cap, the
	farmer's 3.4 straw disc) pulls the camera back, so the face is smaller there. The focus hangs off the Root, so a posed head moves inside a steady frame.
		local cf, fov = Kit.portraitCamera(portrait) -- reads the Root's current CFrame (after any PivotTo)
		camera.CFrame, camera.FieldOfView = cf, fov

	Poses (FORGE-04 reactions). Anchored parts ignore Motor6D.Transform. Portrait.pose(model, joints) places
	every part by forward kinematics through the rig's own motors, as the engine would with those Transforms
	(joints = { [motor name]: CFrame }, the Sim/Pose sample format; a missing joint rests), and welded headwear
	follows. It is absolute, not cumulative (call it each frame; {} restores the rest pose) and needs no
	WorldModel. Alternative: parent the portrait into a WorldModel, set Anchored = false on every part but the
	Root (the world rig's state), and drive Motor6D.Transform.
]]

local Character = require("./Character")
local CharacterMesh = require("./CharacterMesh")

local Portrait = {}

Portrait.FOV = 30 -- suggested vertical field of view (degrees) for a square ViewportFrame

local PITCH = math.rad(6) -- the camera sits a little above the face and looks down at it
local CHEST = 1.15 -- the frame's bottom edge below the shoulder line (top of the torso)
local HEADROOM = 0.45 -- above the highest point of the head or headwear (no hat or crest touches the edge)
local SHOULDER_PAD = 0.1 -- beyond the middle of the upper arms
local MARGIN = 1.08
local NEAR = 1.0 -- the face is about this much nearer the camera than the rig's centre plane
local HAT_NEAR = 1.15 -- a wide hat's near edge is closer to the camera than the shoulders: allow for its parallax

-- Highest point of a part's box (exact for the rig's upright and X-tilted primitives, conservative otherwise).
local function topOf(p: BasePart): number
	local cf, h = p.CFrame, p.Size / 2
	return cf.Position.Y
		+ math.abs(cf.RightVector.Y) * h.X
		+ math.abs(cf.UpVector.Y) * h.Y
		+ math.abs(cf.LookVector.Y) * h.Z
end

-- Half the width (X) of a part's box (exact for any rotation, like topOf).
local function halfWidthOf(p: BasePart): number
	local cf, h = p.CFrame, p.Size / 2
	return math.abs(cf.RightVector.X) * h.X + math.abs(cf.UpVector.X) * h.Y + math.abs(cf.LookVector.X) * h.Z
end

-- Camera pose (world) and its distance to the framed centre, for a rig in its rest pose.
local function frame(model: Model): (CFrame, number)
	local root = model.PrimaryPart :: BasePart
	local torso = model:FindFirstChild("Torso") :: BasePart
	local head = model:FindFirstChild("Head") :: BasePart
	local arm = model:FindFirstChild("RightArm") :: BasePart
	-- everything worn on the head: every part welded to it, directly or through other welds (never across a Motor6D): the hair
	-- or hat, a crown or helm crest, the D-048 detail parts (lamp, visor, pompom, the farmer's crown, the governor's velvet cap),
	-- an accessory, and on a mesh rig (Kit/CharacterMesh) any extra welded to the Head or to its hat
	local worn: { BasePart } = {}
	local reached: { [BasePart]: boolean } = { [head] = true }
	local queue: { BasePart } = { head }
	local welds: { Weld } = {}
	for _, d in model:GetDescendants() do
		if d:IsA("Weld") and not d:IsA("Motor6D") then
			table.insert(welds, d :: Weld)
		end
	end
	local at = 1
	while at <= #queue do
		local part = queue[at]
		at += 1
		for _, w in welds do
			local a, b = w.Part0, w.Part1
			local other = if a == part then b elseif b == part then a else nil
			if other and not reached[other] then
				reached[other] = true
				table.insert(queue, other)
				table.insert(worn, other)
			end
		end
	end
	local shoulders = torso.CFrame.Position.Y + torso.Size.Y / 2
	local top = topOf(head)
	for _, p in worn do
		top = math.max(top, topOf(p))
	end
	top += HEADROOM
	local halfWidth = torso.Size.X / 2 + arm.Size.X / 2 + SHOULDER_PAD
	for _, p in worn do -- the farmer's 3.1 straw disc is wider than the shoulders: keep the whole brim in view
		halfWidth =
			math.max(halfWidth, math.abs(p.CFrame.Position.X - root.CFrame.Position.X) + halfWidthOf(p) * HAT_NEAR)
	end
	local half = math.max((top - (shoulders - CHEST)) / 2, halfWidth) * MARGIN
	-- any spare height goes to the chest, never above the head
	local centre = Vector3.new(root.CFrame.Position.X, top - half, root.CFrame.Position.Z)
	local dist = half / math.tan(math.rad(Portrait.FOV) / 2) + NEAR
	local eye = centre + Vector3.new(0, math.sin(PITCH) * dist, -math.cos(PITCH) * dist)
	return CFrame.lookAt(eye, centre), dist
end

function Portrait.portrait(
	kind: string,
	job: string,
	kingdomColor: Color3,
	look: Character.CitizenLook?,
	kingdom: string?
): Model
	local model = CharacterMesh.character(kind, job, kingdomColor, look, kingdom)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	local root = model.PrimaryPart :: BasePart
	local cf, dist = frame(model)
	local focus = Instance.new("Attachment")
	focus.Name = "PortraitFocus"
	focus.CFrame = root.CFrame:ToObjectSpace(cf)
	focus:SetAttribute("PortraitFov", Portrait.FOV)
	focus:SetAttribute("PortraitDistance", dist)
	focus.Parent = root
	model:SetAttribute("KitPortrait", true)
	return model
end

-- (camera CFrame, vertical FOV) for a portrait wherever it is now.
function Portrait.camera(model: Model): (CFrame, number)
	local root = model.PrimaryPart
	local focus = if root then root:FindFirstChild("PortraitFocus") else nil
	assert(root and focus and focus:IsA("Attachment"), "Kit.portraitCamera: not a Kit.portrait model")
	local fov = focus:GetAttribute("PortraitFov")
	return root.CFrame * focus.CFrame, if type(fov) == "number" then fov else Portrait.FOV
end

-- Places the anchored parts for joint transforms { [motor name]: CFrame } (Sim/Pose samples); the Root stays.
function Portrait.pose(model: Model, joints: { [string]: CFrame })
	local root = model.PrimaryPart :: BasePart
	local links: { JointInstance } = {}
	for _, d in model:GetDescendants() do
		if d:IsA("Motor6D") or (d:IsA("Weld") and not d:IsA("Motor6D")) then
			table.insert(links, d :: JointInstance)
		end
	end
	local placed: { [BasePart]: CFrame } = { [root] = root.CFrame }
	local moved = true
	while moved do
		moved = false
		for _, j in links do
			local p0, p1 = j.Part0, j.Part1
			if p0 and p1 and placed[p0] and not placed[p1] then
				local t = if j:IsA("Motor6D") then joints[j.Name] or CFrame.new() else CFrame.new()
				placed[p1] = placed[p0] * j.C0 * t * j.C1:Inverse()
				moved = true
			end
		end
	end
	for part, cf in placed do
		if part ~= root then
			part.CFrame = cf
		end
	end
end

return Portrait
