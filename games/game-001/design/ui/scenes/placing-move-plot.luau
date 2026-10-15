--[[
	FL-0120 scene "placing-move-plot": moving a house onto a free medium plot from the aerial camera.
	The ghost snaps to the plot (the plot's outline stays put), turned a quarter ("Faces right"); the bar
	says "✓ Faces right" and confirms with Build.MoveToSlot. The real ghost folder is moved
	into a full-screen ViewportFrame, as in "placing-ghost" (the ViewportFrame renderer, FL-0099).
]]
local Create = require("@game/ReplicatedStorage/Forge/UI/Create")
local MoveDoubles = require("../../../tests/economy/doubles/MoveDoubles")
local Slots = require("@game/StarterPlayer/StarterPlayerScripts/Game/UI/Slots")
local scene = require("./_plots")

local ZOOM = 120
local PITCH = math.rad(52)

return function(ctx)
	local ghost, focus = nil, nil
	local result = scene(ctx, { move = true }, function(world, _, _, _, build)
		local id = world.build:add("crimson", "house", 1, "complete", Vector3.new(40, 0, 40))
		world.build.buildings[id].cframe = MoveDoubles.cframe(Vector3.new(40, 0, 40), 0)
		world.build:push(id)
		world:advance(0.1)
		build:startMove(id)
		world:advance(0.2)
		local frame = Slots.frame("crimson_slot5")
		focus = frame.center
		build:aimAt(frame.center + Vector3.new(3, 0, 2))
		build:rotate(1)
		world:advance(0.2)
		ghost = build.ghost.folder
	end)
	local player = result.guis[1].Parent
	local position = focus + Vector3.new(0, 0, ZOOM * math.cos(PITCH)) + Vector3.new(0, ZOOM * math.sin(PITCH), 0)
	local camera = Create("Camera", { CFrame = CFrame.lookAt(position, focus), FieldOfView = 70 })
	local ground = Create("Part", {
		Name = "Ground",
		Anchored = true,
		Size = Vector3.new(140, 1, 140),
		CFrame = CFrame.new(focus.X, -0.5, focus.Z),
		Color = Color3.fromRGB(104, 152, 74),
	})
	local view = Create("ViewportFrame", {
		Name = "World",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(104, 152, 74),
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
