--!strict
--[[
	Experience/SettingsPanel (FORGE-04, FL-0103): the settings drawer, built from FORGE-03's kit
	(UI/Components Panel, IconButton, Button, ProgressBar). It draws SettingsModel sections and calls
	back; it never changes a setting itself.

		SettingsPanel.new(parent) -> panel
		panel:render(sections, frame, ui)
		    sections  SettingsModel.sections(...)
		    frame     { x, y, width, height, compact? }   px inside `parent` (a game's drawer rect);
		              compact = phones: no title, 8 px padding
		    ui        { onChange(key, action), onClose() }   action "down" | "up" | "toggle" | "cycle"
		    The first render (or a new frame) builds the panel; later renders with the same frame patch
		    each row in place (text, bar, enabled), so a tap never swaps the control under the finger.
		panel:destroy()
		panel.instance   the Panel frame, named "SettingsPanel"; each row is a Frame named after its key
	Rows: a volume is "−  [bar 60%]  +"; a toggle is a small button "On" / "Off"; a choice is a small
	button with the option's label that cycles. Every control is at least 36 px (the kit's plain
	square) inside a 44 px row.
]]

local Button = require("../UI/Components/Button")
local Create = require("../UI/Create")
local IconButton = require("../UI/Components/IconButton")
local Panel = require("../UI/Components/Panel")
local ProgressBar = require("../UI/Components/ProgressBar")
local Style = require("../UI/Style")
local Theme = require("../UI/Theme")

local SettingsPanel = {}
SettingsPanel.__index = SettingsPanel

SettingsPanel.ROW_HEIGHT = 44
SettingsPanel.CONTROL_WIDTH = 164 -- − bar + on desktop and phones alike
SettingsPanel.STEPPER = 36
SettingsPanel.SCROLL_GUTTER = 12 -- right padding: the 4 px scroll bar never sits on a control

function SettingsPanel.new(parent: Instance)
	return setmetatable({ _parent = parent, panel = nil, rows = {}, _frameKey = nil, _ui = {} }, SettingsPanel)
end

local function frameKey(frame: { [string]: any }): string
	return `{frame.x}|{frame.y}|{frame.width}|{frame.height}|{frame.compact == true}`
end

function SettingsPanel:_call(key: string, action: string)
	local onChange = self._ui.onChange
	if onChange then
		onChange(key, action)
	end
end

function SettingsPanel:_volumeControls(row: { [string]: any }, holder: Instance): { [string]: any }
	local minus = IconButton.new({
		icon = "minus",
		variant = "plain",
		size = SettingsPanel.STEPPER,
		disabled = not row.canDown,
		layoutOrder = 1,
		onActivated = function()
			self:_call(row.key, "down")
		end,
	})
	minus.instance.Name = "Down"
	minus.instance.Parent = holder
	local bar = ProgressBar.new({
		progress = row.progress,
		label = row.text,
		width = UDim.new(0, SettingsPanel.CONTROL_WIDTH - 2 * SettingsPanel.STEPPER - 16),
		layoutOrder = 2,
	})
	bar.instance.Name = "Level"
	bar.instance.Parent = holder
	local plus = IconButton.new({
		icon = "plus",
		variant = "plain",
		size = SettingsPanel.STEPPER,
		disabled = not row.canUp,
		layoutOrder = 3,
		onActivated = function()
			self:_call(row.key, "up")
		end,
	})
	plus.instance.Name = "Up"
	plus.instance.Parent = holder
	return {
		update = function(r: { [string]: any })
			minus:update({ disabled = not r.canDown })
			bar:update({ progress = r.progress, label = r.text })
			plus:update({ disabled = not r.canUp })
		end,
	}
end

function SettingsPanel:_buttonControl(row: { [string]: any }, holder: Instance): { [string]: any }
	local action = if row.kind == "boolean" then "toggle" else "cycle"
	local function variant(r: { [string]: any }): string
		return if r.kind == "boolean" and r.value == true then "success" else "secondary"
	end
	local button = Button.new({
		text = row.text,
		variant = variant(row),
		size = "small",
		width = SettingsPanel.CONTROL_WIDTH,
		onActivated = function()
			self:_call(row.key, action)
		end,
	})
	button.instance.Name = "Toggle"
	button.instance.Parent = holder
	return {
		update = function(r: { [string]: any })
			button:update({ text = r.text, variant = variant(r) })
		end,
	}
