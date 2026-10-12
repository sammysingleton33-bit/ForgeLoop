--!strict
--[[
	ArmyPanelController (FORGE-03, game-001 client, FL-0060) — the army drawer: recruit soldiers at a
	barracks (`Army.Recruit`) and send the idle ones to capture (`Army.Command`), CONTRACTS G8.

	Where it opens (one drawer, one state; menu id "army"):
		- the rail button "Army" (hud:addRailItem; OnboardingTarget "HUD.ArmyButton") toggles it for my
		  barracks: the one the player tapped last, else my first finished one, else none ("Build a
		  Barracks to recruit soldiers"; Send to capture still works);
		- tapping my barracks in the world opens its upgrade panel (UpgradePanelController, FL-0087),
		  which gets an "Army" tab (upgrade:addTab) that opens this drawer for that barracks; here the
		  "Barracks · Lv N" tab goes back to the upgrade panel.
		- selection "none" (InputModeController, G13.6) closes it, like the upgrade panel.

	Recruit: `Army.Recruit(barracksId, "soldier", count)` with count 1..10 (− / + stepper). The cost is
	Costs.unit("soldier") × count from the store's catalogue (Treasury.GetCosts `units`, config Costs
	until it answers), shown against the treasury; the CTA is disabled with the reason when short
	("Need 30 Food"). One request in flight (the CTA shows "Recruiting…"); a toast on success or with
	the server's reason as a sentence (UI/ArmyText), never the raw code. The server spends the
	treasury and raises the population; the panel shows what Treasury.Changed and Kingdom.Population
	push. Soldier count: hud.store:population().byJob.soldier, "—" until the server sends it.

	Send to capture: `Army.Command({}, "capture")` — no unit ids = all my idle soldiers, no target = the
	server's choice (CONTRACTS "VS-1 command"; target picking is VS-2). Army.Command is an event (no
	reply): local feedback only — a toast "Soldiers sent", the button reads "Sent" and ignores taps
	for COOLDOWN_SEC. Disabled with a reason when the server says there are no soldiers, or when every
	objective is already mine (ObjectivePanelController's list, optional).

	Depends on KingdomHudController. Optional: UpgradePanelController, ObjectivePanelController,
	InputModeController (registry:find in start).
	API (specs and the snapshot scenes)
		army:open(barracksId?)  army:close()  army:setCount(n)  army:less()  army:more()
		army:recruit()  army:send()  army:model() -> UI/ArmyModel Panel
		army.state = { barracksId?, count, pending, cooling }   army.view (UI/ArmyPanel)
		ArmyPanelController.MENU = "army"  .COOLDOWN_SEC  .RECRUIT  .COMMAND
]]

local ArmyModel = require("../UI/ArmyModel")
local ArmyPanel = require("../UI/ArmyPanel")
local ArmyText = require("../UI/ArmyText")
local HudModel = require("../UI/HudModel")
local Motion = require("@game/ReplicatedStorage/Forge/UI/Motion")

local ArmyPanelController = {}
ArmyPanelController.__index = ArmyPanelController

local Def = { name = "ArmyPanelController", dependencies = { "KingdomHudController" } }

ArmyPanelController.MENU = "army"
ArmyPanelController.COOLDOWN_SEC = 3
ArmyPanelController.RECRUIT = "Army.Recruit"
ArmyPanelController.COMMAND = "Army.Command"
ArmyPanelController.RAIL = table.freeze({
	id = "army",
	icon = "army",
	label = "Army",
	target = "HUD.ArmyButton",
	order = 3,
})

function Def.new(env: any, registry: any)
	return setmetatable({
		_env = env,
		_registry = registry,
		_motion = Motion.new(env),
		hud = registry:get("KingdomHudController"),
		state = { barracksId = nil :: number?, count = 1, pending = false, cooling = false },
		view = nil :: any,
		_cooldownToken = 0,
		_connections = {} :: { any },
	}, ArmyPanelController)
end

-- Framework Signal (:connect) or RBXScriptSignal (:Connect).
local function connect(signal: any, fn: (...any) -> ()): any
	if signal == nil then
		return nil
	end
	local ok, connection = pcall(function()
		if type(signal) == "table" and type(signal.connect) == "function" then
			return signal:connect(fn)
		end
		return signal:Connect(fn)
	end)
	return if ok then connection else nil
end

function ArmyPanelController:start()
	local hud = self.hud
	local registry = self._registry
	hud:addRailItem(ArmyPanelController.RAIL)
	table.insert(
		self._connections,
		hud.rendered:connect(function(metrics)
			self:render(metrics)
		end)
	)
	local input = registry:find("InputModeController")
	local selection = connect(input and input.selected, function(kind, id)
		self:_onSelected(kind, id)
	end)
	if selection then
		table.insert(self._connections, selection)
	end
	self._objectives = registry:find("ObjectivePanelController")
	if self._objectives and self._objectives.changed then
		table.insert(
			self._connections,
			self._objectives.changed:connect(function()
				if self:isOpen() then
					self:render()
				end
			end)
		)
	end
	self._upgrade = registry:find("UpgradePanelController")
	if self._upgrade and self._upgrade.addTab then
		self._upgrade:addTab({
			id = "army",
			label = ArmyText.TAB,
			icon = "army",
			applies = function(building: any)
				return building.type == "barracks"
			end,
			onSelect = function(buildingId: number)
				self:open(buildingId)
			end,
		})
	end
