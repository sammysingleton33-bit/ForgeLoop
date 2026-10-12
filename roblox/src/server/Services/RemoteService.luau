--!strict
--[[
	RemoteService — creates every declared remote and guards every client call (interfaces §6).

	Declarations: each area's roblox/src/shared/<Area>/Remotes.luau returns a list of
		{ name = "<Area>.<Action>", kind = "event" | "function" | "serverEvent" | "unreliableServerEvent",
		  args = { Validator }?, rate = { burst = number, perSecond = number }? }
	found with env.sharedModules("Remotes") ({ [Area] = list }).

	API
		RemoteService:handle(name, fn: (player, ...any) -> ...any)
			register the one handler of an `event` or `function` remote (errors: undeclared name,
			server -> client kind, second handler, fn not a function)
		RemoteService:fire(name, player, ...): boolean
			FireClient on a `serverEvent` / `unreliableServerEvent` remote; false (nothing sent)
			when the player is no longer in Players
		RemoteService:fireAll(name, ...)
			FireAllClients on a `serverEvent` / `unreliableServerEvent` remote
		RemoteService:stats() -> { dropped = { [reason] = count }, droppedByName = { [name] = count },
		                           buckets = number }   -- buckets: live rate-limit entries (memory)
		RemoteService:destroy()   -- disconnects everything and removes ReplicatedStorage.ForgeRemotes

	Boot (new, never yields): every declaration is checked and a bad one fails the boot with the
	area, index and problem: name must be "<Area>.<Action>" with <Area> equal to the folder it was
	declared in, kind one of the four above, names unique, `args` (a list of validator functions)
	and `rate` (finite burst > 0, perSecond >= 0) only on client -> server kinds (event, function),
	no other fields. Instances: ReplicatedStorage.ForgeRemotes.<Area>.<Action> (RemoteEvent for
	event/serverEvent, RemoteFunction for function, UnreliableRemoteEvent for unreliableServerEvent),
	built through env.newInstance and parented to ReplicatedStorage last (one complete tree).

	Every inbound call, in this order; a failed step drops the call and counts it under that reason:
		wrongDirection   the client fired a server -> client remote
		playerGone       the sender is no longer in Players (no rate-limit state is created)
		noHandler        declared client -> server remote without handle() yet
		rateLimited      token bucket per player per remote: the declared rate, else burst 10 /
		                 5 per second (RateLimiter on env.clock)
		extraArgs        more arguments than #args (a declaration without args takes none)
		invalidArgs      a validator rejected argument i; missing arguments are validated as nil, so
		                 Validate.optional works
		handlerError     the handler errored (xpcall): logged with env.log("error", ...) every time
	Only the first drop of each (remote, reason) pair is logged (warn); later ones are only counted,
	so a flood cannot flood the logs. Nothing a client sends can error the server. `function`
	remotes return the handler's results, or nil when the call was dropped or the handler errored.
	The server never calls InvokeClient. Rate-limit state of a player is freed on
	Players.PlayerRemoving. Calls that arrive before handle() are dropped, not queued.
	Undeclared names never reach the server: only declared remotes exist and are listened to;
	handle/fire/fireAll with an undeclared name error at the call site.
]]

local RateLimiter = require("@game/ReplicatedStorage/Forge/Core/RateLimiter")
local Trove = require("@game/ReplicatedStorage/Forge/Core/Trove")

type Validator = (value: any) -> (boolean, string?)

type Remote = {
	name: string,
	area: string,
	action: string,
	kind: string,
	inbound: boolean,
	args: { Validator },
	rate: { burst: number, perSecond: number },
	instance: any,
	limiter: any?,
	handler: ((...any) -> ...any)?,
}

local RemoteService = {}
RemoteService.__index = RemoteService

local Def = { name = "RemoteService" }

