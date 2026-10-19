--!strict
--[[
	Kit/Siege — siege engines for the war kit (FL-0128, Operation Crownfall): part-built, kingdom-tinted, client entity
	models in the Kit.character mould (D-026: primitive parts only, nothing yields, no CSG).

	API
		Kit.siege(kind, kingdomColor) -> Model   kind "ram" (the only one so far); other kinds error
		Kit.siegePose(model, thrust)             the pose driver's helper: thrust 0..1 places the swinging log
		Siege.KINDS = { "ram" }, Siege.MAX_PARTS (45), Siege.THRUST_TRAVEL (3.0 studs)

	The ram (config Military unit "ram", the siege unit that does the work against buildings): a covered battering
	ram on four wheels. Skids and cross beams, four posts, hide-covered sides and a gabled roof in the kingdom colour
	over a pennant with the kingdom emblem and a shield crest on the right side; a swinging log with an iron head hangs
	under the ridge on two hangers.
	  Rig, like Kit.character: Root anchored, invisible, 0.1 above the ground with the pivot at the feet (PivotOffset), every
	  other part unanchored, Massless and non-colliding, welded to the Root by a Weld "RigWeld". ONE Motor6D, named `Log`
	  (Root -> Log), carries the log with its iron head, bands and hangers (welded to the Log). Its frame is axis-aligned
	  with the model (+X right, +Y up, -Z front), so Motor6D.Transform is a translation along the model's Z. Front is -Z.
	  Thrust: 0 is the log drawn back (the built pose, tip flush with the front of the body), 1 is the log thrust THRUST_TRAVEL
	  (3) studs forward with a 0.35-stud arc lift; Kit.siegePose sets the Transform. The kingdom colour is on the roof, the
	  ridge, the pennant and the crest (KitTint, so Kit.setKingdomColor recolours a pooled ram; the emblem re-forms with it).
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

local HIDE = Color3.fromRGB(122, 84, 52) -- tanned hide on the sides
local FOOTPRINT = Vector2.new(8, 14)

local function buildRam(color: Color3): Model
	local ctx = Parts.newModel("siege_ram", FOOTPRINT)
	local style = Parts.hueStyle(color)
	ctx.style = style
	local block, log, ball = Parts.block, Parts.log, Parts.ball
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
	-- frame and cover: corner posts, hide sides, the gabled roof (kingdom colour) with its ridge
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			block(ctx, "Post", Vector3.new(0.7, 4.8, 0.7), CFrame.new(sx * 2.55, 4.4, sz * 5.0), C.timber, M.Wood)
		end
		block(ctx, "Hide", Vector3.new(0.25, 3.6, 10.0), CFrame.new(sx * 2.75, 4.0, 0), HIDE, M.Fabric)
	end
	local slope = math.atan2(2.0, 3.1)
	for _, sx in { -1, 1 } do
		Parts.block(
			ctx,
			"RoofSlab",
			Vector3.new(4.1, 0.5, 12.6),
			CFrame.new(sx * 1.6, 7.6, 0) * CFrame.Angles(0, 0, -sx * slope),
			Parts.shade(color, 0.88),
			M.WoodPlanks,
			0.88
		)
	end
	block(
		ctx,
		"RidgeCap",
		Vector3.new(0.8, 0.8, 12.9),
		CFrame.new(0, 8.65, 0) * CFrame.Angles(0, 0, PI / 4),
		Parts.shade(color, 0.62),
		M.Wood,
		0.62
	)

	-- the log group: log, iron head, two iron bands, two hangers up to the ridge; the Log joint carries it
	local logCF = CFrame.new(0, 3.9, -0.4) * CFrame.Angles(0, PI / 2, 0)
	local ram = log(ctx, "Log", 0.85, 11.2, logCF, C.bark, M.Wood)
	local group: { BasePart } = {
		log(ctx, "RamHead", 1.0, 1.0, CFrame.new(0, 3.9, -6.5) * CFrame.Angles(0, PI / 2, 0), C.iron, M.Metal),
		log(ctx, "RamBand", 0.95, 0.35, CFrame.new(0, 3.9, -4.4) * CFrame.Angles(0, PI / 2, 0), C.iron, M.Metal),
		log(ctx, "RamBand", 0.95, 0.35, CFrame.new(0, 3.9, 0.9) * CFrame.Angles(0, PI / 2, 0), C.iron, M.Metal),
		block(ctx, "Hanger", Vector3.new(0.3, 4.1, 0.3), CFrame.new(0, 6.6, -2.4), C.iron, M.Metal),
		block(ctx, "Hanger", Vector3.new(0.3, 4.1, 0.3), CFrame.new(0, 6.6, 1.8), C.iron, M.Metal),
	}

	-- heraldry: the pennant (with the emblem) on the ridge's rear end, the shield crest on the right side
	Pieces.pennant(ctx, 0, 8.8, 5.6, 3.6, color, style)
	Pieces.crest(ctx, CFrame.new(2.95, 4.1, 0) * CFrame.Angles(0, -PI / 2, 0), 2.6, color, style)
	ball(ctx, "Knob", 0.5, Vector3.new(0, 9.2, -6.5), C.iron, M.Metal).CastShadow = false

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
