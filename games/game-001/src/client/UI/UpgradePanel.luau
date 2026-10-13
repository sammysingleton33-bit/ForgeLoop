--!strict
--[[
	UI/UpgradePanel — the drawer that opens when a building is tapped in the aerial view (FL-0087,
	prototype scenes "building-upgrade", "building-max", "building-foreign"): one tab naming the
	building and its level, then the shared DetailView — next level's cost and build time, what the
	building gives now and what the next level adds, and one CTA (Upgrade, or why not).

	UpgradePanel.new(parent) -> panel
	panel:render(detail: BuildModel Detail, metrics, ui: { onUpgrade(detail), onClose(),
		tabs: { { id, label, icon } }?, onTab(id)? })
		`tabs` are extra tabs after the building's own (FL-0060: "Army" on my barracks); tapping one
		calls onTab(id). The panel itself always shows the building tab.
	panel:destroy()
	The panel is named "UpgradePanel"; its CTA face carries the attribute `cta`.
	A render that shows the same building at the same level patches the costs and the CTA in place
	(DetailView:update, FORGE-05 M1), so a push never swaps the button under the player's finger.
]]

local Create = require("@game/ReplicatedStorage/Forge/UI/Create")
local DetailView = require("./DetailView")
local IconButton = require("@game/ReplicatedStorage/Forge/UI/Components/IconButton")
local Panel = require("@game/ReplicatedStorage/Forge/UI/Components/Panel")
local Signature = require("./Signature")
local Tabs = require("@game/ReplicatedStorage/Forge/UI/Components/Tabs")

local UpgradePanel = {}
UpgradePanel.__index = UpgradePanel

function UpgradePanel.new(parent: Instance)
	return setmetatable({ _parent = parent, panel = nil, detail = nil, _ui = {} }, UpgradePanel)
end

function UpgradePanel:render(detail: any, metrics: any, ui: { [string]: any })
	self._ui = ui
	local phone = metrics.breakpoint == "phone"
	local handlers = {
		onCta = function(d)
			if self._ui.onUpgrade then
				self._ui.onUpgrade(d)
			end
		end,
	}
	local key = Signature.of({
		breakpoint = metrics.breakpoint,
		drawer = metrics.drawer,
		detail = DetailView.key(detail, phone, nil),
		tabs = ui.tabs,
	})
	if self.panel and key == self._key then
		self.detail:update(detail, handlers)
		return
	end
	-- Rebuilt for the same building (new screen size, the strip shown): keep where the player had
	-- scrolled (FORGE-05, #58 review).
	local scroll = nil
	if self.panel and self._buildingId == detail.buildingId then
		local body = self.panel.instance:FindFirstChild("Body", true)
		if body and body:IsA("ScrollingFrame") then
			scroll = body.CanvasPosition
		end
	end
	self:destroy()
	self._buildingId = detail.buildingId
	self._key = key
	local d = metrics.drawer
	local header = Create("Frame", {
		Name = "HeaderRow",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
	})
	local level = if detail.action == "upgrade" then detail.level - 1 else detail.level
	local tabs = { { id = "building", label = `{detail.name} · Lv {level}`, icon = detail.icon } }
	for _, tab in ui.tabs or {} do
		table.insert(tabs, { id = tab.id, label = tab.label, icon = tab.icon })
	end
	local function chooseTab(id: string)
		if id ~= "building" and self._ui.onTab then
			self._ui.onTab(id)
		end
	end
	local strip = Tabs.new({ tabs = tabs, selected = "building", compact = false, onSelect = chooseTab })
	if phone then
		-- The kit tabs are 34 px tall: on phones an extra tab gets a 44 px hit area (same look).
		for id, button in strip.buttons do
			if id ~= "building" then
				Create("TextButton", {
					Name = "Hit",
					Text = "",
					AutoButtonColor = false,
					BackgroundTransparency = 1,
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.new(1, 0, 0, 44),
					ZIndex = 4,
					Parent = button,
					[Create.Event.Activated] = function()
						chooseTab(id)
					end,
				})
			end
		end
	end
	strip.instance.Parent = header
	local close = IconButton.new({
		icon = "close",
		variant = "plain",
		size = 36,
		onActivated = function()
			if self._ui.onClose then
				self._ui.onClose()
			end
		end,
	})
	close.instance.AnchorPoint = Vector2.new(1, 0.5)
	close.instance.Position = UDim2.fromScale(1, 0.5)
	close.instance.Name = "Close"
	close.instance.Parent = header
	self.panel = Panel.new({
		title = if phone then nil elseif detail.action == "upgrade" then "Upgrade" else "Building",
		header = header,
		size = UDim2.fromOffset(d.width, d.height),
		position = UDim2.fromOffset(d.x, d.y),
		padding = if phone then 10 else 12,
	})
	self.panel.instance.Name = "UpgradePanel"
	self.detail = DetailView.new({ detail = detail, compact = phone, onCta = handlers.onCta })
	self.detail.instance.Parent = self.panel.content
	self.panel.instance.Parent = self._parent
	local body = self.detail.instance:FindFirstChild("Body")
	if scroll and body and body:IsA("ScrollingFrame") then
		body.CanvasPosition = scroll -- after parenting, so the canvas has its size
	end
end

function UpgradePanel:destroy()
	if self.panel then
		self.panel:destroy()
		self.panel = nil
	end
	self.detail = nil
	self._key = nil
end

return UpgradePanel
