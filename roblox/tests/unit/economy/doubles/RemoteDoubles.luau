--[[
	Test doubles for FORGE-01's remote layer (interfaces §6) until RemoteService, Core/RemoteClient
	and Core/Validate merge. Built on the MockRemotes network of a MockEnv, so payloads are copied
	like real remotes. Swap for the real modules when they land (FORGE-03 STATUS.md tracks it).

	RemoteDoubles.Validate      string(min, max), integer(min, max), boolean(), optional(v) — the §6
	                            validator shape: (value) -> (ok, err)
	RemoteDoubles.serviceDefinition()   Loader definition named "RemoteService":
		:handle(name, fn(player, ...)), :fire(name, player, ...), :fireAll(name, ...)
		Instances: ReplicatedStorage.ForgeRemotes.<Area>.<Action> from env.sharedModules("Remotes").
		Arguments are checked against `args`; extra or invalid arguments drop the call
		(functions return nil) and are recorded in service.dropped. No rate limiting (not modelled).
	RemoteDoubles.client(env) -> RemoteClient { invoke(name, ...), send(name, ...), on(name, fn) }
		Client calls run in the MockEnv's default client context (MockEnv localPlayer option).
]]

local RemoteDoubles = {}

local Validate = {}
function Validate.string(min: number, max: number)
	return function(v)
		if type(v) ~= "string" or #v < min or #v > max or utf8.len(v) == nil then
			return false, "string"
		end
		return true
	end
end
function Validate.integer(min: number, max: number)
	return function(v)
		if type(v) ~= "number" or v ~= v or v ~= math.floor(v) or v < min or v > max then
			return false, "integer"
		end
		return true
	end
end
function Validate.boolean()
	return function(v)
		return type(v) == "boolean", "boolean"
	end
end
function Validate.optional(inner)
	return function(v)
		if v == nil then
			return true
		end
		return inner(v)
	end
end
RemoteDoubles.Validate = Validate

local CLASS = { ["function"] = "RemoteFunction", event = "RemoteEvent", serverEvent = "RemoteEvent" }

local function split(name: string): (string, string)
	local area, action = string.match(name, "^(%w+)%.(%w+)$")
	assert(area and action, `remote name '{name}' must be <Area>.<Action>`)
	return area :: string, action :: string
end

function RemoteDoubles.serviceDefinition()
	return {
		name = "RemoteService",
		dependencies = {},
		new = function(env)
			local service = { dropped = {}, _decl = {}, _instances = {} }
			local root = env.newInstance("Folder")
			root.Name = "ForgeRemotes"
			root.Parent = env.ReplicatedStorage
			for areaName, list in env.sharedModules("Remotes") do
				for _, decl in list do
					local area, action = split(decl.name)
					assert(area == areaName, `{decl.name} declared in {areaName}/Remotes.luau`)
					local folder = root:FindFirstChild(area)
					if folder == nil then
						folder = env.newInstance("Folder")
						folder.Name = area
						folder.Parent = root
					end
					local remote = env.newInstance(CLASS[decl.kind] or "RemoteEvent")
					remote.Name = action
					remote.Parent = folder
					service._decl[decl.name] = decl
					service._instances[decl.name] = remote
				end
			end
			local function valid(decl, packed): boolean
				local args = decl.args or {}
				if packed.n > #args then
					return false
				end
				for i, validator in args do
					if not validator(packed[i]) then
						return false
					end
				end
				return true
			end
			function service:handle(name: string, fn)
				local decl = assert(self._decl[name], `RemoteService:handle: '{name}' is not declared`)
				local remote = self._instances[name]
				if decl.kind == "function" then
					remote.OnServerInvoke = function(player, ...)
						local packed = table.pack(...)
						if not valid(decl, packed) then
							table.insert(self.dropped, { name = name, userId = player.UserId })
							return nil
						end
						return fn(player, ...)
					end
				else
					remote.OnServerEvent:Connect(function(player, ...)
						local packed = table.pack(...)
						if not valid(decl, packed) then
							table.insert(self.dropped, { name = name, userId = player.UserId })
							return
						end
						fn(player, ...)
					end)
				end
			end
			function service:fire(name: string, player, ...)
				assert(self._decl[name], `RemoteService:fire: '{name}' is not declared`)
				self._instances[name]:FireClient(player, ...)
			end
			function service:fireAll(name: string, ...)
				assert(self._decl[name], `RemoteService:fireAll: '{name}' is not declared`)
				self._instances[name]:FireAllClients(...)
			end
			return service
		end,
	}
end

function RemoteDoubles.client(env)
	local function find(name: string)
		local area, action = split(name)
		local root = env.ReplicatedStorage:FindFirstChild("ForgeRemotes")
		local folder = root and root:FindFirstChild(area)
		local remote = folder and folder:FindFirstChild(action)
		assert(remote, `RemoteClient: remote '{name}' does not exist`)
		return remote
	end
	return {
		invoke = function(name: string, ...)
			return find(name):InvokeServer(...)
		end,
		send = function(name: string, ...)
			find(name):FireServer(...)
		end,
		on = function(name: string, fn)
			return find(name).OnClientEvent:Connect(fn)
		end,
	}
end

return RemoteDoubles
