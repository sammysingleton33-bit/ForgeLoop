--[[
	MockPlayers — a real (Lune) Players service instance with the engine behaviour filled in, and
	real Player instances (typeof(player) == "Instance", player:IsA("Player")).

	Imitates (creator-docs content/en-us/reference/engine/classes/...):
	  Players.yaml  PlayerAdded, PlayerRemoving, GetPlayers(), GetPlayerByUserId(), LocalPlayer
	  Player.yaml   Kick(message?) — the player is disconnected and later removed
	Semantics kept:
	  - add(): the player is parented to Players, then PlayerAdded fires (each handler in its own
	    thread through `spawn`, so with MockEnv a handler that waits stays suspended until advance()).
	  - remove(): PlayerRemoving fires while player.Parent is still Players; afterwards Parent = nil
	    (code that finishes an async load after the player left sees player.Parent == nil).
	  - Kick(msg): recorded; the player is removed on the next scheduler step (deferred like the
	    real disconnect), i.e. after env.mock:advance(0) when created through MockEnv.

	API
		MockPlayers.new(dataModel, { spawn = fn?, defer = fn? }) -> (playersInstance, control)
		control:add({ userId = number, name = string?, displayName = string? }) -> Player
		control:remove(player)
		control:setLocalPlayer(player)              -- for client-side specs (Players.LocalPlayer)
		control:get(userId) -> Player?
		control.kicks: { { userId: number, message: string? } }
		control:wasKicked(player) -> (boolean, string?)
]]

local roblox = require("@lune/roblox")

local LuneInstances = require("../harness/LuneInstances")
local MockSignal = require("./MockSignal")

local MockPlayers = {}

-- Process-wide: engine members are registered once per Lune process (see harness/LuneInstances).
local stateByService = LuneInstances.store("MockPlayers.services")
local controlByPlayer = LuneInstances.store("MockPlayers.players")

local function register()
	local function stateOf(service)
		local state = stateByService[service]
		if state == nil then
			error("this Players instance was not created by MockPlayers/MockEnv", 3)
		end
		return state
	end
	roblox.implementProperty("Players", "PlayerAdded", function(service)
		return stateOf(service).PlayerAdded
	end)
	roblox.implementProperty("Players", "PlayerRemoving", function(service)
		return stateOf(service).PlayerRemoving
	end)
	roblox.implementMethod("Players", "GetPlayers", function(service)
		stateOf(service)
		local out = {}
		for _, child in service:GetChildren() do
			if child:IsA("Player") then
				table.insert(out, child)
			end
		end
		return out
	end)
	roblox.implementMethod("Players", "GetPlayerByUserId", function(service, userId: number)
		stateOf(service)
		for _, child in service:GetChildren() do
			if child:IsA("Player") and child.UserId == userId then
				return child
			end
		end
		return nil
	end)
	roblox.implementMethod("Player", "Kick", function(player, message: string?)
		local control = controlByPlayer[player]
		if control == nil then
			error("Kick: this Player was not created by MockPlayers", 2)
		end
		control:_kick(player, message)
	end)
end

function MockPlayers.new(dataModel: any, options: { spawn: ((...any) -> ())?, defer: ((() -> ()) -> ())? }?)
	LuneInstances.once("MockPlayers", register)
	local service = dataModel:GetService("Players")
	local spawn = options and options.spawn
	local state = {
		PlayerAdded = MockSignal.new({ spawn = spawn, name = "Players.PlayerAdded" }),
		PlayerRemoving = MockSignal.new({ spawn = spawn, name = "Players.PlayerRemoving" }),
		localPlayer = nil,
	}
	stateByService[service] = state

	local control = {
		kicks = {},
		_service = service,
		_defer = (options and options.defer) or function(fn)
			fn()
		end,
	}

	function control:add(spec: { userId: number, name: string?, displayName: string? })
		assert(type(spec) == "table" and type(spec.userId) == "number", "add({ userId = number })")
		assert(service:GetPlayerByUserId(spec.userId) == nil, `a player with UserId {spec.userId} is already in game`)
		local player = roblox.Instance.new("Player")
		player.Name = spec.name or `Player{spec.userId}`
		player.DisplayName = spec.displayName or player.Name
		player.UserId = spec.userId
		controlByPlayer[player] = control
		player.Parent = service
		state.PlayerAdded:Fire(player)
		return player
	end

	function control:remove(player: any)
		if player.Parent ~= service then
			return
		end
		state.PlayerRemoving:Fire(player)
		player.Parent = nil
	end

	function control:get(userId: number)
		return service:GetPlayerByUserId(userId)
	end

	function control:setLocalPlayer(player: any)
		state.localPlayer = player
		service.LocalPlayer = player -- a real (reflected) property on the Lune instance
	end

	function control:wasKicked(player: any): (boolean, string?)
		for _, kick in self.kicks do
			if kick.userId == player.UserId then
				return true, kick.message
			end
		end
		return false, nil
	end

	function control:_kick(player: any, message: string?)
		table.insert(self.kicks, { userId = player.UserId, message = message })
		self._defer(function()
			self:remove(player)
		end)
	end

	return service, control
end

return MockPlayers
