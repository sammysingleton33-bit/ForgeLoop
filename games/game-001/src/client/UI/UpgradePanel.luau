--!strict
--[[
	UI/UpgradePanel — the drawer that opens when a building is tapped in the aerial view (FL-0087,
	prototype scenes "building-upgrade", "building-max", "building-foreign"): one tab naming the
	building and its level, then the shared DetailView — next level's cost and build time, what the
	building gives now and what the next level adds, and one CTA (Upgrade, or why not).

	UpgradePanel.new(parent) -> panel
	panel:render(detail: BuildModel Detail, metrics, ui: { onUpgrade(detail), onClose() })
	panel:destroy()
	The panel is named "UpgradePanel"; its CTA face carries the attribute `cta`.
]]

local Create = require("@game/ReplicatedStorage/Forge/UI/Create")
local DetailView = require("./DetailView")
local IconButton = require("@game/ReplicatedStorage/Forge/UI/Components/IconButton")
local Panel = require("@game/ReplicatedStorage/Forge/UI/Components/Panel")
local Tabs = require("@game/ReplicatedStorage/Forge/UI/Components/Tabs")

local UpgradePanel = {}
UpgradePanel.__index = UpgradePanel

function UpgradePanel.new(parent: Instance)
	return setmetatable({ _parent = parent, panel = nil, detail = nil }, UpgradePanel)
end

function UpgradePanel:render(detail: any, metrics: any, ui: { [string]: any })
	self:destroy()
	local phone = metrics.breakpoint == "phone"
	local d = metrics.drawer
	local header = Create("Frame", {
		Name = "HeaderRow",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
	})
	local level = if detail.action == "upgrade" then detail.level - 1 else detail.level
	Tabs.new({
		tabs = { { id = "building", label = `{detail.name} · Lv {level}`, icon = detail.icon } },
		selected = "building",
		compact = false,
	}).instance.Parent =
		header
	local close = IconButton.new({ icon = "close", variant = "plain", size = 36, onActivated = ui.onClose })
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
	self.detail = DetailView.new({ detail = detail, compact = phone, onCta = ui.onUpgrade })
	self.detail.instance.Parent = self.panel.content
	self.panel.instance.Parent = self._parent
end

function UpgradePanel:destroy()
	if self.panel then
		self.panel:destroy()
		self.panel = nil
	end
	self.detail = nil
end

return UpgradePanel
