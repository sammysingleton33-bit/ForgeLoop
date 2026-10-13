--!strict
--[[
	UI/PortraitView — the citizen's head-and-shoulders portrait for the cinematic conversation
	(CONTRACTS G13.8, D-036; FL-0099): a ViewportFrame holding FORGE-02's `Kit.portrait` rig and a
	Camera placed by `Kit.portraitCamera`. The portrait is built from the same arguments as the
	world rig (EntityController): kind "citizen", the job, the kingdom's colour from config Kingdoms
	and the `look` from the Kingdom.Converse result, so the two look identical.

		PortraitView.useSource(source? | false)
			source = { portrait(kind, job, kingdomColor, look?, kingdom?) -> Model,
			           camera(model) -> (CFrame, number)? }; nil restores Kit; false means no source
			(the panel). For specs and render scenes, and before #85 is on main.
		PortraitView.colorOf(kingdom: string?) -> Color3
			the kingdom's colour as EntityController paints the world rig (Kit.NEUTRAL_COLOR otherwise)
		PortraitView.new(spec: { look: any?, job: string?, kingdom: string? }) -> view?
			nil when there is no source (FORGE-02's Kit.portrait, #85, or one installed with
			useSource) or building the rig fails: the conversation then uses the drawer panel. The rig is
			built once; the view is moved between renders, never rebuilt.
		view.frame   ViewportFrame "Viewport" (fills its parent; transparent; Camera "PortraitCamera")
		view.model   the portrait Model (KitPortrait = true with Kit.portrait)
		view:destroy()

	The ViewportFrame's light comes from the upper left of the picture, a little warm, so faces read
	in front of the kingdom-coloured backdrop (UI/ConversationStage).
]]

local Kit = require("@game/ReplicatedStorage/Game/Kit/Kit")
local KingdomsConfig = require("@game/ReplicatedStorage/Forge/Config/Kingdoms")

local PortraitView = {}
PortraitView.__index = PortraitView

PortraitView.FOV = 30 -- Kit.PORTRAIT_FOV: the vertical field of view the focus is framed for
PortraitView.AMBIENT = Color3.fromRGB(150, 140, 132)
PortraitView.LIGHT = Color3.fromRGB(255, 240, 222)
-- The camera looks along +Z at the face (the rig faces -Z), so the picture's left is world +X:
-- light travelling to -X, down and away from the camera comes from the upper left.
PortraitView.LIGHT_DIRECTION = Vector3.new(-0.55, -1, 0.65)

local COLORS: { [string]: Color3 } = {}
for _, identity in KingdomsConfig.identities do
	local c = identity.color
	COLORS[identity.id] = Color3.fromRGB(c[1], c[2], c[3])
end

local override: any = nil

local function source(): any
	if override == false then
		return nil
	elseif override ~= nil then
		return override
	end
	local kit = Kit :: any
	if type(kit.portrait) == "function" then
		return { portrait = kit.portrait, camera = kit.portraitCamera }
	end
	return nil
end

function PortraitView.useSource(s: any?)
	override = s
end

function PortraitView.colorOf(kingdom: string?): Color3
	return (if kingdom then COLORS[kingdom] else nil) or (Kit :: any).NEUTRAL_COLOR or Color3.fromRGB(150, 150, 150)
end

-- (camera CFrame, FieldOfView) from the source's camera, else from the PortraitFocus attachment
-- (G13.8: the attachment IS the camera pose).
local function cameraOf(src: any, model: Model): (CFrame?, number)
	if type(src.camera) == "function" then
		local ok, cf, fov = pcall(src.camera, model)
		if ok and typeof(cf) == "CFrame" then
			return cf, if type(fov) == "number" then fov else PortraitView.FOV
		end
	end
	local root = model.PrimaryPart
	local focus = if root then root:FindFirstChild("PortraitFocus") else nil
	if root and focus and focus:IsA("Attachment") then
		local fov = focus:GetAttribute("PortraitFov")
		return root.CFrame * focus.CFrame, if type(fov) == "number" then fov else PortraitView.FOV
	end
	return nil, PortraitView.FOV
end

function PortraitView.new(spec: { look: any?, job: string?, kingdom: string? }): any
	local src = source()
	if src == nil then
		return nil
	end
	local job = if type(spec.job) == "string" and spec.job ~= "" then spec.job else "idle"
	local ok, model = pcall(src.portrait, "citizen", job, PortraitView.colorOf(spec.kingdom), spec.look, spec.kingdom)
	if not ok or typeof(model) ~= "Instance" or not (model :: Instance):IsA("Model") then
		return nil
	end
	local cf, fov = cameraOf(src, model :: Model)
	if cf == nil then
		(model :: Instance):Destroy()
		return nil
	end
	local frame = Instance.new("ViewportFrame")
	frame.Name = "Viewport"
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.fromScale(1, 1)
	frame.Ambient = PortraitView.AMBIENT
	frame.LightColor = PortraitView.LIGHT
	frame.LightDirection = PortraitView.LIGHT_DIRECTION
	local camera = Instance.new("Camera")
	camera.Name = "PortraitCamera"
	camera.FieldOfView = fov
	camera.CFrame = cf :: CFrame
	camera.Parent = frame
	frame.CurrentCamera = camera;
	(model :: Model).Parent = frame
	return setmetatable({ frame = frame, model = model, camera = camera }, PortraitView)
end

function PortraitView:destroy()
	if self.frame then
		self.frame:Destroy()
		self.frame = nil
	end
	self.model = nil
	self.camera = nil
end

return PortraitView
