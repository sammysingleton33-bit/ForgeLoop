--!strict
--[[
	UI/Create — the instance builder every FORGELOOP screen uses (interfaces §9). No framework:
	one function that makes an instance, sets properties, connects events and parents children.

		local Create = require("./Create")
		local button = Create("TextButton", {
			Name = "Build",
			Size = UDim2.fromOffset(120, 44),
			[Create.Event.Activated] = function() print("tap") end,
			[Create.Ref] = function(instance) self._button = instance end,
		}, {
			Create("UICorner", { CornerRadius = UDim.new(0, 8) }),
			Label = Create("TextLabel", { Text = "Build" }),   -- keyed child: Name = "Label"
		})

	Props: any property of the class; `Parent` is applied last (after children). Special keys:
		[Create.Event.<Name>] = fn   connects instance.<Name> (Activated, MouseEnter, ...)
		[Create.Ref] = fn(instance)  called once the instance is built
	Children: a list of instances and/or a map name -> instance (the key becomes Name). nil/false
	entries are skipped, so `cond and Create(...)` works.

	Create.connect(instance, eventName, fn) -> connection   (what Event keys use)
	Create.setConnector(fn?) -> previous   tests: route connections through a fake (the Lune
		harness has no instance events); fn(instance, eventName, handler) -> { Disconnect: () -> () }
	Create.fire(instance, eventName, ...)   tests: call handlers registered through the default
		test connector installed by Create.useTestConnector() (each call starts with no handlers)
	Create.clear(instance)                  destroys every child
]]

export type Connection = { Disconnect: (any) -> () }

local Create = {}

local eventKeys: { [string]: any } = {}
Create.Event = setmetatable({}, {
	__index = function(_, name: string)
		local key = eventKeys[name]
		if key == nil then
			key = table.freeze({ kind = "CreateEvent", name = name })
			eventKeys[name] = key
		end
		return key
	end,
}) :: any
Create.Ref = table.freeze({ kind = "CreateRef" })

local function engineConnector(instance: any, eventName: string, fn: (...any) -> ()): Connection
	return instance[eventName]:Connect(fn)
end

local connector: (any, string, (...any) -> ()) -> Connection = engineConnector

function Create.connect(instance: any, eventName: string, fn: (...any) -> ()): Connection
	return connector(instance, eventName, fn)
end

function Create.setConnector(fn: ((any, string, (...any) -> ()) -> Connection)?)
	local previous = connector
	connector = fn or engineConnector
	return previous
end

-- Test connector: handlers live in a table keyed by instance; Create.fire calls them. The keys are
-- strong on purpose: Lune hands out a new userdata for an instance once nothing in Lua holds the
-- old one, so weak keys lost handlers whenever the GC ran. Each useTestConnector() starts a new
-- table, so a test run keeps one test's instances at a time.
local handlers: { [any]: { [string]: { (...any) -> () } } } = {}

function Create.useTestConnector()
	handlers = {}
	return Create.setConnector(function(instance: any, eventName: string, fn: (...any) -> ()): Connection
		local byEvent = handlers[instance]
		if byEvent == nil then
			byEvent = {}
			handlers[instance] = byEvent
		end
		local list = byEvent[eventName]
		if list == nil then
			list = {}
			byEvent[eventName] = list
		end
		table.insert(list, fn)
		return {
			Disconnect = function()
				local index = table.find(list, fn)
				if index then
					table.remove(list, index)
				end
			end,
		}
	end)
end

function Create.fire(instance: any, eventName: string, ...: any): number
	local byEvent = handlers[instance]
	local list = byEvent and byEvent[eventName]
	if list == nil then
		return 0
	end
	for _, fn in table.clone(list) do
		fn(...)
	end
	return #list
end

function Create.clear(instance: any)
	for _, child in instance:GetChildren() do
		child:Destroy()
	end
end

local function build(className: string, props: { [any]: any }?, children: { [any]: any }?): any
	local instance = Instance.new(className :: any)
	local parent = nil
	local ref = nil
	if props then
		for key, value in props do
			if key == "Parent" then
				parent = value
			elseif key == Create.Ref then
				ref = value
			elseif type(key) == "table" and key.kind == "CreateEvent" then
				Create.connect(instance, key.name, value)
			else
				(instance :: any)[key] = value
			end
		end
	end
	if children then
		for key, child in children do
			if child then
				if typeof(child) ~= "Instance" then
					error(`Create({className}): child {tostring(key)} is a {typeof(child)}, not an Instance`, 2)
				end
				if type(key) == "string" then
					child.Name = key
				end
				child.Parent = instance
			end
		end
	end
	if ref then
		ref(instance)
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

return setmetatable(Create, {
	__call = function(_, className: string, props: { [any]: any }?, children: { [any]: any }?)
		return build(className, props, children)
	end,
}) :: any
