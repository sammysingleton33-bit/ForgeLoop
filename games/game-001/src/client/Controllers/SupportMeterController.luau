--!strict
--[[
	SupportMeterController (FORGE-03, game-001 client, FL-0073) — the in-match support meter and its breakdown
	(design crown-arena.md §3, §8; CONTRACTS G12.1 SupportView, G12.4 remotes).
		HUD chip   "Adoring 91 ▲" under the reputation strip (UI/SupportMeter at Layout `metrics.hud.support`), shown
		           while the player has a kingdom and the server has sent a SupportView. A tap opens the breakdown
		           (hud:setMenu("support"); the same tap again closes it).
		Breakdown  the drawer (UI/SupportPanel): tier, trend, next tier, what the tier buys in the arena, the seven
		           components with their weights, and the latest moments that moved it.

	Data (the client decides nothing): on start, in a spawned thread, listen to `Kingdom.Support` (serverEvent to the
	ruler) first, then ask `Kingdom.GetSupport` → SupportView?. Asked again when my kingdom changes (late join). Both are
	gated by hud:hasRemote: until FORGE-01's SupportService declares them nothing is asked, nothing shows and Layout
	keeps no room for the chip (dark launch).

	Depends on KingdomHudController (store, remotes, menus, layout).

	API (specs and the snapshot scenes drive these directly)
		sup:open()               toggles the breakdown (what the chip tap does)
		sup:refresh()            asks Kingdom.GetSupport now (yields; use env.spawn)
		sup:apply(view, pushed?) feeds a SupportView as if it came from the server
		sup.support (SupportView?)   sup.view (UI/SupportMeterModel View?)
		sup.meter (UI/SupportMeter)  sup.panel (UI/SupportPanel)?
]]

local HudModel = require("../UI/HudModel")
local Signature = require("../UI/Signature")
local SupportMeter = require("../UI/SupportMeter")
local SupportMeterModel = require("../UI/SupportMeterModel")
local SupportPanel = require("../UI/SupportPanel")

local SupportMeterController = {}
SupportMeterController.__index = SupportMeterController

local Def = { name = "SupportMeterController", dependencies = { "KingdomHudController" } }

SupportMeterController.MENU = "support"
SupportMeterController.PUSH = "Kingdom.Support"
SupportMeterController.GET = "Kingdom.GetSupport"

function Def.new(env: any, registry: any)
	return setmetatable({
		_env = env,
		hud = registry:get("KingdomHudController"),
		support = nil :: any,
		view = nil :: any,
		_mine = nil :: string?,
		_meterKey = nil :: string?,
		_panelKey = nil :: string?,
		_connections = {} :: { any },
		meter = nil :: any,
		panel = nil :: any,
	}, SupportMeterController)
end

function SupportMeterController:start()
	local env = self._env
	local hud = self.hud
	self._connections = {
		hud.rendered:connect(function(metrics)
			self:render(metrics)
		end),
		hud.store.changed:connect(function(what)
			if what == "kingdoms" then
				self:_onKingdoms()
			end
		end),
	}
	-- Push first, then the full state (G4 rule). Dark until SupportService declares the remotes.
	env.spawn(function()
		if hud:hasRemote(SupportMeterController.PUSH) then
			local ok, err = pcall(function()
				local push = hud.remotes:on(SupportMeterController.PUSH, function(view)
					self:apply(view, true)
				end)
				if self._destroyed then
					push:Disconnect()
				else
					self._push = push
				end
			end)
			if not ok then
				env.log("warn", "SupportMeterController: cannot listen to " .. SupportMeterController.PUSH, {
					error = tostring(err),
				})
			end
		end
		self:refresh()
	end)
end

function SupportMeterController:destroy()
	self._destroyed = true
	for _, connection in self._connections do
		connection:disconnect()
	end
	self._connections = {}
	if self._push then
		pcall(function()
			self._push:Disconnect()
		end)
		self._push = nil
	end
	if self.panel then
		self.panel:destroy()
	end
	if self.meter then
		self.meter:destroy()
	end
end

-- ------------------------------------------------------------------ data

function SupportMeterController:refresh()
	if not self.hud:hasRemote(SupportMeterController.GET) then
		return
	end
	local ok, view = pcall(function()
		return self.hud.remotes:invoke(SupportMeterController.GET)
	end)
	if ok then
		self:apply(view, false)
	else
		self._env.log("warn", "SupportMeterController: " .. SupportMeterController.GET .. " failed", {
			error = tostring(view),
		})
	end
end

function SupportMeterController:apply(view: any, pushed: boolean?)
	if self._destroyed then
		return
	end
	local model = SupportMeterModel.view(view)
	if pushed and model == nil then
		return -- a malformed push never wipes what the server told us before
	end
	self.support = if model then view else nil
	self.view = model
	-- Layout keeps the chip's room only while it shows.
	local hud = self.hud
	local visible = model ~= nil
	if hud.state.support ~= visible then
		hud.state.support = visible
		hud:render() -- new metrics for every view; this controller renders through hud.rendered
	else
		self:render()
	end
end

function SupportMeterController:_onKingdoms()
	local kingdom = self.hud.store:mine()
	local mine = if kingdom then kingdom.id else nil
	if mine == self._mine then
		return
	end
	self._mine = mine
	if mine ~= nil then
		self._env.spawn(function()
			self:refresh()
		end)
	else
		self:apply(nil, false) -- no kingdom: no chip and no room kept for it in Layout (FORGE-00, #225 verifier)
	end
end

-- ------------------------------------------------------------------ actions

function SupportMeterController:open()
	self.hud:setMenu(SupportMeterController.MENU)
end

-- ------------------------------------------------------------------ rendering

function SupportMeterController:render(metrics: any?)
	local hud = self.hud
	if hud.roots.hud == nil or hud.roots.menus == nil then
		return -- not mounted yet (no PlayerGui)
	end
	local m = metrics or hud:metrics()
	local model = self.view
	local active = HudModel.banner(hud.store) ~= nil and model ~= nil
	local open = active and hud.state.menu == SupportMeterController.MENU
	-- a narrow phone's conversation covers the strip rows (as ReputationPanelController hides its strip)
	local narrow = m.hud.pills ~= nil and (m.hud.pills.rows or 1) > 1
	local talking = narrow and hud.state.menu == "conversation"
	self.meter = self.meter or SupportMeter.new(hud.roots.hud)
	local shown = active and not talking and m.hud.support ~= nil
	-- The HUD re-renders on every treasury or construction push: rebuild the chip only when what it shows moved.
	local meterKey = if shown
		then Signature.of({
			tier = model.tier.id,
			score = model.score,
			arrow = model.trend.arrow,
			open = open,
			rect = m.hud.support,
			breakpoint = m.breakpoint,
		})
		else nil
	if meterKey ~= self._meterKey or (shown and self.meter.instance == nil) then
		self._meterKey = meterKey
		if shown then
			self.meter:render(model, m, {
				open = open,
				onOpen = function()
					self:open()
				end,
			})
		else
			self.meter:destroy()
		end
	end
	if not open then
		if self.panel then
			self.panel:destroy()
		end
		self._panelKey = nil
		return
	end
	local key = Signature.of({
		support = self.support,
		breakpoint = m.breakpoint,
		width = m.width,
		height = m.height,
	})
	if key == self._panelKey and self.panel and self.panel.panel then
		return -- unchanged: keep the player's scroll
	end
	self._panelKey = key
	self.panel = self.panel or SupportPanel.new(hud.roots.menus)
	self.panel:render(model, m, {
		onClose = function()
			hud:setMenu(nil)
		end,
	})
end

return Def
