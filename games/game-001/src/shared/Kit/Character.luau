--!strict
--[[
	Kit/Character — ≤ 8-part entity rigs (Motor6Ds named after the moving part, no Humanoid) and ruler
	regalia (crown + cape accessories). CONTRACTS G4 rendering, D-026.
]]

local Parts = require("./Parts")
local C = Parts.C
local shade = Parts.shade

local Character = {}

-- ------------------------------------------------------------------ characters (≤ 8 parts)

local JOB_LOOK: { [string]: { legs: Color3, tool: string } } = {
	idle = { legs = Color3.fromRGB(110, 86, 60), tool = "none" },
	farmer = { legs = Color3.fromRGB(94, 127, 58), tool = "hoe" },
	woodcutter = { legs = Color3.fromRGB(122, 74, 42), tool = "axe" },
	miner = { legs = Color3.fromRGB(95, 102, 111), tool = "pick" },
	builder = { legs = Color3.fromRGB(139, 94, 60), tool = "hammer" },
	hauler = { legs = Color3.fromRGB(150, 130, 100), tool = "sack" },
	soldier = { legs = Color3.fromRGB(93, 102, 112), tool = "spear" },
}

local function rigPart(
	model: Model,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?,
	shape: Enum.PartType?
)
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = shape or Enum.PartType.Block
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = false
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Massless = true
	p.CastShadow = true
	p.Parent = model
	return p
end

local function motor(part0: BasePart, part1: BasePart, jointWorld: CFrame)
	local m = Instance.new("Motor6D")
	m.Name = part1.Name
	m.Part0 = part0
	m.Part1 = part1
	m.C0 = part0.CFrame:Inverse() * jointWorld
	m.C1 = part1.CFrame:Inverse() * jointWorld
	m.Parent = part0
	return m
end

local TOOL_SHAPES: { [string]: { size: Vector3, color: Color3, material: Enum.Material, offset: CFrame } } = {
	hoe = {
		size = Vector3.new(0.25, 4.2, 0.25),
		color = C.wood,
		material = Enum.Material.Wood,
		offset = CFrame.new(0, -0.6, -0.4),
	},
	axe = {
		size = Vector3.new(0.35, 2.6, 0.9),
		color = C.iron,
		material = Enum.Material.Metal,
		offset = CFrame.new(0, -1.2, -0.5),
	},
	pick = {
		size = Vector3.new(0.3, 2.4, 1.6),
		color = C.iron,
		material = Enum.Material.Metal,
		offset = CFrame.new(0, -1.2, -0.5),
	},
	hammer = {
		size = Vector3.new(0.6, 1.8, 0.6),
		color = C.iron,
		material = Enum.Material.Metal,
		offset = CFrame.new(0, -1.1, -0.4),
	},
	sack = {
		size = Vector3.new(1.6, 1.6, 1.6),
		color = C.canvas,
		material = Enum.Material.Fabric,
		offset = CFrame.new(0, 1.2, 0.9),
	},
	spear = {
		size = Vector3.new(0.22, 7.0, 0.22),
		color = C.woodDark,
		material = Enum.Material.Wood,
		offset = CFrame.new(0, 0.6, -0.4),
	},
}