end

function ArmyPanelController:destroy()
	for _, connection in self._connections do
		pcall(function()
			if connection.disconnect then
				connection:disconnect()
			else
				connection:Disconnect()
			end
		end)
	end
	self._connections = {}
	if self.view then
		self.view:destroy()
	end
end

function ArmyPanelController:isOpen(): boolean
	return self.hud.state.menu == ArmyPanelController.MENU
end

function ArmyPanelController:_onSelected(kind: any, id: any)
	if kind == "building" then
		-- Remember my barracks: the rail opens the drawer for the one tapped last.
		local building = self.hud.store:building(id)
		local mine = self.hud.store:mine()
		if building and mine and building.kingdom == mine.id and building.type == "barracks" then
			self.state.barracksId = building.id
		end
	elseif kind == "none" and self:isOpen() then
		self:close()
	end
end

-- ------------------------------------------------------------------ actions

function ArmyPanelController:open(barracksId: number?)
	if barracksId ~= nil then
		self.state.barracksId = barracksId
	end
	if self:isOpen() then
		self.hud:render()
	else
		self.hud:setMenu(ArmyPanelController.MENU)
	end
end

function ArmyPanelController:close()
	if self:isOpen() then
		self.hud:setMenu(nil)
	end
end

function ArmyPanelController:setCount(n: number)
	self.state.count = ArmyModel.clampCount(n)
	self:render()
end

function ArmyPanelController:less()
	self:setCount(self.state.count - 1)
end

function ArmyPanelController:more()
	self:setCount(self.state.count + 1)
end

function ArmyPanelController:model(): any
	local s = self.state
	return ArmyModel.panel(self.hud.store, {
		barracksId = s.barracksId,
		count = s.count,
		pending = s.pending,
		cooling = s.cooling,
		objectives = if self._objectives then self._objectives:list() else nil,
	})
end

function ArmyPanelController:recruit()
	local s = self.state
	local model = self:model()
	if s.pending or model.recruit.state ~= "ready" or model.barracks == nil then
		return
	end
	local hud = self.hud
	local barracksId, count = model.barracks.id, model.count
	s.pending = true
	self:render()
	self._env.spawn(function()
		local called, ok, reason = pcall(function()
			return hud.remotes:invoke(ArmyPanelController.RECRUIT, barracksId, ArmyModel.UNIT, count)
		end)
		s.pending = false
		if called and ok == true then
			hud:notify({ kind = "success", title = ArmyText.recruited(count), body = ArmyText.RECRUITED_BODY })
		else
			hud:notify({
				kind = "error",
				title = ArmyText.RECRUIT_FAILED,
				body = ArmyText.reason(if called then reason else nil),
			})
		end
		self:render()
	end)
end

function ArmyPanelController:send()
	local s = self.state
	if s.cooling or self:model().send.state ~= "ready" then
		return
	end
	local hud = self.hud
	s.cooling = true
	self._cooldownToken += 1
	local token = self._cooldownToken
	self:render()
	hud:notify({ kind = "success", title = ArmyText.SENT_TOAST, body = ArmyText.SENT_TOAST_BODY })
	-- An event: fire and forget (send may wait for the remote to replicate, so not on this thread).
	self._env.spawn(function()
		local ok, err = pcall(function()
			hud.remotes:send(ArmyPanelController.COMMAND, {}, "capture")
		end)
		if not ok then
			self._env.log("warn", "ArmyPanelController: " .. ArmyPanelController.COMMAND .. " failed", {
				error = tostring(err),
			})
			hud:notify({ kind = "error", title = ArmyText.UNREACHABLE })
		end
	end)
	self._motion:after(ArmyPanelController.COOLDOWN_SEC, function()
		if token == self._cooldownToken then
			s.cooling = false
			self:render()
		end
	end)
end

-- ------------------------------------------------------------------ rendering

function ArmyPanelController:render(metrics: any?)
	local hud = self.hud
	if hud.roots.menus == nil then
		return -- not mounted yet (no PlayerGui)
	end
	self.view = self.view or ArmyPanel.new(hud.roots.menus)
	local open = self:isOpen() and HudModel.banner(hud.store) ~= nil
	if not open then
		self.view:destroy()
		return
	end
	local m = metrics or hud:metrics()
	-- Keyed render (UI/ArmyPanel.key): treasury, population and construction pushes patch the
	-- values on the same instances (FORGE-05 M1).
	self.view:render(self:model(), m, {
		onTab = function(id)
			local barracks = ArmyModel.barracks(hud.store, self.state.barracksId)
			if id == "building" and barracks and self._upgrade then
				self._upgrade:open(barracks.id)
			end
		end,
		onLess = function()
			self:less()
		end,
		onMore = function()
			self:more()
		end,
		onRecruit = function()
			self:recruit()
		end,
		onSend = function()
			self:send()
		end,
		onClose = function()
			self:close()
		end,
	})
end

return Def
