--!strict
--[[
	Kit/Siege — siege engines for the war kit (FL-0128, Operation Crownfall): part-built, kingdom-tinted, client entity
	models in the Kit.character mould (D-026: primitive parts only, nothing yields, no CSG).

	API
		Kit.siege(kind, kingdomColor) -> Model   kind "ram" (the only one so far); other kinds error
		Kit.siegePose(model, thrust)             the pose driver's helper: thrust 0..1 places the swinging log
		Siege.KINDS = { "ram" }, Siege.MAX_PARTS (45), Siege.THRUST_TRAVEL (3.0 studs)

	The ram (config Military unit "ram", the siege unit that does the work against buildings): a battering ram on four
	wheels. Skids and cross beams, four posts (the rear ones taller) with a rail along each side and ONE low pent roof that
	falls toward the front, in the kingdom colour, with the kingdom's shield crest lying on it and a pennant at the rear (the
	roof is the only place that carries the kingdom). The log is the silhouette: a long thick pale timber slung from the roof
	on two straps, with three iron bands and a dark wedge-shaped iron head that projects about 7 studs past the roof's front
	edge, so it shows from the side, the front and the air at thrust 0 as well as when thrust.
	  Rig, like Kit.character: Root anchored, invisible, 0.1 above the ground with the pivot at the feet (PivotOffset), every
	  other part unanchored, Massless and non-colliding, welded to the Root by a Weld "RigWeld". ONE Motor6D, named `Log`
	  (Root -> Log), carries the log with its iron head, bands and straps (welded to the Log). Its frame is axis-aligned
	  with the model (+X right, +Y up, -Z front), so Motor6D.Transform is a translation along the model's Z. Front is -Z.
	  Thrust: 0 is the log drawn back (the built pose, the head 7 studs out in front of the roof), 1 is the log thrust
	  THRUST_TRAVEL (3) studs forward with a 0.35-stud arc lift; Kit.siegePose sets the Transform. The kingdom colour is on
	  the roof, its edge, the crest and the pennant (KitTint, so Kit.setKingdomColor recolours a pooled ram; the emblems
	  re-form with it).
	Budget: at most MAX_PARTS (45) BaseParts including the Root (measured 39-42, the emerald emblem costs most).
	Wire: the unit kind does not reach the client yet (Replication sends job = "soldier" for every unit): see the handoff
	production/handoffs/2026-10-19-forge-02-to-forge-00-04-fl0128-war-kit.md.
]]

local Parts = require("./Parts")
local Pieces = require("./Pieces")
local KingdomStyle = require("./KingdomStyle")

local C = Parts.C
local M = Enum.Material
local PI = math.pi

local Siege = {}

Siege.KINDS = table.freeze({ "ram" })
Siege.MAX_PARTS = 45
Siege.THRUST_TRAVEL = 3.0 -- studs the log travels from drawn back (thrust 0) to the wall (thrust 1)
Siege.THRUST_LIFT = 0.35 -- the arc: the log rises this much at mid-thrust
Siege.ROOT_HEIGHT = 0.1 -- the Root's centre above the ground (the pivot is at the feet)

local IRON_DARK = Color3.fromRGB(34, 36, 42)
local PALE_LOG = Color3.fromRGB(198, 168, 124) -- a peeled timber: the log is the light shape against the dark iron
local FOOTPRINT = Vector2.new(8, 14)

