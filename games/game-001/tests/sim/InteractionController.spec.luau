--[[
	InteractionController (CONTRACTS G4.1 `gathered`, G8 Kingdom.Gather; FL-0051 ruler gathering).

	Unit: a client MockEnv with the real CollectionService mock (tags, added/removed signals) and a
	recording adapter for the engine calls Lune cannot make (ProximityPrompt.Triggered, AncestryChanged,
	DescendantAdded): a test triggers a prompt by calling its recorded `triggered`, streams a part out by
	calling `lost`, and back in by calling the node's recorded `arrived`. Kingdom.Gather is a recording
	double (`replies` queue) unless the test wires the real server.
	End to end: FORGE-02's real WorldService places and tags the world nodes; MatchService, KingdomService,
	RemoteService and FORGE-04's OnboardingService run as in Main.server; the controller's prompt for
	crimson_wood1 invokes the real Kingdom.Gather as the ruler (MockRemotes), so the treasury, the G9
	ResourceGathered (source "ruler") are the server's own. (FORGE-04's onboarding v2 has no Gather
	step any more; the idle hint still points at trees and rocks.)
	Not covered here (Studio, roblox/studio-tests/gameplay.md K12): the prompt's look, its reach as the
	engine measures it, key/touch input, streaming.
]]

local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect, afterEach = T.describe, T.it, T.expect, T.afterEach

local MockEnv = require("../../../../roblox/tests/mocks/MockEnv")
local MockServices = require("../../../../roblox/tests/mocks/MockServices")
local ExperienceRemotes = require("@game/ReplicatedStorage/Forge/Experience/Remotes")
local GameEvents = require("@game/ReplicatedStorage/Forge/Contracts/GameEvents")
local JobsConfig = require("@game/ReplicatedStorage/Forge/Config/Jobs")
local Loader = require("@game/ReplicatedStorage/Forge/Contracts/Loader")
local MatchConfig = require("@game/ReplicatedStorage/Forge/Config/Match")
local KingdomRemotes = require("@game/ReplicatedStorage/Game/Kingdom/Remotes")
local Layout = require("@game/ReplicatedStorage/Game/Kingdom/Layout")
local Match = require("@game/ReplicatedStorage/Game/Kingdom/Match")
local MatchRemotes = require("@game/ReplicatedStorage/Game/Match/Remotes")
local RulerGather = require("@game/ReplicatedStorage/Game/Sim/RulerGather")
local Terrain = require("@game/ReplicatedStorage/Game/Kit/Terrain")
local TreasuryRemotes = require("@game/ReplicatedStorage/Game/Treasury/Remotes")
local AnalyticsServiceDef = require("@game/ServerScriptService/Forge/Services/AnalyticsService")
local OnboardingServiceDef = require("@game/ServerScriptService/Forge/Services/OnboardingService")
local RemoteServiceDef = require("@game/ServerScriptService/Forge/Services/RemoteService")
local SettingsServiceDef = require("@game/ServerScriptService/Forge/Services/SettingsService")
local KingdomServiceDef = require("@game/ServerScriptService/Game/Services/KingdomService")
local MatchServiceDef = require("@game/ServerScriptService/Game/Services/MatchService")
local WorldServiceDef = require("@game/ServerScriptService/Game/Services/WorldService")
local InputDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/InputModeController")
local Def = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/InteractionController")

local TAG = "ResourceNode"
local AFTER_COOLDOWN = Def.COOLDOWN + 0.05 -- virtual seconds that surely pass the client cooldown
local cleanup = {} -- functions run after each test

afterEach(function()
	for _, fn in cleanup do
		fn()
	end
	table.clear(cleanup)
	GameEvents.disconnectAll()
end)

-- Recording adapter: the real tag queries (MockCollectionService), recorded prompts.
local function recorder(env)
	local real = Def.robloxAdapter(env)
	local rec = { prompts = {}, attached = 0, detached = 0, arrived = {} }
	rec.adapter = {
		tagged = real.tagged,
		listen = real.listen,
		watchParts = function(node, arrived)
			rec.arrived[node] = arrived
			return {
				Disconnect = function()
					rec.arrived[node] = nil
				end,
			}
		end,
		attach = function(node, props, triggered, lost)
			local part = Def.anchorOf(node)
			if part == nil then
				return nil
			end
			local handle =
				{ node = node, part = part, props = props, triggered = triggered, lost = lost, enabled = true }
			rec.prompts[node] = handle
			rec.attached += 1
			return handle
		end,
		setEnabled = function(handle, enabled)
			handle.enabled = enabled
		end,
		detach = function(handle)
			if rec.prompts[handle.node] == handle then
				rec.prompts[handle.node] = nil
			end
			rec.detached += 1
		end,
	}
	return rec
