--!strict
--[[
	Experience/Bus — safe subscriptions to the server event bus (Contracts/GameEvents, interfaces §4).

	GameEvents errors when an undeclared event is read (typo guard). Experience systems also listen
	to events that are proposed but not declared yet (Experience/KingdomSignals), so they subscribe
	through this module: undeclared names are skipped and reported instead of crashing the service.
	Any table with EVENT_NAMES and one Signal per name works as a bus (specs pass a fake bus).

	API
		Bus.declared(bus, name) -> boolean
		Bus.connect(bus, name, handler) -> Connection?            -- nil when `name` is not declared
		Bus.connectAll(bus, handlers: { [name]: handler }) -> (connections: { Connection }, missing: { string })
		Bus.disconnect(connections)                                -- disconnects every connection (idempotent)
]]

local Bus = {}

function Bus.declared(bus: any, name: string): boolean
	local names = if type(bus) == "table" then bus.EVENT_NAMES else nil
	return type(names) == "table" and table.find(names, name) ~= nil
end

function Bus.connect(bus: any, name: string, handler: (...any) -> ()): any
	if not Bus.declared(bus, name) then
		return nil
	end
	return bus[name]:connect(handler)
end

function Bus.connectAll(bus: any, handlers: { [string]: (...any) -> () }): ({ any }, { string })
	local names = {}
	for name in handlers do
		table.insert(names, name)
	end
	table.sort(names)
	local connections, missing = {}, {}
	for _, name in names do
		local connection = Bus.connect(bus, name, handlers[name])
		if connection then
			table.insert(connections, connection)
		else
			table.insert(missing, name)
		end
	end
	return connections, missing
end

function Bus.disconnect(connections: { any })
	for _, connection in connections do
		connection:disconnect()
	end
	table.clear(connections)
end

return table.freeze(Bus)
