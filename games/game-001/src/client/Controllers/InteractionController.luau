--!strict
--[[
	InteractionController (game-001 client, FORGE-01, FL-0051; CONTRACTS G4.1, G8): the ruler gathers
	from resource nodes by hand.

	Prompts
		Every instance WorldService tags `ResourceNode` (attributes NodeId and Resource, CONTRACTS G10)
		gets a client-side ProximityPrompt "GatherPrompt" on its PrimaryPart, else its first BasePart:
		ActionText "Gather", ObjectText the resource's name (config Resources), HoldDuration 0,
		RequiresLineOfSight false, MaxActivationDistance Def.activationDistance(resource). That distance
		is RulerGather.CONFIG.range plus the smallest footprint of the resource's node kinds (config
		Jobs.nodes) less Def.MARGIN, and the prompt measures in 3D from the base of the model, so it only
		shows where the server's check (node footprint + range from the node centre, on X/Z) passes.
		A node tagged later gets a prompt too; an untagged or removed node loses it. A node whose parts
		have not streamed in yet gets its prompt when a part arrives, and again after its part streams
		out and back. The prompts are disabled outside explore mode.
	Gathering (a prompt's Triggered calls controller:gather(nodeId))
		- Only in explore mode: FORGE-04's InputModeController is absent or its mode is "explore". In build
		  mode nothing is sent.
		- At most once per Def.COOLDOWN (RulerGather.CONFIG.cooldown) and one request in flight.
		- Invokes Kingdom.Gather(nodeId) through RemoteClient. The server checks the ruler, the range from
		  its own view of the character, its cooldown and the node (Sim/RulerGather), deposits into the
		  treasury and fires the G9 ResourceGathered (source "ruler"), which the onboarding Gather step
		  waits for.
		- (true, resource, amount): gathered:fire(nodeId, resource, amount); lastRefusal = nil.
		- (false, code): nothing visible; lastRefusal = code ("dropped" when the server dropped the
		  call, "error" when the call failed).
		The client decides nothing valuable: the amount and the treasury come from the server.

	API (G4.1)
		InteractionController.gathered: Signal<(nodeId: string, ResourceId, amount: number)>
	Additive
		controller:gather(nodeId): (boolean, string?)   -- true when a request was sent; else false and
		                                                   "not_explore" | "cooldown" | "pending" | "stopped"
		controller.lastRefusal: string?                 -- the last refusal code (nil after a success)
		controller.adapter                              -- engine calls (Adapter); specs replace it before start()
		controller.remotes                              -- RemoteClient, made in start() unless a spec set one
		controller:promptCount(): number                -- live prompts (specs)
		Def.TAG, Def.COOLDOWN, Def.MARGIN, Def.activationDistance(resource), Def.promptProps(resource),
		Def.anchorOf(node), Def.robloxAdapter(env)
	Without CollectionService or ProximityPrompt support (the headless boot gate tags no nodes) it boots
	and does nothing. Unverified in Studio until roblox/studio-tests/gameplay.md K12 is run.
]]

local JobsConfig = require("@game/ReplicatedStorage/Forge/Config/Jobs")
local RemoteClient = require("@game/ReplicatedStorage/Forge/Core/RemoteClient")
local Resources = require("@game/ReplicatedStorage/Forge/Config/Resources")
local Signal = require("@game/ReplicatedStorage/Forge/Core/Signal")
local RulerGather = require("@game/ReplicatedStorage/Game/Sim/RulerGather")

local InteractionController = {}
InteractionController.__index = InteractionController

local Def = { name = "InteractionController", dependencies = {} }

