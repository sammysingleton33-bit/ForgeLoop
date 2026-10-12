--[[
	MockInstanceEvents — Instance:WaitForChild and the ChildAdded / ChildRemoved events on Lune
	instances, driven by the MockEnv scheduler. Lune's @lune/roblox instances have no events and no
	WaitForChild; this fills in the members day-one code needs and makes the rest fail clearly.

	Imitates (creator-docs content/en-us/reference/engine/classes/Instance.yaml):
	  WaitForChild(name, timeout?)  returns the child at once if present; otherwise yields until a
	      child with that name exists, or returns nil once `timeout` seconds passed. Without a
	      timeout Roblox waits forever and warns "Infinite yield possible" after 5 s.
	  ChildAdded(child) / ChildRemoved(child)  RBXScriptSignals.
	Semantics under the mock (virtual time, see MockEnv "Time model"):
	  - WaitForChild checks once per frame (1/60 virtual second) on the MockEnv clock. In a scheduled
	    thread it suspends until env.mock:advance() moves time; in the spec's own thread it advances
	    time frame by frame itself. With a timeout it returns nil after `timeout` virtual seconds.
	    Without one, a scheduled thread keeps waiting and records "Infinite yield possible ..." in
	    env.mock.warnings after 5 s; the spec's own thread errors after 5 s instead of hanging.
	  - ChildAdded/ChildRemoved are detected by comparing children at every scheduler step
	    (env.mock:advance, env.wait), and fire then — after the change, like Roblox's Deferred
	    SignalBehavior. Removals fire before additions; additions in child order. Handlers run
	    through env.spawn (a handler that waits suspends until advance()).
	  - Only instances inside a MockEnv DataModel (env.ReplicatedStorage, env.Workspace, ...) or made
	    with env.newInstance have these members; anything else errors with a clear message.
	Not provided (clear error on use): Changed, Destroying, AncestryChanged, DescendantAdded,
	DescendantRemoving, AttributeChanged, GetPropertyChangedSignal, GetAttributeChangedSignal.
	Request them from FORGE-05 by handoff.

	API (MockEnv only)
		MockInstanceEvents.newHub(scheduler) -> hub
			scheduler = { wait(seconds), elapsed() -> number, isDriver() -> boolean,
			              spawn(fn, ...), warn(message), newSignal(name) -> MockSignal }
		hub:adopt(rootInstance)   -- instances under this root (or this unparented instance) use the hub
		hub:poll()                -- compare children and fire events (MockEnv calls it every step)
]]

local roblox = require("@lune/roblox")

local LuneInstances = require("../harness/LuneInstances")

local MockInstanceEvents = {}

local FRAME = 1 / 60
local INFINITE_YIELD_WARNING = 5

-- Process-wide (implementMethod/implementProperty register once per process): root -> hub.
local hubs = LuneInstances.store("MockInstanceEvents.hubs")

local UNSUPPORTED_PROPERTIES =
	{ "Changed", "Destroying", "AncestryChanged", "DescendantAdded", "DescendantRemoving", "AttributeChanged" }
local UNSUPPORTED_METHODS = { "GetPropertyChangedSignal", "GetAttributeChangedSignal" }

local function rootOf(instance: any): any
	local current = instance
	while current.Parent ~= nil do
		current = current.Parent
	end
	return current
end

local function hubOf(instance: any, member: string)
	local hub = hubs[rootOf(instance)]
	if hub == nil then
		error(
			`{instance.ClassName}.{member} under the Lune harness needs an instance inside a MockEnv DataModel `
				.. "(env.ReplicatedStorage, env.Workspace, ...) or one made with env.newInstance",
			3
		)
	end
	return hub
end

local function notMocked(className: string, member: string)
	error(
		`{className}.{member} is not mocked under the Lune harness (roblox/README.md, "Mocks"); `
			.. "request it from FORGE-05 by handoff",
		3
	)
end

local function register()
	roblox.implementMethod("Instance", "WaitForChild", function(instance: any, name: string, timeout: number?)
		if type(name) ~= "string" then
			error("WaitForChild: Argument 1 missing or nil", 2)
		end
		if timeout ~= nil and type(timeout) ~= "number" then
			error("WaitForChild: timeout must be a number", 2)
		end
		local child = instance:FindFirstChild(name)
		if child then
			return child
		end
		return hubOf(instance, "WaitForChild"):waitForChild(instance, name, timeout)
	end)
	for _, kind in { "ChildAdded", "ChildRemoved" } do
		roblox.implementProperty("Instance", kind, function(instance: any)
			return hubOf(instance, kind):signal(instance, kind)
		end)
	end
	for _, name in UNSUPPORTED_PROPERTIES do
		roblox.implementProperty("Instance", name, function(instance: any)
			notMocked(instance.ClassName, name)
		end)
	end
	for _, name in UNSUPPORTED_METHODS do
		roblox.implementMethod("Instance", name, function(instance: any)
			notMocked(instance.ClassName, name .. "()")
		end)
	end
end

function MockInstanceEvents.newHub(scheduler)
	LuneInstances.once("MockInstanceEvents", register)
	local watched = {} -- ordered { { instance, children = { [child]: true }, ChildAdded, ChildRemoved } }
	local entryOf = {}
	local hub = {}

	function hub:adopt(root: any)
		hubs[root] = self
	end

	function hub:signal(instance: any, kind: string)
		local entry = entryOf[instance]
		if entry == nil then
			local children = {}
			for _, child in instance:GetChildren() do
				children[child] = true
			end
			entry = {
				instance = instance,
				children = children,
				ChildAdded = scheduler.newSignal(`{instance.Name}.ChildAdded`),
				ChildRemoved = scheduler.newSignal(`{instance.Name}.ChildRemoved`),
			}
			entryOf[instance] = entry
			table.insert(watched, entry)
		end
		return entry[kind]
	end

	function hub:poll()
		for _, entry in watched do
			local current = entry.instance:GetChildren()
			local before = entry.children
			local now = {}
			for _, child in current do
				now[child] = true
			end
			entry.children = now
			local removed = {}
			for child in before do
				if not now[child] then
					table.insert(removed, child)
				end
			end
			table.sort(removed, function(a, b)
				return a.Name < b.Name
			end)
			for _, child in removed do
				entry.ChildRemoved:Fire(child)
			end
			for _, child in current do
				if not before[child] then
					entry.ChildAdded:Fire(child)
				end
			end
		end
	end

	function hub:waitForChild(parent: any, name: string, timeout: number?)
		local started = scheduler.elapsed()
		local warned = false
		while true do
			scheduler.wait(FRAME)
			local child = parent:FindFirstChild(name)
			if child then
				return child
			end
			local waited = scheduler.elapsed() - started
			if timeout ~= nil and waited >= timeout then
				return nil
			end
			if timeout == nil and not warned and waited >= INFINITE_YIELD_WARNING then
				warned = true
				local message = `Infinite yield possible on '{parent:GetFullName()}:WaitForChild("{name}")'`
				if scheduler.isDriver() then
					error(
						message
							.. " — the spec's own thread would wait forever: create the child first, pass a "
							.. "timeout, or wait in env.spawn and advance time from the spec",
						3
					)
				end
				scheduler.warn(message)
			end
		end
	end

	return hub
end

return MockInstanceEvents
