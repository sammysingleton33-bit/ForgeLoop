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
	Turning (CONTRACTS G13.5 v0.4-g9h; the user's first Studio feedback): while the server takes a turn
	(UI/Turns.supported), the detail has a Facing row: the dial shows where the front will face from the
	current camera, the label says how it stands to the street, and Turn steps through the quarter
	turns that fit the plot (`Fit.fits(type, size, turn)`); `Build.PlaceSlot(slotId, type, turn)` sends
	it. Without that support PlaceSlot keeps its two arguments. Either way a ghost (UI/Ghost: the
	footprint, the door strip and the facing arrow) previews the selected building on the plot, inside
	the plot's outline, from `world/Layout` plots[*].buildSlots (centre and yaw).
	A tapped slot that is already built on belongs to UpgradePanelController. Any other selection
	(citizen, building, none) closes the picker.

	Data: `Build.Slots` (push) and `Build.GetSlots` (my kingdom's plots { id, size, occupiedBy? })
	into KingdomStore:applySlots.
	Depends on KingdomHudController. Optional: InputModeController (FORGE-04).

	API (specs and snapshot scenes drive these directly)
		picker:open(slotId)  picker:select(type)  picker:back()  picker:place(detail)  picker:close()
		picker:turn()        the next turn that fits (no-op without turn support)
		picker.state = { slotId?, selected?, phoneView, turn }   picker.ghost (UI/Ghost)?
		PlotPickerController.slotFrame(slotId) -> { center: Vector3, yaw: number, size: Vector2 }?   picker._inFlight[slotId] while its order is out   picker.menu (UI/BuildMenu)
]]

local BuildMenu = require("../UI/BuildMenu")
local BuildModel = require("../UI/BuildModel")
local Ghost = require("../UI/Ghost")
local Placement = require("../UI/Placement")
local Slots = require("../UI/Slots")
local Text = require("../UI/Text")
local Turns = require("../UI/Turns")

local PlotPickerController = {}
PlotPickerController.__index = PlotPickerController

local Def = { name = "PlotPickerController", dependencies = { "KingdomHudController" } }

PlotPickerController.MENU = "plot"

-- Where a build slot stands in the world (UI/Slots: world/Layout, FORGE-02's shape).
function PlotPickerController.slotFrame(slotId: any): { center: Vector3, yaw: number, size: Vector2 }?
	return Slots.frame(slotId)
end

function Def.new(env: any, registry: any)
	return setmetatable({
		_env = env,
		_registry = registry,
		hud = registry:get("KingdomHudController"),
		state = { slotId = nil :: string?, selected = nil :: string?, phoneView = "list", turn = 0 },
		ghost = nil :: any,
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
	-- the back key (KingdomHudController:setBackStep): a phone detail goes back to its list first
	if self.hud.setBackStep ~= nil then
		self.hud:setBackStep(PlotPickerController.MENU, function()
			if self.state.phoneView ~= "detail" or self.hud:metrics().breakpoint ~= "phone" then
				return false
			end
			self:back()
			return true
		end)
	end
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
	self:_hideGhost()
end

-- While a building is picked up (FL-0120; edit mode, FL-0121, or build mode before it) a tap on my own
-- plot or building belongs to the move: opening a menu would cancel it (FORGE-07 B1 on #148).
function PlotPickerController:_editing(): boolean
	local build = self._registry:find("BuildMenuController")
	return build ~= nil and build.moving ~= nil and build:moving()
end

function PlotPickerController:_onSelected(kind: any, id: any)
	if self:_editing() then
		return
	end
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
	s.turn = 0
	if self.hud.state.menu == PlotPickerController.MENU then
		self.hud:render()
	else
		self.hud:setMenu(PlotPickerController.MENU)
	end
end

function PlotPickerController:select(buildingType: string)
	self.state.selected = buildingType
	self.state.phoneView = "detail"
	self.state.turn = 0
	self.hud:render()
end

-- The next quarter turn that fits the plot (v0.4-g9h). Nothing while the server takes no turn.
function PlotPickerController:turn()
	local view = self._view
	local detail = view and view.detail
	if detail == nil or detail.turn == nil or self._inFlight[self.state.slotId] then
		return
	end
	self.state.turn = Turns.next(detail.turn.allowed, detail.turn.value)
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
			if detail.turn ~= nil then
				return hud.remotes:invoke("Build.PlaceSlot", slotId, detail.type, detail.turn.value)
			end
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

-- Where a building turned by `yaw` faces on screen now (degrees, 0 = away from the camera).
function PlotPickerController:_facing(yaw: number): number
	local ok, camera = pcall(function()
		return self._env.Workspace.CurrentCamera.CFrame
	end)
	return Placement.screenAngle(yaw, if ok and typeof(camera) == "CFrame" then camera else nil)
end

-- The selected building on its plot: footprint, door and facing arrow, inside the plot's outline.
function PlotPickerController:_showGhost(slotId: string, detail: any)
	local frame = PlotPickerController.slotFrame(slotId)
	local footprint = detail.footprint
	if frame == nil or footprint == nil then
		self:_hideGhost()
		return
	end
	local turn = if detail.turn then detail.turn.value else 0
	self.ghost = self.ghost or Ghost.new(self._env)
	-- the outline is the plot itself: it stays put while the building turns inside it
	local plot = if turn % 2 == 1 then Vector2.new(frame.size.Y, frame.size.X) else frame.size
	self.ghost:show(footprint, CFrame.new(frame.center) * CFrame.Angles(0, Turns.yaw(frame.yaw, turn), 0), plot)
	self.ghost:tint(if detail.cta.state == "ready" then "ok" else "pending")
end

function PlotPickerController:_hideGhost()
	if self.ghost then
		self.ghost:destroy()
		self.ghost = nil
	end
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
		self._view = nil
		self:_hideGhost()
		return
	end
	-- Reopening a plot whose order is still on its way shows it busy: no second PlaceSlot.
	local view = BuildModel.plotMenu(
		hud.store,
		{ slot = slot, selected = s.selected, pending = self._inFlight[slot.id] == true, turn = s.turn }
	)
	local detail = view and view.detail
	if detail and detail.turn then
		s.turn = detail.turn.value -- a turn that no longer fits falls back to one that does
		local frame = PlotPickerController.slotFrame(slot.id)
		detail.turn.facing = self:_facing(Turns.yaw(if frame then frame.yaw else 0, detail.turn.value))
	end
	self._view = view
	if detail then
		self:_showGhost(slot.id, detail)
	else
		self:_hideGhost()
	end
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
		onPlace = function(chosen)
			self:place(chosen)
		end,
		onClose = function()
			self:close()
		end,
		onTurn = function()
			self:turn()
		end,
	})
end

Def.slotFrame = PlotPickerController.slotFrame

return Def
