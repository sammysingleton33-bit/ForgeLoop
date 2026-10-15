--[[
	PortraitDoubles — a stand-in for FORGE-02's Kit.portrait / Kit.portraitCamera (#85, CONTRACTS
	G13.8) for the FL-0099 specs and render scenes while #85 is not on main. Install it through
	UI/PortraitView.useSource and restore Kit afterwards:

		local source = PortraitDoubles.source()        -- or PortraitDoubles.source({ fail = true })
		PortraitView.useSource(source)
		...
		PortraitView.useSource(nil)
		source.calls   -- { { kind, job, kingdomColor, look, kingdom } } one per portrait built

	It follows the contract, not FORGE-02's framing maths: Kit.character's rig for the same arguments,
	every part Anchored, an Attachment "PortraitFocus" on the Root that IS the camera (in front of the
	face, looking at it from a little above) with the attributes PortraitFov (30) and PortraitDistance,
	and the model attribute KitPortrait. `fail = true` makes portrait() error (the panel fallback).
	PortraitDoubles.real() returns Kit's own source when Kit.portrait exists (after #85), else nil.
]]

local Kit = require("@game/ReplicatedStorage/Game/Kit/Kit")

local PortraitDoubles = {}

PortraitDoubles.FOV = 30
PortraitDoubles.DISTANCE = 7.5 -- studs from the camera to the face

function PortraitDoubles.source(opts: { fail: boolean? }?)
	local o = opts or {}
	local source = { calls = {} }
	function source.portrait(kind, job, kingdomColor, look, kingdom)
		table.insert(
			source.calls,
			{ kind = kind, job = job, kingdomColor = kingdomColor, look = look, kingdom = kingdom }
		)
		if o.fail then
			error("PortraitDoubles: portrait failed (spec)")
		end
		local model = (Kit :: any).character(kind, job, kingdomColor, look, kingdom)
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
			end
		end
		local root = model.PrimaryPart
		local head = model:FindFirstChild("Head")
		local face = if head then head.CFrame.Position else root.CFrame.Position + Vector3.new(0, 3, 0)
		local centre = face - Vector3.new(0, 0.6, 0)
		local pitch = math.rad(6)
		local eye = centre
			+ Vector3.new(0, math.sin(pitch) * PortraitDoubles.DISTANCE, -math.cos(pitch) * PortraitDoubles.DISTANCE)
		local focus = Instance.new("Attachment")
		focus.Name = "PortraitFocus"
		focus.CFrame = root.CFrame:ToObjectSpace(CFrame.lookAt(eye, centre))
		focus:SetAttribute("PortraitFov", PortraitDoubles.FOV)
		focus:SetAttribute("PortraitDistance", PortraitDoubles.DISTANCE)
		focus.Parent = root
		model:SetAttribute("KitPortrait", true)
		return model
	end
	function source.camera(model)
		local root = model.PrimaryPart
		local focus = root:FindFirstChild("PortraitFocus")
		return root.CFrame * focus.CFrame, focus:GetAttribute("PortraitFov")
	end
	return source
end

function PortraitDoubles.real(): any
	local kit = Kit :: any
	if type(kit.portrait) == "function" then
		return { portrait = kit.portrait, camera = kit.portraitCamera, calls = {} }
	end
	return nil
end

return PortraitDoubles
