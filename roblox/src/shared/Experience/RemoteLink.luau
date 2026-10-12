--!strict
--[[
	Experience/RemoteLink — client access to remotes by the documented instance layout
	ReplicatedStorage.ForgeRemotes.<Area>.<Action> (interfaces §6).

	TEMPORARY seam: the contract's client API is FORGE-01's shared/Core/RemoteClient (FL-0009), which
	is not on main yet. Experience controllers call only these three functions, so switching to
	RemoteClient later changes this file alone (handoff to FORGE-01).

		RemoteLink.find(env, "Area.Action") -> Instance?                 -- no yield
		RemoteLink.on(env, "Area.Action", fn, timeoutSec = 30) -> Link    -- waits in its own thread
		RemoteLink.send(env, "Area.Action", ...) -> boolean                -- FireServer if the remote exists
		link:disconnect()
	A remote that never appears (its owner has not declared it yet) logs one info line and stays inert.
]]

local RemoteLink = {}

local function split(name: string): (string, string)
	local area, action = string.match(name, "^(%w+)%.(%w+)$")
	assert(area and action, `RemoteLink: '{name}' is not "<Area>.<Action>"`)
	return area :: string, action :: string
end

function RemoteLink.find(env: any, name: string): any
	local area, action = split(name)
	local root = env.ReplicatedStorage:FindFirstChild("ForgeRemotes")
	local folder = if root then root:FindFirstChild(area) else nil
	return if folder then folder:FindFirstChild(action) else nil
end

function RemoteLink.on(env: any, name: string, fn: (...any) -> (), timeoutSec: number?)
	local area, action = split(name)
	local link = { connection = nil :: any, active = true }
	function link.disconnect(_self: any)
		link.active = false
		if link.connection then
			link.connection:Disconnect()
			link.connection = nil
		end
	end
	env.spawn(function()
		local timeout = timeoutSec or 30
		local root = env.ReplicatedStorage:WaitForChild("ForgeRemotes", timeout)
		local folder = if root then root:WaitForChild(area, timeout) else nil
		local remote = if folder then folder:WaitForChild(action, timeout) else nil
		if not link.active then
			return
		end
		if remote == nil then
			env.log("info", `RemoteLink: {name} not available; feature inactive until its owner declares it`, {})
			return
		end
		link.connection = remote.OnClientEvent:Connect(fn)
	end)
	return link
end

function RemoteLink.send(env: any, name: string, ...): boolean
	local remote = RemoteLink.find(env, name)
	if remote == nil then
		return false
	end
	remote:FireServer(...)
	return true
end

return table.freeze(RemoteLink)
