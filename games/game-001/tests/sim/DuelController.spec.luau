--[[
	DuelController (FL-0071; CONTRACTS G12.4, G12.6): the client's one door to the Crown Arena. It relays Arena.State and
	Arena.Events (batches unpacked, in order), answers getState / isChampion, and is the only sender of Arena.Action,
	which it sends only for a champion in the duel stage and within the server's own rate.
]]

local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect, afterEach = T.describe, T.it, T.expect, T.afterEach

local MockEnv = require("../../../../roblox/tests/mocks/MockEnv")
local Loader = require("@game/ReplicatedStorage/Forge/Contracts/Loader")
local DuelDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/DuelController")
local ArenaRemotes = require("@game/ReplicatedStorage/Game/Arena/Remotes")

local ME = 8101
local RIVAL = 8102

local booted = {}

afterEach(function()
	for _, b in booted do
		b.registry:destroy()
	end
	table.clear(booted)
end)

local function duellist(userId: number, isAI: boolean?)
	return {
		userId = userId,
		kingdom = `k{userId}`,
		isAI = isAI == true,
		tier = "loyal",
		score = 60,
		triggers = {},
		reasons = {},
	}
end

local function arenaState(stage: string, a: any?, b: any?)
	return { stage = stage, a = a or duellist(ME), b = b or duellist(RIVAL) }
end

-- the server's end of the Arena remotes, created before the controller starts
local function boot(opts: any?)
	opts = opts or {}
	local env = MockEnv.new({ seed = 81, isServer = false, localPlayer = { userId = opts.userId or ME } })
	local remotes = {}
	if opts.remotes ~= false then
		local root = env.newInstance("Folder")
		root.Name = "ForgeRemotes"
		root.Parent = env.ReplicatedStorage
		local area = env.newInstance("Folder")
		area.Name = "Arena"
		area.Parent = root
		for _, name in { "State", "Events", "Action" } do
			local remote = env.newInstance("RemoteEvent")
			remote.Name = name
			remote.Parent = area
			remotes[name] = remote
		end
		local getState = env.newInstance("RemoteFunction")
		getState.Name = "GetState"
		getState.Parent = area
		getState.OnServerInvoke = function()
			return opts.initial
		end
		remotes.GetState = getState
	end
	local sent = {}
	if remotes.Action then
		remotes.Action.OnServerEvent:Connect(function(_player: any, action: string)
			table.insert(sent, action)
		end)
	end
	local registry = Loader.load(env, { DuelDef })
	table.insert(booted, { registry = registry })
	env.mock:advance(0.5)
	return {
		env = env,
		registry = registry,
		controller = registry:get("DuelController"),
		remotes = remotes,
		sent = sent,
	}
end

local function push(world: any, state: any)
	world.remotes.State:FireAllClients(state)
	world.env.mock:advance(0.1)
end

describe("DuelController: the feed", function()
	it("keeps the latest Arena.State and announces each one", function()
		local world = boot()
		local seen = {}
		world.controller.stateChanged:connect(function(state)
			table.insert(seen, state.stage)
		end)
		expect(world.controller:getState()).toBeNil()
		push(world, arenaState("loadout"))
		push(world, arenaState("duel"))
		expect(world.controller:getState().stage).toBe("duel")
		expect(seen).toEqual({ "loadout", "duel" })
		push(world, "junk")
		push(world, { stage = 5 })
		expect(world.controller:getState().stage).toBe("duel") -- not a state: ignored
	end)

	it("asks Arena.GetState once at the start", function()
		local world = boot({ initial = arenaState("intro") })
		expect(world.controller:getState().stage).toBe("intro")
	end)

	it("unpacks Arena.Events batches into single events, in order, and drops junk entries", function()
		local world = boot()
		local seen = {}
		world.controller.events:connect(function(event)
			table.insert(seen, `{event.kind}:{event.side}`)
		end)
		world.remotes.Events:FireAllClients({
			{ t = 1, kind = "hit", side = "a", data = { damageShare = 0.1, hpShare = 0.9, heavy = false } },
			"junk",
			{ t = 1.1, kind = "parry", side = "b" },
			{ t = 1.2 },
		})
		world.env.mock:advance(0.1)
		world.remotes.Events:FireAllClients("not a batch")
		world.env.mock:advance(0.1)
		expect(seen).toEqual({ "hit:a", "parry:b" })
	end)
end)

