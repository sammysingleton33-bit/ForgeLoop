--!strict
--[[
	PlotPickerController (FORGE-03, game-001 client, FL-0087) — building on a plot from the aerial
	view (CONTRACTS G13.5, G13.6):
		1. FORGE-04's InputModeController fires `selected("slot", slotId)` when the player taps a free
		   build slot. (Nobody else raycasts for selection.)
		2. The drawer opens on that plot: the structures that fit its size (BuildModel.plotTypes over Build/Fit), each with its
		   cost against the treasury, build time and what it gives; phones show the list, then the detail.
		3. "Build <name> here" calls `Build.PlaceSlot(slotId, type)`. On success a toast confirms and the
		   drawer closes; the spend floats under the pills (Treasury.Changed) and the new building
		   arrives as a construction chip (Build.Buildings). A refusal shows the server's reason.
	A tapped slot that is already built on belongs to UpgradePanelController. Any other selection
	(citizen, building, none) closes the picker.

	Data: `Build.Slots` (push) and `Build.GetSlots` (my kingdom's plots { id, size, occupiedBy? })
	into KingdomStore:applySlots.
	Depends on KingdomHudController. Optional: InputModeController (FORGE-04).

	API (specs and snapshot scenes drive these directly)
		picker:open(slotId)  picker:select(type)  picker:back()  picker:place(detail)  picker:close()
		picker.state = { slotId?, selected?, phoneView }   picker._inFlight[slotId] while its order is out   picker.menu (UI/BuildMenu)
]]

local BuildMenu = require("../UI/BuildMenu")
local BuildModel = require("../UI/BuildModel")
local Text = require("../UI/Text")

local PlotPickerController = {}
PlotPickerController.__index = PlotPickerController

local Def = { name = "PlotPickerController", dependencies = { "KingdomHudController" } }

PlotPickerController.MENU = "plot"

function Def.new(env: any, registry: any)
	return setmetatable({
		_env = env,
		_registry = registry,
		hud = registry:get("KingdomHudController"),
		state = { slotId = nil :: string?, selected = nil :: string?, phoneView = "list" },
		_connections = {},
		_inFlight = {}, -- slotId -> true while its Build.PlaceSlot has no reply (FORGE-05 L2)
	}, PlotPickerController)
end

-- Connects to a framework Signal (:connect) or an RBXScriptSignal (:Connect).
local function listen(signal: any, fn: (...any) -> ()): any
	if signal == nil then
		return nil
	end
	local ok, connection = pcall(function()
		return if signal.connect then signal:connect(fn) else signal:Connect(fn)
	end)
	return if ok then connection else nil
end

function PlotPickerController:start()
	local env = self._env
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
			if menu ~= PlotPickerController.MENU then
				self.state.slotId = nil
			end
		end)
	)
	-- Push first, then the full list (as KingdomHudController does for every area).
	env.spawn(function()
		local ok, err = pcall(function()
			local connection = hud.remotes:on("Build.Slots", function(list)
				hud.store:applySlots(list)
				self:_checkOpenPlot()
			end)
			if self._destroyed then
				connection:Disconnect() -- the remote replicated after destroy (FORGE-05, #41 review)
				return
			end
			table.insert(self._connections, {
				disconnect = function()
					connection:Disconnect()
				end,
			})
		end)
		if not ok then
			env.log("warn", "PlotPickerController: cannot listen to Build.Slots", { error = tostring(err) })
		end
		if self._destroyed then
			return
		end
		local fetched, list = pcall(function()
			return hud.remotes:invoke("Build.GetSlots")
		end)
		if fetched then
			hud.store:applySlots(list)
		else
			env.log("warn", "PlotPickerController: Build.GetSlots failed", { error = tostring(list) })
		end
	end)
end

function PlotPickerController:destroy()
	self._destroyed = true
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
	if self.menu then
		self.menu:destroy()
	end
end

function PlotPickerController:_onSelected(kind: any, id: any)
	if kind == "slot" then
		self:open(id)
	elseif self.hud.state.menu == PlotPickerController.MENU then
		self:close()
	end
end

-- The open plot was built on by someone else (a co-ruler, or the server): the drawer would vanish
-- with hud.state.menu still "plot" (FORGE-05, #48 review). Close it and say why. My own order closes
-- it on its reply instead.
function PlotPickerController:_checkOpenPlot()
	local s = self.state
	if self.hud.state.menu ~= PlotPickerController.MENU or s.slotId == nil or self._inFlight[s.slotId] then
		return
	end
	local slot = self.hud.store:slot(s.slotId)
	if slot == nil or slot.occupiedBy ~= nil then
		self:close()
		self.hud:notify({ kind = "info", title = "This plot was just built on", body = "Pick another plot" })
	end
end

function PlotPickerController:open(slotId: any)
	local slot = self.hud.store:slot(slotId)
	if slot == nil or slot.occupiedBy ~= nil then
		-- Not one of my free plots: a built-on plot is the upgrade panel's, others are not mine.
		if self.hud.state.menu == PlotPickerController.MENU then
			self:close()
		end
		return
	end
	local s = self.state
	s.slotId = slot.id
	s.selected = nil
	s.phoneView = "list"
	if self.hud.state.menu == PlotPickerController.MENU then
		self.hud:render()
	else
		self.hud:setMenu(PlotPickerController.MENU)
	end
end

function PlotPickerController:select(buildingType: string)
	self.state.selected = buildingType
	self.state.phoneView = "detail"
	self.hud:render()
end

function PlotPickerController:back()
	self.state.phoneView = "list"
	self.hud:render()
end

function PlotPickerController:close()
	self.state.slotId = nil
	if self.hud.state.menu == PlotPickerController.MENU then
		self.hud:setMenu(nil)
	end
end

function PlotPickerController:place(detail: any)
	local s = self.state
	-- One order per plot until its reply, whatever was opened or closed meanwhile: `_inFlight` is the
	-- only record (a second flag per showing masked bugs in either, FORGE-05 #48 review).
	if detail == nil or detail.cta.state ~= "ready" or s.slotId == nil or self._inFlight[s.slotId] then
		return
	end
	local hud = self.hud
	local slotId = s.slotId
	self._inFlight[slotId] = true
	hud:render()
	self._env.spawn(function()
		local called, buildingId, reason = pcall(function()
			return hud.remotes:invoke("Build.PlaceSlot", slotId, detail.type)
		end)
		self._inFlight[slotId] = nil
		if called and type(buildingId) == "number" then
			hud:notify({ kind = "success", title = `{detail.name} ordered`, body = "Builders are on their way" })
			if s.slotId == slotId then
				self:close()
			end
		else
			hud:notify({
				kind = "error",
				title = "Couldn't build here",
				body = Text.reason(if called then reason else nil, "slot"),
			})
		end
		hud:render()
	end)
end

function PlotPickerController:render(metrics: any)
	local hud = self.hud
	if hud.roots.menus == nil then
		return
	end
	self.menu = self.menu or BuildMenu.new(hud.roots.menus)
	local s = self.state
	local slot = if hud.state.menu == PlotPickerController.MENU then hud.store:slot(s.slotId) else nil
	if slot == nil or slot.occupiedBy ~= nil then
		self.menu:destroy()
		return
	end
	-- Reopening a plot whose order is still on its way shows it busy: no second PlaceSlot.
	local view = BuildModel.plotMenu(
		hud.store,
		{ slot = slot, selected = s.selected, pending = self._inFlight[slot.id] == true }
	)
	self.menu:render(view, metrics, {
		title = "Build here",
		name = "PlotPicker",
		phoneView = s.phoneView,
		onCategory = function() end,
		onSelect = function(buildingType)
			self:select(buildingType)
		end,
		onBack = function()
			self:back()
		end,
		onPlace = function(detail)
			self:place(detail)
		end,
		onClose = function()
			self:close()
		end,
	})
end

return Def