end

-- A tagged node as WorldService makes it: a Model with a Root PrimaryPart, NodeId and Resource attributes.
local function makeNode(env, id: string?, resource: string, options: { [string]: any }?)
	local opts = options or {}
	local model = env.newInstance("Model")
	model.Name = id or "node"
	if id then
		model:SetAttribute("NodeId", id)
	end
	model:SetAttribute("Resource", resource)
	if not opts.empty then
		local root = env.newInstance("Part")
		root.Name = "Root"
		root.Parent = model
		model.PrimaryPart = root
	end
	model.Parent = env.Workspace
	env.CollectionService:AddTag(model, TAG)
	return model
end

-- options: { input = InputModeController?, services = MockEnv services? }
local function setup(options: { [string]: any }?)
	local opts = options or {}
	local env = MockEnv.new({ seed = 3, services = opts.services })
	local found = {}
	local registry = {
		find = function(_, name)
			return found[name]
		end,
	}
	if opts.input then
		found.InputModeController = InputDef.new(env, registry)
	end
	local controller = Def.new(env, registry)
	local rec = recorder(env)
	controller.adapter = rec.adapter
	local h = { env = env, controller = controller, rec = rec, calls = {}, replies = {}, gathered = {} }
	h.input = found.InputModeController
	controller.remotes = {
		invoke = function(_, name, ...)
			table.insert(h.calls, { name, ... })
			if h.delay then
				env.wait(h.delay)
			end
			local reply = table.remove(h.replies, 1) or { true, "wood", 2 }
			return table.unpack(reply, 1, reply.n or #reply)
		end,
	}
	controller.gathered:connect(function(nodeId, resource, amount)
		table.insert(h.gathered, { nodeId, resource, amount })
	end)
	table.insert(cleanup, function()
		controller:destroy()
	end)
	return h
end

local function count(map): number
	local n = 0
	for _ in map do
		n += 1
	end
	return n
end

describe("InteractionController: gather prompts on ResourceNode tags (G10)", function()
	it("puts one Gather prompt on every tagged node's PrimaryPart, also on nodes tagged later", function()
		local h = setup()
		local env = h.env
		local wood = makeNode(env, "crimson_wood1", "wood")
		local stone = makeNode(env, "crimson_stone1", "stone")
		makeNode(env, nil, "wood") -- no NodeId: not a node the server knows
		h.controller:start()
		expect(h.controller:promptCount()).toBe(2)
		local prompt = h.rec.prompts[wood]
		expect(prompt.part).toBe(wood.PrimaryPart)
		expect(prompt.props).toEqual({
			Name = "GatherPrompt",
			ActionText = "Gather",
			ObjectText = "Wood",
			HoldDuration = 0,
			MaxActivationDistance = Def.activationDistance("wood"),
			RequiresLineOfSight = false,
		})
		expect(h.rec.prompts[stone].props.ObjectText).toBe("Stone")
		local gold = makeNode(env, "crimson_gold1", "gold")
		expect(h.controller:promptCount()).toBe(3)
		expect(h.rec.prompts[gold].props.ObjectText).toBe("Gold")
		-- a second added signal for the same node adds nothing
		h.controller:_add(gold)
		expect(h.rec.attached).toBe(3)
	end)

	it("removes a node's prompt with its tag, and destroy() removes the rest", function()
		local h = setup()
		local env = h.env
		local wood = makeNode(env, "crimson_wood1", "wood")
		local stone = makeNode(env, "crimson_stone1", "stone")
		h.controller:start()
		env.CollectionService:RemoveTag(wood, TAG)
		expect(h.rec.prompts[wood]).toBeNil()
		expect(h.rec.arrived[wood]).toBeNil() -- its part watch is disconnected too
		expect(h.controller:promptCount()).toBe(1)
		expect(h.rec.prompts[stone]).toBeTruthy()
		h.controller:destroy()
		expect(count(h.rec.prompts)).toBe(0)
		expect(h.rec.detached).toBe(2)
		-- a node tagged after destroy gets nothing
		makeNode(env, "crimson_food1", "food")
		expect(count(h.rec.prompts)).toBe(0)
	end)

	it("waits for a streamed-in part, and re-attaches after the part streams out and back", function()
		local h = setup()
		local env = h.env
		local node = makeNode(env, "crimson_wood2", "wood", { empty = true })
		h.controller:start()
		expect(h.controller:promptCount()).toBe(0)
		local trunk = env.newInstance("Part")
		trunk.Name = "Trunk"
		trunk.Parent = node -- no PrimaryPart yet: the first BasePart carries the prompt
		h.rec.arrived[node]()
		expect(h.rec.prompts[node].part).toBe(trunk)
		-- streamed out
		trunk.Parent = nil
		h.rec.prompts[node].lost()
		expect(h.controller:promptCount()).toBe(0)
		-- and back
		trunk.Parent = node
		h.rec.arrived[node]()
		expect(h.rec.prompts[node].part).toBe(trunk)
		expect(h.controller:promptCount()).toBe(1)
	end)

	it("reaches no further than the server's range check: range + node footprint, on X/Z", function()
		for kind, def in JobsConfig.nodes do
			local reach = Def.activationDistance(def.resource)
			expect(reach).toBe(RulerGather.CONFIG.range + def.footprint - Def.MARGIN) -- one kind per resource
			expect(reach < RulerGather.CONFIG.range + def.footprint).toBe(true)
			expect(reach > 0).toBe(true)
			expect(Layout.NODE_KIND[def.resource]).toBe(kind)
		end
	end)
end)

describe("InteractionController: gathering (G4.1 gathered, G8 Kingdom.Gather)", function()
	it("in explore mode a triggered prompt invokes Kingdom.Gather and fires gathered with the reply", function()
		local h = setup({ input = true })
		local wood = makeNode(h.env, "crimson_wood1", "wood")
		h.input:start()
		h.controller:start()
		expect(h.input.mode).toBe("explore")
		h.rec.prompts[wood].triggered()
		expect(h.calls).toEqual({ { "Kingdom.Gather", "crimson_wood1" } })
		expect(h.gathered).toEqual({ { "crimson_wood1", "wood", 2 } })
		expect(h.controller.lastRefusal).toBeNil()
	end)

	it("without an InputModeController it gathers too", function()
		local h = setup()
		local stone = makeNode(h.env, "crimson_stone1", "stone")
		h.controller:start()
		h.replies = { { true, "stone", 1 } }
		h.rec.prompts[stone].triggered()
		expect(h.gathered).toEqual({ { "crimson_stone1", "stone", 1 } })
	end)

	it("a refusal fires nothing and keeps the code; a dropped call is 'dropped'", function()
		local h = setup()
		local wood = makeNode(h.env, "crimson_wood1", "wood")
		h.controller:start()
		h.replies = { { false, "too_far" }, { n = 1 }, { true, "wood", 2 } }
		h.rec.prompts[wood].triggered()
		expect(h.controller.lastRefusal).toBe("too_far")
		h.env.mock:advance(AFTER_COOLDOWN)
		h.rec.prompts[wood].triggered()
		expect(h.controller.lastRefusal).toBe("dropped")
		expect(h.gathered).toEqual({})
		h.env.mock:advance(AFTER_COOLDOWN)
		h.rec.prompts[wood].triggered()
		expect(h.gathered).toEqual({ { "crimson_wood1", "wood", 2 } })
		expect(h.controller.lastRefusal).toBeNil()
		expect(#h.calls).toBe(3)
	end)

	it("in build mode sends nothing and disables the prompts; back in explore they work again", function()
		local h = setup({ input = true })
		local wood = makeNode(h.env, "crimson_wood1", "wood")
		h.input:start()
		h.controller:start()
		expect(h.rec.prompts[wood].enabled).toBe(true)
		expect(h.input:set("build")).toBe(true)
		expect(h.rec.prompts[wood].enabled).toBe(false)
		local later = makeNode(h.env, "crimson_wood2", "wood") -- tagged while building: disabled too
		expect(h.rec.prompts[later].enabled).toBe(false)
		h.rec.prompts[wood].triggered()
		expect({ h.controller:gather("crimson_wood1") }).toEqual({ false, "not_explore" })
		expect(h.calls).toEqual({})
		expect(h.gathered).toEqual({})
		h.input:set("explore")
		expect(h.rec.prompts[wood].enabled).toBe(true)
		expect(h.rec.prompts[later].enabled).toBe(true)
		h.rec.prompts[later].triggered()
		expect(h.calls).toEqual({ { "Kingdom.Gather", "crimson_wood2" } })
	end)

	it("sends at most one request per RulerGather cooldown and one at a time", function()
		local h = setup()
		local wood = makeNode(h.env, "crimson_wood1", "wood")
		h.controller:start()
		local prompt = h.rec.prompts[wood]
		prompt.triggered()
		expect({ h.controller:gather("crimson_wood1") }).toEqual({ false, "cooldown" })
		h.env.mock:advance(Def.COOLDOWN - 0.05)
		prompt.triggered()
		expect(#h.calls).toBe(1)
		h.env.mock:advance(0.1)
		prompt.triggered()
		expect(#h.calls).toBe(2)
		expect(Def.COOLDOWN).toBe(RulerGather.CONFIG.cooldown)
		-- a slow reply: nothing else is sent while it is in flight, even after the cooldown
		h.delay = 2
		h.env.mock:advance(AFTER_COOLDOWN)
		prompt.triggered()
		expect(#h.calls).toBe(3)
		h.env.mock:advance(1)
		expect({ h.controller:gather("crimson_wood1") }).toEqual({ false, "pending" })
		expect(#h.gathered).toBe(2)
		h.env.mock:advance(1.1)
		expect(#h.gathered).toBe(3)
		prompt.triggered()
		expect(#h.calls).toBe(4)
	end)

	it("fires nothing for a reply that arrives after destroy()", function()
		local h = setup()
		local wood = makeNode(h.env, "crimson_wood1", "wood")
		h.controller:start()
		h.delay = 1
		h.rec.prompts[wood].triggered()
		h.controller:destroy()
		h.env.mock:advance(2)
		expect(h.gathered).toEqual({})
		expect({ h.controller:gather("crimson_wood1") }).toEqual({ false, "stopped" })
	end)

	it("boots and does nothing without CollectionService (headless engines)", function()
		local env =
			MockEnv.new({ seed = 4, services = { CollectionService = MockServices.unmocked("CollectionService") } })
		local controller = Def.new(env, {
			find = function()
				return nil
			end,
		})
		controller:start()
		expect(controller:promptCount()).toBe(0)
		expect(env.mock:hasLog("warn", "InteractionController: cannot follow ResourceNode tags")).toBe(true)
		env.mock:advance(5)
		expect(env.mock.threadErrors).toEqual({})
		controller:destroy()
	end)
end)

-- --------------------------------------------------------------------------- end to end

-- The world as WorldService builds it (terrain calls recorded), in `env`.
local function worldServiceDef()
	return {
		name = "WorldService",
		new = function(e, r)
			local service = WorldServiceDef.new(e, r)
			service.terrain = Terrain.recorder()
			return service
		end,
	}
end

local function remote(env, name)
	local area, action = string.match(name, "^(%w+)%.(%w+)$")
	return env.ReplicatedStorage.ForgeRemotes:FindFirstChild(area):FindFirstChild(action)
end

local function invokeAs(env, player, name, ...)
	local args = table.pack(...)
	local results
	env.mock.remotes:asClient(player, function()
		results = table.pack(remote(env, name):InvokeServer(table.unpack(args, 1, args.n)))
	end)
	return table.unpack(results, 1, results.n)
end

local function taggedById(env): { [string]: any }
	local out = {}
	for _, model in env.CollectionService:GetTagged(TAG) do
		out[model:GetAttribute("NodeId")] = model
	end
	return out
end

describe("World resource nodes end to end (FL-0051 ruler gathering)", function()
	it("every node WorldService tags gets a prompt, and every NodeId is a simulation node at that spot", function()
		local env = MockEnv.new({ seed = 6 })
		local registry = Loader.load(env, { worldServiceDef() })
		table.insert(cleanup, function()
			registry:destroy()
		end)
		env.mock:advance(30)
		expect(registry:get("WorldService"):isReady()).toBe(true)
		local controller = Def.new(env, {
			find = function()
				return nil
			end,
		})
		local rec = recorder(env)
		controller.adapter = rec.adapter
		controller:start()
		table.insert(cleanup, function()
			controller:destroy()
		end)
		local models = taggedById(env)
		expect(count(models)).toBe(#Layout.WORLD.resourceNodes)
		expect(controller:promptCount()).toBe(#Layout.WORLD.resourceNodes)
		local match = Match.new({ random = Random.new(9), mode = "slice" })
		local sim = match.sim
		for id, model in models do
			local node = sim.nodes[id]
			if node == nil then
				error(`tagged node {id} is not a simulation node: Kingdom.Gather would refuse it`)
			end
			expect(node.resource).toBe(model:GetAttribute("Resource"))
			local p = rec.prompts[model].part.CFrame.Position
			expect(math.abs(p.X - node.x) < 1e-3 and math.abs(p.Z - node.z) < 1e-3).toBe(true)
			expect(rec.prompts[model].props.MaxActivationDistance < RulerGather.CONFIG.range + node.footprint).toBe(
				true
			)
		end
	end)

	it("a ruler next to crimson_wood1 gathers it: treasury +2, ResourceGathered (ruler)", function()
		local savedMode = MatchConfig.mode
		MatchConfig.mode = "slice"
		local env = MockEnv.new({
			seed = 5,
			sharedModules = {
				Remotes = {
					Kingdom = KingdomRemotes,
					Match = MatchRemotes,
					Treasury = TreasuryRemotes,
					Experience = ExperienceRemotes,
				},
			},
		})
		local registry = Loader.load(env, {
			RemoteServiceDef,
			worldServiceDef(),
			MatchServiceDef,
			KingdomServiceDef,
			AnalyticsServiceDef,
			SettingsServiceDef,
			OnboardingServiceDef,
		})
		table.insert(cleanup, function()
			registry:destroy()
			MatchConfig.mode = savedMode
			for _, entry in env.mock.logs do
				if entry.level == "error" then
					error(`server logged an error: {entry.message}`)
				end
			end
			expect(env.mock.threadErrors).toEqual({})
		end)
		-- KingdomService loads characters through its adapter; Lune has none, so a minimal stand-in
		local kingdoms = registry:get("KingdomService")
		kingdoms.adapter = {
			partyOf = function()
				return nil
			end,
			load = function(player)
				local character = env.newInstance("Model")
				character.Name = player.Name
				local root = env.newInstance("Part")
				root.Name = "HumanoidRootPart"
				root.Parent = character
				character.Parent = env.Workspace
				player.Character = character
				return character
			end,
			pivot = function(character, cframe)
				character.HumanoidRootPart.CFrame = cframe
			end,
			attach = function(character, accessory)
				accessory.Parent = character
			end,
			onDied = function()
				return { Disconnect = function() end }
			end,
			respawnDelay = function()
				return 5
			end,
		}
		local events = {}
		GameEvents.ResourceGathered:connect(function(player, kingdomId, resource, amount, source)
			table.insert(events, { player and player.UserId or false, kingdomId, resource, amount, source })
		end)
		local p1 = env.mock.players:add({ userId = 1 })
		env.mock:advance(30) -- the world builds, then the ruler spawns at the plot
		expect(kingdoms:getKingdomOf(p1)).toBe("crimson")
		expect(p1.Character).toBeTruthy()

		-- the client: the prompt on WorldService's crimson_wood1 model, the real remote as the ruler
		local controller = Def.new(env, {
			find = function()
				return nil
			end,
		})
		local rec = recorder(env)
		controller.adapter = rec.adapter
		controller.remotes = {
			invoke = function(_, name, ...)
				return invokeAs(env, p1, name, ...)
			end,
		}
		local gathered = {}
		controller.gathered:connect(function(nodeId, resource, amount)
			table.insert(gathered, { nodeId, resource, amount })
		end)
		controller:start()
		table.insert(cleanup, function()
			controller:destroy()
		end)
		local model = taggedById(env).crimson_wood1
		local prompt = rec.prompts[model]
		expect(prompt).toBeTruthy()

		-- from the keep door: too far, the server refuses
		prompt.triggered()
		expect(controller.lastRefusal).toBe("too_far")
		expect(gathered).toEqual({})

		-- walk up to the tree (the server reads the HumanoidRootPart)
		local sim = registry:get("MatchService").host.match.sim
		local node = sim.nodes.crimson_wood1
		p1.Character.HumanoidRootPart.CFrame = CFrame.new(node.x + 5, 3, node.z)
		env.mock:advance(AFTER_COOLDOWN)
		local before = sim:balance("crimson", "wood")
		local amountBefore = node.amount
		prompt.triggered()
		expect(gathered).toEqual({ { "crimson_wood1", "wood", RulerGather.CONFIG.amounts.wood } })
		expect(controller.lastRefusal).toBeNil()
		expect(sim:balance("crimson", "wood") - before).toBe(RulerGather.CONFIG.amounts.wood)
		expect(amountBefore - node.amount).toBe(RulerGather.CONFIG.amounts.wood)

		env.mock:advance(MatchConfig.tickSeconds * 2) -- the host fans the sim event out on its tick
		local mine = {}
		for _, e in events do
			if e[5] == "ruler" then
				table.insert(mine, e)
			end
		end
		expect(mine).toEqual({ { 1, "crimson", "wood", RulerGather.CONFIG.amounts.wood, "ruler" } })
	end)
end)
