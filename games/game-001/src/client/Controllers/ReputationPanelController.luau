--!strict
--[[
	ReputationPanelController (FORGE-03, game-001 client, FL-0089) — the HUD reputation strip and
	the reputation screen (CONTRACTS G13.4; design/living-kingdom.md §3).
		HUD strip   six small bars with icon and number (and name on tablet/desktop), always visible
		            while the player has a kingdom and the server has answered (UI/ReputationStrip).
		            A tap opens the screen (hud:setMenu("reputation"); the same tap again closes it).
		Screen      the drawer with tabs Reputation / History / Kingdom (UI/ReputationPanel).

	Data (the client decides nothing; values change only when the server says so):
		on start, in a spawned thread: listen to `Kingdom.Reputation` (serverEvent to the ruler)
		first, then ask `Kingdom.GetReputation` → { values, history (latest 30), kingdom:
		{ happiness, stability, morale } }. A push is assumed to carry the same shape (handoff
		production/handoffs/2026-10-12-forge-03-to-forge-01-reputation-ui.md): it replaces the data,
		moves the bars, adds the history line at the top and floats each changed value on the strip.
		GetReputation is asked again when my kingdom changes (late join). History `t` is read as
		serverTimeNow seconds; "… ago" labels in the open screen refresh every REFRESH_SEC.
	Category prose ("About", "What affects it") comes from a provider: ReputationText.provider (the
	content library, nil until FL-0083 lands) or setCategoryText(fn). Without one, no prose is shown.

	Depends on KingdomHudController (store, remotes, menus, layout). The strip is drawn into
	hud.roots.hud at Layout `metrics.hud.reputation`; the screen into hud.roots.menus at
	`metrics.drawer`.

	API (specs and the snapshot scenes drive these directly)
		rep:open()                          toggles the screen (what the strip tap does)
		rep:selectTab(id)  rep:select(category)  rep:back()
		rep:setCategoryText(provider?)      (id) -> { name?, description?, affects? }?
		rep:refresh()                       asks Kingdom.GetReputation now (yields; use env.spawn)
		rep:apply(payload, pushed?)         feeds a payload as if it came from the server
		rep.data (UI/ReputationModel Data)  rep.state = { tab, selected, phoneView, fresh }
		rep.strip (UI/ReputationStrip)      rep.panel (UI/ReputationPanel)?
]]

local HudModel = require("../UI/HudModel")
local Motion = require("@game/ReplicatedStorage/Forge/UI/Motion")
local ReputationModel = require("../UI/ReputationModel")
local ReputationPanel = require("../UI/ReputationPanel")
local ReputationStrip = require("../UI/ReputationStrip")
local ReputationText = require("../UI/ReputationText")

local ReputationPanelController = {}
ReputationPanelController.__index = ReputationPanelController

local Def = { name = "ReputationPanelController", dependencies = { "KingdomHudController" } }

ReputationPanelController.MENU = "reputation"
ReputationPanelController.PUSH = "Kingdom.Reputation"
ReputationPanelController.GET = "Kingdom.GetReputation"
ReputationPanelController.REFRESH_SEC = 10

function Def.new(env: any, registry: any)
	return setmetatable({
		_env = env,
		_motion = Motion.new(env),
		hud = registry:get("KingdomHudController"),
		data = ReputationModel.empty(),
		state = { tab = "values", selected = "compassion", phoneView = "list", fresh = false },
		_provider = ReputationText.provider :: ReputationText.Provider?,
		_version = 0,
		_panelKey = nil :: string?,
		_mine = nil :: string?,
		_running = false,
		strip = nil :: any,
		panel = nil :: any,
	}, ReputationPanelController)
end

function ReputationPanelController:start()
	local env = self._env
	local hud = self.hud
	self._connections = {
		hud.rendered:connect(function(metrics)
			self:render(metrics)
		end),
		hud.menuChanged:connect(function(menu)
			if menu == ReputationPanelController.MENU then
				self.state.phoneView = "list"
			end
		end),
		hud.store.changed:connect(function(what)
			if what == "kingdoms" then
				self:_onKingdoms()
			end
		end),
	}
	self._running = true
	-- Push first, then the full state (G4 rule, as KingdomHudController does for every area).
	env.spawn(function()
		local ok, err = pcall(function()
			hud.remotes:on(ReputationPanelController.PUSH, function(payload)
				self:apply(payload, true)
			end)
		end)
		if not ok then
			env.log("warn", "ReputationPanelController: cannot listen to " .. ReputationPanelController.PUSH, {
				error = tostring(err),
			})
		end
		self:refresh()
	end)
	env.spawn(function()
		while self._running do
			env.wait(ReputationPanelController.REFRESH_SEC)
			if self._running and self.panel and hud.state.menu == ReputationPanelController.MENU then
				self.panel:refreshTimes(env.serverTimeNow())
			end
		end
	end)