local ROOT_NAME = "ForgeRemotes"
local DEFAULT_RATE = table.freeze({ burst = 10, perSecond = 5 })
local KINDS: { [string]: { className: string, inbound: boolean } } = {
	event = { className = "RemoteEvent", inbound = true },
	["function"] = { className = "RemoteFunction", inbound = true },
	serverEvent = { className = "RemoteEvent", inbound = false },
	unreliableServerEvent = { className = "UnreliableRemoteEvent", inbound = false },
}
local FIELDS = { name = true, kind = true, args = true, rate = true }
local IDENTIFIER = "^[%a][%w_]*$"

Def.DEFAULT_RATE = DEFAULT_RATE

local function isFinite(n: any): boolean
	return type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge
end

local function isList(t: any): boolean
	if type(t) ~= "table" then
		return false
	end
	local count = 0
	for key in t do
		if type(key) ~= "number" then
			return false
		end
		count += 1
	end
	return count == #t
end

local function bootError(where: string, problem: string)
	error(`RemoteService: {where}: {problem}`, 0)
end

-- Validates one declaration; returns the parsed Remote (without instance/limiter).
local function parseDeclaration(area: string, index: number, decl: any): Remote
	local where = `{area}/Remotes.luau declaration #{index}`
	if type(decl) ~= "table" then
		bootError(where, `expected a table, got {typeof(decl)}`)
	end
	if type(decl.name) == "string" then
		where = `{where} ('{decl.name}')`
	end
	for key in decl do
		if not FIELDS[key] then
			bootError(where, `unknown field '{tostring(key)}' (allowed: name, kind, args, rate)`)
		end
	end
	if type(decl.name) ~= "string" then
		bootError(where, "name must be a string '<Area>.<Action>'")
	end
	local declaredArea, action = string.match(decl.name, "^([^.]+)%.([^.]+)$")
	if declaredArea == nil or action == nil then
		bootError(where, "name must be '<Area>.<Action>'")
	end
	if declaredArea ~= area then
		bootError(where, `area '{declaredArea}' does not match the folder '{area}' it is declared in`)
	end
	if not string.match(action :: string, IDENTIFIER) then
		bootError(where, `action '{action}' must be letters, digits and _ (starting with a letter)`)
	end
	local kind = KINDS[decl.kind]
	if type(decl.kind) ~= "string" or kind == nil then
		bootError(where, `kind '{tostring(decl.kind)}' must be event, function, serverEvent or unreliableServerEvent`)
	end
	if decl.args ~= nil then
		if not kind.inbound then
			bootError(where, `args are only allowed on client -> server kinds (event, function), not {decl.kind}`)
		end
		if not isList(decl.args) then
			bootError(where, "args must be a list of validators")
		end
		for i, validator in decl.args do
			if type(validator) ~= "function" then
				bootError(where, `args[{i}] must be a validator function, got {typeof(validator)}`)
			end
		end
	end
	if decl.rate ~= nil then
		if not kind.inbound then
			bootError(where, `rate is only allowed on client -> server kinds (event, function), not {decl.kind}`)
		end
		local rate = decl.rate
		if type(rate) ~= "table" then
			bootError(where, "rate must be { burst = number, perSecond = number }")
		end
		for key in rate do
			if key ~= "burst" and key ~= "perSecond" then
				bootError(where, `rate has unknown field '{tostring(key)}'`)
			end
		end
		if not isFinite(rate.burst) or rate.burst <= 0 then
			bootError(where, "rate.burst must be a finite number > 0")
		end
		if not isFinite(rate.perSecond) or rate.perSecond < 0 then
			bootError(where, "rate.perSecond must be a finite number >= 0")
		end
	end
	return {
		name = decl.name,
		area = area,
		action = action :: string,
		kind = decl.kind,
		inbound = kind.inbound,
		args = if decl.args then table.clone(decl.args) else {},
		rate = if decl.rate then { burst = decl.rate.burst, perSecond = decl.rate.perSecond } else DEFAULT_RATE,
		instance = nil,
		limiter = nil,
		handler = nil,
	}
end

