--!strict
--[[
	SupportService — the support a ruler has earned, as the meter and the arena read it (CONTRACTS G12.2/G12.4, design §3/§8).
	Owner: FORGE-01. It computes nothing itself: LeadershipService samples the kingdom and the ruler, SupportModel turns
	those samples into a score, a tier, the trigger offers and their slots.

		SupportService:getView(kingdom, userId?): SupportView?     nil for a kingdom that is not in the match
			{ kingdom, userId (0 for an AI-held kingdom), score, tier, trend, breakdown, moments (the latest 5),
			  offers, slots }
		SupportService:forChampion(userId?, kingdom): Support?     what ArenaFlow needs: { score, tier, offers, slots,
			reasons } where `reasons` are the three moment texts that moved the score most (largest change first, the
			newest of equals), each text once
		Remote Kingdom.GetSupport() -> SupportView?    the caller's own view; nil for anyone who rules no kingdom
		Remote Kingdom.Support(SupportView)            pushed to every seated ruler after each leadership sample
		SupportService:enabled() -> boolean            config Arena `enabled`; while false GetSupport answers nil and nothing is
		                                               pushed (the support meter stays dark until the arena is real)

	A ruler only ever sees their own view (userId comes from the sender, never from an argument).
	Dependencies: MatchService, RemoteService, LeadershipService.
]]

local ArenaConfig = require("@game/ReplicatedStorage/Forge/Config/Arena")
local SupportModel = require("@game/ReplicatedStorage/Game/Arena/SupportModel")

local SupportService = {}
SupportService.__index = SupportService

local Def = { name = "SupportService", dependencies = { "MatchService", "RemoteService", "LeadershipService" } }

local MOMENTS_SHOWN = 5
local REASONS = 3
local REASON_POOL = 200

function Def.new(env: any, registry: any)
	local self = setmetatable({}, SupportService)
	self._env = env
	self._registry = registry
	self._match = registry:get("MatchService")
	self._remotes = registry:get("RemoteService")
	self._leadership = registry:get("LeadershipService")
	self._connections = {} :: { any }
	return self
end

function SupportService:_sim(): any
	return self._match.host.match.sim
end

-- The support meter stays dark until the arena is real: one switch (config Arena `enabled`, read from ArenaService so a
-- spec that swaps its config swaps both) rules the arena and what leads to it. getView and forChampion are unaffected.
function SupportService:enabled(): boolean
	local arena = self._registry:find("ArenaService")
	local config = if arena and arena.config then arena.config else ArenaConfig
	return config.enabled == true
end

function SupportService:getView(kingdom: string, userId: number?): any?
	local sim = self:_sim()
	if sim.kingdoms[kingdom] == nil then
		return nil
	end
	local leadership = self._leadership
	local samples = leadership:samples(kingdom, userId)
	local ruler = { now = sim.time }
	local score, tier, breakdown = SupportModel.score(samples, ruler)
	local offers, slots = SupportModel.offers(leadership:keyCitizens(kingdom), tier)
	return {
		kingdom = kingdom,
		userId = userId or 0,
		score = score,
		tier = tier,
		trend = SupportModel.trend(samples, ruler),
		breakdown = breakdown,
		moments = leadership:getMoments(kingdom, userId, MOMENTS_SHOWN),
		offers = offers,
		slots = slots,
	}
end

function SupportService:forChampion(userId: number?, kingdom: string): any?
	local view = self:getView(kingdom, userId)
	if view == nil then
		return nil
	end
	local moments = self._leadership:getMoments(kingdom, userId, REASON_POOL)
	if userId == nil then
		-- an AI champion answers for the kingdom, not for a human ruler who held it before: only the moments no ruler
		-- owns (a kingdom act, or an act of the unseated series)
		local own = {}
		for _, moment in moments do
			if moment.userId == nil then
				table.insert(own, moment)
			end
		end
		moments = own
	end
	-- newest first already; a stable sort by the size of the change keeps the newest of equals first
	local ranked = {}
	for index, moment in moments do
		table.insert(ranked, { moment = moment, index = index })
	end
	table.sort(ranked, function(a, b)
		local da, db = math.abs(a.moment.delta), math.abs(b.moment.delta)
		if da ~= db then
			return da > db
		end
		return a.index < b.index
	end)
	local reasons: { string } = {}
	local seen: { [string]: boolean } = {}
	for _, entry in ranked do
		if #reasons >= REASONS then
			break
		end
		if not seen[entry.moment.text] then
			seen[entry.moment.text] = true
			table.insert(reasons, entry.moment.text)
		end
	end
	return { score = view.score, tier = view.tier, offers = view.offers, slots = view.slots, reasons = reasons }
end

-- The kingdom and userId a player rules, or nil.
function SupportService:_rulerOf(player: any): (string?, number?)
	local ok, userId = pcall(function()
		return player.UserId
	end)
	if not ok or type(userId) ~= "number" then
		return nil, nil
	end
	local kingdom = self:_sim():kingdomOfUser(userId)
	if kingdom == nil then
		return nil, nil
	end
	return kingdom.id, userId
end

function SupportService:_push()
	if not self:enabled() then
		return
	end
	local sim = self:_sim()
	for _, player in self._env.Players:GetPlayers() do
		local kingdom, userId = self:_rulerOf(player)
		if kingdom and sim.active then
			local view = self:getView(kingdom, userId)
			if view then
				self._remotes:fire("Kingdom.Support", player, view)
			end
		end
	end
end

function SupportService:start()
	self._remotes:handle("Kingdom.GetSupport", function(player: any): any?
		if not self:enabled() then
			return nil
		end
		local kingdom, userId = self:_rulerOf(player)
		if kingdom == nil then
			return nil
		end
		return self:getView(kingdom, userId)
	end)
	table.insert(
		self._connections,
		self._leadership.sampled:connect(function()
			local ok, err = pcall(self._push, self)
			if not ok then
				self._env.log("error", "SupportService: push failed", { error = tostring(err) })
			end
		end)
	)
end

function SupportService:destroy()
	for _, connection in self._connections do
		connection:disconnect()
	end
	table.clear(self._connections)
end

return Def
