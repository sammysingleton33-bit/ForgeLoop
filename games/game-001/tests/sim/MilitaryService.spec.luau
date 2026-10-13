--[[
	MilitaryService and ObjectiveService (CONTRACTS G8 Army area, G9; FL-0052) booted with the match
	services and FORGE-03's real TreasuryService and Costs: Army.Recruit charges Costs.unit × count once,
	trains at the barracks asked for and the recruits appear at its Rally; refusals charge nothing;
	Army.Command / Army.Recruit validation, rate limits, ownership and spectators; Send-to-capture
	(empty unitIds) captures the watchtower (owner, ObjectiveCaptured, region, Crown Points); the
	Army.Objectives / Army.GetObjectives shape and throttle; the tower built neutral and recoloured.
]]

local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect, afterEach = T.describe, T.it, T.expect, T.afterEach

local MockEnv = require("../../../../roblox/tests/mocks/MockEnv")
local GameEvents = require("@game/ReplicatedStorage/Forge/Contracts/GameEvents")
local Loader = require("@game/ReplicatedStorage/Forge/Contracts/Loader")
local Costs = require("@game/ReplicatedStorage/Forge/Config/Costs")
local ArmyRemotes = require("@game/ReplicatedStorage/Game/Army/Remotes")
local KingdomRemotes = require("@game/ReplicatedStorage/Game/Kingdom/Remotes")
local MatchRemotes = require("@game/ReplicatedStorage/Game/Match/Remotes")
local TreasuryRemotes = require("@game/ReplicatedStorage/Game/Treasury/Remotes")
local Kit = require("@game/ReplicatedStorage/Game/Kit/Kit")
local Layout = require("@game/ReplicatedStorage/Game/Kingdom/Layout")
local MatchConfig = require("@game/ReplicatedStorage/Forge/Config/Match")
local MatchHost = require("@game/ReplicatedStorage/Game/Kingdom/MatchHost")
local Military = require("@game/ReplicatedStorage/Game/Sim/Military")
local WorldView = require("@game/ReplicatedStorage/Game/Sim/WorldView")

local function service(name)
	return require(`@game/ServerScriptService/{if name == "RemoteService" then "Forge" else "Game"}/Services/{name}`)
end

local SERVICES =
	{ "RemoteService", "MatchService", "KingdomService", "TreasuryService", "MilitaryService", "ObjectiveService" }

local booted = {}

local function boot()
	local env = MockEnv.new({
		seed = 8,
		sharedModules = {
			Remotes = {
				Kingdom = KingdomRemotes,
				Match = MatchRemotes,
				Treasury = TreasuryRemotes,
				Army = ArmyRemotes,
			},
		},
	})
	local definitions = {}
	for _, name in SERVICES do
		table.insert(definitions, service(name))
	end
	local registry = Loader.load(env, definitions)
	table.insert(booted, { registry = registry, env = env })
	registry:get("KingdomService").adapter = {
		partyOf = function()
			return nil
		end,
		load = function()
			return nil
		end,
		pivot = function() end,
		attach = function() end,
		onDied = function()
			return nil
		end,
		respawnDelay = function()
			return 5
		end,
	}
	return env,
		{
			match = registry:get("MatchService"),
			treasury = registry:get("TreasuryService"),
			military = registry:get("MilitaryService"),
			objectives = registry:get("ObjectiveService"),
			remotes = registry:get("RemoteService"),
		}
end

local function remote(env, name)
	local area, action = string.match(name, "^(%w+)%.(%w+)$")
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

local function fire(env, player, name, ...)
	local args = table.pack(...)
	env.mock.remotes:asClient(player, function()
		remote(env, name):FireServer(table.unpack(args, 1, args.n))
	end)
end

local function sent(env, name)
	local out = {}
	for _, entry in env.mock.remotes:sent(remote(env, name)) do
		table.insert(out, entry.args[1])
	end
	return out
end

-- A finished building of the kingdom at the first spot around its keep where it may stand (cost aside).
local function addBuilding(sim, k, kind: string)
	local keep = sim.buildings[k.keepId]
	for radius = 40, 160, 10 do
		for step = 0, 23 do
			local a = step / 24 * 2 * math.pi
			local x, z = keep.x + math.cos(a) * radius, keep.z + math.sin(a) * radius
			local ok, err = sim:canPlace(k, kind, x, z)
			if ok or err == "cannot_afford" then
				local b = sim:_createBuilding(k, kind, x, z)
				sim:_completeInstantly(b)
				sim:_recompute(k)
				return b
			end
		end
	end
	error(`no free spot for {kind}`)
