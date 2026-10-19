--!strict
--[[
	ArenaHudVoteController (FORGE-03, game-001 client, FL-0142) — the co-rulers' champion vote (design crown-arena.md
	§2; CONTRACTS G12.4 Arena.Vote). UI/ArenaVote over UI/ArenaVoteModel, on the modal layer.

	Shown in the "vote" stage to a seated ruler whose kingdom has two or more candidates, read from ArenaState.vote
	(FORGE-01; see UI/ArenaVoteModel). The state comes from ArenaHudController, which follows DuelController (the
	client's one arena door, G12.6): this controller asks the server nothing but Arena.Vote. Dark without
	ArenaState.vote or without the Arena.Vote remote.

		A tap on a candidate sends Arena.Vote(userId); the latest vote counts, so a ruler may change it until the
		time runs out. One call at a time (the remote allows 3 at once, then 1 a second); "false" or no answer
		(nil: dropped by the rate limit) says "not counted, try again"; VOTE_TIMEOUT_SEC without an answer too.
		When the stage moves on, the panel closes and the result is said once as a toast ("Rowan fights for
		Emberhold in the Crown Arena"), from the champions in the next ArenaState.

	Depends on KingdomHudController (modal layer, layout, remotes, notify) and ArenaHudController (state, lookup).
	API (specs and scenes)   vote.view   vote.pick   vote:model()   vote:vote(userId) -> boolean (sent)
		ArenaHudVoteController.VOTE   .POLL_SEC   .VOTE_TIMEOUT_SEC
]]

local ArenaVote = require("../UI/ArenaVote")
local ArenaVoteModel = require("../UI/ArenaVoteModel")
local Signature = require("../UI/Signature")

local ArenaHudVoteController = {}
ArenaHudVoteController.__index = ArenaHudVoteController

local Def = {
	name = "ArenaHudVoteController",
	dependencies = { "KingdomHudController", "ArenaHudController" },
}

ArenaHudVoteController.VOTE = "Arena.Vote"
ArenaHudVoteController.POLL_SEC = 0.5 -- the countdown
ArenaHudVoteController.VOTE_TIMEOUT_SEC = 6

Def.VOTE = ArenaHudVoteController.VOTE
Def.POLL_SEC = ArenaHudVoteController.POLL_SEC
Def.VOTE_TIMEOUT_SEC = ArenaHudVoteController.VOTE_TIMEOUT_SEC

function Def.new(env: any, registry: any)
	return setmetatable({
		_env = env,
		hud = registry:get("KingdomHudController"),
		arena = registry:get("ArenaHudController"),
		view = nil :: any,
		pick = nil :: any, -- { candidate, status = "pending" | "ok" | "failed" }
		_side = nil :: string?, -- the side this ruler voted on, until the result is said
		_token = 0,
		_key = nil :: string?,
		_connections = {} :: { any },
	}, ArenaHudVoteController)
end

function ArenaHudVoteController:start()
	local env = self._env
	table.insert(
		self._connections,
		self.hud.rendered:connect(function(metrics)
			self:render(metrics)
		end)
	)
	table.insert(
		self._connections,
		self.arena.changed:connect(function(state)
			self:_onState(state)
		end)
	)
	self:_onState(self.arena.state)
	self._running = true
	env.spawn(function()
		while self._running do
			env.wait(ArenaHudVoteController.POLL_SEC)
			local st = self.arena.state
			if self._running and st ~= nil and st.stage == "vote" then
				self:render()
			end
		end
	end)
end

function ArenaHudVoteController:destroy()
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

function ArenaHudVoteController:_onState(state: any)
	if self._destroyed then
		return
	end
	local side = ArenaVoteModel.entry(state, self.arena:userId())
	if side ~= nil then
		self._side = side -- a voter this round
	elseif self._side ~= nil and type(state) == "table" and state.stage ~= "vote" then
		local text = ArenaVoteModel.result(state, self._side, self.arena:userId(), self.arena:lookup())
		if text ~= nil or state.stage == "done" then
			self._side = nil
			self.pick = nil
			if text ~= nil then
				self.hud:notify({ kind = "info", title = text })
			end
		end
	end
	if side == nil and (type(state) ~= "table" or state.stage ~= "vote") then
		self.pick = nil
	end
	self:render()
end

function ArenaHudVoteController:model(): any
	return ArenaVoteModel.view(
		self.arena.state,
		self.arena:lookup(),
		self.arena:userId(),
		self._env.serverTimeNow(),
		self.pick
	)
end

-- Sends one vote; false when it cannot be sent now (no panel, not a candidate, a call already on its way).
function ArenaHudVoteController:vote(candidate: number): boolean
	local model = self:model()
	if model == nil or not self.hud:hasRemote(ArenaHudVoteController.VOTE) then
		return false
	end
	if self.pick ~= nil and self.pick.status == "pending" then
		return false
	end
	local known = false
	for _, c in model.candidates do
		if c.userId == candidate then
			known = true
		end
	end
	if not known then
		return false
	end
	self._token += 1
	local token = self._token
	self.pick = { candidate = candidate, status = "pending" }
	self:render()
	local env = self._env
	env.spawn(function()
		local ok, accepted = pcall(function()
			return self.hud.remotes:invoke(ArenaHudVoteController.VOTE, candidate)
		end)
		if self._destroyed or token ~= self._token or self.pick == nil then
			return
		end
		self.pick = { candidate = candidate, status = if ok and accepted == true then "ok" else "failed" }
		self:render()
	end)
	env.spawn(function()
		env.wait(ArenaHudVoteController.VOTE_TIMEOUT_SEC)
		if not self._destroyed and token == self._token and self.pick ~= nil and self.pick.status == "pending" then
			self.pick = { candidate = candidate, status = "failed" }
			self:render()
		end
	end)
	return true
end

function ArenaHudVoteController:render(metrics: any?)
	local hud = self.hud
	if self._destroyed or hud.roots.modals == nil then
		return
	end
	self.view = self.view or ArenaVote.new(hud.roots.modals)
	local model = if hud:hasRemote(ArenaHudVoteController.VOTE) then self:model() else nil
	if model == nil then
		self.view:destroy()
		self._key = nil
		return
	end
	local m = metrics or hud:metrics()
	local key = Signature.of({ model = model, breakpoint = m.breakpoint, width = m.width, height = m.height })
	if key == self._key and self.view.instance ~= nil then
		return
	end
	self._key = key
	self.view:render(model, m, {
		onVote = function(userId)
			self:vote(userId)
		end,
	})
end

return Def
