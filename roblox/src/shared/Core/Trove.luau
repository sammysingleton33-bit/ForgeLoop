--!strict
--[[
	Trove — collects things to clean up and cleans them together (connections, instances, functions).

	API
		Trove.new(reporter: ((message: string) -> ())?): Trove   -- reporter defaults to warn
		trove:add(item): item          -- returns the item; errors at once if it cannot be cleaned
		trove:extend(): Trove          -- a child trove, added to this one (same reporter)
		trove:remove(item): (found: boolean, err: string?)
		                               -- takes the item out and cleans it now (like RbxUtil Trove)
		trove:clean(): { string }      -- cleans everything; returns the failure messages
		trove:destroy()                -- same as clean() (so a Trove can be an owned resource)
		Trove.is(value): boolean

	Items and how they are cleaned (checked in this order)
		function                         called with no arguments
		Trove (child, e.g. from extend)  child:clean() — its failures join the parent's list
		Instance                         :Destroy()
		RBXScriptConnection              :Disconnect()
		table/userdata with Disconnect   :Disconnect()  (engine connection, MockSignal connection)
		table/userdata with disconnect   :disconnect()  (Core/Signal connection)
		table/userdata with Destroy      :Destroy()
		table/userdata with destroy      :destroy()
	Anything else (nil, numbers, strings, plain tables without those methods) is rejected by add().

	Semantics
		- clean() cleans in reverse order of add() (last added first). Items added while cleaning
		  are cleaned in the same pass. Afterwards the trove is empty and reusable; a second
		  clean() does nothing (idempotent), and clean() called from inside a cleanup returns {}.
		- Every cleanup runs in protected mode: an error in one does not stop the others. Each
		  failure is collected ("Trove: <kind> cleanup failed: <error>"), passed to the reporter
		  once per clean()/remove(), and returned by clean().
		- An item added twice is cleaned twice.
]]

export type Trove = {
	add: <T>(self: Trove, item: T) -> T,
	extend: (self: Trove) -> Trove,
	remove: (self: Trove, item: any) -> (boolean, string?),
	clean: (self: Trove) -> { string },
	destroy: (self: Trove) -> (),
}

type Entry = { item: any, kind: string }

local Trove = {}
Trove.__index = Trove

local function defaultReporter(message: string)
	warn(message)
end

function Trove.new(reporter: ((string) -> ())?): Trove
	if reporter ~= nil and type(reporter) ~= "function" then
		error("Trove.new(reporter?): reporter must be a function", 2)
	end
	local self = setmetatable({
		_items = {} :: { Entry },
		_reporter = reporter or defaultReporter,
		_cleaning = false,
	}, Trove)
	return (self :: any) :: Trove
end

function Trove.is(value: any): boolean
	return type(value) == "table" and getmetatable(value) == Trove
end

local function hasMethod(item: any, name: string): boolean
	local ok, member = pcall(function()
		return item[name]
	end)
	return ok and type(member) == "function"
end

local function kindOf(item: any): string?
	local t = typeof(item)
	if t == "function" then
		return "function"
	elseif t == "table" and getmetatable(item) == Trove then
		return "trove"
	elseif t == "Instance" then
		return "Destroy"
	elseif t == "RBXScriptConnection" then
		return "Disconnect"
	elseif t == "table" or t == "userdata" then
		for _, method in { "Disconnect", "disconnect", "Destroy", "destroy" } do
			if hasMethod(item, method) then
				return method
			end
		end
	end
	return nil
end

-- Cleans one entry; appends failure messages to `failures`.
local function cleanEntry(entry: Entry, failures: { string })
	local item, kind = entry.item, entry.kind
	if kind == "trove" then
		local ok, err = pcall(function()
			for _, message in item:_cleanAll() do
				table.insert(failures, message)
			end
		end)
		if not ok then
			table.insert(failures, `Trove: child trove cleanup failed: {tostring(err)}`)
		end
		return
	end
	local ok, err
	if kind == "function" then
		ok, err = pcall(item)
	else
		ok, err = pcall(function()
			item[kind](item)
		end)
	end
	if not ok then
		local label = if kind == "function" then "function" else `{typeof(item)}:{kind}()`
		table.insert(failures, `Trove: {label} cleanup failed: {tostring(err)}`)
	end
end

local function report(self: any, failures: { string })
	if #failures > 0 then
		pcall(self._reporter, table.concat(failures, "\n"))
	end
end

function Trove.add(self: any, item: any): any
	local kind = kindOf(item)
	if kind == nil then
		error(
			`Trove:add: cannot clean a {typeof(item)} (expected a function, Instance, connection, or object `
				.. "with Disconnect/disconnect/Destroy/destroy)",
			2
		)
	end
	if item == self then
		error("Trove:add: a trove cannot contain itself", 2)
	end
	table.insert(self._items, { item = item, kind = kind :: string })
	return item
end

function Trove.extend(self: any): Trove
	local child = Trove.new(self._reporter)
	Trove.add(self, child)
	return child
end

-- Cleans every item without reporting; returns the failures (used by clean() and parent troves).
function Trove._cleanAll(self: any): { string }
	local failures: { string } = {}
	if self._cleaning then
		return failures
	end
	self._cleaning = true
	local items: { Entry } = self._items
	while #items > 0 do
		local entry = table.remove(items) :: Entry
		cleanEntry(entry, failures)
	end
	self._cleaning = false
	return failures
end

function Trove.clean(self: any): { string }
	local failures = Trove._cleanAll(self)
	report(self, failures)
	return failures
end

function Trove.destroy(self: any)
	Trove.clean(self)
end

function Trove.remove(self: any, item: any): (boolean, string?)
	local items: { Entry } = self._items
	for i = #items, 1, -1 do
		if items[i].item == item then
			local entry = table.remove(items, i) :: Entry
			local failures: { string } = {}
			cleanEntry(entry, failures)
			report(self, failures)
			return true, failures[1]
		end
	end
	return false, nil
end

return Trove