end

-- Two houses: eight more beds (slice mode fills the keep's twelve with the starting citizens).
local function addBeds(sim, k)
	addBuilding(sim, k, "house")
	addBuilding(sim, k, "house")
end

local function setup()
	local env, s = boot()
	local p1 = env.mock.players:add({ userId = 1 })
	env.mock:advance(0.5)
	local sim = s.match.host.match.sim
	local k = sim.kingdoms[s.match.host:kingdomOf(p1)]
	return env, s, p1, sim, k
end

-- Counts calls that reach the simulation's command path.
local function countCommands(host)
	local calls = { n = 0 }
	host.command = function(self, ...)
		calls.n += 1
		return MatchHost.command(self, ...)
	end
	return calls
end

-- (x, z) of every unit Military.spawnUnit creates while `fn` runs.
local function spawnedDuring(fn: () -> ()): { { x: number, z: number, id: number } }
	local spawned = {}
	local original = Military.spawnUnit
	Military.spawnUnit = function(sim, kingdom, kind, x, z)
		local u = original(sim, kingdom, kind, x, z)
		table.insert(spawned, { x = x, z = z, id = u.id })
		return u
	end
	local ok, err = pcall(fn)
	Military.spawnUnit = original
	assert(ok, err)
	return spawned
end

local function tintColors(model): { Color3 }
	local out = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and type(d:GetAttribute("KitTint")) == "number" then
			table.insert(out, d.Color)
		end
	end
	return out
end

local function kingdomColor(k): Color3
	return Color3.fromRGB(k.color[1], k.color[2], k.color[3])
end

afterEach(function()
	for _, b in booted do
		b.registry:destroy()
		for _, entry in b.env.mock.logs do
			if entry.level == "error" then
				error(`server logged an error: {entry.message} {entry.fields and entry.fields.error or ""}`)
			end
		end
	end
	table.clear(booted)
	GameEvents.disconnectAll()
end)

describe("MilitaryService: Army.Recruit (G8)", function()
	it("charges Costs.unit × count once, trains at the barracks asked for and fires UnitsRecruited", function()
		local env, s, p1, sim, k = setup()
		addBeds(sim, k)
		local first = addBuilding(sim, k, "barracks")
		local second = addBuilding(sim, k, "barracks")
		s.treasury:deposit(k.id, "food", 500, "spec:food", "spec")
		s.treasury:deposit(k.id, "wood", 500, "spec:wood", "spec")
		local fired = {}
		GameEvents.UnitsRecruited:connect(function(player, kingdomId, count)
			table.insert(fired, { player = player, kingdom = kingdomId, count = count })
		end)
		local before = s.treasury:get(k.id)
		expect({ invoke(env, p1, "Army.Recruit", second.id, "soldier", 3) }).toEqual({ true })
		local after = s.treasury:get(k.id)
		local cost = assert(Costs.unit("soldier")).cost
		for res, amount in before do
			expect(after[res]).toBe(amount - (cost[res] or 0) * 3)
		end
		expect(#second.queue).toBe(3) -- the barracks asked for, though both queues were empty
		expect(#first.queue).toBe(0)
		env.mock:advance(0.5) -- the host fans simulation events out on its tick
		expect(#fired).toBe(1)
		expect(fired[1].player).toBe(p1)
		expect(fired[1].kingdom).toBe(k.id)
		expect(fired[1].count).toBe(3)

		-- trained one by one, each at the barracks' Rally (Kit attachment), as simulation soldiers
		local spawned = spawnedDuring(function()
			env.mock:advance(3 * assert(Costs.unit("soldier")).trainSeconds + 0.5)
		end)
		expect(#spawned).toBe(3)
		local model = Kit.build("barracks", 1, "complete", Kit.NEUTRAL_COLOR)
		WorldView.placeModel(model, CFrame.new(second.x, 0, second.z) * CFrame.Angles(0, second.yaw, 0))
		local root = model.PrimaryPart :: BasePart
		local rally = (root.CFrame * (root:FindFirstChild("Rally") :: Attachment).CFrame).Position
		expect(spawned[1].x).toBeNear(rally.X, 1e-3)
		expect(spawned[1].z).toBeNear(rally.Z, 1e-3)
		for _, entry in spawned do
			local u = sim.units[entry.id]
			expect(u.entityKind).toBe("soldier")
			expect(u.kingdomId).toBe(k.id)
			expect(table.find(k.unitIds, u.id)).never.toBeNil()
		end
		expect(#fired).toBe(1) -- once per recruit, not per soldier
	end)

	it("refuses short funds, full bunks and bad barracks, charging nothing; full beds never refuse (D-041)", function()
		local env, s, p1, sim, k = setup()
		local barracks = addBuilding(sim, k, "barracks") -- level 1: 4 bunks
		expect(#k.citizenIds).toBe(k.popCap) -- twelve citizens in the keep's twelve beds, no house
		local fired = 0
		GameEvents.UnitsRecruited:connect(function()
			fired += 1
		end)
		local function refused(reason, barracksId, count)
			local before = s.treasury:get(k.id)
			expect({ invoke(env, p1, "Army.Recruit", barracksId, "soldier", count) }).toEqual({ false, reason })
			expect(s.treasury:get(k.id)).toEqual(before)
			env.mock:advance(0.6) -- keep within Army.Recruit's rate (burst 4, 2 per second)
		end
		local food = s.treasury:get(k.id).food
		assert(s.treasury:spend(k.id, { food = food - 60 }, "spec:spend", "spec")) -- 60 food: two soldiers
		refused("cannot_afford", barracks.id, 3)
		local azure = addBuilding(sim, sim.kingdoms.azure, "barracks")
		refused("not_owner", azure.id, 1)
		refused("not_found", 99999, 1)
		refused("not_barracks", k.keepId, 1)
		s.treasury:deposit(k.id, "food", 500, "spec:food", "spec")
		s.treasury:deposit(k.id, "wood", 500, "spec:wood", "spec")
		refused("recruit_cap", barracks.id, 5) -- more than the 4 bunks at once
		expect({ invoke(env, p1, "Army.Recruit", barracks.id, "soldier", 4) }).toEqual({ true })
		env.mock:advance(0.6)
		refused("recruit_cap", barracks.id, 1) -- four living or training fill the bunks
		expect(#barracks.queue).toBe(4)
		expect(#azure.queue).toBe(0)
		expect(fired).toBe(1)
	end)
end)

describe("MilitaryService: remotes (G8)", function()
	it("drops malformed Army.Recruit and Army.Command calls before the simulation", function()
		local env, s, p1, sim, k = setup()
		local barracks = addBuilding(sim, k, "barracks")
		local u = Military.spawnUnit(sim, k, "soldier", sim.buildings[k.keepId].x + 30, sim.buildings[k.keepId].z)
		local calls = countCommands(s.match.host)
		local recruits = {
			{ "1", "soldier", 1 },
			{ 1.5, "soldier", 1 },
			{ 0, "soldier", 1 },
			{ barracks.id, "knight", 1 }, -- VS-1: enum{"soldier"}
			{ barracks.id, "soldier", 0 },
			{ barracks.id, "soldier", 11 },
			{ barracks.id, "soldier", 0 / 0 },
			{ barracks.id, "soldier", 1, "extra" },
		}
		for _, args in recruits do
			expect(invoke(env, p1, "Army.Recruit", table.unpack(args))).toBeNil()
			env.mock:advance(0.6)
		end
		local many = {}
		for i = 1, 51 do
			many[i] = u.id
		end
		local commands = {
			{ {}, "charge" },
			{ {}, "Move", Vector3.new(0, 0, 0) },
			{ "x", "move", Vector3.new(0, 0, 0) },
			{ { 1.5 }, "move", Vector3.new(0, 0, 0) },
			{ { 70000 }, "move", Vector3.new(0, 0, 0) },
			{ many, "move", Vector3.new(0, 0, 0) }, -- 51 ids
			{ { u.id }, "move", Vector3.new(0 / 0, 0, 0) },
			{ { u.id }, "move", Vector3.new(5000, 0, 0) },
			{ { u.id }, "move", CFrame.new() }, -- no CFrame on the wire
			{ { u.id }, "capture", nil, string.rep("a", 33) },
			{ { u.id }, "capture", nil, 5 },
		}
		for _, args in commands do
			fire(env, p1, "Army.Command", args[1], args[2], args[3], args[4])
			env.mock:advance(0.4)
		end
		expect(calls.n).toBe(0)
		local stats = s.remotes:stats()
		expect(stats.droppedByName["Army.Recruit"]).toBe(#recruits)
		expect(stats.droppedByName["Army.Command"]).toBe(#commands)
		expect(stats.dropped.extraArgs).toBe(1) -- the "extra" Recruit
		expect(stats.dropped.invalidArgs).toBe(#recruits - 1 + #commands)
		expect(stats.dropped.rateLimited).toBeNil()
		expect(#barracks.queue).toBe(0)
		-- 50 ids are fine
		local fifty = table.move(many, 1, 50, 1, {})
		fire(env, p1, "Army.Command", fifty, "move", Vector3.new(u.x, 0, u.z + 20))
		expect(calls.n).toBe(1)
		expect(u.order.kind).toBe("Move")
	end)

	it("refuses a targetPos off the map (out_of_bounds): the soldier stays where it is", function()
		local env, s, p1, sim, k = setup()
		local keep = sim.buildings[k.keepId]
		local u = Military.spawnUnit(sim, k, "soldier", keep.x + 30, keep.z)
		u.order = { kind = "Hold" }
		local calls = countCommands(s.match.host)
		-- (3900, 0, 900) itself is 4002 long: the remote's vector3(4000) drops it before the simulation
		fire(env, p1, "Army.Command", { u.id }, "move", Vector3.new(3900, 0, 900))
		expect(calls.n).toBe(0)
		fire(env, p1, "Army.Command", { u.id }, "move", Vector3.new(3500, 0, 900)) -- passes vector3(4000)
		expect(calls.n).toBe(1) -- it reached the simulation, which refused it
		env.mock:advance(5)
		expect(u.order).toEqual({ kind = "Hold" })
		expect(u.x).toBe(keep.x + 30)
		expect(u.z).toBe(keep.z)
		expect({ s.military:command(p1, { u.id }, { kind = "move", targetPos = Vector3.new(3900, 0, 900) }) }).toEqual({
			false,
			"out_of_bounds",
		})
		local b = sim.bounds
		expect(b.maxX < 3900).toBe(true)
		expect({
			s.military:command(p1, { u.id }, { kind = "guard", targetPos = Vector3.new(b.maxX - 1, 0, b.maxZ - 1) }),
		}).toEqual({ true })
	end)

	it("rate-limits Army.Recruit (burst 4) and Army.Command (burst 6) per player", function()
		local env, s, p1, sim, k = setup()
		local barracks = addBuilding(sim, k, "barracks")
		local calls = countCommands(s.match.host)
		for _ = 1, 6 do
			invoke(env, p1, "Army.Recruit", barracks.id, "soldier", 1) -- the first four fill the 4 bunks
		end
		expect(calls.n).toBe(4)
		for _ = 1, 10 do
			fire(env, p1, "Army.Command", {}, "guard")
		end
		expect(calls.n).toBe(4 + 6)
		expect(s.remotes:stats().dropped.rateLimited).toBe(2 + 4)
		env.mock:advance(3) -- the buckets refill
		expect(#barracks.queue).toBe(4)
		expect({ invoke(env, p1, "Army.Recruit", barracks.id, "soldier", 1) }).toEqual({ false, "recruit_cap" })
	end)

	it("answers not_in_match to spectators and leaves other kingdoms' soldiers alone", function()
		local env, s, p1, sim, k = setup()
		local players = { p1 }
		for userId = 2, 17 do
			table.insert(players, env.mock.players:add({ userId = userId }))
		end
		env.mock:advance(0.5)
		local spectator = players[17] -- four kingdoms of four rulers: the 17th player watches
		expect(s.match.host:kingdomOf(spectator)).toBeNil()
		local barracks = addBuilding(sim, k, "barracks")
		expect({ invoke(env, spectator, "Army.Recruit", barracks.id, "soldier", 1) }).toEqual({
			false,
			"not_in_match",
		})
		expect({ s.military:recruit(spectator, barracks.id, "soldier", 1) }).toEqual({ false, "not_in_match" })
		expect({ s.military:command(spectator, {}, { kind = "guard" }) }).toEqual({ false, "not_in_match" })
		local keep = sim.buildings[k.keepId]
		local mine = Military.spawnUnit(sim, k, "soldier", keep.x + 30, keep.z)
		mine.order = { kind = "Hold" }
		local rival
		for _, p in players do
			local kid = s.match.host:kingdomOf(p)
			if kid and kid ~= k.id then
				rival = p
				break
			end
		end
		fire(env, rival, "Army.Command", { mine.id }, "move", Vector3.new(0, 0, 0))
		fire(env, spectator, "Army.Command", { mine.id }, "move", Vector3.new(0, 0, 0))
		expect({ s.military:command(rival, { mine.id }, { kind = "move", targetPos = Vector3.new(0, 0, 0) }) }).toEqual({
			false,
			"no_units",
		})
		expect(mine.order).toEqual({ kind = "Hold" })
		-- and the owner can
		expect({ s.military:command(p1, { mine.id }, { kind = "guard" }) }).toEqual({ true })
		expect(mine.order.kind).toBe("Guard")
	end)
end)

describe("MilitaryService + ObjectiveService: Send-to-capture (VS-1 row 7)", function()
	it("an empty Army.Command sends the idle soldiers to capture the watchtower; the capture pays out", function()
		local env, s, p1, sim, k = setup()
		addBeds(sim, k)
		local barracks = addBuilding(sim, k, "barracks")
		s.treasury:deposit(k.id, "food", 500, "spec:food", "spec")
		s.treasury:deposit(k.id, "wood", 500, "spec:wood", "spec")
		expect({ invoke(env, p1, "Army.Recruit", barracks.id, "soldier", 3) }).toEqual({ true })
		env.mock:advance(3 * 8 + 0.5)
		expect(#k.unitIds).toBe(3)
		local captures, signalled = {}, {}
		GameEvents.ObjectiveCaptured:connect(function(objectiveId, kingdomId)
			table.insert(captures, { objectiveId, kingdomId })
		end)
		s.objectives.captured:connect(function(objectiveId, kingdomId)
			table.insert(signalled, { objectiveId, kingdomId })
		end)
		local tower = sim.objectives.list[1]
		local world = Layout.WORLD.objectives[1]
		expect(tower.id).toBe(world.id)
		local crownBefore = k.crownPoints
		fire(env, p1, "Army.Command", {}, "capture", nil, tower.id)
		for _, uid in k.unitIds do
			expect(sim.units[uid].order.kind).toBe("Capture")
		end
		local waited = 0
		while tower.owner == nil and waited < 300 do
			env.mock:advance(1)
			waited += 1
		end
		expect(tower.owner).toBe(k.id)
		env.mock:advance(0.5)
		expect(captures).toEqual({ { tower.id, k.id } }) -- G9 ObjectiveCaptured, exactly once
		expect(signalled).toEqual({ { tower.id, k.id } }) -- ObjectiveService.captured
		expect(table.find(s.match.host:kingdomView(k.id).regions, world.regionId)).never.toBeNil()
		expect(k.crownPoints - crownBefore >= tower.crownPoints).toBe(true)
		for _, uid in k.unitIds do
			local u = sim.units[uid]
			expect(math.sqrt((u.x - tower.x) ^ 2 + (u.z - tower.z) ^ 2) <= tower.radius).toBe(true)
		end
		local model = assert(s.objectives:getModel(tower.id))
		expect(model:GetAttribute("Owner")).toBe(k.id)
		expect(s.match:getPhase()).toBe("Results") -- slice mode: the first capture ends the slice
	end)
end)

describe("MilitaryService: the slice without a house (D-041, VS-1 B7)", function()
	it("builds a barracks, recruits 3 with every bed taken and captures with Send-to-capture", function()
		local env, s, p1, sim, k = setup()
		expect(s.match:getPhase()).toBe("Founding")
		expect(#k.citizenIds).toBe(k.popCap) -- the keep's twelve beds are full from the start
		-- the spec adds only what the treasury lacks for a price: what a ruler gathers first
		local function topUp(price: { [string]: number }, times: number)
			local stock = s.treasury:get(k.id)
			for res, amount in price do
				local short = amount * times - (stock[res] or 0)
				if short > 0 then
					s.treasury:deposit(k.id, res, short, `spec:{res}:{times}`, "spec")
				end
			end
		end
		-- the barracks goes up through the real build path: cost, construction site, builders
		topUp(assert(Costs.building("barracks", 1)).cost, 1)
		local keep = sim.buildings[k.keepId]
		local barracks
		for radius = 40, 160, 10 do
			for step = 0, 23 do
				local a = step / 24 * 2 * math.pi
				barracks =
					sim:placeBuilding(k, "barracks", keep.x + math.cos(a) * radius, keep.z + math.sin(a) * radius)
				if barracks then
					break
				end
			end
			if barracks then
				break
			end
		end
		assert(barracks, "no spot for the barracks")
		local waited = 0
		while barracks.level < 1 and waited < 120 do
			env.mock:advance(1)
			waited += 1
		end
		expect(barracks.level).toBe(1)
		for _, bid in k.buildingIds do
			expect(sim.buildings[bid].kind).never.toBe("house")
		end
		expect(#k.citizenIds).toBe(k.popCap)
		-- recruit 3: soldiers sleep in the barracks' bunks, so the full beds do not matter
		local unitCost = assert(Costs.unit("soldier")).cost
		topUp(unitCost, 3)
		local charges = {}
		s.treasury.changed:connect(function(kingdom, _totals, deltas)
			if kingdom == k.id then
				for res, delta in deltas do
					if delta < 0 then
						table.insert(charges, { res, delta })
					end
				end
			end
		end)
		expect({ invoke(env, p1, "Army.Recruit", barracks.id, "soldier", 3) }).toEqual({ true })
		env.mock:advance(3 * assert(Costs.unit("soldier")).trainSeconds + 0.5)
		expect(#k.unitIds).toBe(3)
		-- paid once, at queue time: Costs.unit("soldier") x 3 in one charge per resource
		local expected = {}
		for res, amount in unitCost do
			table.insert(expected, { res, -amount * 3 })
		end
		table.sort(expected, function(a, b)
			return a[1] < b[1]
		end)
		table.sort(charges, function(a, b)
			return a[1] < b[1]
		end)
		expect(charges).toEqual(expected)
		expect(s.match:getPhase()).toBe("Founding")
		-- Send-to-capture (no target): the nearest tower the kingdom does not hold
		fire(env, p1, "Army.Command", {}, "capture")
		for _, uid in k.unitIds do
			expect(sim.units[uid].order.kind).toBe("Capture")
		end
		local towerId = sim.units[k.unitIds[1]].order.objectiveId
		local tower
		for _, o in sim.objectives.list do
			if o.id == towerId then
				tower = o
			end
		end
		assert(tower, "the soldiers march on no tower")
		waited = 0
		while tower.owner == nil and waited < 300 do
			env.mock:advance(1)
			waited += 1
		end
		expect(tower.owner).toBe(k.id)
		env.mock:advance(0.5)
		expect(s.match:getPhase()).toBe("Results") -- slice mode: the first capture ends the slice
		env.mock:advance(5)
		local ended = sent(env, "Match.Ended")
		expect(#ended).toBe(1) -- once, with this kingdom as the winner
		expect(ended[1].winner).toBe(k.id)
	end)
end)

describe("MilitaryService: Send-to-capture without a target (FORGE-03 #63 button)", function()
	it('Army.Command({}, "capture") sends the idle soldiers to the nearest tower the kingdom does not hold', function()
		local env, s, p1, sim, k = setup()
		local keep = sim.buildings[k.keepId]
		local soldiers = {}
		for i = 1, 3 do
			local u = Military.spawnUnit(sim, k, "soldier", keep.x + 30, keep.z + i * 3)
			table.insert(soldiers, u)
		end
		expect(#sim.objectives.list >= 1).toBe(true)
		local function nearestUnowned(): any
			local cx, cz = 0, 0
			for _, u in soldiers do
				cx += u.x / #soldiers
				cz += u.z / #soldiers
			end
			local best, bestDistance = nil, math.huge
			for _, o in sim.objectives.list do
				local d = math.sqrt((o.x - cx) ^ 2 + (o.z - cz) ^ 2)
				if o.owner ~= k.id and d < bestDistance then
					best, bestDistance = o, d
				end
			end
			return best
		end
		local calls = countCommands(s.match.host)
		fire(env, p1, "Army.Command", {}, "capture")
		expect(calls.n).toBe(1)
		local target = assert(nearestUnowned())
		for _, u in soldiers do
			expect(u.order.kind).toBe("Capture")
			expect(u.order.objectiveId).toBe(target.id)
		end
		env.mock:advance(5)
		for _, u in soldiers do
			expect(
				math.sqrt((u.x - target.x) ^ 2 + (u.z - target.z) ^ 2)
					< math.sqrt((keep.x + 30 - target.x) ^ 2 + (keep.z - target.z) ^ 2)
			).toBe(true) -- on their way
		end

		-- every tower already the kingdom's: nothing changes, nothing breaks (afterEach: no error logs).
		-- (Slice mode ends at the first capture, on the match's next update: no time passes here.)
		for _, o in sim.objectives.list do
			o.owner = k.id
		end
		for _, u in soldiers do
			u.order = { kind = "Defend" }
			u.target = nil
		end
		fire(env, p1, "Army.Command", {}, "capture")
		expect(calls.n).toBe(2)
		for _, u in soldiers do
			expect(u.order).toEqual({ kind = "Defend" })
		end
		expect({ s.military:command(p1, {}, { kind = "capture" }) }).toEqual({ false, "no_objective" })
	end)
end)

describe("ObjectiveService (G8)", function()
	it("lists objectives in the G8 shape on GetObjectives and in Army.Objectives", function()
		local env, _, p1, sim = setup()
		env.mock:advance(1)
		local list = invoke(env, p1, "Army.GetObjectives")
		expect(#list).toBe(#sim.objectives.list)
		local o = sim.objectives.list[1]
		local view = list[1]
		local keys = {}
		for key in view do
			table.insert(keys, key)
		end
		table.sort(keys)
		expect(keys).toEqual({ "id", "kind", "position", "progress", "radius" }) -- owner nil while neutral
		expect(view.id).toBe(o.id)
		expect(view.kind).toBe("capture")
		expect(typeof(view.position)).toBe("Vector3")
		expect(view.position.X).toBeNear(o.x, 1e-3)
		expect(view.position.Z).toBeNear(o.z, 1e-3)
		expect(view.radius).toBe(o.radius)
		expect(view.progress).toEqual({})
		local broadcasts = sent(env, "Army.Objectives")
		expect(#broadcasts).toBe(1) -- the first round, then nothing while nothing changes
		expect(broadcasts[1]).toEqual(list)
		env.mock:advance(5)
		expect(#sent(env, "Army.Objectives")).toBe(1)
	end)

	it("a tower rebuilt on capture keeps its pivot, a second kingdom still captures it, and nothing leaks", function()
		-- the full match: in the slice the first capture ends the match, so nobody could capture it again
		local savedMode = MatchConfig.mode
		MatchConfig.mode = "match"
		local ok, env, s, _, sim, k = pcall(setup)
		MatchConfig.mode = savedMode
		assert(ok, env)
		local waitedActive = 0
		while not sim.active and waitedActive < 60 do -- past the Lobby countdown
			env.mock:advance(1)
			waitedActive += 1
		end
		assert(sim.active, "the match is running")
		local o = sim.objectives.list[1]
		local first = assert(s.objectives:getModel(o.id))
		local folder = first.Parent
		local function pivotOf(m)
			local root = m.PrimaryPart :: BasePart
			return root.CFrame * root.PivotOffset
		end
		local pivot = pivotOf(first)
		local function towers()
			local n = 0
			for _, child in folder:GetChildren() do
				if child.Name == o.id then
					n += 1
				end
			end
			return n
		end
		local function waitOwner(owner, seconds)
			local waited = 0
			while o.owner ~= owner and waited < seconds do
				env.mock:advance(0.25)
				waited += 0.25
			end
			return o.owner == owner
		end
		local other
		for id, kingdom in sim.kingdoms do
			if id ~= k.id and kingdom.alive then
				other = kingdom
				break
			end
		end
		assert(other, "a second kingdom")
		local a = Military.spawnUnit(sim, k, "soldier", o.x, o.z)
		a.order = { kind = "Hold" }
		expect(waitOwner(k.id, 60)).toBe(true)
		local byA = assert(s.objectives:getModel(o.id))
		expect(rawequal(byA, first)).toBe(false)
		expect(towers()).toBe(1)
		expect((pivotOf(byA).Position - pivot.Position).Magnitude < 1e-4).toBe(true) -- rebuilt in place
		expect((pivotOf(byA).LookVector - pivot.LookVector).Magnitude < 1e-4).toBe(true) -- facing kept
		-- kingdom A walks away; kingdom B's soldier takes the zone: the capture still progresses and completes
		a.x, a.z = o.x + 400, o.z + 400
		local b = Military.spawnUnit(sim, other, "soldier", o.x, o.z)
		b.order = { kind = "Hold" }
		expect(waitOwner(other.id, 180)).toBe(true)
		local byB = assert(s.objectives:getModel(o.id))
		expect(rawequal(byB, byA)).toBe(false)
		expect(byA.Parent).toBeNil()
		expect(byB:GetAttribute("Owner")).toBe(other.id)
		expect((pivotOf(byB).Position - pivot.Position).Magnitude < 1e-4).toBe(true)
		expect((pivotOf(byB).LookVector - pivot.LookVector).Magnitude < 1e-4).toBe(true)
		expect(tintColors(byB)).toEqual(tintColors(Kit.build("watchtower", 1, "complete", kingdomColor(other))))
		expect(towers()).toBe(1)
		-- A again, then neutral: one tower at every step, each old one destroyed
		local previous = byB
		for _, owner in { k.id, nil :: any } do
			o.owner = owner
			s.objectives:broadcast()
			local now = assert(s.objectives:getModel(o.id))
			expect(rawequal(now, previous)).toBe(false)
			expect(previous.Parent).toBeNil()
			expect(towers()).toBe(1)
			expect(now:GetAttribute("Owner")).toBe(owner)
			previous = now
		end
	end)

	it("broadcasts progress at most twice a second, builds the tower neutral and rebuilds it on capture", function()
		local env, s, _, sim, k = setup()
		local o = sim.objectives.list[1]
		local model = assert(s.objectives:getModel(o.id))
		expect(model.Parent.Name).toBe("KingdomObjectives")
		expect(model.Parent.Parent).toBe(env.Workspace)
		local neutral = Kit.build("watchtower", 1, "complete", Kit.NEUTRAL_COLOR)
		expect(tintColors(model)).toEqual(tintColors(neutral))
		expect(#tintColors(model) > 0).toBe(true)
		local pivot = (model.PrimaryPart :: BasePart).CFrame * (model.PrimaryPart :: BasePart).PivotOffset
		expect(pivot.Position.X).toBeNear(o.x, 1e-3)
		expect(pivot.Position.Z).toBeNear(o.z, 1e-3)

		local u = Military.spawnUnit(sim, k, "soldier", o.x, o.z) -- a soldier holding the zone
		u.order = { kind = "Hold" }
		local start = #sent(env, "Army.Objectives")
		env.mock:advance(5)
		local during = sent(env, "Army.Objectives")
		local count = #during - start
		expect(count >= 5).toBe(true) -- progress rises every round
		expect(count <= 5 * 2 + 1).toBe(true) -- ≤ 2 per second
		local last = during[#during][1]
		expect(last.progress[k.id] > 0).toBe(true)
		expect(last.owner).toBeNil()
		for i = start + 1, #during do -- progress goes out rounded to 0.01 (the raw value moves 0.0125 a tick)
			for _, view in during[i] do
				for _, value in view.progress do
					expect(math.abs(value * 100 - math.floor(value * 100 + 0.5)) < 1e-9).toBe(true)
				end
			end
		end
		local raw = o.progress[k.id]
		expect(last.progress[k.id]).toBeNear(raw, 0.005 + 0.0125 * 2 + 1e-9) -- the latest, give or take a tick

		local waited = 0
		while o.owner == nil and waited < 60 do
			env.mock:advance(0.25)
			waited += 0.25
		end
		expect(o.owner).toBe(k.id)
		-- rebuilt in the capture tick: a fresh Kit tower in the owner's colour, never a recolour in place
		local captured = assert(s.objectives:getModel(o.id))
		expect(rawequal(captured, model)).toBe(false)
		expect(model.Parent).toBeNil() -- the old model is destroyed
		expect(captured:GetAttribute("Owner")).toBe(k.id)
		expect(captured:GetAttribute("ObjectiveId")).toBe(o.id)
		expect(captured.Name).toBe(o.id)
		local fresh = Kit.build("watchtower", 1, "complete", kingdomColor(k))
		expect(captured:GetAttribute("KitColor")).toEqual(fresh:GetAttribute("KitColor")) -- as built, not recoloured
		expect(#captured:GetDescendants()).toBe(#fresh:GetDescendants()) -- caps and emblems of the owner
		local function shape(m)
			local out = {}
			for _, d in m:GetDescendants() do
				if d:IsA("BasePart") then
					local size = d.Size
					table.insert(out, string.format("%s %.2f %.2f %.2f", d.Name, size.X, size.Y, size.Z))
				end
			end
			table.sort(out)
			return out
		end
		expect(shape(captured)).toEqual(shape(fresh))
		local recoloured = Kit.build("watchtower", 1, "complete", Kit.NEUTRAL_COLOR)
		Kit.setKingdomColor(recoloured, kingdomColor(k))
		-- the defect this guards against: a recoloured neutral tower keeps the neutral silhouette
		expect(shape(recoloured)).never.toEqual(shape(fresh))
		expect(tintColors(captured)).toEqual(tintColors(fresh))
		local towers = 0
		for _, child in captured.Parent:GetChildren() do
			if child.Name == o.id then
				towers += 1
			end
		end
		expect(towers).toBe(1) -- one model per objective
		env.mock:advance(1)
		local final = sent(env, "Army.Objectives")
		expect(final[#final][1].owner).toBe(k.id)
		expect(rawequal(s.objectives:getModel(o.id), captured)).toBe(true) -- same owner: kept, not rebuilt
		-- back to neutral (as a new match would): rebuilt neutral
		o.owner = nil
		s.objectives:broadcast()
		local back = assert(s.objectives:getModel(o.id))
		expect(rawequal(back, captured)).toBe(false)
		expect(captured.Parent).toBeNil()
		expect(back:GetAttribute("Owner")).toBeNil()
		expect(tintColors(back)).toEqual(tintColors(neutral))
		expect(#back:GetDescendants()).toBe(#neutral:GetDescendants())
	end)
end)