end

function ReputationPanelController:destroy()
	self._running = false
	for _, connection in self._connections or {} do
		connection:disconnect()
	end
	if self.panel then
		self.panel:destroy()
	end
	if self.strip then
		self.strip:destroy()
	end
end

-- ------------------------------------------------------------------ data

function ReputationPanelController:refresh()
	local ok, payload = pcall(function()
		return self.hud.remotes:invoke(ReputationPanelController.GET)
	end)
	if ok then
		self:apply(payload, false)
	else
		self._env.log(
			"warn",
			"ReputationPanelController: " .. ReputationPanelController.GET .. " failed",
			{ error = tostring(payload) }
		)
	end
end

function ReputationPanelController:apply(payload: any, pushed: boolean?)
	if pushed and type(payload) ~= "table" then
		return -- a malformed push never wipes what the server told us before
	end
	local before = self.data
	self.data = ReputationModel.normalize(payload)
	self._version += 1
	self.state.fresh = pushed == true and #self.data.history > 0
	self:render()
	if pushed and self.strip then
		self.strip:pulse(ReputationModel.deltas(before, self.data))
	end
end

function ReputationPanelController:_onKingdoms()
	local kingdom = self.hud.store:mine()
	local mine = if kingdom then kingdom.id else nil
	if mine == self._mine then
		return
	end
	self._mine = mine
	if mine ~= nil then
		-- A late join: this ruler's reputation was never pushed to this client.
		self._env.spawn(function()
			self:refresh()
		end)
	end
end

function ReputationPanelController:setCategoryText(provider: ReputationText.Provider?)
	self._provider = provider
	self._version += 1
	self:render()
end

-- ------------------------------------------------------------------ actions

function ReputationPanelController:open()
	self.hud:setMenu(ReputationPanelController.MENU)
end

function ReputationPanelController:selectTab(id: string)
	self.state.tab = id
	self.state.phoneView = "list"
	self:render()
end

function ReputationPanelController:select(category: string)
	if not ReputationText.isCategory(category) then
		return
	end
	self.state.selected = category
	self.state.phoneView = "detail"
	self:render()
end

function ReputationPanelController:back()
	self.state.phoneView = "list"
	self:render()
end

-- ------------------------------------------------------------------ rendering

function ReputationPanelController:_model(): { [string]: any }
	local now = self._env.serverTimeNow()
	return {
		tab = self.state.tab,
		selected = self.state.selected,
		phoneView = self.state.phoneView,
		fresh = self.state.fresh,
		known = self.data.known,
		categories = ReputationModel.categories(self.data, now, self._provider),
		history = ReputationModel.history(self.data, now),
		conditions = ReputationModel.conditions(self.data),
	}
end

function ReputationPanelController:render(metrics: any?)
	local hud = self.hud
	if hud.roots.hud == nil or hud.roots.menus == nil then
		return -- not mounted yet (no PlayerGui)
	end
	local m = metrics or hud:metrics()
	local active = HudModel.banner(hud.store) ~= nil
	local open = active and hud.state.menu == ReputationPanelController.MENU
	self.strip = self.strip or ReputationStrip.new(hud.roots.hud, self._motion)
	self.strip:render({
		visible = active and self.data.known,
		items = ReputationModel.strip(self.data, self._provider),
		open = open,
		onOpen = function()
			self:open()
		end,
	}, m)
	if not open then
		if self.panel then
			self.panel:destroy()
		end
		self._panelKey = nil
		return
	end
	local s = self.state
	-- Rebuild only when something it shows changed: the HUD re-renders on every treasury or
	-- construction push, and a rebuild would reset the player's scroll position.
	local key = `{self._version}|{s.tab}|{s.selected}|{s.phoneView}|{m.breakpoint}|{m.width}x{m.height}`
	if key == self._panelKey and self.panel and self.panel.panel then
		return
	end
	self._panelKey = key
	self.panel = self.panel or ReputationPanel.new(hud.roots.menus)
	self.panel:render(self:_model(), m, {
		onTab = function(id)
			self:selectTab(id)
		end,
		onSelect = function(id)
			self:select(id)
		end,
		onBack = function()
			self:back()
		end,
		onClose = function()
			hud:setMenu(nil)
		end,
	})
end

return Def