local function buildRam(color: Color3): Model
	local ctx = Parts.newModel("siege_ram", FOOTPRINT)
	local style = Parts.hueStyle(color)
	ctx.style = style
	local block, wedge, log = Parts.block, Parts.wedge, Parts.log
	local root = ctx.root

	-- chassis: two skids, three cross beams, four wheels (axis along X)
	for _, sx in { -1, 1 } do
		block(ctx, "Skid", Vector3.new(0.9, 0.9, 12.4), CFrame.new(sx * 2.55, 1.35, 0), C.wood, M.Wood)
	end
	for _, z in { -4.6, 0, 4.6 } do
		block(ctx, "CrossBeam", Vector3.new(6.2, 0.8, 0.9), CFrame.new(0, 2.0, z), C.timber, M.Wood)
	end
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			log(ctx, "Wheel", 1.35, 0.7, CFrame.new(sx * 3.4, 1.35, sz * 3.9), C.woodDark, M.Wood)
		end
	end
	-- an open frame: four posts (the rear ones taller), a rail along each side, and a single low pent roof that falls
	-- toward the front, in the kingdom colour; nothing hides the log
	for _, sx in { -1, 1 } do
		block(ctx, "Post", Vector3.new(0.7, 5.0, 0.7), CFrame.new(sx * 2.55, 4.3, 4.8), C.timber, M.Wood)
		block(ctx, "Post", Vector3.new(0.7, 3.6, 0.7), CFrame.new(sx * 2.55, 3.6, -4.0), C.timber, M.Wood)
		block(ctx, "Rail", Vector3.new(0.35, 0.35, 8.8), CFrame.new(sx * 2.55, 3.0, 0.4), C.woodDark, M.Wood)
	end
	local fall = math.atan2(1.4, 8.8) -- the roof's fall toward the front (-Z)
	local roofCF = CFrame.new(0, 6.45, 0.4) * CFrame.Angles(-fall, 0, 0)
	block(ctx, "RoofSlab", Vector3.new(6.9, 0.6, 10.8), roofCF, Parts.shade(color, 0.92), M.WoodPlanks, 0.92)
	block(
		ctx,
		"RoofEdge",
		Vector3.new(6.9, 0.9, 0.5),
		roofCF * CFrame.new(0, -0.15, -5.5),
		Parts.shade(color, 0.7),
		M.Wood,
		0.7
	)

	-- the log group: a long thick pale log slung from the roof on two straps, three iron bands and a wedge-shaped iron
	-- head well past the roof's front edge; the Log joint carries it
	local logY, logZ, logLen = 3.4, -2.8, 15.0
	local logCF = CFrame.new(0, logY, logZ) * CFrame.Angles(0, PI / 2, 0)
	local ram = log(ctx, "Log", 1.5, logLen, logCF, PALE_LOG, M.Wood)
	local frontZ = logZ - logLen / 2
	local group: { BasePart } = {
		wedge(ctx, "RamHead", Vector3.new(1.9, 1.9, 2.2), CFrame.new(0, logY, frontZ - 1.1), IRON_DARK, M.Metal),
	}
	for _, bz in { frontZ + 1.2, frontZ + 3.4, frontZ + 9.0 } do
		table.insert(
			group,
			log(ctx, "RamBand", 1.62, 0.4, CFrame.new(0, logY, bz) * CFrame.Angles(0, PI / 2, 0), IRON_DARK, M.Metal)
		)
	end
	for _, hz in { -4.6, 0.8 } do -- from the log's top up to the roof's underside there
		local under = roofCF.Y + (hz - roofCF.Z) * math.tan(fall) - 0.3
		local top = logY + 0.75
		table.insert(
			group,
			block(
				ctx,
				"Hanger",
				Vector3.new(0.3, under - top, 0.3),
				CFrame.new(0, (under + top) / 2, hz),
				C.iron,
				M.Metal
			)
		)
	end

	-- heraldry, on the roof only: the kingdom's shield crest lying on the roof, a pennant on a pole at the rear
	Pieces.crest(ctx, roofCF * CFrame.new(0, 0.32, -0.6) * CFrame.Angles(PI / 2, 0, 0), 3.0, color, style)
	Pieces.pennant(ctx, 0, 7.0, 5.0, 3.4, color, style)

	-- the kingdom's wood, then the rig: unanchored, welded to the Root, the log on its Motor6D
	KingdomStyle.paint(ctx.model, style)
	local inGroup: { [Instance]: boolean } = {}
	for _, p in group do
		inGroup[p] = true
	end
	for _, d in ctx.model:GetDescendants() do
		if d:IsA("BasePart") and d ~= root then
			local part = d :: BasePart
			part.Anchored = false
			part.Massless = true
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
			if part ~= ram then
				local owner = if inGroup[part] then ram else root
				local weld = Instance.new("Weld")
				weld.Name = "RigWeld"
				weld.Part0 = owner
				weld.Part1 = part
				weld.C0 = owner.CFrame:Inverse() * part.CFrame
				weld.C1 = CFrame.new()
				weld.Parent = part
			end
		end
	end
	root.CanCollide = false
	root.CanTouch = false
	root.CanQuery = false
	root.CastShadow = false
	-- Root -> Log: an axis-aligned joint frame at the log's centre, so Transform translates along the model's Z
	local joint = CFrame.new(ram.CFrame.Position)
	local m = Instance.new("Motor6D")
	m.Name = "Log"
	m.Part0 = root
	m.Part1 = ram
	m.C0 = root.CFrame:Inverse() * joint
	m.C1 = ram.CFrame:Inverse() * joint
	m.Parent = root
	ctx.model:SetAttribute("KitKind", "siege")
	ctx.model:SetAttribute("KitSiege", "ram")
	ctx.model:SetAttribute("KitRootHeight", Siege.ROOT_HEIGHT)
	return ctx.model
end

function Siege.build(kind: string, kingdomColor: Color3): Model
	assert(kind == "ram", `Kit.siege: unknown siege kind {tostring(kind)}`)
	return buildRam(kingdomColor)
end

-- The Log joint's Transform for a thrust in 0..1 (NaN and out-of-range values clamp): a translation along the model's
-- Z with a small arc, so a pose driver needs only the number.
function Siege.thrustTransform(thrust: number): CFrame
	local t = if thrust ~= thrust then 0 else math.clamp(thrust, 0, 1)
	return CFrame.new(0, Siege.THRUST_LIFT * math.sin(PI * t), -Siege.THRUST_TRAVEL * t)
end

function Siege.pose(model: Model, thrust: number)
	local root = model.PrimaryPart
	local joint = if root then root:FindFirstChild("Log") else nil
	if joint and joint:IsA("Motor6D") then
		joint.Transform = Siege.thrustTransform(thrust)
	end
end

return Siege
