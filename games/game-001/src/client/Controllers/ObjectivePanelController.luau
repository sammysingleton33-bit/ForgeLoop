--!strict
--[[
	ObjectivePanelController (FORGE-03, game-001 client, FL-0060) — the HUD objective tracker
	(CONTRACTS G8: ObjectiveService:list() through `Army.Objectives` / `Army.GetObjectives`).
		Tracker   under the top-left stack (Layout `hud.objectives`): each objective's name, its owner
		          (colour swatch + name, "Neutral" or "Yours") and a capture bar per contesting kingdom
		          (name + percentage; mine reads "You" in gold). Collapsed it shows the objective that
		          matters most (one I am capturing, else one I don't hold) with two bars at most and
		          "+N more"; a tap expands the whole list (and closes it again).
	Data (the client decides nothing; the bars move only when the server says so):
		on start, in a spawned thread: listen to `Army.Objectives` (serverEvent to every player) first,
		then ask `Army.GetObjectives`. A push replaces the list; a malformed push (not a table) is
		ignored, and bad entries are dropped (UI/ObjectiveModel.normalize), never an error.
		Pushes patch the tracker in place: the HUD does not re-render for them (they can be frequent).
	It reports its bottom edge to the HUD (hud:setStackBottom) so phone toasts with an open drawer
	start below it.

	Depends on KingdomHudController (remotes, store for kingdom names and colours, layout).
	API (ArmyPanelController, specs and the snapshot scenes)
		objectives:list() -> { Objective }       the newest normalized list (a copy)
		objectives.changed: Signal<({ Objective })>   after every accepted push or fetch
		objectives:apply(payload, pushed?)       feeds a payload as if it came from the server
		objectives:refresh()                     asks Army.GetObjectives now (yields; use env.spawn)
		objectives:toggle()                      what a tap on the tracker does
		objectives.state = { expanded }          objectives.tracker (UI/ObjectiveTracker)
		ObjectivePanelController.PUSH / GET
]]

local HudModel = require("../UI/HudModel")
local ObjectiveModel = require("../UI/ObjectiveModel")
local ObjectiveTracker = require("../UI/ObjectiveTracker")
local Signal = require("@game/ReplicatedStorage/Forge/Core/Signal")

local ObjectivePanelController = {}
ObjectivePanelController.__index = ObjectivePanelController

local Def = { name = "ObjectivePanelController", dependencies = { "KingdomHudController" } }

ObjectivePanelController.PUSH = "Army.Objectives"
ObjectivePanelController.GET = "Army.GetObjectives"

function Def.new(env: any, registry: any)
	return setmetatable({
		_env = env,
		hud = registry:get("KingdomHudController"),
		state = { expanded = false },
		changed = Signal.new(),
		tracker = nil :: any,
		_objectives = {} :: { any },
		_connections = {} :: { any },
	}, ObjectivePanelController)
end

function ObjectivePanelController:start()
	local env = self._env
	local hud = self.hud
	table.insert(
		self._connections,
		hud.rendered:connect(function(metrics)
			self:render(metrics)
		end)
	)
	-- Push first, then the full list (G4 rule, as KingdomHudController does for every area).
	env.spawn(function()
		local ok, err = pcall(function()
			local connection = hud.remotes:on(ObjectivePanelController.PUSH, function(payload)
				self:apply(payload, true)
			end)
			if self._destroyed then
				connection:Disconnect()
			else
				table.insert(self._connections, connection)
			end
		end)
		if not ok then
			env.log("warn", "ObjectivePanelController: cannot listen to " .. ObjectivePanelController.PUSH, {
				error = tostring(err),
			})
		end
		self:refresh() -- returns at once after destroy (FORGE-05 M2 on #63)
	end)
end

function ObjectivePanelController:destroy()
	self._destroyed = true
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
	if self.tracker then
		self.tracker:destroy()
	end
	self.hud:setStackBottom(nil)
end

function ObjectivePanelController:refresh()
	if self._destroyed then
		return
	end
	local ok, payload = pcall(function()
		return self.hud.remotes:invoke(ObjectivePanelController.GET)
	end)
	if ok then
		self:apply(payload, false)
	else
		self._env.log("warn", "ObjectivePanelController: " .. ObjectivePanelController.GET .. " failed", {
			error = tostring(payload),
		})
	end
end

function ObjectivePanelController:apply(payload: any, _pushed: boolean?)
	if self._destroyed then
		return -- a reply that lands after destroy changes nothing and draws nothing
	end
	local list = ObjectiveModel.normalize(payload)
	if list == nil then
		return -- a malformed reply or push never wipes what the server told us before
	end
	self._objectives = list
	self.changed:fire(table.clone(list))
	self:render()
end

function ObjectivePanelController:list(): { any }
	return table.clone(self._objectives)
end

function ObjectivePanelController:toggle()
	self.state.expanded = not self.state.expanded
	self:render()
end

function ObjectivePanelController:render(metrics: any?)
	local hud = self.hud
	if self._destroyed or hud.roots.hud == nil then
		return -- not mounted yet (no PlayerGui)
	end
	local m = metrics or hud:metrics()
	local active = HudModel.banner(hud.store) ~= nil
	local model = ObjectiveModel.tracker(if active then self._objectives else {}, hud.store, {
		expanded = self.state.expanded,
		maxHeight = m.hud.objectives.maxHeight,
	})
	self.tracker = self.tracker or ObjectiveTracker.new(hud.roots.hud)
	self.tracker:render(model, m, {
		onToggle = function()
			self:toggle()
		end,
	})
	hud:setStackBottom(self.tracker:bottom())
end

return Def
