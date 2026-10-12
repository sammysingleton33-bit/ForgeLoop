--!strict
--[[
	UI/ReputationStrip — the always-visible reputation strip in the HUD's top-left stack (FL-0089;
	prototype games/game-001/design/ui/reputation.js, scenes "hud" and "hud-change"): six small bars
	(0..100), each with its icon and its number, plus its name on tablet and desktop. Colour is
	never the only signal. Tapping anywhere on it opens the reputation screen.
	Placed by Layout `metrics.hud.reputation` (phones: one row under the crest; tablet/desktop:
	3 × 2 under the rulers). It lives in the HUD root, next to UI/KingdomHud's container.

	ReputationStrip.new(parent, motion?) -> strip
	strip:render(model, metrics)
		model = { visible: boolean, items: { ReputationModel Item }, open: boolean, onOpen: () -> () }
	strip:pulse(deltas)     floats a signed chip ("+4", "−2") on each changed item for PULSE_SEC
	strip:destroy()
	strip.instance: Frame "ReputationStrip" (OnboardingTarget "HUD.Reputation")
	strip.hit: TextButton "Open" over the whole strip, at least Theme TOUCH (44) px tall
	strip.items[id] = { frame: Frame "Rep_<id>" (attribute `value`; children "Icon", "RepName"
		(tablet/desktop), "Value", "Bar"), value: TextLabel, bar: ProgressBar }
]]

local Create = require("@game/ReplicatedStorage/Forge/UI/Create")
local Icon = require("@game/ReplicatedStorage/Forge/UI/Icon")
local ProgressBar = require("@game/ReplicatedStorage/Forge/UI/Components/ProgressBar")
local ReputationModel = require("./ReputationModel")
local ReputationText = require("./ReputationText")
local Style = require("@game/ReplicatedStorage/Forge/UI/Style")
local Theme = require("@game/ReplicatedStorage/Forge/UI/Theme")

local ReputationStrip = {}
ReputationStrip.__index = ReputationStrip

ReputationStrip.PULSE_SEC = 1.6
ReputationStrip.ICON = 16
ReputationStrip.VALUE_WIDTH = 24

function ReputationStrip.new(parent: Instance, motion: any?)
	return setmetatable({
		_parent = parent,
		_motion = motion,
		_key = nil :: string?,
		_compact = false,
		instance = nil :: Frame?,
		hit = nil :: TextButton?,
		items = {},
	}, ReputationStrip)
end

function ReputationStrip:_build(metrics: any)
	self:destroy()
	local r = metrics.hud.reputation
	local compact = metrics.breakpoint == "phone"
	self._compact = compact
	self._stroke = Style.stroke(Theme.color("gold600"), 1, 0.4)
	local strip = Create("Frame", {
		Name = "ReputationStrip",
		BackgroundColor3 = Theme.color("ink950"),
		BackgroundTransparency = 0.2,
		Position = UDim2.fromOffset(r.x, r.y),
		Size = UDim2.fromOffset(r.width, r.height),
	}, {
		Corner = Style.corner(10),
		Stroke = self._stroke,
	})
	strip:SetAttribute("OnboardingTarget", "HUD.Reputation")
	self.items = {}
	for i, id in ReputationText.IDS do
		local info = ReputationText.CATEGORIES[id]
		local column = (i - 1) % r.columns
		local row = (i - 1) // r.columns
		local w, h = r.item.width, r.item.height
		local icon = Icon.new(info.icon, ReputationStrip.ICON)
		icon.Position = UDim2.fromOffset(0, -1)
		local value = Style.text({
			text = "…",
			weight = Enum.FontWeight.ExtraBold,
			size = 12,
			xAlign = if compact then "Left" else "Right",
			extra = if compact
				then { Name = "Value", Position = UDim2.fromOffset(19, 0), Size = UDim2.fromOffset(w - 19, 15) }
				else {
					Name = "Value",
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.fromScale(1, 0),
					Size = UDim2.fromOffset(ReputationStrip.VALUE_WIDTH, 15),
				},
		})
		local bar = ProgressBar.new({ progress = 0, color = Theme.color(info.color), height = 4 })
		bar.instance.AnchorPoint = Vector2.new(0, 1)
		bar.instance.Position = UDim2.fromScale(0, 1)
		local frame = Create("Frame", {
			Name = "Rep_" .. id,
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(r.pad + column * (w + r.gap.x), r.pad + row * (h + r.gap.y)),
			Size = UDim2.fromOffset(w, h),
			Parent = strip,
		}, {
			Icon = icon,
			RepName = if compact
				then nil
				else Style.text({
					text = info.name,
					size = 10,
					color = Theme.color("textSecondary"),
					extra = {
						Position = UDim2.fromOffset(19, 0),
						Size = UDim2.fromOffset(w - 19 - ReputationStrip.VALUE_WIDTH, 15),
					},
				}),
			Value = value,
			Bar = bar.instance,
		})
		self.items[id] = { frame = frame, value = value, bar = bar }
	end
	-- One target for the whole strip, centred on it and never under 44 px tall (Theme TOUCH).
	local hitHeight = math.max(Theme.TOUCH or 44, r.height)
	self.hit = Create("TextButton", {
		Name = "Open",
		Text = "",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.new(1, 0, 0, hitHeight),
		ZIndex = 5,
		Parent = strip,
		[Create.Event.Activated] = function()
			if self._onOpen then
				self._onOpen()
			end
		end,
	})
	strip.Parent = self._parent
	self.instance = strip
