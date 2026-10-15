--[[
	Off-screen request indicators (FL-0115 B16) for FORGE-03's headless renderer.

	The overview camera at its start zoom (120 studs) over the ruler's own keep. Four citizens with open
	requests are out of view: one far east, one far north, and two together south-west, which share
	one badge with a count. One request near the keep is on screen and gets no badge. The badges come from
	the real CitizenBubbleIndicatorController (Feedback/Requests placement, its own badge build)
	projected through the real RulerCameraController aerial CFrame. A headless approximation, not the
	Studio check (E8 step 13): no terrain, trees or lighting, and no on-screen bubbles drawn here.
		PROJECT=games/game-001/default.project.json DEVICES="phone 667x375 desktop" RENDER_FLAGS="--shots=<dir>" \
			bash design/ui/render/shoot-luau.sh roblox/tests/unit/experience/scenes/requests-edge.luau
]]

local roblox = require("@lune/roblox")
local CameraDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/RulerCameraController")
local IndicatorDef =
	require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/CitizenBubbleIndicatorController")

local Instance = roblox.Instance

local function make(className: string, props: { [string]: any }): any
	local instance = Instance.new(className)
	for key, value in props do
		if key ~= "Parent" then
			instance[key] = value
		end
	end
	instance.Parent = props.Parent
	return instance
end

return function(ctx: any)
	-- the scene draws in the device's safe area (IgnoreGuiInset); the badges' GUI keeps Roblox's core-UI
	-- safe insets, so it starts lower by the top bar: its points are moved into its own area
	local w, h = ctx.deviceArea.width, ctx.deviceArea.height
	local device = ctx.device
	local below = math.max(device.inset.top, device.topbar) - device.inset.top
	local zoom = 120
	local overview = CameraDef.DEFAULTS.overview
	local camera = CameraDef.aerialCFrame(Vector3.zero, math.rad(20), zoom, overview)
	local tanHalf = math.tan(math.rad(CameraDef.DEFAULTS.fieldOfView) / 2)
	-- Camera:WorldToViewportPoint's shape: X, Y in pixels, Z = depth (<= 0 behind the camera)
	local function project(p: Vector3): Vector3
		local l = camera:PointToObjectSpace(p)
		local depth = -l.Z
		local safe = if math.abs(depth) < 1e-3 then 1e-3 else depth
		return Vector3.new(
			math.round((1 + l.X / (safe * tanHalf * w / h)) / 2 * w),
			math.round((1 - l.Y / (safe * tanHalf)) / 2 * h),
			depth
		)
	end

	local scene = make("ScreenGui", { Name = "Aerial", IgnoreGuiInset = true })
	make("Frame", {
		Name = "Ground",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(108, 150, 78),
		BorderSizePixel = 0,
		Parent = scene,
	})
	local function box(name: string, center: Vector3, size: Vector3, color: Color3)
		local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
		for _, sx in { -1, 1 } do
			for _, sy in { 0, 1 } do
				for _, sz in { -1, 1 } do
					local p = project(center + Vector3.new(sx * size.X / 2, sy * size.Y, sz * size.Z / 2))
					minX, minY = math.min(minX, p.X), math.min(minY, p.Y)
					maxX, maxY = math.max(maxX, p.X), math.max(maxY, p.Y)
				end
			end
		end
		make("Frame", {
			Name = name,
			Position = UDim2.fromOffset(minX, minY),
			Size = UDim2.fromOffset(maxX - minX, maxY - minY),
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			Parent = scene,
		})
	end
	box("Keep", Vector3.zero, Vector3.new(24, 18, 24), Color3.fromRGB(150, 146, 140))
	for i, at in { Vector3.new(-40, 0, 10), Vector3.new(36, 0, -18), Vector3.new(-10, 0, -44), Vector3.new(30, 0, 34) } do
		box(`House{i}`, at, Vector3.new(12, 9, 12), Color3.fromRGB(150, 98, 62))
	end

	local requests = {
		{ entityId = 1, position = Vector3.new(18, 2.5, 12), since = 1 }, -- by the keep: on screen
		{ entityId = 2, position = Vector3.new(260, 2.5, -20), since = 2 }, -- far east
		{ entityId = 3, position = Vector3.new(-30, 2.5, -320), since = 3 }, -- far north
		{ entityId = 4, position = Vector3.new(-240, 2.5, 230), since = 4 }, -- south-west, together
		{ entityId = 5, position = Vector3.new(-250, 2.5, 238), since = 5 },
	}
	local near = project(requests[1].position + Vector3.new(0, IndicatorDef.HEIGHT, 0))
	make("TextLabel", {
		Name = "OnScreenRequest",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromOffset(near.X, near.Y),
		Size = UDim2.fromOffset(46, 46),
		BackgroundColor3 = IndicatorDef.GOLD,
		Text = "!",
		Font = Enum.Font.GothamBlack,
		TextSize = 28,
		TextColor3 = IndicatorDef.INK,
		Parent = scene,
	})

	local playerGui = Instance.new("Folder")
	local env = {
		newInstance = function(className)
			return Instance.new(className)
		end,
		clock = function()
			return 0
		end,
		spawn = function() end,
		wait = function() end,
		log = function() end,
	}
	local doubles = {
		CitizenBubbleController = {
			requests = function()
				return requests
			end,
		},
	}
	local controller = IndicatorDef.create(env, {
		find = function(_, name)
			return doubles[name]
		end,
	}, {
		playerGui = playerGui,
		viewport = Vector2.new(ctx.core.width, ctx.core.height),
		project = function(p: Vector3): Vector3
			local q = project(p)
			return Vector3.new(q.X, q.Y - below, q.Z)
		end,
	})
	controller:start()
	controller:refresh()
	local indicators = playerGui:FindFirstChild("ForgeRequestIndicators")
	make("TextLabel", {
		Name = "Caption",
		BackgroundTransparency = 0.3,
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -8),
		Size = UDim2.fromOffset(250, 22),
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		Text = "off-screen requests · F / DPad → next",
		Parent = scene,
	})
	return { guis = { scene, indicators } }
end
