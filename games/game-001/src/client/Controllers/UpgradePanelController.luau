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
	Move (FL-0120, CONTRACTS G13.9): my own building, not the keep, not destroyed, while the server
	serves `Build.Move` (hud:hasRemote) gets a Move button beside the CTA; it closes the panel and
	starts BuildMenuController:startMove. For Buildings.moveCooldown seconds (else 10) after my own
	accepted move of it, Move is disabled and reads "Moved"; the server sends no time left, so this
	counts from the client's own answer.
	Extra tabs (FL-0060): another controller adds a tab with `panel:addTab({ id, label, icon,
	applies(building, store) -> boolean, onSelect(buildingId) })`; it shows after the building's tab
	when `applies` says so (ArmyPanelController: "Army" on my barracks, which opens the army drawer).

	Depends on KingdomHudController. Optional: InputModeController (FORGE-04).
	API: panel:open(buildingId)  panel:close()  panel:addTab(tab)  panel:removeTab(id)  panel:move(buildingId)
	     panel.state = { buildingId? }
		panel.view (UI/UpgradePanel)
]]

local BuildModel = require("../UI/BuildModel")
local BuildingLevels = require("../UI/BuildingLevels")
local Buildings = require("../UI/Buildings")
local BuildingsConfig = require("@game/ReplicatedStorage/Forge/Config/Buildings")
local UpgradePanel = require("../UI/UpgradePanel")

local UpgradePanelController = {}
UpgradePanelController.__index = UpgradePanelController

local Def = { name = "UpgradePanelController", dependencies = { "KingdomHudController" } }

UpgradePanelController.MENU = "upgrade"
UpgradePanelController.MOVE_COOLDOWN = 10 -- seconds, when config Buildings has no moveCooldown

function Def.new(env: any, registry: any)
	return setmetatable({
		_env = env,
		_registry = registry,
		hud = registry:get("KingdomHudController"),
		state = { buildingId = nil :: number? },
		_tabs = {} :: { any },
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

-- While a building is picked up (FL-0120; edit mode, FL-0121, or build mode before it) a tap on my own
-- plot or building belongs to the move: opening a menu would cancel it (FORGE-07 B1 on #148).
function UpgradePanelController:_editing(): boolean
	local build = self._registry:find("BuildMenuController")
	return build ~= nil and build.moving ~= nil and build:moving()
end

function UpgradePanelController:_onSelected(kind: any, id: any)
	if self:_editing() then
		return
	end
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

function UpgradePanelController:addTab(tab: { [string]: any })
	for _, existing in self._tabs do
		if existing.id == tab.id then
			return
		end
	end
	table.insert(self._tabs, tab)
	if self.hud.state.menu == UpgradePanelController.MENU then
		self.hud:render()
	end
end

function UpgradePanelController:removeTab(id: string)
	for i, existing in self._tabs do
		if existing.id == id then
			table.remove(self._tabs, i)
			if self.hud.state.menu == UpgradePanelController.MENU then
				self.hud:render()
			end
			return
		end
	end
end

-- The extra tabs that apply to this building (only buildings of my kingdom get any).
function UpgradePanelController:_extraTabs(building: any): { any }
	local store = self.hud.store
	local mine = store:mine()
	local out = {}
	if building == nil or mine == nil or building.kingdom ~= mine.id then
		return out
	end
	for _, tab in self._tabs do
		local ok, applies = pcall(tab.applies, building, store)
		if ok and applies then
			table.insert(out, { id = tab.id, label = tab.label, icon = tab.icon })
		end
	end
	return out
end

function UpgradePanelController:_selectTab(id: string)
	local buildingId = self.state.buildingId
	for _, tab in self._tabs do
		if tab.id == id and buildingId ~= nil then
			tab.onSelect(buildingId)
			return
		end
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
	local detail = BuildModel.upgradeDetail(store, building, {
		pending = panel.pending == building.id,
		done = panel.done == building.id,
	})
	if detail then
		detail.side = self:_moveAction(building)
	end
	return detail
end

-- The Move button (FL-0120), or nil where a move can never apply.
function UpgradePanelController:_moveAction(building: any): any
	local hud = self.hud
	if building.type == "keep" or building.state == "destroyed" or not hud:hasRemote("Build.Move") then
		return nil
	end
	local build = self._registry:find("BuildMenuController")
	if build == nil or build.startMove == nil then
		return nil
	end
	-- one rule for the Move button and the drag (FL-0123): BuildMenuController:moveCooldownLeft
	local left
	if type(build.moveCooldownLeft) == "function" then
		left = build:moveCooldownLeft(building.id)
	else
		local cooldown = (BuildingsConfig :: any).moveCooldown
		cooldown = if type(cooldown) == "number" then cooldown else UpgradePanelController.MOVE_COOLDOWN
		local movedAt = build.movedAt and build.movedAt[building.id]
		left = if movedAt then cooldown - (self._env.clock() - movedAt) else 0
	end
	if left > 0 then
		self:_renderAfter(left)
		return { text = "Moved", icon = "move", state = "disabled" }
	end
	return { text = "Move", icon = "move", state = "ready" }
end

-- One render when the Move cooldown is over, so the button wakes up by itself.
function UpgradePanelController:_renderAfter(seconds: number)
	local due = self._env.clock() + seconds
	if self._wake and self._wake <= due + 0.05 and self._wake >= due - 0.05 then
		return
	end
	self._wake = due
	self._env.spawn(function()
		self._env.wait(seconds + 0.05)
		if self._wake == due then
			self._wake = nil
			if self.hud.state.menu == UpgradePanelController.MENU then
				self.hud:render()
			end
		end
	end)
end

function UpgradePanelController:move(buildingId: any)
	local build = self._registry:find("BuildMenuController")
	if build and build.startMove then
		build:startMove(buildingId) -- closes this panel (another menu: setMenu(nil))
	end
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
	local extra = self:_extraTabs(hud.store:building(self.state.buildingId))
	self.view:render(detail, metrics, {
		tabs = if #extra > 0 then extra else nil,
		onTab = function(id)
			self:_selectTab(id)
		end,
		onUpgrade = function(d)
			hud:requestUpgrade(d)
		end,
		onSide = function(d)
			self:move(d.buildingId)
		end,
		onClose = function()
			self:close()
		end,
	})
end

return Def