Def.TAG = "ResourceNode" -- WorldService's tag (CONTRACTS G10)
Def.PROMPT_NAME = "GatherPrompt"
Def.COOLDOWN = RulerGather.CONFIG.cooldown -- seconds between two requests (the server's own cooldown)
Def.MARGIN = 2 -- studs kept inside the server's range (the server sees the character a little late)

export type Adapter = {
	tagged: () -> { any }, -- CollectionService:GetTagged(TAG)
	listen: (added: (node: any) -> (), removed: (node: any) -> ()) -> { any }, -- tag signals; connections
	watchParts: (node: any, arrived: () -> ()) -> any?, -- a BasePart arrived under the node; connection
	-- a prompt on the node's anchor part (PrimaryPart, else the first BasePart); nil while it has none.
	-- `lost` runs when that part leaves the node (streamed out).
	attach: (node: any, props: { [string]: any }, triggered: () -> (), lost: () -> ()) -> any?,
	setEnabled: (handle: any, enabled: boolean) -> (),
	detach: (handle: any) -> (),
}

type Entry = { node: any, id: string, resource: string?, handle: any?, parts: any? }

-- Prompt reach for a node of `resource`: the server's range plus the smallest footprint of the node
-- kinds that yield it, less MARGIN.
function Def.activationDistance(resource: string?): number
	local footprint = math.huge
	local smallest = math.huge
	for _, def in JobsConfig.nodes do
		smallest = math.min(smallest, def.footprint)
		if def.resource == resource then
			footprint = math.min(footprint, def.footprint)
		end
	end
	if footprint == math.huge then
		footprint = smallest
	end
	return RulerGather.CONFIG.range + footprint - Def.MARGIN
end

function Def.promptProps(resource: string?): { [string]: any }
	local def = if resource then Resources.defs[resource] else nil
	return {
		Name = Def.PROMPT_NAME,
		ActionText = "Gather",
		ObjectText = if def then def.name else "",
		HoldDuration = 0,
		MaxActivationDistance = Def.activationDistance(resource),
		RequiresLineOfSight = false,
	}
end

-- The part a node's prompt sits on: the node itself when it is a part, else its PrimaryPart, else its
-- first BasePart; nil while none has streamed in.
function Def.anchorOf(node: any): any?
	if node:IsA("BasePart") then
		return node
	end
	local primary = if node:IsA("Model") then node.PrimaryPart else nil
	return primary or node:FindFirstChildWhichIsA("BasePart", true)
end

function Def.robloxAdapter(env: any): Adapter
	return {
		tagged = function(): { any }
			return env.CollectionService:GetTagged(Def.TAG)
		end,
		listen = function(added: (any) -> (), removed: (any) -> ()): { any }
			local tags = env.CollectionService
			return {
				tags:GetInstanceAddedSignal(Def.TAG):Connect(added),
				tags:GetInstanceRemovedSignal(Def.TAG):Connect(removed),
			}
		end,
		watchParts = function(node: any, arrived: () -> ()): any?
			return node.DescendantAdded:Connect(function(descendant)
				if descendant:IsA("BasePart") then
					arrived()
				end
			end)
		end,
		attach = function(node: any, props: { [string]: any }, triggered: () -> (), lost: () -> ()): any?
			local part = Def.anchorOf(node)
			if part == nil then
				return nil
			end
			local prompt = env.newInstance("ProximityPrompt")
			for key, value in props do
				prompt[key] = value
			end
			prompt.Parent = part
			local connections = {
				prompt.Triggered:Connect(function()
					triggered()
				end),
				part.AncestryChanged:Connect(function()
					if part ~= node and not part:IsDescendantOf(node) then
						lost()
					end
				end),
			}
			return { prompt = prompt, connections = connections }
		end,
		setEnabled = function(handle: any, enabled: boolean)
			handle.prompt.Enabled = enabled
		end,
		detach = function(handle: any)
			for _, connection in handle.connections do
				connection:Disconnect()
			end
			handle.prompt:Destroy()
		end,
	}
end

local function disconnect(connection: any)
	if connection ~= nil then
		pcall(function()
			connection:Disconnect()
		end)
	end
end

local function attribute(node: any, name: string): any
	local ok, value = pcall(function()
		return node:GetAttribute(name)
	end)
	return if ok then value else nil
end

function Def.new(env: any, registry: any)
	return setmetatable({
		_env = env,
		_registry = registry,
		gathered = Signal.new(),
		adapter = Def.robloxAdapter(env),
		remotes = nil :: any,
		lastRefusal = nil :: string?,
		_nodes = {} :: { [any]: Entry },
		_connections = {} :: { any },
		_input = nil :: any,
		_inputConnection = nil :: any,
		_lastAt = -math.huge,
		_pending = false,
		_running = false,
		_warned = false,
	}, InteractionController)
end

function InteractionController:start()
	local env = self._env
	self._running = true
	self._input = self._registry:find("InputModeController")
	if self.remotes == nil then
		self.remotes = RemoteClient.new(env)
	end
	local input = self._input
	if input ~= nil and input.changed ~= nil then
		self._inputConnection = input.changed:connect(function()
			self:_refreshEnabled()
		end)
	end
	local ok, err = pcall(function()
		for _, connection in
			self.adapter.listen(function(node)
				self:_add(node)
			end, function(node)
				self:_remove(node)
			end)
		do
			table.insert(self._connections, connection)
		end
		for _, node in self.adapter.tagged() do
			self:_add(node)
		end
	end)
	if not ok then
		env.log("warn", "InteractionController: cannot follow ResourceNode tags; no gather prompts", {
			error = tostring(err),
		})
	end
end

function InteractionController:destroy()
	self._running = false
	local nodes = {}
	for node in self._nodes do
		table.insert(nodes, node)
	end
	for _, node in nodes do
		self:_remove(node)
	end
	for _, connection in self._connections do
		disconnect(connection)
	end
	table.clear(self._connections)
	if self._inputConnection ~= nil then
		self._inputConnection:disconnect()
		self._inputConnection = nil
	end
	self.gathered:disconnectAll()
end

function InteractionController:_explore(): boolean
	local input = self._input
	return input == nil or input.mode == "explore"
end

function InteractionController:_add(node: any)
	if not self._running or self._nodes[node] ~= nil then
		return
	end
	local id = attribute(node, "NodeId")
	if type(id) ~= "string" or id == "" then
		return
	end
	local resource = attribute(node, "Resource")
	local entry: Entry = {
		node = node,
		id = id,
		resource = if type(resource) == "string" then resource else nil,
		handle = nil,
		parts = nil,
	}
	self._nodes[node] = entry
	local ok, connection = pcall(self.adapter.watchParts, node, function()
		if entry.handle == nil and self._nodes[node] == entry then
			self:_attach(entry)
		end
	end)
	entry.parts = if ok then connection else nil
	self:_attach(entry)
end

function InteractionController:_attach(entry: Entry)
	local handle: any = nil
	local ok, result = pcall(self.adapter.attach, entry.node, Def.promptProps(entry.resource), function()
		self:gather(entry.id)
	end, function()
		-- the anchor part left the node (streamed out): try another part, else wait for one to arrive
		if handle ~= nil and entry.handle == handle and self._nodes[entry.node] == entry then
			entry.handle = nil
			pcall(self.adapter.detach, handle)
			self:_attach(entry)
		end
	end)
	if not ok then
		if not self._warned then
			self._warned = true
			self._env.log("warn", "InteractionController: cannot attach a gather prompt", { error = tostring(result) })
		end
		return
	end
	handle = result
	entry.handle = handle
	if handle ~= nil and not self:_explore() then
		pcall(self.adapter.setEnabled, handle, false)
	end
end

function InteractionController:_remove(node: any)
	local entry = self._nodes[node]
	if entry == nil then
		return
	end
	self._nodes[node] = nil
	if entry.handle ~= nil then
		pcall(self.adapter.detach, entry.handle)
		entry.handle = nil
	end
	disconnect(entry.parts)
	entry.parts = nil
end

function InteractionController:_refreshEnabled()
	local enabled = self:_explore()
	for _, entry in self._nodes do
		if entry.handle ~= nil then
			pcall(self.adapter.setEnabled, entry.handle, enabled)
		end
	end
end

function InteractionController:promptCount(): number
	local n = 0
	for _, entry in self._nodes do
		if entry.handle ~= nil then
			n += 1
		end
	end
	return n
end

-- What a prompt's Triggered calls. Sends Kingdom.Gather(nodeId) from a spawned thread; the reply fires
-- `gathered` or sets lastRefusal.
function InteractionController:gather(nodeId: string): (boolean, string?)
	if not self._running then
		return false, "stopped"
	end
	if not self:_explore() then
		return false, "not_explore"
	end
	if self._pending then
		return false, "pending"
	end
	local env = self._env
	local now = env.clock()
	if now - self._lastAt < Def.COOLDOWN then
		return false, "cooldown"
	end
	self._lastAt = now
	self._pending = true
	env.spawn(function()
		local reply = table.pack(pcall(function()
			return self.remotes:invoke("Kingdom.Gather", nodeId)
		end))
		self._pending = false
		if not self._running then
			return
		end
		if not reply[1] then
			self.lastRefusal = "error"
			env.log("warn", "InteractionController: Kingdom.Gather failed", { error = tostring(reply[2]) })
			return
		end
		local ok, resource, amount = reply[2], reply[3], reply[4]
		if ok == true and type(resource) == "string" and type(amount) == "number" then
			self.lastRefusal = nil
			self.gathered:fire(nodeId, resource, amount)
		else
			self.lastRefusal = if ok == false and type(resource) == "string" then resource else "dropped"
		end
	end)
	return true, nil
end

return Def
