--!strict
--[[
	DuelController (game-001 client, FORGE-01, FL-0071; CONTRACTS G12.4, G12.6) — the client's one door to the Crown
	Arena's server: it relays Arena.State and Arena.Events and is the only sender of Arena.Action.

		controller.events: Signal<(event)>        every duel event, one at a time, in server order (Arena.Events batches
		                                          are unpacked); { t, kind, side, data? }, shares only (DuelRunner)
		controller.stateChanged: Signal<(ArenaState)>
		controller:getState() -> ArenaState?      the latest Arena.State (asked once with Arena.GetState at start)
		controller:isChampion() -> boolean        the local player is duellist a or b (not an AI) in the duel stage
		controller:act(action) -> boolean         light | heavy | block | blockEnd | parry | dodge. Sent only while the
		                                          local player is a champion in the duel stage; true = sent. A press the
		                                          server would drop anyway (spectator, wrong stage, unknown action, over
		                                          the same 8-burst / 12-per-second rate) is not sent.

	The server decides everything (reach, facing, stamina, who wins); the client only asks. A missing remote (before
	ArenaService is on) leaves the controller inert: act() returns false and no event ever fires.
	Consumers: InputModeArenaController (act, getState), ArenaHudController and the crowd (events).
]]

local RemoteLink = require("@game/ReplicatedStorage/Forge/Experience/RemoteLink")
local Signal = require("@game/ReplicatedStorage/Forge/Core/Signal")

local DuelController = {}
DuelController.__index = DuelController

local Def = { name = "DuelController", dependencies = {} }

DuelController.ACTIONS = table.freeze({
	light = true,
	heavy = true,
	block = true,
	blockEnd = true,
	parry = true,
	dodge = true,
})
DuelController.BURST = 8 -- the server's Arena.Action bucket (Arena/Remotes)
DuelController.PER_SECOND = 12

function Def.new(env: any, registry: any)
	local self = setmetatable({}, DuelController)
	self._env = env
	self._registry = registry
	self.events = Signal.new()
	self.stateChanged = Signal.new()
	self._state = nil :: any
	self._links = {} :: { any }
	self._tokens = DuelController.BURST :: number
	self._refilledAt = nil :: number?
	self._destroyed = false
	return self
end

function DuelController:getState(): any
	return self._state
end

function DuelController:_userId(): number?
	local ok, id = pcall(function()
		return self._env.Players.LocalPlayer.UserId
	end)
	return if ok and type(id) == "number" then id else nil
end

function DuelController:isChampion(): boolean
	local state = self._state
	if type(state) ~= "table" or state.stage ~= "duel" then
		return false
	end
	local me = self:_userId()
	if me == nil then
		return false
	end
	for _, side in { "a", "b" } do
		local duellist = state[side]
		if type(duellist) == "table" and duellist.userId == me and duellist.isAI ~= true then
			return true
		end
	end
	return false
end

function DuelController:setState(state: any)
	if type(state) ~= "table" or type(state.stage) ~= "string" then
		return
	end
	self._state = state
	if state.stage ~= "duel" then
		self._tokens = DuelController.BURST -- a fresh duel starts with a full bucket
		self._refilledAt = nil
	end
	self.stateChanged:fire(state)
end

function DuelController:onEvents(batch: any)
	if type(batch) ~= "table" then
		return
	end
	for _, event in batch do
		if type(event) == "table" and type(event.kind) == "string" then
			self.events:fire(event)
		end
	end
end

function DuelController:_take(): boolean
	local now = self._env.serverTimeNow()
	local last = self._refilledAt
	self._refilledAt = now
	if last ~= nil then
		self._tokens =
			math.min(DuelController.BURST, self._tokens + math.max(0, now - last) * DuelController.PER_SECOND)
	end
	if self._tokens < 1 then
		return false
	end
	self._tokens -= 1
	return true
end

function DuelController:act(action: string): boolean
	if self._destroyed or type(action) ~= "string" or not DuelController.ACTIONS[action] then
		return false
	end
	if not self:isChampion() then
		return false
	end
	if not self:_take() then
		return false
	end
	return RemoteLink.send(self._env, "Arena.Action", action)
end

function DuelController:start()
	table.insert(
		self._links,
		RemoteLink.on(self._env, "Arena.State", function(state: any)
			self:setState(state)
		end)
	)
	table.insert(
		self._links,
		RemoteLink.on(self._env, "Arena.Events", function(batch: any)
			self:onEvents(batch)
		end)
	)
	RemoteLink.request(self._env, "Arena.GetState", function(state: any)
		if not self._destroyed and self._state == nil then
			self:setState(state)
		end
	end)
end

function DuelController:destroy()
	self._destroyed = true
	for _, link in self._links do
		link:disconnect()
	end
	table.clear(self._links)
end

return Def