local function parseAll(modules: any): ({ string }, { Remote })
	if type(modules) ~= "table" then
		bootError(
			'env.sharedModules("Remotes")',
			`expected a table of declarations keyed by area, got {typeof(modules)}`
		)
	end
	local areas: { string } = {}
	for area in modules do
		if type(area) ~= "string" or not string.match(area, IDENTIFIER) then
			bootError(`area '{tostring(area)}'`, "area folder names must be letters, digits and _")
		end
		table.insert(areas, area)
	end
	table.sort(areas)
	local remotes: { Remote } = {}
	local seen: { [string]: string } = {}
	for _, area in areas do
		local list = modules[area]
		if not isList(list) then
			bootError(`{area}/Remotes.luau`, "must return a list of declarations")
		end
		for index, decl in list do
			local remote = parseDeclaration(area, index, decl)
			if seen[remote.name] then
				bootError(`{area}/Remotes.luau declaration #{index}`, `duplicate remote name '{remote.name}'`)
			end
			seen[remote.name] = area
			table.insert(remotes, remote)
		end
	end
	return areas, remotes
end

local function traceback(err: any): string
	return debug.traceback(tostring(err), 2)
end

function Def.new(env: any, _registry: any)
	local areas, list = parseAll(env.sharedModules("Remotes"))
	if env.ReplicatedStorage:FindFirstChild(ROOT_NAME) ~= nil then
		error(`RemoteService: ReplicatedStorage.{ROOT_NAME} already exists (one RemoteService per server)`, 0)
	end

	local self = setmetatable({
		_env = env,
		_remotes = {} :: { [string]: Remote },
		_inbound = {} :: { Remote },
		_dropped = {} :: { [string]: number },
		_droppedByName = {} :: { [string]: number },
		_loggedDrops = {} :: { [string]: boolean },
		_trove = Trove.new(function(message: string)
			env.log("warn", "RemoteService: cleanup failed", { error = message })
		end),
	}, RemoteService)

	local root = env.newInstance("Folder")
	root.Name = ROOT_NAME
	self._root = root
	self._trove:add(root) -- added first, so destroyed last (after listeners are disconnected)
	local folders: { [string]: any } = {}
	for _, area in areas do
		local folder = env.newInstance("Folder")
		folder.Name = area
		folder.Parent = root
		folders[area] = folder
	end

	for _, remote in list do
		local instance = env.newInstance(KINDS[remote.kind].className)
		instance.Name = remote.action
		instance.Parent = folders[remote.area]
		remote.instance = instance
		self._remotes[remote.name] = remote
		if remote.inbound then
			table.insert(self._inbound, remote)
			remote.limiter =
				RateLimiter.new({ burst = remote.rate.burst, perSecond = remote.rate.perSecond, clock = env.clock })
		end
		if remote.kind == "function" then
			instance.OnServerInvoke = function(player: any, ...: any): ...any
				local results = self:_dispatch(remote, player, ...)
				if results == nil then
					return nil
				end
				return table.unpack(results, 2, results.n)
			end
			self._trove:add(function()
				instance.OnServerInvoke = nil
			end)
		else
			-- Listen on every RemoteEvent, also server -> client ones: a client firing those is
			-- dropped and counted instead of queued by the engine.
			self._trove:add(instance.OnServerEvent:Connect(function(player: any, ...: any)
				self:_dispatch(remote, player, ...)
			end))
		end
	end

	self._trove:add(env.Players.PlayerRemoving:Connect(function(player: any)
		for _, remote in self._inbound do
			remote.limiter:reset(player)
		end
	end))
	root.Parent = env.ReplicatedStorage
	return self
end

function RemoteService._drop(self: any, remote: Remote, reason: string, player: any, detail: string?): nil
	self._dropped[reason] = (self._dropped[reason] or 0) + 1
	self._droppedByName[remote.name] = (self._droppedByName[remote.name] or 0) + 1
	local key = `{remote.name}|{reason}`
	if not self._loggedDrops[key] then
		self._loggedDrops[key] = true
		self._env.log("warn", "RemoteService: dropped call (later drops of this kind are only counted)", {
			remote = remote.name,
			reason = reason,
			userId = if typeof(player) == "Instance" and player:IsA("Player") then player.UserId else nil,
			detail = detail,
		})
	end
	return nil
