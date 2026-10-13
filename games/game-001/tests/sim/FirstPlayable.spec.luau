--[[
	The first playable milestone, end to end on the server path a real client uses:
	MockEnv players -> RemoteService (validation, rate limits) -> MatchHost -> Match/Simulation ->
	treasury (G7 double) -> WorldView parts, the G8 Kingdom/Match remotes and G9 GameEvents.
	Building orders go through host:command, the server path the Build area remotes (FL-0051) call.
	The match runs in the VS-1 slice mode (CONTRACTS G3) unless a test asks for the full match.

	1. A player spawns as a ruler in a small kingdom with twelve citizens (VS-1 rows 3-4).
	2. Farmers produce food; workers gather; the treasury ledger matches every delivery (row 4).
	3. The ruler harvests a node by hand (row 5).
	4. The ruler orders a building; it is paid, raised by builders and appears in the world (row 6).
	5. A second player joins through the multiplayer path without corrupting kingdom state.
	6. Rulers standing on the neutral watchtower capture it, which ends the slice (row 7, G3/G8).
]]

local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect, afterEach = T.describe, T.it, T.expect, T.afterEach

local MockEnv = require("../../../../roblox/tests/mocks/MockEnv")
local GameEvents = require("@game/ReplicatedStorage/Forge/Contracts/GameEvents")
local KingdomRemotes = require("@game/ReplicatedStorage/Game/Kingdom/Remotes")
local Layout = require("@game/ReplicatedStorage/Game/Kingdom/Layout")
local MatchHost = require("@game/ReplicatedStorage/Game/Kingdom/MatchHost")
local MatchRemotes = require("@game/ReplicatedStorage/Game/Match/Remotes")
local Snapshot = require("@game/ReplicatedStorage/Game/Sim/Snapshot")
local RemoteServiceDef = require("@game/ServerScriptService/Forge/Services/RemoteService")

-- Characters do not exist in Lune: specs place rulers through this table (userId -> { x, z }).
local positions = {}

local function setup(matchOptions)
	table.clear(positions)
	local env = MockEnv.new({
		seed = 3,
		sharedModules = { Remotes = { Kingdom = KingdomRemotes, Match = MatchRemotes } },
	})
	local remotes = RemoteServiceDef.new(env, {})
	local options = { mode = "slice" }
	for k, v in matchOptions or {} do
		options[k] = v
	end
	local host = MatchHost.new(env, remotes, {
		seed = 7,
		match = options,
		positionOf = function(player)
			local p = positions[player.UserId]
			if p then
				return p.x, p.z
			end
			return nil, nil
		end,
	})
	host:start()
	return env, remotes, host
end

local function remote(env, name)
	local area, action = string.match(name, "^(%w+)%.(%w+)$")
	-- FindFirstChild: "Changed" would index the Instance event, not the remote
	return env.ReplicatedStorage.ForgeRemotes:FindFirstChild(area):FindFirstChild(action)
end

local function invoke(env, player, name, ...)
	local args = table.pack(...)
	local results
	env.mock.remotes:asClient(player, function()
		results = table.pack(remote(env, name):InvokeServer(table.unpack(args, 1, args.n)))
	end)
	return table.unpack(results, 1, results.n)
end

-- args of every firing of a server event that reached `player` (FireClient to them, or FireAllClients)
local function sentTo(env, name, player)
	local out = {}
	for _, entry in env.mock.remotes:sent(remote(env, name)) do
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

-- kingdom snapshots without the ruler lists, for "nothing else changed" comparisons
local function worldState(sim, except: string?)
	local out = {}
	for _, kid in sim.kingdomOrder do
		if kid ~= except then
			local snap = Snapshot.kingdom(sim, kid, 0)
			snap.kingdom.rulers = nil
			snap.kingdom.isAI = nil
			out[kid] = snap
		end
	end
	return out
end

-- The first spot around the keep where the kingdom may place `kind` (rings outwards; the sim decides).
local function freeSpot(sim, k, kind)
	local keep = sim.buildings[k.keepId]
	for radius = 30, 140, 10 do
		for step = 0, 23 do
			local a = step / 24 * 2 * math.pi
			local x, z = keep.x + math.cos(a) * radius, keep.z + math.sin(a) * radius
			if sim:canPlace(k, kind, x, z) then
				return x, z
			end
		end
	end
	error(`no free spot for {kind}`)