function Character.character(kind: string, job: string, kingdomColor: Color3): Model
	local look = JOB_LOOK[job] or JOB_LOOK.idle
	local model = Instance.new("Model")
	model.Name = `{kind}_{job}`
	model:SetAttribute("KitKind", kind)
	model:SetAttribute("KitJob", job)
	-- proportions: legs 2.2, torso 2.0, head 1.3 => 5.5 studs
	local root = rigPart(model, "Root", Vector3.new(2, 2, 1), CFrame.new(0, 3.2, 0), C.cloth)
	root.Anchored = true
	root.Transparency = 1
	root.PivotOffset = CFrame.new(0, -3.2, 0)
	model.PrimaryPart = root
	local tunic = if kind == "citizen" then shade(kingdomColor, 0.85):Lerp(C.cloth, 0.45) else kingdomColor
	local torso = rigPart(model, "Torso", Vector3.new(2, 2, 1), CFrame.new(0, 3.2, 0), tunic, Enum.Material.Fabric)
	torso:SetAttribute("KitTint", if kind == "citizen" then 0.85 else 1)
	local head = rigPart(
		model,
		"Head",
		Vector3.new(1.3, 1.3, 1.3),
		CFrame.new(0, 4.85, 0),
		if kind == "soldier" then C.iron else C.skin,
		if kind == "soldier" then Enum.Material.Metal else Enum.Material.SmoothPlastic
	)
	local larm =
		rigPart(model, "LeftArm", Vector3.new(0.9, 2, 0.9), CFrame.new(-1.45, 3.2, 0), tunic, Enum.Material.Fabric)
	local rarm =
		rigPart(model, "RightArm", Vector3.new(0.9, 2, 0.9), CFrame.new(1.45, 3.2, 0), tunic, Enum.Material.Fabric)
	larm:SetAttribute("KitTint", 0.85)
	rarm:SetAttribute("KitTint", 0.85)
	local lleg = rigPart(
		model,
		"LeftLeg",
		Vector3.new(0.95, 2.2, 0.95),
		CFrame.new(-0.5, 1.1, 0),
		look.legs,
		Enum.Material.Fabric
	)
	local rleg = rigPart(
		model,
		"RightLeg",
		Vector3.new(0.95, 2.2, 0.95),
		CFrame.new(0.5, 1.1, 0),
		look.legs,
		Enum.Material.Fabric
	)
	motor(root, torso, CFrame.new(0, 2.2, 0))
	motor(torso, head, CFrame.new(0, 4.2, 0))
	motor(torso, larm, CFrame.new(-1.0, 4.0, 0))
	motor(torso, rarm, CFrame.new(1.0, 4.0, 0))
	motor(torso, lleg, CFrame.new(-0.5, 2.2, 0))
	motor(torso, rleg, CFrame.new(0.5, 2.2, 0))
	local toolName = if kind == "soldier" then "spear" else look.tool
	local spec = TOOL_SHAPES[toolName]
	if spec then
		local hand = CFrame.new(1.45, 2.3, 0)
		local tool = rigPart(model, "Tool", spec.size, hand * spec.offset, spec.color, spec.material)
		motor(rarm, tool, hand)
	end
	return model
end

-- ------------------------------------------------------------------ regalia (ruler crown + cape)

function Character.regalia(kingdomColor: Color3): { Accessory }
	local crown = Instance.new("Accessory")
	crown.Name = "KitCrown"
	local band = Instance.new("Part")
	band.Name = "Handle"
	band.Shape = Enum.PartType.Cylinder
	band.Size = Vector3.new(0.5, 1.5, 1.5)
	band.CFrame = CFrame.Angles(0, 0, math.rad(90))
	band.Color = C.gold
	band.Material = Enum.Material.Metal
	band.CanCollide = false
	band.CanTouch = false
	band.CanQuery = false
	band.Massless = true
	band.Parent = crown
	local hat = Instance.new("Attachment")
	hat.Name = "HatAttachment"
	hat.CFrame = CFrame.Angles(0, 0, math.rad(-90)) * CFrame.new(0, -0.35, 0)
	hat.Parent = band
	for i = 0, 3 do
		local a = math.rad(i * 90 + 45)
		local pt = Instance.new("Part")
		pt.Name = "CrownPoint"
		pt.Size = Vector3.new(0.3, 0.45, 0.3)
		pt.CFrame = band.CFrame
			* CFrame.Angles(0, 0, math.rad(-90))
			* CFrame.new(math.cos(a) * 0.65, 0.4, math.sin(a) * 0.65)
		pt.Color = if i % 2 == 0 then C.gold else kingdomColor
		pt:SetAttribute("KitTint", if i % 2 == 0 then nil else 1)
		pt.Material = Enum.Material.Metal
		pt.CanCollide = false
		pt.CanTouch = false
		pt.CanQuery = false
		pt.Massless = true
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = band
		weld.Part1 = pt
		weld.Parent = pt
		pt.Parent = crown
	end

	local cape = Instance.new("Accessory")
	cape.Name = "KitCape"
	local cloth = Instance.new("Part")
	cloth.Name = "Handle"
	cloth.Size = Vector3.new(2.2, 3.2, 0.2)
	cloth.Color = kingdomColor
	cloth:SetAttribute("KitTint", 1)
	cloth.Material = Enum.Material.Fabric
	cloth.CanCollide = false
	cloth.CanTouch = false
	cloth.CanQuery = false
	cloth.Massless = true
	cloth.Parent = cape
	local back = Instance.new("Attachment")
	back.Name = "BodyBackAttachment"
	back.CFrame = CFrame.new(0, 1.0, -0.15)
	back.Parent = cloth
	return { crown, cape }
end

return Character
