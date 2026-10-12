--[[
	The first playable milestone, end to end on the server path a real client uses:
	MockEnv players -> RemoteService (validation, rate limits) -> MatchHost -> Match/Simulation ->
	WorldView parts + snapshots back to clients.

	1. A player spawns as a ruler in a small kingdom with about ten citizens.
	2. A farmer produces food; a worker gathers resources; the balance updates correctly.
	3. The player orders a building; the resources are consumed and the change appears in the world.
	4. Another player joins through the multiplayer path without corrupting kingdom state.
]]

local T = require("../../../harness/Test")
local describe, it, expect, afterEach = T.describe, T.it, T.expect, T.afterEach

local MockEnv = require("../../../mocks/MockEnv")
local GameEvents = require("@game/ReplicatedStorage/Forge/Contracts/GameEvents")
local GameplayRemotes = require("@game/ReplicatedStorage/Forge/Gameplay/Remotes")
local MatchHost = require("@game/ReplicatedStorage/Forge/Gameplay/Kingdom/MatchHost")
local Snapshot = require("@game/ReplicatedStorage/Forge/Gameplay/Kingdom/Snapshot")
local RemoteServiceDef = require("@game/ServerScriptService/Forge/Services/RemoteService")

local function setup(matchOptions)
	local env = MockEnv.new({ seed = 3, sharedModules = { Remotes = { Gameplay = GameplayRemotes } } })
	local remotes = RemoteServiceDef.new(env, {})
	local options = { countdownSec = 3 }
	for k, v in matchOptions or {} do
		options[k] = v
	end
	local host = MatchHost.new(env, remotes, { seed = 7, match = options })
	host:start()
	return env, remotes, host
end

local function invoke(env, player, name, ...)
	local args = table.pack(...)
	local results
	env.mock.remotes:asClient(player, function()
		local area, action = string.match(name, "^(%w+)%.(%w+)$")
		local remote = env.ReplicatedStorage.ForgeRemotes[area][action]
		results = table.pack(remote:InvokeServer(table.unpack(args, 1, args.n)))
	end)
	return table.unpack(results, 1, results.n)
end

local function sentTo(env, name, player)
	local out = {}
	for _, entry in env.mock.remotes:sent(name) do
		if entry.direction == "toAllClients" or entry.player == player then
			table.insert(out, entry.args)
		end
	end
	return out
end

local function collect(host)
	local events = { list = {}, counts = {} }
	host.events:connect(function(name, event)
		table.insert(events.list, event)
		events.counts[name] = (events.counts[name] or 0) + 1
	end)
	return events
end

-- kingdom snapshots without the ruler list, for "nothing else changed" comparisons
local function worldState(sim)
	local out = {}
	for _, kid in sim.kingdomOrder do
		local snap = Snapshot.kingdom(sim, kid, 0)
		snap.kingdom.rulers = nil
		snap.kingdom.score = nil
		out[kid] = snap
	end
	return out
end

afterEach(function()
	GameEvents.disconnectAll()
end)

