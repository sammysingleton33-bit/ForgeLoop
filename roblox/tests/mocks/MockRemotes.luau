--[[
	MockRemotes — RemoteEvent / RemoteFunction / UnreliableRemoteEvent with a server end and one
	client end per player, all inside one Lune process.

	Remotes are real (Lune) instances created through env.newInstance (MockEnv attaches them to its
	network), so RemoteService can name and parent them under ReplicatedStorage.ForgeRemotes. The
	engine members below are filled in.

	Imitates (creator-docs content/en-us/...):
	  reference/engine/classes/RemoteEvent.yaml            FireServer, FireClient, FireAllClients,
	                                                       OnServerEvent(player, ...), OnClientEvent(...)
	  reference/engine/classes/RemoteFunction.yaml         InvokeServer -> OnServerInvoke(player, ...);
	                                                       InvokeClient -> OnClientInvoke(...); errors
	                                                       in the callback propagate to the invoker
	  reference/engine/classes/UnreliableRemoteEvent.yaml  same API; payloads over 1000 bytes are
	                                                       dropped; may be dropped (dropNext)
	  scripting/events/remote.md#argument-limitations      arguments are copied (functions -> nil,
	                                                       non-string dictionary keys -> strings,
	                                                       metatables dropped, Instances by reference)
	Queueing: a RemoteEvent fired before anyone listens is delivered when the first handler connects
	(Roblox queues these); an UnreliableRemoteEvent without a listener is discarded.
	Not modelled: the ~500 requests/s client rate limit, latency, replication of the instance tree.

	Server code uses the instance API directly. Client code needs a client context:
		network:setLocalPlayer(player)              -- default client (client-side specs)
		network:asClient(player, fn)                -- run fn as that player's client
	API
		MockRemotes.newNetwork({ players = playersControl?, spawn = fn? }) -> network
		network:attach(remoteInstance)              -- MockEnv.newInstance does this for you
		network.log: { { remote, name, direction, player?, args, dropped? } }
		     direction: "toServer" | "toClient" | "toAllClients" | "invokeServer" | "invokeClient"
		network:sent(remoteOrName, direction?) -> log entries
		network:dropNext(unreliableRemote, count?)
]]

local roblox = require("@lune/roblox")

local LuneInstances = require("../harness/LuneInstances")
local MockSignal = require("./MockSignal")
local Wire = require("./Wire")

local MockRemotes = {}

local UNRELIABLE_LIMIT = 1000

-- Process-wide: engine members are registered once per Lune process (see harness/LuneInstances).
local stateByRemote = LuneInstances.store("MockRemotes.remotes")

local function copyArgs(...): { any }
	local packed = table.pack(...)
	local out = { n = packed.n }
	for i = 1, packed.n do
		out[i] = Wire.copyForRemote(packed[i])
	end
	return out
end

local function stateOf(remote)
	local state = stateByRemote[remote]
	if state == nil then
		error(`{remote.ClassName} '{remote.Name}' was not created through env.newInstance (MockEnv)`, 3)
	end
	return state
end

local function register()
	for _, className in { "RemoteEvent", "UnreliableRemoteEvent" } do
		roblox.implementProperty(className, "OnServerEvent", function(remote)
			return stateOf(remote).serverSignal
		end)
		roblox.implementProperty(className, "OnClientEvent", function(remote)
			local state = stateOf(remote)
			return state.network:_clientSignal(state, state.network:_currentClient("OnClientEvent"))
		end)
		roblox.implementMethod(className, "FireServer", function(remote, ...)
			local state = stateOf(remote)
			state.network:_toServer(state, state.network:_currentClient("FireServer"), ...)
		end)
		roblox.implementMethod(className, "FireClient", function(remote, player, ...)
			local state = stateOf(remote)
			assert(typeof(player) == "Instance" and player:IsA("Player"), "FireClient: argument 1 must be a Player")
			state.network:_toClient(state, player, "toClient", ...)
		end)
		roblox.implementMethod(className, "FireAllClients", function(remote, ...)
			local state = stateOf(remote)
			state.network:_toAll(state, ...)
		end)
	end

	roblox.implementProperty("RemoteFunction", "OnServerInvoke", function(remote)
		return stateOf(remote).onServerInvoke
	end, function(remote, fn)
		stateOf(remote).onServerInvoke = fn
	end)
	roblox.implementProperty("RemoteFunction", "OnClientInvoke", function(remote)
		local state = stateOf(remote)
		return state.onClientInvoke[state.network:_currentClient("OnClientInvoke")]
	end, function(remote, fn)
		local state = stateOf(remote)
		state.onClientInvoke[state.network:_currentClient("OnClientInvoke")] = fn
	end)
	roblox.implementMethod("RemoteFunction", "InvokeServer", function(remote, ...)
		local state = stateOf(remote)
		local network = state.network
		local player = network:_currentClient("InvokeServer")
		local args = copyArgs(...)
		network:_record(state, "invokeServer", player, args)
		if state.onServerInvoke == nil then
			error(`OnServerInvoke is not set for '{remote.Name}' (Roblox would yield until it is set)`, 2)
		end
		local results = table.pack(state.onServerInvoke(player, table.unpack(args, 1, args.n)))
		return table.unpack(copyArgs(table.unpack(results, 1, results.n)), 1, results.n)
	end)
	roblox.implementMethod("RemoteFunction", "InvokeClient", function(remote, player, ...)
		local state = stateOf(remote)
		local args = copyArgs(...)
		state.network:_record(state, "invokeClient", player, args)
		local callback = state.onClientInvoke[player]
		if callback == nil then
			error(`OnClientInvoke is not set for '{remote.Name}' on {player.Name}'s client`, 2)
		end
		local results = table.pack(callback(table.unpack(args, 1, args.n)))
		return table.unpack(copyArgs(table.unpack(results, 1, results.n)), 1, results.n)
	end)
