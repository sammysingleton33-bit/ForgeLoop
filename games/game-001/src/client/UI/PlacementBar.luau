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
		          status: "pending" | "ok" | "bad", reason: string?, busy: boolean,
		          facing: number? (degrees on screen, Placement.screenAngle; default 0) }
		ui = { onRotate, onCancel, onPlace }
	bar:destroy()
	The ghost moves cell by cell and every move re-renders: the bar keeps its instances and patches
	the verdict, the Place button and the short costs (FORGE-05 M1: 200 bars for 200 cells). It is
	rebuilt only for another building or another screen size.
	Children: "Status" (TextLabel, attribute `status`), buttons "Rotate" (the Turn button: rotate icon,
	"Turn" on tablet and desktop, and the "Facing" dial, attribute `facing`), "Cancel", "Place"
	(Place's face carries the attribute `cta`: "ready" | "disabled" | "loading").
]]

local Button = require("@game/ReplicatedStorage/Forge/UI/Components/Button")
local Create = require("@game/ReplicatedStorage/Forge/UI/Create")
local FacingDial = require("./FacingDial")
local Format = require("@game/ReplicatedStorage/Forge/UI/Format")
local Icon = require("@game/ReplicatedStorage/Forge/UI/Icon")
local IconButton = require("@game/ReplicatedStorage/Forge/UI/Components/IconButton")
local Layout = require("./Layout")
local Signature = require("./Signature")
local Style = require("@game/ReplicatedStorage/Forge/UI/Style")
local Theme = require("@game/ReplicatedStorage/Forge/UI/Theme")

local PlacementBar = {}
PlacementBar.__index = PlacementBar

local SHORT = Color3.fromRGB(255, 138, 115)
local GOOD = Color3.fromRGB(169, 229, 124)

function PlacementBar.new(parent: Instance)
	return setmetatable({ _parent = parent, instance = nil :: Frame?, _ui = {} }, PlacementBar)
end

local function statusOf(model: any): (string, Color3)
	if model.status == "ok" then
		return "✓ Good spot", GOOD
	elseif model.status == "bad" then
		return "✕ " .. (model.reason or "Can't build here"), SHORT
	end
	return "Checking the ground…", Theme.color("textSecondary")
end

local function key(model: any, metrics: any): string
	local costs = {}
	for i, c in model.costs do
		costs[i] = { currency = c.currency, amount = c.amount }
	end
	return Signature.of({
		breakpoint = metrics.breakpoint,
		place = metrics.place,
		free = Layout.freeArea(metrics, false),
		name = model.name,
		icon = model.icon,
		category = model.category,
		costs = costs,
	})
end

-- What changes while the ghost moves: the verdict, the Place button, which costs are short.
function PlacementBar:_paint(model: any)
	local text, color = statusOf(model)
	self.status.Text = text
	self.status.TextColor3 = color
	self.status:SetAttribute("status", model.status)
	FacingDial.set(self.facing, model.facing or 0)
	self._ready = model.status == "ok" and not model.busy
	local cta = if model.busy then "loading" elseif self._ready then "ready" else "disabled"
	if cta ~= self._cta then
		self._cta = cta
		self.place:update({ state = if cta == "ready" then "default" else cta })
		self.place.face:SetAttribute("cta", cta)
	end
	for _, c in model.costs do
		local chip = self._costs:FindFirstChild("Chip_" .. c.currency)
		local amount = chip and chip:FindFirstChild("Amount")
		if amount then
			amount.TextColor3 = if c.short then SHORT else Theme.color("textPrimary")
		end
	end
end

function PlacementBar:render(model: any, metrics: any, ui: { [string]: any })
	self._ui = ui
	local k = key(model, metrics)
	if self.instance and k == self._key then
		self:_paint(model)
		return
	end
	self:destroy()
	self._key = k
	local phone = metrics.breakpoint == "phone"
	local height = metrics.place.height
	local button = if phone then 44 else 48
	local width = if phone then 480 else 600
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
				extra = { AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromScale(0, 1), LayoutOrder = 2 },
			}),
		})
	end

	local status = Style.text({
		text = "",
		weight = Enum.FontWeight.Bold,
		size = 11,
		extra = { Name = "Status", Size = UDim2.new(1, 0, 0, 14), LayoutOrder = 2 },
	})

	local function call(name: string): () -> ()
		return function()
			local fn = self._ui[name]
			if fn then
				fn()
			end
		end
	end
	-- Turn: the rotate icon, the word on tablet and desktop, and the dial showing the facing now.
	local dialSize = if phone then 24 else 26
	local rotateIcon = Icon.new("rotate", if phone then 18 else 20)
	rotateIcon.LayoutOrder = 1
	local facing = FacingDial.new(dialSize, 3)
	local rotateWidth = if phone then 70 else 116
	local rotate = Create("TextButton", {
		Name = "Rotate",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.fromOffset(rotateWidth, button),
		LayoutOrder = 1,
		[Create.Event.Activated] = call("onRotate"),
	}, {
		Corner = Style.corner(10),
		Stroke = Style.stroke(Theme.color("gold600"), 1.5),
		Gradient = Style.gradient(Theme.color("ink600"), Theme.color("ink800")),
		List = Style.list("x", 6, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center),
		Icon = rotateIcon,
		Label = if phone
			then nil
			else Style.text({
				text = "Turn",
				weight = Enum.FontWeight.Bold,
				size = 14,
				color = Theme.color("parchment100"),
				extra = { AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromScale(0, 1), LayoutOrder = 2 },
			}),
		Facing = facing,
	})
	-- Phones: an X instead of the word, so the building name and its cost keep their room.
	local cancelWidth = if phone then button else 88
	local cancel = if phone
		then IconButton.new({ icon = "close", size = button, layoutOrder = 2, onActivated = call("onCancel") })
		else Button.new({
			text = "Cancel",
			variant = "secondary",
			width = cancelWidth,
			layoutOrder = 2,
			onActivated = call("onCancel"),
		})
	cancel.instance.Name = "Cancel"
	local placeWidth = if phone then 92 else 104
	local place = Button.new({
		text = "Place",
		icon = "check",
		variant = "primary",
		state = "disabled",
		width = placeWidth,
		layoutOrder = 3,
		onActivated = function()
			if self._ready and self._ui.onPlace then
				self._ui.onPlace()
			end
		end,
	})
	place.instance.Name = "Place"

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
				Size = UDim2.new(1, -(tileSize + 10 + rotateWidth + 8 + cancelWidth + 8 + placeWidth + 10), 1, 0),
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
				Rotate = rotate,
				Cancel = cancel.instance,
				Place = place.instance,
			}),
		}),
	})
	if not phone then
		Style.text({
			text = "Move the mouse to aim · R turns (Shift+R back) · Click places · Q cancels",
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
	self.facing = facing
	self._costs, self._cta = costs, nil
	self:_paint(model)
	bar.Parent = self._parent
	self.instance = bar
end

function PlacementBar:destroy()
	if self.instance then
		self.instance:Destroy()
		self.instance = nil
	end
	self._key = nil
end

return PlacementBar