end

function SettingsPanel:_row(row: { [string]: any }, order: number, compact: boolean): Instance
	local frame = Create("Frame", {
		Name = row.key,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, SettingsPanel.ROW_HEIGHT),
		LayoutOrder = order,
	})
	local label = Style.text({
		text = row.label,
		size = Theme.textSize(if compact then "small" else "body"),
		extra = {
			Name = "Label",
			Size = UDim2.new(
				1,
				-(SettingsPanel.CONTROL_WIDTH + 8),
				0,
				if row.note then 24 else SettingsPanel.ROW_HEIGHT
			),
		},
	})
	label.Parent = frame
	local note = Style.text({
		text = row.note or "",
		size = Theme.textSize("caption"),
		color = Theme.color("textMuted"),
		extra = {
			Name = "Note",
			Position = UDim2.fromOffset(0, 22),
			Size = UDim2.new(1, -(SettingsPanel.CONTROL_WIDTH + 8), 0, 18),
			Visible = row.note ~= nil,
		},
	})
	note.Parent = frame
	local holder = Create("Frame", {
		Name = "Control",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.new(0, SettingsPanel.CONTROL_WIDTH, 1, 0),
	})
	Style.list("x", 8, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center).Parent = holder
	holder.Parent = frame
	local controls = if row.kind == "volume"
		then self:_volumeControls(row, holder)
		else self:_buttonControl(row, holder)
	self.rows[row.key] = {
		update = function(r: { [string]: any })
			controls.update(r)
			label.Size =
				UDim2.new(1, -(SettingsPanel.CONTROL_WIDTH + 8), 0, if r.note then 24 else SettingsPanel.ROW_HEIGHT)
			note.Text = r.note or ""
			note.Visible = r.note ~= nil
		end,
	}
	return frame
end

function SettingsPanel:render(sections: { { [string]: any } }, frame: { [string]: any }, ui: { [string]: any })
	self._ui = ui
	local key = frameKey(frame)
	if self.panel and key == self._frameKey then
		for _, section in sections do
			for _, row in section.rows do
				local handle = self.rows[row.key]
				if handle then
					handle.update(row)
				end
			end
		end
		return
	end
	self:destroy()
	self._frameKey = key
	local compact = frame.compact == true
	self.panel = Panel.new({
		title = if compact then nil else "Settings",
		size = UDim2.fromOffset(frame.width, frame.height),
		position = UDim2.fromOffset(frame.x, frame.y),
		padding = if compact then 8 else 12,
		compact = compact,
		onClose = function()
			if self._ui.onClose then
				self._ui.onClose()
			end
		end,
	})
	self.panel.instance.Name = "SettingsPanel"
	local body = Create("ScrollingFrame", {
		Name = "Body",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 4,
	})
	Style.list("y", 2, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top).Parent = body
	Style.padding(0, SettingsPanel.SCROLL_GUTTER, 0, 0).Parent = body -- controls clear the scroll bar
	local order = 0
	for _, section in sections do
		order += 1
		local title = Style.text({
			text = section.title,
			role = "heading",
			size = Theme.textSize("label"),
			color = Theme.color("gold300"),
			extra = { Name = `Section_{section.id}`, Size = UDim2.new(1, 0, 0, 28), LayoutOrder = order },
		})
		title.Parent = body
		for _, row in section.rows do
			order += 1
			self:_row(row, order, compact).Parent = body
		end
	end
	body.Parent = self.panel.content
	self.panel.instance.Parent = self._parent
	self.instance = self.panel.instance
end

function SettingsPanel:destroy()
	if self.panel then
		self.panel:destroy()
		self.panel = nil
	end
	self.instance = nil
	self._frameKey = nil
	table.clear(self.rows)
end

return SettingsPanel