describe("AI Kingdoms first playable", function()
	it("plays the milestone sequence over remotes", function()
		local env, _, host = setup()
		local events = collect(host)
		local p1 = env.mock.players:add({ userId = 101, name = "Ruler1" })

		-- 1. joined as a ruler, on the kingdom's team, match counting down then active
		local kid = host:kingdomOf(p1)
		expect(kid).toBe("crimson")
		expect(p1.Team).toBeTruthy()
		expect(p1.Team:GetAttribute("KingdomId")).toBe("crimson")
		expect(host.match.state).toBe("Lobby")
		env.mock:advance(0.5)
		expect(host.match.state).toBe("Countdown")
		env.mock:advance(3.5)
		expect(host.match.state).toBe("Active")
		local roundStates = sentTo(env, "RoundState", p1)
		expect(roundStates[#roundStates][1]).toBe("Active")
		expect(roundStates[#roundStates][4]).toBe(4) -- four kingdoms standing

		local sim = host.match.sim
		local k = sim.kingdoms[kid]
		expect(#k.citizenIds).toBe(10)
		expect(k.rulers).toEqual({ 101 })
		local view = host._view
		for _, cid in k.citizenIds do
			expect(view:find(cid)).toBeTruthy()
		end
		local state = invoke(env, p1, "Gameplay.GetKingdomState")
		expect(state.kingdomId).toBe("crimson")
		expect(#state.kingdom.citizens).toBe(10)
		expect(state.round.state).toBe("Active")

		-- 2. farmers and workers fill the stockpile; the ledger matches every delivery
		env.mock:advance(60)
		local delivered = { food = 0, wood = 0, stone = 0, gold = 0 }
		for _, e in events.list do
			if e.name == "ResourceGathered" and e.kingdomId == kid then
				delivered[e.resource] += e.amount
			end
		end
		expect(delivered.food).toBeGreaterThan(0)
		expect(delivered.wood).toBeGreaterThan(0)
		expect(delivered.stone).toBeGreaterThan(0)
		local flows = F.stock(sim, k):flows()
		for res, amount in delivered do
			expect((flows.income.gathered or {})[res] or 0).toBe(amount)
		end
		expect(sim.treasury:audit(k.id)).toBe(true)
		local snapshots = sentTo(env, "KingdomSnapshot", p1)
		expect(#snapshots).toBeGreaterThan(100) -- about two per second
		local latest = snapshots[#snapshots][1]
		expect(latest.kingdom.resources).toEqual(sim.treasury:get(k.id))

		-- 3. order a House: exact cost, a site appears, builders finish it, the world shows it
		local before = sim.treasury:get(k.id)
		local keep = sim.buildings[k.keepId]
		local ok, err, result = invoke(env, p1, "Gameplay.PlaceBuilding", "house", keep.x, keep.z)
		expect(ok).toBe(false)
		expect(err).toBe("blocked") -- on the keep: rejected, nothing spent
		ok, err = invoke(env, p1, "Gameplay.PlaceBuilding", "house", 0, 0)
		expect(err).toBe("out_of_territory") -- the map centre is no one's land
		expect(sim.treasury:get(k.id)).toEqual(before)
		local hx, hz = keep.x + 30, keep.z + 30
		ok, err, result = invoke(env, p1, "Gameplay.PlaceBuilding", "house", hx, hz)
		expect(err).toBeNil()
		expect(ok).toBe(true)
		local after = sim.treasury:get(k.id)
		expect(after.wood).toBe(before.wood - 40)
		expect(after.food).toBe(before.food)
		local houseId = result.buildingId
		-- the ruler gets an immediate snapshot with the site
		local fresh = sentTo(env, "KingdomSnapshot", p1)
		local site
		for _, b in fresh[#fresh][1].buildings do
			if b.id == houseId then
				site = b
			end
		end
		expect(site).toBeTruthy()
		expect(site.level).toBe(0)
		env.mock:advance(0.25)
		local part = view:find(houseId)
		expect(part).toBeTruthy()
		expect(part:GetAttribute("Level")).toBe(0)
		expect(part.Transparency).toBeNear(0.55, 1e-6) -- float32 property
		env.mock:advance(70)
		expect(sim.buildings[houseId].level).toBe(1)
		expect(part:GetAttribute("Level")).toBe(1)
		expect(part.Transparency).toBe(0)
		expect(math.abs(part.CFrame.Position.X - hx) < 0.01).toBe(true)
		expect(k.popCap).toBe(14)
		local notices = sentTo(env, "KingdomEvent", p1)
		local completed = false
		for _, args in notices do
			if args[1].name == "BuildingCompleted" and args[1].buildingId == houseId then
				completed = true
			end
		end
		expect(completed).toBe(true)

		-- 4. a second player joins: assigned to another kingdom, nothing else changes
		local beforeJoin = worldState(sim)
		local p2 = env.mock.players:add({ userId = 202, name = "Ruler2" })
		local kid2 = host:kingdomOf(p2)
		expect(kid2).toBe("azure")
		expect(worldState(sim)).toEqual(beforeJoin)
		expect(sim.kingdoms.azure.rulers).toEqual({ 202 })
		expect(k.rulers).toEqual({ 101 })
		local state2 = invoke(env, p2, "Gameplay.GetKingdomState")
		expect(state2.kingdomId).toBe("azure")
		expect(state2.round.state).toBe("Active") -- mid-match joiner learns the round
		-- the newcomer cannot command someone else's kingdom
		ok, err = invoke(env, p2, "Gameplay.UpgradeBuilding", houseId)
		expect(ok).toBe(false)
		expect(err).toBe("not_owner")
		env.mock:advance(30)
		for _, kingdomId in sim.kingdomOrder do
			expect(F.stock(sim, sim.kingdoms[kingdomId]):audit()).toBe(true)
		end
		expect(env.mock:hasLog("error", "tick failed")).toBe(false)
		expect(events.counts.MatchStateChanged).toBe(2)
	end)

	it("lets two rulers share one kingdom and keeps the ledger exact under both", function()
		local env, _, host = setup({ maxRulersPerKingdom = 4 })
		local p1 = env.mock.players:add({ userId = 1 })
		local p2 = env.mock.players:add({ userId = 2 })
		expect(host:kingdomOf(p2)).toBe("azure")
		env.mock:advance(1)
		local ok, err = invoke(env, p2, "Gameplay.ChooseKingdom", "crimson")
		expect(err).toBeNil()
		expect(ok).toBe(true)
		expect(host:kingdomOf(p2)).toBe("crimson")
		expect(p2.Team).toBe(p1.Team)
		env.mock:advance(4)
		expect(host.match.state).toBe("Active")
		ok, err = invoke(env, p2, "Gameplay.ChooseKingdom", "emerald")
		expect(ok).toBe(false)
		expect(err).toBe("too_late")

		local sim = host.match.sim
		local k = sim.kingdoms.crimson
		local keep = sim.buildings[k.keepId]
		local wood = sim:balance(k.id, "wood")
		expect(invoke(env, p1, "Gameplay.PlaceBuilding", "house", keep.x + 30, keep.z + 30)).toBe(true)
		expect(invoke(env, p2, "Gameplay.PlaceBuilding", "farm", keep.x - 35, keep.z + 25)).toBe(true)
		expect(sim:balance(k.id, "wood")).toBe(wood - 40 - 50)
		local placed = {}
		for _, e in sim:drainEvents() do
			if e.name == "BuildingPlaced" then
				placed[e.by] = e.kind
			end
		end
		expect(placed).toEqual({ [1] = "house", [2] = "farm" })
		expect(sim.treasury:audit(k.id)).toBe(true)
	end)

	it("drops malformed or flooding calls before they reach the kingdom", function()
		local env, remotes, host = setup()
		local p1 = env.mock.players:add({ userId = 1 })
		env.mock:advance(4)
		local k = host.match.sim.kingdoms.crimson
		local before = sim.treasury:get(k.id)
		expect(invoke(env, p1, "Gameplay.PlaceBuilding", "house", 0 / 0, 5)).toBeNil()
		expect(invoke(env, p1, "Gameplay.PlaceBuilding", "house", math.huge, 5)).toBeNil()
		expect(invoke(env, p1, "Gameplay.PlaceBuilding", "keep", 30, 30)).toBeNil()
		expect(invoke(env, p1, "Gameplay.PlaceBuilding", "house", 30, 30, "extra")).toBeNil()
		expect(invoke(env, p1, "Gameplay.SetPriority", "wood", 7)).toBeNil()
		expect(invoke(env, p1, "Gameplay.SetAlarm", "yes")).toBeNil()
		expect(sim.treasury:get(k.id)).toEqual(before)
		local stats = remotes:stats()
		expect(stats.dropped.invalidArgs).toBe(5)
		expect(stats.dropped.extraArgs).toBe(1)
		-- burst then rate limit (SetAlarm: burst 3)
		local accepted = 0
		for _ = 1, 6 do
			if invoke(env, p1, "Gameplay.SetAlarm", false) then
				accepted += 1
			end
		end
		expect(accepted).toBe(2) -- one token went to the rejected "yes" call above
		expect(remotes:stats().dropped.rateLimited).toBe(4)
	end)

	it("fills four kingdoms with four rulers each; the seventeenth player spectates", function()
		local env, _, host = setup()
		local perKingdom = {}
		for i = 1, 16 do
			local p = env.mock.players:add({ userId = i })
			local kid = host:kingdomOf(p)
			perKingdom[kid] = (perKingdom[kid] or 0) + 1
		end
		expect(perKingdom).toEqual({ crimson = 4, azure = 4, emerald = 4, gold = 4 })
		local extra = env.mock.players:add({ userId = 17 })
		expect(host:kingdomOf(extra)).toBeNil()
		expect(extra.Team).toBeNil()
		env.mock:advance(4)
		local ok, err = invoke(env, extra, "Gameplay.SetAlarm", true)
		expect(ok).toBe(false)
		expect(err).toBe("not_in_match")
		-- a ruler leaves: the seat frees up and the kingdom keeps running
		env.mock.players:remove(env.Players:GetPlayerByUserId(1))
		expect(#host.match.sim.kingdoms.crimson.rulers).toBe(3)
	end)

	it("ends the match, reports the result once, and starts a fresh world for everyone", function()
		local env, _, host = setup({ durationSec = 60, resultsSec = 20 })
		local ended = {}
		GameEvents.RoundEnded:connect(function(result)
			table.insert(ended, result)
		end)
		local states = {}
		GameEvents.RoundStateChanged:connect(function(state)
			table.insert(states, state)
		end)
		local p1 = env.mock.players:add({ userId = 5 })
		env.mock:advance(70)
		expect(host.match.state).toBe("Results")
		expect(#ended).toBe(1)
		expect(ended[1].mode).toBe("kingdoms")
		expect(ended[1].roundId).toBe("km-1")
		expect(#ended[1].participants).toBe(1)
		expect(ended[1].participants[1].userId).toBe(5)
		local results = sentTo(env, "RoundResult", p1)
		expect(#results).toBe(1)
		local firstTeam = p1.Team
		env.mock:advance(15)
		expect(host.match.state).toBe("Countdown")
		expect(host.match.roundId).toBe("km-2")
		expect(host:kingdomOf(p1)).toBe("crimson")
		expect(p1.Team).toBeTruthy()
		expect(rawequal(p1.Team, firstTeam)).toBe(false) -- teams were rebuilt with the new world
		expect(table.find(env.Teams:GetChildren(), firstTeam)).toBeNil()
		expect(#env.Teams:GetChildren()).toBe(4)
		expect(states).toEqual({ "Countdown", "Active", "Results", "Lobby", "Countdown" })
		expect(#ended).toBe(1)
	end)
end)