describe("DuelController: act", function()
	it("sends the action for a champion in the duel stage", function()
		local world = boot()
		push(world, arenaState("duel"))
		expect(world.controller:isChampion()).toBe(true)
		expect(world.controller:act("light")).toBe(true)
		expect(world.controller:act("block")).toBe(true)
		world.env.mock:advance(0.1)
		expect(world.sent).toEqual({ "light", "block" })
	end)

	it("sends all six actions, and the same six the server's Arena.Action accepts", function()
		local world = boot()
		push(world, arenaState("duel"))
		for _, action in { "light", "heavy", "block", "blockEnd", "parry", "dodge" } do
			expect(world.controller:act(action)).toBe(true)
		end
		world.env.mock:advance(0.1)
		expect(world.sent).toEqual({ "light", "heavy", "block", "blockEnd", "parry", "dodge" })
		local count = 0
		for _ in world.controller.ACTIONS do
			count += 1
		end
		expect(count).toBe(6)
		local row
		for _, remote in ArenaRemotes do
			if remote.name == "Arena.Action" then
				row = remote
			end
		end
		assert(row, "the Arena.Action remote")
		for _, action in { "light", "heavy", "block", "blockEnd", "parry", "dodge" } do
			expect((row.args[1](action))).toBe(true) -- the server's own check takes each of the six
		end
		expect((row.args[1]("taunt"))).toBe(false)
	end)

	it("lets the second champion (side b) act too", function()
		local world = boot()
		push(world, arenaState("duel", duellist(RIVAL), duellist(ME)))
		expect(world.controller:isChampion()).toBe(true)
		expect(world.controller:act("heavy")).toBe(true)
		world.env.mock:advance(0.1)
		expect(world.sent).toEqual({ "heavy" })
	end)

	it("mirrors the server's rate row for Arena.Action: burst 8, 12 a second", function()
		local row
		for _, remote in ArenaRemotes do
			if remote.name == "Arena.Action" then
				row = remote
			end
		end
		assert(row, "the Arena.Action remote")
		expect(row.rate.burst).toBe(8)
		expect(row.rate.perSecond).toBe(12)
		local world = boot()
		expect(world.controller.BURST).toBe(row.rate.burst)
		expect(world.controller.PER_SECOND).toBe(row.rate.perSecond)
	end)

	it("sends nothing from a spectator, an AI's seat, another stage, or before any state", function()
		local spectator = boot({ userId = 9999 })
		push(spectator, arenaState("duel"))
		expect(spectator.controller:isChampion()).toBe(false)
		expect(spectator.controller:act("light")).toBe(false)
		local ai = boot()
		push(ai, arenaState("duel", duellist(ME, true), duellist(RIVAL)))
		expect(ai.controller:isChampion()).toBe(false)
		expect(ai.controller:act("light")).toBe(false)
		local early = boot()
		expect(early.controller:act("light")).toBe(false)
		push(early, arenaState("intro"))
		expect(early.controller:act("light")).toBe(false)
		push(early, arenaState("crowning"))
		expect(early.controller:act("light")).toBe(false)
		for _, world in { spectator, ai, early } do
			world.env.mock:advance(0.2)
			expect(world.sent).toEqual({})
		end
	end)

	it("refuses an action that is not a DuelAction", function()
		local world = boot()
		push(world, arenaState("duel"))
		expect(world.controller:act("fireball")).toBe(false)
		expect(world.controller:act(5 :: any)).toBe(false)
		expect(world.controller:act(nil :: any)).toBe(false)
		world.env.mock:advance(0.2)
		expect(world.sent).toEqual({})
	end)

	it("keeps to the server's rate: a burst of 8, then one more per 1/12 s", function()
		local world = boot()
		push(world, arenaState("duel"))
		local sentNow = 0
		for _ = 1, 12 do
			if world.controller:act("light") then
				sentNow += 1
			end
		end
		expect(sentNow).toBe(world.controller.BURST)
		world.env.mock:advance(1 / 6) -- two tokens
		expect(world.controller:act("light")).toBe(true)
		expect(world.controller:act("light")).toBe(true)
		expect(world.controller:act("light")).toBe(false)
		world.env.mock:advance(0.5)
		expect(#world.sent).toBe(world.controller.BURST + 2)
	end)

	it("starts a new duel with a full bucket", function()
		local world = boot()
		push(world, arenaState("duel"))
		for _ = 1, 8 do
			world.controller:act("light")
		end
		expect(world.controller:act("light")).toBe(false)
		push(world, arenaState("crowning"))
		push(world, arenaState("duel"))
		expect(world.controller:act("light")).toBe(true)
	end)

	it("stays inert without the Arena remotes: nothing sent, nothing thrown", function()
		local world = boot({ remotes = false })
		expect(world.controller:getState()).toBeNil()
		expect(world.controller:act("light")).toBe(false)
		world.env.mock:advance(1)
		expect(world.env.mock.threadErrors).toEqual({})
	end)

	it("stops relaying and sending after destroy", function()
		local world = boot()
		push(world, arenaState("duel"))
		local count = 0
		world.controller.events:connect(function()
			count += 1
		end)
		world.controller:destroy()
		world.remotes.Events:FireAllClients({ { t = 1, kind = "hit", side = "a" } })
		world.env.mock:advance(0.1)
		expect(count).toBe(0)
		expect(world.controller:act("light")).toBe(false)
	end)
end)
