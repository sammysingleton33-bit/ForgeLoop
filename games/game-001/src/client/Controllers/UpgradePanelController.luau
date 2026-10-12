--!strict
--[[
	UpgradePanelController (FORGE-03, game-001 client, FL-0087) — upgrading a building from the
	aerial view (CONTRACTS G13.5, G13.6):
		- InputModeController (FORGE-04) fires `selected("building", buildingId)` for a tapped
		  building, or `selected("slot", slotId)` for a plot that is built on (`occupiedBy`).
		- The drawer shows the building and its level, the next level's cost against the treasury, its
		  build time, what the building gives now and what the next level adds (UI/BuildingLevels), and
		  one CTA: "Upgrade to Lv N", or why not (short of resources, still building, highest level).
		- Upgrade goes through KingdomHudController:requestUpgrade — the same path as the Kingdom
		  panel: a large spend asks for confirmation first, then `Build.Upgrade(buildingId)`, a toast,
		  and the chip "Barracks Lv 2" once the server pushes the building.
		- Another kingdom's building opens a read-only card ("Not your building").
	Any other selection (citizen, a free plot, none) closes the panel.

	Depends on KingdomHudController. Optional: InputModeController (FORGE-04).
	API: panel:open(buildingId)  panel:close()  panel.state = { buildingId? }  panel.view (UI/UpgradePanel)
]]

local BuildModel = require("../UI/BuildModel")
local BuildingLevels = require("../UI/BuildingLevels")
local Buildings = require("../UI/Buildings")
local UpgradePanel = require("../UI/UpgradePanel")

local UpgradePanelController = {}
UpgradePanelController.__index = UpgradePanelController

local Def = { name = "UpgradePanelController", dependencies = { "KingdomHudController" } }

UpgradePanelController.MENU = "upgrade"

function Def.new(env: any, registry: any)
	return setmetatable({
		_env = env,
		_registry = registry,
		hud = registry:get("KingdomHudController"),
		state = { buildingId = nil :: number? },
		_connections = {},
	}, UpgradePanelController)
end

local function listen(signal: any, fn: (...any) -> ()): any
	if signal == nil then
		return nil
	end
	local ok, connection = pcall(function()
		return if signal.connect then signal:connect(fn) else signal:Connect(fn)
	end)
	return if ok then connection else nil
end

function UpgradePanelController:start()
	local hud = self.hud
	local input = self._registry:find("InputModeController")
	table.insert(
		self._connections,
		listen(input and input.selected, function(kind, id)
			self:_onSelected(kind, id)
		end)
	)
	table.insert(
		self._connections,
		hud.rendered:connect(function(metrics)
			self:render(metrics)
		end)
	)
	table.insert(
		self._connections,
		hud.menuChanged:connect(function(menu)
			if menu ~= UpgradePanelController.MENU then
				self.state.buildingId = nil
			end
		end)
	)
end

function UpgradePanelController:destroy()
	for _, connection in self._connections do
		if connection then
			pcall(function()
				if connection.disconnect then
					connection:disconnect()
				else
					connection:Disconnect()
				end
			end)
		end
	end
	if self.view then
		self.view:destroy()
	end
end

function UpgradePanelController:_onSelected(kind: any, id: any)
	local store = self.hud.store
	if kind == "building" then
		self:open(id)
		return
	elseif kind == "slot" then
		local slot = store:slot(id)
		if slot and slot.occupiedBy then
			self:open(slot.occupiedBy)
			return
		end
	end
	if self.hud.state.menu == UpgradePanelController.MENU then
		self:close()
	end
end

function UpgradePanelController:open(buildingId: any)
	if self.hud.store:building(buildingId) == nil then
		return
	end
	self.state.buildingId = buildingId
	if self.hud.state.menu == UpgradePanelController.MENU then
		self.hud:render()
	else
		self.hud:setMenu(UpgradePanelController.MENU)
	end
end

function UpgradePanelController:close()
	self.state.buildingId = nil
	if self.hud.state.menu == UpgradePanelController.MENU then
		self.hud:setMenu(nil)
	end
end

-- A building of another kingdom: what it is and its level, nothing to buy.
local function foreignDetail(store: any, building: any): any
	local info = Buildings.get(building.type)
	if info == nil then
		return nil
	end
	local owner = nil
	for _, kingdom in store:kingdoms() do
		if kingdom.id == building.kingdom then
			owner = kingdom.name
		end
	end
	local now = BuildingLevels.benefit(building.type, building.level)
	return {
		type = building.type,
		name = info.name,
		icon = info.icon,
		category = info.category,
		description = nil, -- the catalogue lines speak to the owner ("your kingdom")
		meta = `{owner or "Another kingdom"} · Level {building.level}`,
		action = "view",
		buildingId = building.id,
		level = building.level,
		costs = {},
		benefits = if now then { { label = "Gives", text = now } } else {},
		cta = { state = "disabled", text = "Not your building" },
		needsConfirm = false,
	}
end

function UpgradePanelController:detail(): any
	local hud = self.hud
	local store = hud.store
	local building = store:building(self.state.buildingId)
	if building == nil then
		return nil
	end
	local mine = store:mine()
	if mine == nil or building.kingdom ~= mine.id then
		return foreignDetail(store, building)
	end
	local panel = hud.state.panel
	return BuildModel.upgradeDetail(store, building, {
		pending = panel.pending == building.id,
		done = panel.done == building.id,
	})
end

function UpgradePanelController:render(metrics: any)
	local hud = self.hud
	if hud.roots.menus == nil then
		return
	end
	self.view = self.view or UpgradePanel.new(hud.roots.menus)
	local detail = if hud.state.menu == UpgradePanelController.MENU then self:detail() else nil
	if detail == nil then
		self.view:destroy()
		return
	end
	self.view:render(detail, metrics, {
		onUpgrade = function(d)
			hud:requestUpgrade(d)
		end,
		onClose = function()
			self:close()
		end,
	})
end

return Def
