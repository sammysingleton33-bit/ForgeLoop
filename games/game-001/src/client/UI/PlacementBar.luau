--!strict
--[[
	UI/PlacementBar — the bar shown while placing a building (prototype scenes "placing",
	"placing-bad"): the building and its cost, the server's verdict for the ghost's spot, and the
	Rotate / Cancel / Place buttons, sized for touch. Desktop also gets a one-line key hint above it.
	It sits at the bottom centre of the free area (Layout.place), where the construction chips are
	while not placing.

	PlacementBar.new(parent) -> bar
	bar:render(model, metrics, ui)
		model = { name, icon, category, costs: { { currency, amount, short } },
		          status: "pending" | "ok" | "bad", reason: string?, busy: boolean }
		ui = { onRotate, onCancel, onPlace }
	bar:destroy()
	Children: "Status" (TextLabel, attribute `status`), buttons "Rotate", "Cancel", "Place"
	(Place's face carries the attribute `cta`: "ready" | "disabled" | "loading").
]]

local Button = require("@game/ReplicatedStorage/Forge/UI/Components/Button")
local Create = require("@game/ReplicatedStorage/Forge/UI/Create")
local Format = require("@game/ReplicatedStorage/Forge/UI/Format")
local Icon = require("@game/ReplicatedStorage/Forge/UI/Icon")
local IconButton = require("@game/ReplicatedStorage/Forge/UI/Components/IconButton")
local Layout = require("./Layout")
local Style = require("@game/ReplicatedStorage/Forge/UI/Style")
local Theme = require("@game/ReplicatedStorage/Forge/UI/Theme")

local PlacementBar = {}
PlacementBar.__index = PlacementBar

local SHORT = Color3.fromRGB(255, 138, 115)
local GOOD = Color3.fromRGB(169, 229, 124)

function PlacementBar.new(parent: Instance)
	return setmetatable({ _parent = parent, instance = nil :: Frame? }, PlacementBar)
end

function PlacementBar:render(model: any, metrics: any, ui: { [string]: any })
	self:destroy()
	local phone = metrics.breakpoint == "phone"
	local height = metrics.place.height
	local button = if phone then 44 else 48
	local width = if phone then 460 else 520
	local free = Layout.freeArea(metrics, false)

	local costs = Create("Frame", {
		Name = "Costs",
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 16),
		LayoutOrder = 2,
	}, { List = Style.list("x", 6, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center) })
	for i, c in model.costs do
		local icon = Icon.new(c.currency, 14)
		icon.LayoutOrder = 1
		Create("Frame", {
			Name = "Chip_" .. c.currency,
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 16),
			LayoutOrder = i,
			Parent = costs,
		}, {
			List = Style.list("x", 2, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center),
			Icon = icon,
			Amount = Style.text({
				text = Format.amount(c.amount),
				weight = Enum.FontWeight.Bold,
				size = 11,
				color = if c.short then SHORT else Theme.color("textPrimary"),
				extra = { AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromScale(0, 1), LayoutOrder = 2 },
			}),
		})
	end

	local statusText, statusColor
	if model.status == "ok" then
		statusText, statusColor = "✓ Good spot", GOOD
	elseif model.status == "bad" then
		statusText, statusColor = "✕ " .. (model.reason or "Can't build here"), SHORT
	else
		statusText, statusColor = "Checking the ground…", Theme.color("textSecondary")
	end
	local status = Style.text({
		text = statusText,
		weight = Enum.FontWeight.Bold,
		size = 11,
		color = statusColor,
		extra = { Name = "Status", Size = UDim2.new(1, 0, 0, 14), LayoutOrder = 2 },
	})
	status:SetAttribute("status", model.status)

	local rotate = IconButton.new({ icon = "rotate", size = button, layoutOrder = 1, onActivated = ui.onRotate })
	rotate.instance.Name = "Rotate"
	-- Phones: an X instead of the word, so the building name and its cost keep their room.
	local cancelWidth = if phone then button else 88
	local cancel = if phone
		then IconButton.new({ icon = "close", size = button, layoutOrder = 2, onActivated = ui.onCancel })
		else Button.new({
			text = "Cancel",
			variant = "secondary",
			width = cancelWidth,
			layoutOrder = 2,
			onActivated = ui.onCancel,
		})
	cancel.instance.Name = "Cancel"
	local placeWidth = if phone then 92 else 104
	local ready = model.status == "ok" and not model.busy
	local place = Button.new({
		text = "Place",
		icon = "check",
		variant = "primary",
		state = if model.busy then "loading" elseif ready then "default" else "disabled",
		width = placeWidth,
		layoutOrder = 3,
		onActivated = function()
			if ready and ui.onPlace then
				ui.onPlace()
			end
		end,
	})
	place.instance.Name = "Place"
	place.face:SetAttribute("cta", if model.busy then "loading" elseif ready then "ready" else "disabled")

	local tileSize = button - 4
	local tile = Icon.tile(model.icon, tileSize, model.category)
	tile.LayoutOrder = 1
	local bar = Create("Frame", {
		Name = "PlacementBar",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0, math.floor(free.x + free.width / 2), 1, -metrics.place.bottom),
		Size = UDim2.fromOffset(width, height),
		BackgroundColor3 = Color3.new(1, 1, 1),
	}, {
		Corner = Style.corner(14),
		Stroke = Style.stroke(Theme.color("gold600"), 1.5),
		Gradient = Style.gradient(Theme.color("ink700"), Theme.color("ink950")),
		Padding = Style.padding(0, 10, 0, 8),
		Row = Create("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
		}, {
			List = Style.list("x", 10, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center),
			Tile = tile,
			Info = Create("Frame", {
				BackgroundTransparency = 1,
				Size = UDim2.new(1, -(tileSize + 10 + button + 8 + cancelWidth + 8 + placeWidth + 10), 1, 0),
				LayoutOrder = 2,
			}, {
				List = Style.list("y", 3, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center),
				Title = Create("Frame", {
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 0, 18),
					LayoutOrder = 1,
				}, {
					List = Style.list("x", 6, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center),
					BuildingName = Style.text({
						text = model.name,
						role = "heading",
						weight = Enum.FontWeight.Bold,
						size = 14,
						color = Theme.color("parchment100"),
						extra = { AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromScale(0, 1), LayoutOrder = 1 },
					}),
					Costs = costs,
				}),
				Status = status,
			}),
			Buttons = Create("Frame", {
				BackgroundTransparency = 1,
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.fromScale(0, 1),
				LayoutOrder = 3,
			}, {
				List = Style.list("x", 8, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center),
				Rotate = rotate.instance,
				Cancel = cancel.instance,
				Place = place.instance,
			}),
		}),
	})
	if not phone then
		Style.text({
			text = "Move the mouse to aim · R rotates · Click places · Q cancels",
			weight = Enum.FontWeight.Bold,
			size = 11,
			color = Theme.color("parchment100"),
			xAlign = "Center",
			extra = {
				Name = "Hint",
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 0, -8),
				Size = UDim2.new(1, 40, 0, 14),
				TextStrokeTransparency = 0.5,
			},
		}).Parent =
			bar
	end
	self.rotate, self.cancel, self.place, self.status = rotate, cancel, place, status
	bar.Parent = self._parent
	self.instance = bar
end

function PlacementBar:destroy()
	if self.instance then
		self.instance:Destroy()
		self.instance = nil
	end
end

return PlacementBar
