--!strict
--[[
	RemoteClient — the client side of interfaces §6: call and listen to the remotes RemoteService
	creates under ReplicatedStorage.ForgeRemotes.<Area>.<Action>.

	API
		RemoteClient.new(env, options?): Client          -- uses env.ReplicatedStorage and env.clock
			options.timeout = 10                         -- seconds to wait for a remote to replicate
		client:invoke(name, ...): ...any                 -- RemoteFunction:InvokeServer(...)
		client:send(name, ...)                           -- RemoteEvent / UnreliableRemoteEvent :FireServer(...)
		client:on(name, fn: (...any) -> ()): connection  -- OnClientEvent:Connect(fn)

		RemoteClient.init(env, options?): Client         -- sets the module-level default client
		RemoteClient.invoke(name, ...) / RemoteClient.send(name, ...) / RemoteClient.on(name, fn)
		                                                 -- the same calls on the default client;
		                                                 -- error until init() was called
		RemoteClient.DEFAULT_TIMEOUT = 10

	Who calls init: the client entry point (or the first controller that needs remotes) calls
	RemoteClient.init(env) once with the injected Env; specs build their own client with new(env).

	Semantics
		- name is "<Area>.<Action>" (e.g. "Economy.BuyItem"); it resolves to
		  ReplicatedStorage.ForgeRemotes.<Area>.<Action> through WaitForChild on each level, sharing
		  one deadline of `timeout` seconds measured with env.clock. On timeout it errors with the
		  name and the full path. A resolved remote is cached until it leaves the tree.
		- invoke/send/on may yield while the remote replicates: call them from start() or a
		  spawned thread, never from a controller's new().
		- Kind checks: invoke needs a RemoteFunction; send and on need a RemoteEvent or
		  UnreliableRemoteEvent (error otherwise, naming the remote and its class).
		- The server validates and rate-limits every call (RemoteService); invoke returns nil when
		  the server dropped the call. Nothing here trusts or retries.
]]

export type Client = {
	invoke: (self: Client, name: string, ...any) -> ...any,
	send: (self: Client, name: string, ...any) -> (),
	on: (self: Client, name: string, fn: (...any) -> ()) -> any,
}

local RemoteClient = {}
RemoteClient.DEFAULT_TIMEOUT = 10

local ClientClass = {}
ClientClass.__index = ClientClass

local ROOT = "ForgeRemotes"

local defaultClient: Client? = nil

function RemoteClient.new(env: any, options: { timeout: number? }?): Client
	if type(env) ~= "table" or env.ReplicatedStorage == nil or type(env.clock) ~= "function" then
		error("RemoteClient.new(env): env must provide ReplicatedStorage and clock (interfaces §2)", 2)
	end
	local timeout = if options and options.timeout ~= nil then options.timeout else RemoteClient.DEFAULT_TIMEOUT
	if type(timeout) ~= "number" or timeout ~= timeout or timeout < 0 then
		error("RemoteClient.new: options.timeout must be a number >= 0", 2)
	end
	local self = setmetatable({
		_env = env,
		_timeout = timeout,
		_cache = {} :: { [string]: any },
	}, ClientClass)
	return (self :: any) :: Client
end

function RemoteClient.init(env: any, options: { timeout: number? }?): Client
	local client = RemoteClient.new(env, options)
	defaultClient = client
	return client
end

local function splitName(name: any): (string, string)
	if type(name) ~= "string" then
		error(`RemoteClient: remote name must be a string "<Area>.<Action>", got {typeof(name)}`, 4)
	end
	local area, action = string.match(name, "^([%w_]+)%.([%w_]+)$")
	if area == nil or action == nil then
		error(`RemoteClient: remote name '{name}' must be "<Area>.<Action>"`, 4)
	end
	return area :: string, action :: string
end

local function resolve(self: any, name: string): any
	local cached = self._cache[name]
	if cached ~= nil and cached.Parent ~= nil then
		return cached
	end
	local area, action = splitName(name)
	local env = self._env
	local deadline = env.clock() + self._timeout
	local node = env.ReplicatedStorage
	for _, childName in { ROOT, area, action } do
		local child = node:FindFirstChild(childName)
		if child == nil then
			local remaining = deadline - env.clock()
			if remaining > 0 then
				child = node:WaitForChild(childName, remaining)
			end
		end
		if child == nil then
			error(
				`RemoteClient: remote '{name}' not found after {self._timeout} s `
					.. `(waiting for ReplicatedStorage.{ROOT}.{area}.{action}; is it declared in {area}/Remotes.luau?)`,
				3
			)
		end
		node = child
	end
	self._cache[name] = node
	return node
end

local function expectClass(remote: any, name: string, method: string, classes: { string })
	for _, className in classes do
		if remote:IsA(className) then
			return
		end
	end
	error(
		`RemoteClient:{method}('{name}'): the remote is a {remote.ClassName}; {method} needs {table.concat(
			classes,
			" or "
		)}`,
		3
	)
end

function ClientClass.invoke(self: any, name: string, ...: any): ...any
	local remote = resolve(self, name)
	expectClass(remote, name, "invoke", { "RemoteFunction" })
	return remote:InvokeServer(...)
end

function ClientClass.send(self: any, name: string, ...: any)
	local remote = resolve(self, name)
	expectClass(remote, name, "send", { "RemoteEvent", "UnreliableRemoteEvent" })
	remote:FireServer(...)
end

function ClientClass.on(self: any, name: string, fn: (...any) -> ()): any
	if type(fn) ~= "function" then
		error(`RemoteClient:on('{tostring(name)}', fn): fn must be a function`, 2)
	end
	local remote = resolve(self, name)
	expectClass(remote, name, "on", { "RemoteEvent", "UnreliableRemoteEvent" })
	return remote.OnClientEvent:Connect(fn)
end

local function default(): any
	if defaultClient == nil then
		error("RemoteClient: call RemoteClient.init(env) before RemoteClient.invoke/send/on", 3)
	end
	return defaultClient
end

function RemoteClient.invoke(name: string, ...: any): ...any
	return ClientClass.invoke(default(), name, ...)
end

function RemoteClient.send(name: string, ...: any)
	ClientClass.send(default(), name, ...)
end

function RemoteClient.on(name: string, fn: (...any) -> ()): any
	return ClientClass.on(default(), name, fn)
end

return RemoteClient