end

function ReputationStrip:render(model: { [string]: any }, metrics: any)
	local r = metrics.hud.reputation
	local key = `{metrics.breakpoint}:{r.x}:{r.y}:{r.width}:{r.height}`
	if self._key ~= key or self.instance == nil or self.instance.Parent == nil then
		self._key = key
		self:_build(metrics)
	end
	local strip = self.instance :: Frame
	self._onOpen = model.onOpen
	strip.Visible = model.visible == true
	self._stroke.Color = if model.open then Theme.color("gold400") else Theme.color("gold600")
	self._stroke.Transparency = if model.open then 0 else 0.4
	for _, item in model.items or {} do
		local entry = self.items[item.id]
		if entry then
			entry.value.Text = item.label
			entry.bar:update({ progress = (item.value or 0) / ReputationModel.MAX })
			entry.frame:SetAttribute("value", item.value)
			local label = entry.frame:FindFirstChild("RepName")
			if label then
				(label :: TextLabel).Text = item.name
			end
		end
	end
end

-- Floats each change on its item: below the strip on phones (one row), over the item's name on
-- tablet/desktop (two rows: a chip under the first row would cover the second).
function ReputationStrip:pulse(deltas: { [string]: number })
	for id, delta in deltas do
		local entry = self.items[id]
		if entry == nil or delta == 0 then
			continue
		end
		local previous = entry.frame:FindFirstChild("Delta")
		if previous then
			previous:Destroy()
		end
		local positive = delta > 0
		local chip = Create("Frame", {
			Name = "Delta",
			BackgroundColor3 = Theme.color("ink950"),
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 18),
			AnchorPoint = if self._compact then Vector2.new(0.5, 0) else Vector2.new(1, 0),
			Position = if self._compact
				then UDim2.new(0.5, 0, 1, 10)
				else UDim2.new(1, -ReputationStrip.VALUE_WIDTH - 2, 0, -2),
			ZIndex = 6,
			Parent = entry.frame,
		}, {
			Corner = Style.corner(999),
			Stroke = Style.stroke(if positive then Theme.color("vert") else Theme.color("gules"), 1),
			Padding = Style.padding(0, 6),
			Text = Style.text({
				text = ReputationModel.signed(delta),
				weight = Enum.FontWeight.ExtraBold,
				size = 12,
				color = if positive then Theme.hex("#A9E57C") else Theme.hex("#FF8A73"),
				xAlign = "Center",
				extra = { AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromScale(0, 1), ZIndex = 6 },
			}),
		})
		if self._motion then
			self._motion:after(ReputationStrip.PULSE_SEC, function()
				if chip.Parent ~= nil then
					chip:Destroy()
				end
			end)
		end
	end
end

function ReputationStrip:destroy()
	if self.instance then
		self.instance:Destroy()
		self.instance = nil
	end
	self.hit = nil
	self.items = {}
end

return ReputationStrip
