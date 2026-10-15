--[[
	Shared builder for the citizen-bubble scenes (FL-0091) of FORGE-03's headless renderer
	(bubbles-start.luau: the overview's start zoom, 120 studs; bubbles-max.luau: its max zoom-out, 220).

	A kingdom (keep, houses, 14 citizens about 5 studs tall) is projected through the real overview
	camera (RulerCameraController's Def.aerialCFrame and field of view). Five citizens have requests, one
	reacts and one strikes. Which bubbles show and which keep their words come from the real
	Feedback/Bubbles rules (pick, textLimit, layout) and each bubble is painted by the real
	CitizenBubbleController (`_build` + `Def.paint`). The renderer draws ScreenGuis only, so each
	BillboardGui's content sits in a Frame of its size whose bottom edge is at the projected point
	HEIGHT studs above the rig's pivot (the BillboardGui's StudsOffset and SizeOffset).
	A headless approximation, not the Studio check (E8): no terrain, trees or lighting.
		PROJECT=games/game-001/default.project.json DEVICES="phone desktop" RENDER_FLAGS="--shots=<dir>" \
			bash design/ui/render/shoot-luau.sh roblox/tests/unit/experience/scenes/bubbles-start.luau
]]

local roblox = require("@lune/roblox")
local Bubbles = require("@game/ReplicatedStorage/Game/Feedback/Bubbles")
local Vfx = require("@game/ReplicatedStorage/Forge/Config/Vfx")
local BubbleDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/CitizenBubbleController")
local CameraDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/RulerCameraController")
local Layout = require("@game/StarterPlayer/StarterPlayerScripts/Game/UI/Layout")

local Instance = roblox.Instance
local RIG_HEIGHT = 5 -- studs, feet to head
local PIVOT_HEIGHT = 2.5 -- the rig's root above its feet

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

return function(ctx: any, zoom: number)
	local w, h = ctx.device.width, ctx.device.height
	local overview = CameraDef.DEFAULTS.overview
	local camera = CameraDef.aerialCFrame(Vector3.zero, math.rad(20), zoom, overview)
	local tanHalf = math.tan(math.rad(CameraDef.DEFAULTS.fieldOfView) / 2)
	local function project(p: Vector3): (number, number)
		local l = camera:PointToObjectSpace(p)
		local depth = -l.Z
		-- whole pixels: Lune keeps UDim offsets as integers
		return math.round((1 + l.X / (depth * tanHalf * w / h)) / 2 * w),
			math.round((1 - l.Y / (depth * tanHalf)) / 2 * h)
	end

	local gui = make("ScreenGui", { Name = "Aerial", IgnoreGuiInset = true })
	make("Frame", {
		Name = "Ground",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(108, 150, 78),
		BorderSizePixel = 0,
		Parent = gui,
	})
	local function box(name: string, center: Vector3, size: Vector3, color: Color3)
		local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
		for _, sx in { -1, 1 } do
			for _, sy in { 0, 1 } do
				for _, sz in { -1, 1 } do
					local x, y = project(center + Vector3.new(sx * size.X / 2, sy * size.Y, sz * size.Z / 2))
					minX, minY = math.min(minX, x), math.min(minY, y)
					maxX, maxY = math.max(maxX, x), math.max(maxY, y)
				end
			end
		end
		make("Frame", {
			Name = name,
			Position = UDim2.fromOffset(minX, minY),
			Size = UDim2.fromOffset(maxX - minX, maxY - minY),
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			Parent = gui,
		})
	end
	box("Keep", Vector3.zero, Vector3.new(24, 18, 24), Color3.fromRGB(150, 146, 140))
	for i, at in { Vector3.new(-40, 0, 10), Vector3.new(36, 0, -18), Vector3.new(-10, 0, -44), Vector3.new(30, 0, 34) } do
		box(`House{i}`, at, Vector3.new(12, 9, 12), Color3.fromRGB(150, 98, 62))
	end

	-- 14 citizens around the keep (fixed, so the scene never changes between runs)
	local spots = {}
	for i = 1, 14 do
		local angle = i * 2.39996 -- golden angle
		local radius = 18 + (i * 37 % 43)
		spots[i] = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
	end
	for i, feet in spots do
		local x, top = project(feet + Vector3.new(0, RIG_HEIGHT, 0))
		local _, bottom = project(feet)
		local tall = math.max(3, bottom - top)
		make("Frame", {
			Name = `Citizen{i}`,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromOffset(x, top),
			Size = UDim2.fromOffset(math.max(2, math.round(tall * 0.45)), tall),
			BackgroundColor3 = Color3.fromRGB(176, 58, 46),
			BorderSizePixel = 0,
			Parent = gui,
		})
	end

	-- the real rules: which bubbles show, which keep their words
	local bubbles = Bubbles.new({
		now = function()
			return 0
		end,
		config = Vfx.bubbles,
	})
	local thoughts = {
		[2] = { text = "These forge walls won't last the month.", icon = "request" },
		[5] = { text = "Another one? My back is a knot of rope.", icon = "concern" },
		[7] = { text = "Half a forge. And the other half?", icon = "idea" },
		[9] = { text = "We need more bread.", icon = "request" },
		[12] = { text = "The well is dry again.", icon = "request" },
	}
	for id, data in thoughts do
		bubbles:thought(id, data)
	end
	bubbles:reaction(4, { text = "Thank you, my lord!", tone = "happy" })
	bubbles:strike(11, true)
	local pivots = {}
	for i, feet in spots do
		pivots[i] = feet + Vector3.new(0, PIVOT_HEIGHT, 0)
	end
	local phone = Layout.breakpoint(w, h) == "phone"
	local order = bubbles:pick(pivots, Vector3.zero)
	local anchors = {}
	for _, id in order do
		local x, y = project(pivots[id] + Vector3.new(0, BubbleDef.HEIGHT, 0))
		anchors[id] = Vector2.new(x, y)
	end
	local forms = bubbles:layout(order, bubbles:textLimit(zoom, phone), anchors)

	local env = {
		newInstance = function(className)
			return Instance.new(className)
		end,
		clock = function()
			return 0
		end,
		spawn = function() end,
		wait = function() end,
	}
	local controller = BubbleDef.create(env, {
		find = function()
			return nil
		end,
	})
	for index = #order, 1, -1 do -- the first picked drawn last, on top
		local id = order[index]
		if forms[id] == nil then
			continue -- a reaction without room: not drawn
		end
		local x, y = anchors[id].X, anchors[id].Y
		local billboard = controller:_build()
		BubbleDef.paint(billboard, bubbles:get(id), forms[id] == "words")
		local holder = make("Frame", {
			Name = `Bubble{id}`,
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.fromOffset(x, y),
			Size = billboard.Size,
			Parent = gui,
		})
		billboard:FindFirstChild("Bubble").Parent = holder
	end
	make("TextLabel", {
		Name = "Caption",
		BackgroundTransparency = 0.3,
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -8, 1, -8),
		Size = UDim2.fromOffset(230, 22),
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		Text = `overview zoom {zoom} studs{if phone then " · phone" else ""}`,
		Parent = gui,
	})
	return { guis = { gui } }
end
