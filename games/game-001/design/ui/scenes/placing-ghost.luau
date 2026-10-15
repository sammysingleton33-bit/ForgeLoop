--[[
	Rotation scene "placing-ghost" (the user's first Studio feedback): the real BuildMenuController's
	ghost seen from the aerial camera (RulerCameraController's overview at its 120-stud start zoom),
	a farm turned a quarter, with its door strip and facing arrow, under the placement bar.
	The ghost's own folder is moved into a full-screen ViewportFrame (with a ground plate and the
	camera) so the renderer can draw it; it needs the ViewportFrame renderer (README deviations 23-24,
	from FL-0099). SelectionBox outlines are not drawn by the renderer; the slab and marks are.
]]
local Create = require("@game/ReplicatedStorage/Forge/UI/Create")
local scene = require("./_world")

local AIM = Vector3.new(80, 0, 80)
local ZOOM = 120
local PITCH = math.rad(52) -- RulerCameraController.pitchFor(120): 38° + (65° − 38°) × 80/180
local YAW = 0 -- the overview's default yaw (looking along -Z), the camera the bar's dial reads in a scene

return function(ctx)
	local ghost = nil
	local result = scene(ctx, {}, function(world, _, build)
		build:startPlacement("farm")
		build:aimAt(AIM)
		world:advance(0.2)
		build:rotate(1)
		world:advance(0.2)
		ghost = build.ghost.folder
	end)
	local player = result.guis[1].Parent
	local forward = Vector3.new(-math.sin(YAW), 0, -math.cos(YAW))
	local position = AIM - forward * (ZOOM * math.cos(PITCH)) + Vector3.new(0, ZOOM * math.sin(PITCH), 0)
	local camera = Create("Camera", { CFrame = CFrame.lookAt(position, AIM), FieldOfView = 70 })
	local ground = Create("Part", {
		Name = "Ground",
		Anchored = true,
		Size = Vector3.new(140, 1, 140),
		CFrame = CFrame.new(AIM.X, -0.5, AIM.Z),
		Color = Color3.fromRGB(104, 152, 74),
	})
	local view = Create("ViewportFrame", {
		Name = "World",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(104, 152, 74), -- grass beyond the plate
		Ambient = Color3.fromRGB(160, 160, 150),
		LightColor = Color3.fromRGB(255, 245, 225),
		LightDirection = Vector3.new(-0.4, -1, 0.3),
	}, { Camera = camera, Ground = ground })
	view.CurrentCamera = camera
	ghost.Parent = view
	local backdrop = Create("ScreenGui", {
		Name = "WorldBackdrop",
		DisplayOrder = 0,
		ScreenInsets = Enum.ScreenInsets.None,
		IgnoreGuiInset = true,
		Parent = player,
	}, { World = view })
	table.insert(result.guis, 1, backdrop)
	return result
end