end

local function viewOf(state, kingdomId)
	for _, view in state.kingdoms do
		if view.id == kingdomId then
			return view
		end
	end
	return nil
end

afterEach(function()
	GameEvents.disconnectAll()
end)

describe("AI Kingdoms first playable", function()
	it("plays the milestone sequence over remotes", function()
		local env, _, host = setup()
		local events = collect(host)
		local p1 = env.mock.players:add({ userId = 101, name = "Ruler1" })

		-- 1. joined as a ruler on the kingdom's team; slice: Founding starts with the first join
		local kid = host:kingdomOf(p1)
		expect(kid).toBe("crimson")
		expect(p1.Team:GetAttribute("KingdomId")).toBe("crimson")
		local arrival = sentTo(env, "Match.State", p1)
		expect(arrival[1][1]).toBe("Lobby")
		env.mock:advance(0.25)
		expect(host.match.state).toBe("Founding")
		local phases = sentTo(env, "Match.State", p1)
		expect(phases[#phases][1]).toBe("Founding")
		expect(phases[#phases][2]).toBeNil() -- untimed in the slice
		expect(type(phases[#phases][3])).toBe("number") -- startedAtServerTime
		expect(host:phaseInfo().aliveCount).toBe(4)

		local sim = host.match.sim
		local k = sim.kingdoms[kid]
		expect(#k.citizenIds).toBe(12)
		expect(#sim.kingdoms.azure.citizenIds).toBe(0) -- no ruler yet: no citizens
		expect(k.rulers).toEqual({ 101 })
		local keepAt = Layout.WORLD.plots.crimson.anchors.keep.Position
		expect(sim.buildings[k.keepId].x).toBeNear(keepAt.X, 1e-6)
		local view = host._view
		for _, cid in k.citizenIds do
			expect(view:find("entity", cid)).toBeTruthy()
		end
		local state = invoke(env, p1, "Kingdom.GetState")
		expect(state.mine).toBe("crimson")
		expect(#state.kingdoms).toBe(4)
		expect(viewOf(state, "crimson").rulers).toEqual({ 101 })
		local phase = invoke(env, p1, "Match.GetState")
		expect(phase).toBe("Founding")

		-- 2. farmers and workers fill the treasury; the ledger matches every delivery
		env.mock:advance(60)
		local delivered = { food = 0, wood = 0, stone = 0, gold = 0 }
		for _, e in events.list do
			if e.name == "ResourceGathered" and e.kingdomId == kid and e.source == "citizen" then
				delivered[e.resource] += e.amount
			end
		end
		expect(delivered.food).toBeGreaterThan(0)
		expect(delivered.wood).toBeGreaterThan(0)
		expect(delivered.stone).toBeGreaterThan(0)
		local ledgerIn = { food = 0, wood = 0, stone = 0, gold = 0 }
		for _, entry in sim.treasury:ledger(kid) do
			if entry.kind == "deposit" and string.sub(entry.source, 1, 8) == "citizen:" then
				for res, amount in entry.bag do
					ledgerIn[res] += amount
				end
			end
		end
		expect(ledgerIn).toEqual(delivered)
		expect(sim.treasury:audit(kid)).toBe(true)

		-- 3. the ruler harvests a tree by hand: range and cooldown are enforced on the server
		local tree
		for _, nid in k.nearNodes do
			local node = sim.nodes[nid]
			if node.resource == "wood" and node.amount >= 10 then
				tree = node
				break
			end
		end
		local woodBefore = sim:balance(kid, "wood")
		expect({ invoke(env, p1, "Kingdom.Gather", tree.id) }).toEqual({ false, "no_character" })
		positions[101] = { x = tree.x + 200, z = tree.z }
		expect({ invoke(env, p1, "Kingdom.Gather", tree.id) }).toEqual({ false, "too_far" })
		positions[101] = { x = tree.x + 4, z = tree.z }
		expect({ invoke(env, p1, "Kingdom.Gather", tree.id) }).toEqual({ true, "wood", 2 })
		expect({ invoke(env, p1, "Kingdom.Gather", tree.id) }).toEqual({ false, "cooldown" })
		expect(sim:balance(kid, "wood") >= woodBefore + 2).toBe(true)

		-- 4. order a House: exact cost, a site appears, builders finish it, the world shows it
		local before = sim.treasury:get(kid)
		local keep = sim.buildings[k.keepId]
		local ok, err, result = host:command(p1, "PlaceBuilding", "house", keep.x, keep.z)
		expect(ok).toBe(false)
		expect(err).toBe("blocked") -- on the keep: rejected, nothing spent
		ok, err = host:command(p1, "PlaceBuilding", "house", 0, 0)
		expect(err).toBe("out_of_territory") -- the map centre is no one's land
		expect(sim.treasury:get(kid)).toEqual(before)
		local hx, hz = keep.x + 30, keep.z + 30
		ok, err, result = host:command(p1, "PlaceBuilding", "house", hx, hz)
		expect(err).toBeNil()
		expect(ok).toBe(true)
		local after = sim.treasury:get(kid)
		expect(after.wood).toBe(before.wood - 40)
		expect(after.food).toBe(before.food)
		local houseId = result.buildingId
		expect(type(houseId)).toBe("number")
		expect(sim:buildingView(houseId).placedBy).toBe(101)
		env.mock:advance(0.25)
		local part = view:find("building", houseId)
		expect(part).toBeTruthy()
		expect(part:GetAttribute("Level")).toBe(0)
		expect(part.Transparency).toBeNear(0.55, 1e-6) -- float32 property
		-- Costs.building("house", 1).buildSeconds builder-seconds; builders also eat and rest
		local waited = 0
		while sim.buildings[houseId].level < 1 and waited < 6 * sim:workFor("house", 1) do
			env.mock:advance(1)
			waited += 1
		end
		expect(sim.buildings[houseId].level).toBe(1)
		expect(part:GetAttribute("Level")).toBe(1)
		expect(part.Transparency).toBe(0)
		expect(math.abs(part.CFrame.Position.X - hx) < 0.01).toBe(true)
		expect(k.popCap).toBe(16)
		local completed = 0
		for _, e in events.list do
			if e.name == "BuildingCompleted" and e.buildingId == houseId then
				completed += 1
			end
		end
		expect(completed).toBe(1)

		-- 5. a second player joins late: seated in another kingdom with its own starting citizens;
		--    no other kingdom changes
		local beforeJoin = worldState(sim, "azure")
		local stateSends = #sentTo(env, "Kingdom.State", p1)
		local p2 = env.mock.players:add({ userId = 202, name = "Ruler2" })
		local kid2 = host:kingdomOf(p2)
		expect(kid2).toBe("azure")
		expect(worldState(sim, "azure")).toEqual(beforeJoin)
		expect(sim.kingdoms.azure.rulers).toEqual({ 202 })
		expect(#sim.kingdoms.azure.citizenIds).toBe(12)
		expect(k.rulers).toEqual({ 101 })
		local state2 = invoke(env, p2, "Kingdom.GetState")
		expect(state2.mine).toBe("azure")
		expect(invoke(env, p2, "Match.GetState")).toBe("Founding") -- a late joiner learns the phase
		env.mock:advance(0.25)
		local pushed = sentTo(env, "Kingdom.State", p1)
		expect(#pushed).toBe(stateSends + 1) -- the first ruler hears about the newcomer
		expect(viewOf(pushed[#pushed][1], "azure").rulers).toEqual({ 202 })
		-- the newcomer cannot command someone else's kingdom
		ok, err = host:command(p2, "UpgradeBuilding", houseId)
		expect(ok).toBe(false)
		expect(err).toBe("not_owner")
		env.mock:advance(30)
		for _, kingdomId in sim.kingdomOrder do
			expect(sim.treasury:audit(kingdomId)).toBe(true)
		end
		expect(env.mock:hasLog("error", "tick failed")).toBe(false)
	end)

	it("captures the neutral watchtower with rulers standing on it, which ends the slice (G3, G8)", function()
		local env, _, host = setup()
		local p1 = env.mock.players:add({ userId = 1 })
		env.mock:advance(4)
		local sim = host.match.sim
		local tower = sim.objectives.list[1]
		positions[1] = { x = tower.x + 2, z = tower.z }
		local captured = {}
		host.events:connect(function(name, event)
			if name == "ObjectiveCaptured" then
				table.insert(captured, event)
			end
		end)
		env.mock:advance(tower.captureSeconds + 1)
		expect(tower.owner).toBe("crimson")
		expect(#captured).toBe(1)
		expect(sim.kingdoms.crimson.crownPoints).toBeGreaterThanOrEqual(tower.crownPoints)
		local state = invoke(env, p1, "Kingdom.GetState")
		expect(viewOf(state, "crimson").regions).toEqual({ "crimson_home", "heartland" })
		expect(host.match.state).toBe("Results")
		local ended = sentTo(env, "Match.Ended", p1)
		expect(#ended).toBe(1)
		expect(ended[1][1].winner).toBe("crimson")
		expect(invoke(env, p1, "Match.GetState")).toBe("Results")
		expect(env.mock:hasLog("error", "tick failed")).toBe(false)
	end)

	it("lets two rulers share one kingdom and keeps the ledger exact under both", function()
		local env, _, host = setup({ maxRulersPerKingdom = 4 })
		host.preferredKingdom = function(player) -- what KingdomService does for a party (PartyId)
			return if player.UserId == 2 then "crimson" else nil
		end
		local p1 = env.mock.players:add({ userId = 1 })
		local p2 = env.mock.players:add({ userId = 2 })
		expect(host:kingdomOf(p1)).toBe("crimson")
		expect(host:kingdomOf(p2)).toBe("crimson")
		expect(p2.Team).toBe(p1.Team)
		env.mock:advance(1)
		expect(host.match.state).toBe("Founding")

		local sim = host.match.sim
		local k = sim.kingdoms.crimson
		expect(#k.citizenIds).toBe(12) -- the second ruler brings no extra citizens
		local keep = sim.buildings[k.keepId]
		local wood = sim:balance(k.id, "wood")
		expect(host:command(p1, "PlaceBuilding", "house", keep.x + 30, keep.z + 30)).toBe(true)
		local cx, cz = freeSpot(sim, k, "lumbercamp")
		expect(host:command(p2, "PlaceBuilding", "lumbercamp", cx, cz)).toBe(true)
		expect(invoke(env, p2, "Kingdom.SetJobQuota", "woodcutter", 4)).toBe(true) -- shared command rights
		expect(k.quotas.woodcutter).toBe(4)
		expect(sim:balance(k.id, "wood")).toBe(wood - 40 - 40)
		local placed = {}
		for _, e in sim:drainEvents() do
			if e.name == "BuildingPlaced" then
				placed[e.by] = e.kind
			end
		end
		expect(placed).toEqual({ [1] = "house", [2] = "lumbercamp" })
		expect(sim.treasury:audit(k.id)).toBe(true)
	end)

	it("drops malformed or flooding calls before they reach the kingdom", function()
		local env, remotes, host = setup()
		local p1 = env.mock.players:add({ userId = 1 })
		env.mock:advance(4)
		local k = host.match.sim.kingdoms.crimson
		local quotas = table.clone(k.quotas)
		expect(invoke(env, p1, "Kingdom.SetJobQuota", "woodcutter", 0 / 0)).toBeNil()
		expect(invoke(env, p1, "Kingdom.SetJobQuota", "woodcutter", math.huge)).toBeNil()
		expect(invoke(env, p1, "Kingdom.SetJobQuota", "woodcutter", 51)).toBeNil() -- G8: integer(0,50)
		expect(invoke(env, p1, "Kingdom.SetJobQuota", "hauler", 3)).toBeNil() -- the pool has no quota
		expect(invoke(env, p1, "Kingdom.SetJobQuota", "woodcutter", 3, "extra")).toBeNil()
		expect(invoke(env, p1, "Kingdom.Gather", 42)).toBeNil()
		expect(invoke(env, p1, "Kingdom.Gather", string.rep("x", 33))).toBeNil()
		expect(k.quotas).toEqual(quotas)
		local stats = remotes:stats()
		expect(stats.dropped.invalidArgs).toBe(6)
		expect(stats.dropped.extraArgs).toBe(1)
		-- burst then rate limit (Gather: burst 4; the two rejected calls above spent two tokens)
		local handled = 0
		for _ = 1, 6 do
			if invoke(env, p1, "Kingdom.Gather", "n1") ~= nil then
				handled += 1
			end
		end
		expect(handled).toBe(2)
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
		expect({ invoke(env, extra, "Kingdom.SetJobQuota", "farmer", 2) }).toEqual({ false, "not_in_match" })
		expect(invoke(env, extra, "Kingdom.GetState").mine).toBeNil()
		-- a ruler leaves: the seat frees up and the kingdom keeps running
		env.mock.players:remove(env.Players:GetPlayerByUserId(1))
		expect(#host.match.sim.kingdoms.crimson.rulers).toBe(3)
	end)

	it("ends the match, reports MatchEnded once (G9), and starts a fresh world for everyone", function()
		local env, _, host = setup({
			mode = "match",
			countdownSec = 3,
			phaseDurations = { Founding = 15, Expansion = 15, Conflict = 15, Endgame = 15 },
			resultsSec = 20,
		})
		local ended = {}
		GameEvents.MatchEnded:connect(function(summary)
			table.insert(ended, summary)
		end)
		local phases = {}
		GameEvents.MatchPhaseChanged:connect(function(phase)
			table.insert(phases, phase)
		end)
		local p1 = env.mock.players:add({ userId = 5 })
		env.mock:advance(70)
		expect(host.match.state).toBe("Results")
		expect(#ended).toBe(1)
		expect(ended[1].durationSec).toBe(60)
		expect(#ended[1].standings).toBe(4)
		local notified = sentTo(env, "Match.Ended", p1)
		expect(#notified).toBe(1)
		expect(notified[1][1]).toEqual(ended[1])
		local firstTeam = p1.Team
		env.mock:advance(15)
		expect(host.match.state).toBe("Lobby")
		expect(host:phaseInfo().endsAtServerTime).toBeTruthy() -- counting down again
		expect(host.match.roundId).toBe("km-2")
		expect(host:kingdomOf(p1)).toBe("crimson")
		expect(p1.Team).toBeTruthy()
		expect(rawequal(p1.Team, firstTeam)).toBe(false) -- teams were rebuilt with the new world
		expect(table.find(env.Teams:GetChildren(), firstTeam)).toBeNil()
		expect(#env.Teams:GetChildren()).toBe(4)
		expect(phases).toEqual({ "Founding", "Expansion", "Conflict", "Endgame", "Results", "Lobby" })
		expect(#ended).toBe(1)
	end)

	it("fires the G9 building and gathering events exactly once with G2 payloads", function()
		local env, _, host = setup()
		local placed, completed, gathered = {}, {}, 0
		GameEvents.BuildingPlaced:connect(function(building, player)
			table.insert(placed, { building = building, player = player })
		end)
		GameEvents.BuildingCompleted:connect(function(building)
			table.insert(completed, building)
		end)
		GameEvents.ResourceGathered:connect(function(_player, kingdomId, _resource, amount, source)
			if kingdomId == "crimson" and source == "citizen" then
				gathered += amount
			end
		end)
		local p1 = env.mock.players:add({ userId = 9 })
		env.mock:advance(4)
		local sim = host.match.sim
		local keep = sim.buildings[sim.kingdoms.crimson.keepId]
		assert(host:command(p1, "PlaceBuilding", "house", keep.x + 30, keep.z + 30))
		env.mock:advance(60)
		expect(#placed).toBe(1)
		expect(placed[1].player).toBe(p1)
		expect(placed[1].building.type).toBe("house")
		expect(placed[1].building.kingdom).toBe("crimson")
		expect(placed[1].building.state).toBe("planned")
		expect(placed[1].building.placedBy).toBe(9) -- G9 funnel: "first build placed" credits placedBy
		expect(typeof(placed[1].building.cframe)).toBe("CFrame")
		expect(typeof(placed[1].building.footprint)).toBe("Vector2")
		expect(#completed).toBe(1)
		expect(completed[1].state).toBe("complete")
		expect(gathered).toBe(
			sim.kingdoms.crimson.stats.gathered.food
				+ sim.kingdoms.crimson.stats.gathered.wood
				+ sim.kingdoms.crimson.stats.gathered.stone
				+ sim.kingdoms.crimson.stats.gathered.gold
		)
	end)
end)