end

local Network = {}
Network.__index = Network

function MockRemotes.newNetwork(options: { players: any?, spawn: ((...any) -> ())? }?)
	LuneInstances.once("MockRemotes", register)
	return setmetatable({
		log = {},
		_players = options and options.players,
		_spawn = options and options.spawn,
		_clientStack = {},
		_localPlayer = nil,
		_drops = {},
	}, Network)
end

function Network:attach(remote: any)
	if stateByRemote[remote] then
		return remote
	end
	local className = remote.ClassName
	assert(
		className == "RemoteEvent" or className == "RemoteFunction" or className == "UnreliableRemoteEvent",
		`attach: {className} is not a remote`
	)
	local state = {
		remote = remote,
		network = self,
		kind = className,
		serverQueue = {},
		clientSignals = {},
		clientQueues = {},
		onServerInvoke = nil,
		onClientInvoke = {},
	}
	state.serverSignal = MockSignal.new({
		spawn = self._spawn,
		name = "OnServerEvent",
		onConnect = function(signal)
			local queued = state.serverQueue
			state.serverQueue = {}
			for _, item in queued do
				signal:Fire(item.player, table.unpack(item.args, 1, item.args.n))
			end
		end,
	})
	stateByRemote[remote] = state
	return remote
end

function Network:setLocalPlayer(player: any)
	self._localPlayer = player
end

function Network:asClient(player: any, fn: () -> ())
	table.insert(self._clientStack, player)
	local ok, err = pcall(fn)
	table.remove(self._clientStack)
	if not ok then
		error(err, 0)
	end
end

function Network:dropNext(remote: any, count: number?)
	assert(remote.ClassName == "UnreliableRemoteEvent", "dropNext only applies to UnreliableRemoteEvent")
	self._drops[remote] = (self._drops[remote] or 0) + (count or 1)
end

function Network:sent(remoteOrName: any, direction: string?)
	local out = {}
	for _, entry in self.log do
		local matches = if type(remoteOrName) == "string"
			then entry.name == remoteOrName
			else entry.remote == remoteOrName
		if matches and (direction == nil or entry.direction == direction) then
			table.insert(out, entry)
		end
	end
	return out
end

function Network:_currentClient(member: string)
	local player = self._clientStack[#self._clientStack] or self._localPlayer
	if player == nil then
		error(`{member} needs a client context: network:asClient(player, fn) or network:setLocalPlayer(player)`, 4)
	end
	return player
end

function Network:_record(state, direction: string, player: any?, args: { any }, dropped: boolean?)
	table.insert(self.log, {
		remote = state.remote,
		name = state.remote.Name,
		direction = direction,
		player = player,
		args = args,
		dropped = dropped or false,
	})
end

function Network:_shouldDrop(state, args): boolean
	if state.kind ~= "UnreliableRemoteEvent" then
		return false
	end
	if Wire.estimateBytes(args) > UNRELIABLE_LIMIT then
		return true
	end
	local pending = self._drops[state.remote]
	if pending and pending > 0 then
		self._drops[state.remote] = pending - 1
		return true
	end
	return false
end

function Network:_clientSignal(state, player)
	local signal = state.clientSignals[player]
	if signal == nil then
		signal = MockSignal.new({
			spawn = self._spawn,
			name = "OnClientEvent",
			onConnect = function(s)
				local queued = state.clientQueues[player] or {}
				state.clientQueues[player] = {}
				for _, args in queued do
					s:Fire(table.unpack(args, 1, args.n))
				end
			end,
		})
		state.clientSignals[player] = signal
	end
	return signal
end

function Network:_toServer(state, player, ...)
	local args = copyArgs(...)
	local dropped = self:_shouldDrop(state, args)
	self:_record(state, "toServer", player, args, dropped)
	if dropped then
		return
	end
	if state.serverSignal:connectionCount() == 0 then
		if state.kind == "RemoteEvent" then
			table.insert(state.serverQueue, { player = player, args = args })
		end
		return
	end
	state.serverSignal:Fire(player, table.unpack(args, 1, args.n))
end

function Network:_deliver(state, player, args)
	local signal = self:_clientSignal(state, player)
	if signal:connectionCount() == 0 then
		if state.kind == "RemoteEvent" then
			state.clientQueues[player] = state.clientQueues[player] or {}
			table.insert(state.clientQueues[player], args)
		end
		return
	end
	signal:Fire(table.unpack(args, 1, args.n))
end

function Network:_toClient(state, player, direction: string, ...)
	local args = copyArgs(...)
	local dropped = self:_shouldDrop(state, args)
	self:_record(state, direction, player, args, dropped)
	if not dropped then
		self:_deliver(state, player, args)
	end
end

function Network:_toAll(state, ...)
	local args = copyArgs(...)
	local dropped = self:_shouldDrop(state, args)
	self:_record(state, "toAllClients", nil, args, dropped)
	if dropped or self._players == nil then
		return
	end
	for _, player in self._players._service:GetPlayers() do
		self:_deliver(state, player, args)
	end
end

return MockRemotes
