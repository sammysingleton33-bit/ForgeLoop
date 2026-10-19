--!strict
--[[
	LeadershipRecapController (FORGE-03, game-001 client, FL-0129) — "Your reign", the leadership recap
	of the Results screen (BRIEF §2): the six reputation values from the start of the match to its end,
	the decisions with the biggest effect, and citizens gained or lost (UI/RecapModel, UI/LeadershipRecap).
	It watches the match while it runs (every POLL_SEC: Match.State from the store, the reputation the
	ReputationPanelController holds, the population), because the server only sends the latest of each.
	The Results summary (SliceSummaryController) shows "Your reign" when recap() has something to say;
	the recap opens over it on the modal layer and Back returns to the results. It closes with the
	summary when a new match starts.

	Arena & support (FL-0073, UI/ArenaRecapModel): each poll also looks at ArenaHudController (optional; its support
	view, ArenaState and duel track) and keeps every support moment, my champion's perks and which fired, and the
	duel's result. recap().arena is set once a SupportView or my kingdom's duel was seen; the recap then has a second
	page ("Arena & support": the five biggest moments, perks fired, the crowd's reaction) behind the Page button.

	Depends on KingdomHudController (store, modal layer, layout); ReputationPanelController is optional
	(no recap without it); ArenaHudController is optional (no arena page without it).
	API (specs, scenes and SliceSummaryController)
		recap:recap() -> UI/RecapModel Recap?      recap:observe()   what each poll does
		recap:open()  recap:close()  recap:setPage("reign" | "arena")  recap.page
		recap.isOpen  recap.track  recap.arenaTrack  recap.view
		LeadershipRecapController.POLL_SEC
]]

local ArenaRecapModel = require("../UI/ArenaRecapModel")
local LeadershipRecap = require("../UI/LeadershipRecap")
local RecapModel = require("../UI/RecapModel")
local Signature = require("../UI/Signature")

local LeadershipRecapController = {}
LeadershipRecapController.__index = LeadershipRecapController

local Def = { name = "LeadershipRecapController", dependencies = { "KingdomHudController" } }

LeadershipRecapController.POLL_SEC = 1

function Def.new(env: any, registry: any)
	return setmetatable({
		_env = env,
		_registry = registry,
		hud = registry:get("KingdomHudController"),
		track = RecapModel.new(),
		arenaTrack = ArenaRecapModel.new(),
		page = "reign",
		_lastKingdom = nil :: string?,
		isOpen = false,
		view = nil :: any,
		_key = nil :: string?,
		_connections = {} :: { any },
	}, LeadershipRecapController)
end

function LeadershipRecapController:start()
	local env = self._env
	table.insert(
		self._connections,
		self.hud.rendered:connect(function(metrics)
			self:render(metrics)
		end)
	)
	self._running = true
	env.spawn(function()
		while self._running do
			env.wait(LeadershipRecapController.POLL_SEC)
			if self._running then
				self:observe()
			end
		end
	end)
end

function LeadershipRecapController:destroy()
	self._destroyed = true
	self._running = false
	for _, connection in self._connections do
		pcall(function()
			connection:disconnect()
		end)
	end
	self._connections = {}
	if self.view then
		self.view:destroy()
	end
end

function LeadershipRecapController:_reputation(): any
	local rep = self._registry:find("ReputationPanelController")
	return if rep ~= nil then rep.data else nil
end

-- One look at the match: the start, the latest values and every history line seen (UI/RecapModel).
function LeadershipRecapController:observe()
	if self._destroyed then
		return
	end
	local store = self.hud.store
	local before = self.track.key
	RecapModel.observe(self.track, store.match, self:_reputation(), store:population())
	local arena = self._registry:find("ArenaHudController")
	if arena ~= nil then
		local kingdom = store:mine()
		ArenaRecapModel.observe(
			self.arenaTrack,
			if type(store.match) == "table" then store.match.startedAt else nil,
			arena.support,
			arena.state,
			arena.track,
			if kingdom then kingdom.id else self._lastKingdom
		)
		if kingdom then
			self._lastKingdom = kingdom.id -- a ruler whose kingdom fell keeps their champion's story
		end
	end
	if self.isOpen and self.track.key ~= before then
		self:close() -- a new match began: last match's recap goes with its summary
	end
end

function LeadershipRecapController:_build(): any
	local recap = RecapModel.build(self.track)
	if recap ~= nil then
		recap.arena = ArenaRecapModel.build(self.arenaTrack)
	end
	return recap
end

function LeadershipRecapController:recap(): any
	self:observe()
	return self:_build()
end

function LeadershipRecapController:setPage(page: string)
	self.page = if page == "arena" then "arena" else "reign"
	self:render()
end

function LeadershipRecapController:open()
	if self:recap() == nil then
		return
	end
	self.isOpen = true
	self.page = "reign"
	self:render()
end

function LeadershipRecapController:close()
	self.isOpen = false
	self:render()
end

function LeadershipRecapController:render(metrics: any?)
	local hud = self.hud
	if self._destroyed or hud.roots.modals == nil then
		return
	end
	self.view = self.view or LeadershipRecap.new(hud.roots.modals)
	if not self.isOpen then
		self.view:destroy()
		self._key = nil
		return
	end
	local recap = self:_build()
	if recap == nil then
		self.view:destroy()
		self._key = nil
		return
	end
	local m = metrics or hud:metrics()
	local key = Signature.of({
		recap = recap,
		page = self.page,
		breakpoint = m.breakpoint,
		width = m.width,
		height = m.height,
	})
	if key == self._key and self.view.instance ~= nil then
		return
	end
	self._key = key
	self.view:render(recap, m, {
		page = self.page,
		onPage = function(page)
			self:setPage(page)
		end,
		onBack = function()
			self:close()
		end,
	})
end

return Def
