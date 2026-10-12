--!strict
--[[
	Experience/RemoteLink — how Experience controllers use Core/RemoteClient (interfaces §6) without
	ever blocking or erroring a controller.

	RemoteClient waits (up to its timeout) for a remote to replicate and errors on timeout. That is
	right for gameplay calls, but feedback, settings and onboarding must keep the game running when
	a remote is late or not declared yet. So:

		RemoteLink.on(env, "Area.Action", fn) -> Link   -- connects in its own thread; a missing remote
		                                                 -- logs one info line and stays inert
		RemoteLink.send(env, "Area.Action", ...) -> boolean  -- fires in its own thread; true = queued
		link:disconnect()
	One RemoteClient per env (RemoteClient.new(env)), shared by every Experience controller.
]]

local RemoteClient = require("../Core/RemoteClient")

local RemoteLink = {}

local clients: { [any]: any } = setmetatable({}, { __mode = "k" }) :: any

local function clientFor(env: any): any
	local client = clients[env]
	if client == nil then
		client = RemoteClient.new(env)
		clients[env] = client
	end
	return client
end

function RemoteLink.on(env: any, name: string, fn: (...any) -> ())
	local link = { connection = nil :: any, active = true }
	function link.disconnect(_self: any)
		link.active = false
		if link.connection then
			link.connection:Disconnect()
			link.connection = nil
		end
	end
	env.spawn(function()
		local ok, connection = pcall(function()
			return clientFor(env):on(name, fn)
		end)
		if not ok then
			env.log("info", `RemoteLink: {name} not available; feature inactive until its owner declares it`, {
				error = tostring(connection),
			})
			return
		end
		if link.active then
			link.connection = connection
		else
			connection:Disconnect()
		end
	end)
	return link
end

function RemoteLink.send(env: any, name: string, ...): boolean
	local args = table.pack(...)
	env.spawn(function()
		local ok, err = pcall(function()
			clientFor(env):send(name, table.unpack(args, 1, args.n))
		end)
		if not ok then
			env.log("warn", `RemoteLink: could not send {name}`, { error = tostring(err) })
		end
	end)
	return true
end

return table.freeze(RemoteLink)