end

-- Runs the inbound pipeline; returns table.pack(true, handler results...) or nil when dropped.
function RemoteService._dispatch(self: any, remote: Remote, player: any, ...: any): any
	if not remote.inbound then
		return self:_drop(remote, "wrongDirection", player)
	end
	if typeof(player) ~= "Instance" or not player:IsA("Player") or player.Parent ~= self._env.Players then
		return self:_drop(remote, "playerGone", player)
	end
	local handler = remote.handler
	if handler == nil then
		return self:_drop(remote, "noHandler", player)
	end
	if not remote.limiter:allow(player) then
		return self:_drop(remote, "rateLimited", player)
	end
	local count = select("#", ...)
	local expected = #remote.args
	if count > expected then
		return self:_drop(remote, "extraArgs", player, `{count} arguments, at most {expected} declared`)
	end
	for i = 1, expected do
		local ran, good, why = pcall(remote.args[i], (select(i, ...)))
		if not ran then
			return self:_drop(remote, "invalidArgs", player, `argument {i}: validator error`)
		elseif not good then
			return self:_drop(remote, "invalidArgs", player, `argument {i}: {why or "invalid"}`)
		end
	end
	local results = table.pack(xpcall(handler :: any, traceback, player, ...))
	if not results[1] then
		self._dropped.handlerError = (self._dropped.handlerError or 0) + 1
		self._droppedByName[remote.name] = (self._droppedByName[remote.name] or 0) + 1
		self._env.log("error", `RemoteService: handler for '{remote.name}' failed`, {
			remote = remote.name,
			userId = player.UserId,
			error = tostring(results[2]),
		})
		return nil
	end
	return results
end

function RemoteService.handle(self: any, name: string, fn: (...any) -> ...any)
	local remote: Remote? = self._remotes[name]
	if remote == nil then
		error(`RemoteService:handle: '{tostring(name)}' is not declared in any <Area>/Remotes.luau`, 2)
	end
	local r = remote :: Remote
	if not r.inbound then
		error(
			`RemoteService:handle: '{name}' is declared as kind '{r.kind}' (server -> client); only event and `
				.. "function remotes take handlers",
			2
		)
	end
	if r.handler ~= nil then
		error(`RemoteService:handle: '{name}' already has a handler (one per remote)`, 2)
	end
	if type(fn) ~= "function" then
		error(`RemoteService:handle('{name}', fn): fn must be a function`, 2)
	end
	r.handler = fn
end

local function outbound(self: any, name: string, method: string): Remote
	local remote: Remote? = self._remotes[name]
	if remote == nil then
		error(`RemoteService:{method}: '{tostring(name)}' is not declared in any <Area>/Remotes.luau`, 3)
	end
	local r = remote :: Remote
	if r.inbound then
		error(
			`RemoteService:{method}: '{name}' is declared as kind '{r.kind}' (client -> server); only serverEvent and `
				.. "unreliableServerEvent remotes are fired to clients",
			3
		)
	end
	return r
end

function RemoteService.fire(self: any, name: string, player: any, ...: any): boolean
	local remote = outbound(self, name, "fire")
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		error(`RemoteService:fire('{name}', player, ...): player must be a Player, got {typeof(player)}`, 2)
	end
	if player.Parent ~= self._env.Players then
		return false
	end
	remote.instance:FireClient(player, ...)
	return true
end

function RemoteService.fireAll(self: any, name: string, ...: any)
	local remote = outbound(self, name, "fireAll")
	remote.instance:FireAllClients(...)
end

function RemoteService.stats(self: any)
	local buckets = 0
	for _, remote in self._inbound do
		buckets += remote.limiter:size()
	end
	return {
		dropped = table.clone(self._dropped),
		droppedByName = table.clone(self._droppedByName),
		buckets = buckets,
	}
end

function RemoteService.destroy(self: any)
	self._trove:clean()
	for _, remote in self._inbound do
		remote.limiter:reset()
		remote.handler = nil
	end
end

return Def
