--!strict
--[[
	SliceSummaryController (FORGE-03, game-001 client, FL-0060) — the end-of-slice summary.
	In VS-1 the first captured objective ends the slice (CONTRACTS G3): the server fires the G9
	MatchEnded payload to every client through the `Match.Ended` remote (G8). G9 events are
	server-only; this controller only listens to the remote.
		Summary   on the modal layer (hud.roots.modals, a ScreenInsets.None ScreenGui): winner (or
		          "No winner"), standings with Crown Points (mine highlighted, AI kingdoms tagged, names
		          and colours from Kingdom.State), how long it lasted, and Continue, which closes it.
	A malformed payload (not a table) is ignored; bad standings entries are dropped
	(UI/SummaryModel.normalize). The summary re-renders only when what it shows changes (kingdom names
	arriving, a new breakpoint), never for a treasury or construction push (FORGE-05 M1).

	Depends on KingdomHudController (remotes, store, modal layer, layout).
	API (specs and the snapshot scenes)
		summary:show(payload)     what a Match.Ended push does
		summary:close()           what Continue does
		summary.isOpen  summary.ended (UI/SummaryModel Ended)  summary.view (UI/SliceSummary)
		SliceSummaryController.EVENT = "Match.Ended"
]]

local Signature = require("../UI/Signature")
local SliceSummary = require("../UI/SliceSummary")
local SummaryModel = require("../UI/SummaryModel")

local SliceSummaryController = {}
SliceSummaryController.__index = SliceSummaryController

local Def = { name = "SliceSummaryController", dependencies = { "KingdomHudController" } }

SliceSummaryController.EVENT = "Match.Ended"

function Def.new(env: any, registry: any)
	return setmetatable({
		_env = env,
		hud = registry:get("KingdomHudController"),
		isOpen = false,
		ended = nil :: any,
		view = nil :: any,
		_key = nil :: string?,
		_connections = {} :: { any },
	}, SliceSummaryController)
end

function SliceSummaryController:start()
	local env = self._env
	local hud = self.hud
	table.insert(
		self._connections,
		hud.rendered:connect(function(metrics)
			self:render(metrics)
		end)
	)
	env.spawn(function()
		local ok, err = pcall(function()
			local connection = hud.remotes:on(SliceSummaryController.EVENT, function(payload)
				self:show(payload)
			end)
			if self._destroyed then
				connection:Disconnect()
			else
				table.insert(self._connections, connection)
			end
		end)
		if not ok then
			env.log("warn", "SliceSummaryController: cannot listen to " .. SliceSummaryController.EVENT, {
				error = tostring(err),
			})
		end
	end)
end

function SliceSummaryController:destroy()
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
	if self.view then
		self.view:destroy()
	end
end

function SliceSummaryController:show(payload: any)
	local ended = SummaryModel.normalize(payload)
	if ended == nil then
		self._env.log("warn", "SliceSummaryController: ignored a malformed Match.Ended payload", {})
		return
	end
	self.ended = ended
	self.isOpen = true
	-- The match is over: no drawer stays open with live buttons under the summary (FORGE-05 low 6).
	local hud = self.hud
	self._shownPhase = if hud.store.match then hud.store.match.phase else nil
	if hud.state.menu ~= nil then
		hud:setMenu(nil)
	end
	self:render()
end

function SliceSummaryController:close()
	self.isOpen = false
	self:render()
end

function SliceSummaryController:render(metrics: any?)
	local hud = self.hud
	if self._destroyed or hud.roots.modals == nil then
		return -- not mounted yet (no PlayerGui)
	end
	-- A new match began (the phase moved past Results, or away from the phase it was shown in, other
	-- than into Results): the old summary goes.
	local phase = if hud.store.match then hud.store.match.phase else nil
	if self.isOpen and phase ~= nil and phase ~= "Results" and phase ~= self._shownPhase then
		self.isOpen = false
	end
	self.view = self.view or SliceSummary.new(hud.roots.modals)
	if not self.isOpen or self.ended == nil then
		self.view:destroy()
		self._key = nil
		return
	end
	local m = metrics or hud:metrics()
	local model = SummaryModel.build(self.ended, hud.store)
	local key = Signature.of({ model = model, breakpoint = m.breakpoint, width = m.width })
	if key == self._key and self.view.instance ~= nil then
		return
	end
	self._key = key
	self.view:render(model, m, {
		onContinue = function()
			self:close()
		end,
	})
end

return Def
