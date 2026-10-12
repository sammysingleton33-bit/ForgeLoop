--[[
	BuildingService (CONTRACTS G6, G8 Build area; FL-0051) booted with the match services and FORGE-03's
	real TreasuryService and Costs: CanPlace and Place agree, Place charges exactly once and sets
	placedBy, the facing comes from rot, Upgrade, and Build.Buildings / Build.GetBuildings.
]]

local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect, afterEach = T.describe, T.it, T.expect, T.afterEach

local MockEnv = require("../../../../roblox/tests/mocks/MockEnv")
local GameEvents = require("@game/ReplicatedStorage/Forge/Contracts/GameEvents")
local Loader = require("@game/ReplicatedStorage/Forge/Contracts/Loader")
local Costs = require("@game/ReplicatedStorage/Forge/Config/Costs")
local BuildRemotes = require("@game/ReplicatedStorage/Game/Build/Remotes")
local KingdomRemotes = require("@game/ReplicatedStorage/Game/Kingdom/Remotes")
local MatchRemotes = require("@game/ReplicatedStorage/Game/Match/Remotes")
local TreasuryRemotes = require("@game/ReplicatedStorage/Game/Treasury/Remotes")

local function service(name)
	return require(`@game/ServerScriptService/{if name == "RemoteService" then "Forge" else "Game"}/Services/{name}`)
end

local booted = {}

local function boot()
	local env = MockEnv.new({
		seed = 8,
		sharedModules = {
			Remotes = {
				Kingdom = KingdomRemotes,
				Match = MatchRemotes,
				Build = BuildRemotes,
				Treasury = TreasuryRemotes,
			},
		},
	})
	local definitions = {}
	for _, name in { "RemoteService", "MatchService", "KingdomService", "BuildingService", "TreasuryService" } do
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
	return env, registry:get("BuildingService"), registry:get("MatchService"), registry:get("TreasuryService")
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

local function broadcasts(env)
	local out = {}
	for _, entry in env.mock.remotes:sent(remote(env, "Build.Buildings")) do
		table.insert(out, entry.args[1])
	end
	return out
end

-- the first spot around the keep where `kind` may stand
local function freeSpot(sim, k, kind)
	local keep = sim.buildings[k.keepId]
	for radius = 40, 140, 10 do
		for step = 0, 23 do
			local a = step / 24 * 2 * math.pi
			local x, z = keep.x + math.cos(a) * radius, keep.z + math.sin(a) * radius
			if sim:canPlace(k, kind, x, z) then
				return Vector3.new(x, 0, z)
			end
		end
	end
	error("no free spot")
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

describe("BuildingService (G6, G8)", function()
	it("CanPlace and Place agree; Place charges Costs once, sets placedBy and faces by rot", function()
		local env, _, match, treasury = boot()
		local p1 = env.mock.players:add({ userId = 1 })
		env.mock:advance(0.5)
		local sim = match.host.match.sim
		local k = sim.kingdoms.crimson
		local spot = freeSpot(sim, k, "house")
		expect({ invoke(env, p1, "Build.CanPlace", "house", spot, 1) }).toEqual({ true })
		local keep = sim.buildings[k.keepId]
		expect({ invoke(env, p1, "Build.CanPlace", "house", Vector3.new(keep.x, 0, keep.z), 0) }).toEqual({
			false,
			"blocked",
		})
		local before = treasury:get("crimson")
		local id, reason = invoke(env, p1, "Build.Place", "house", spot, 2)
		expect(reason).toBeNil()
		expect(type(id)).toBe("number")
		local after = treasury:get("crimson")
		local cost = assert(Costs.building("house", 1)).cost
		for res, amount in cost do
			expect(after[res]).toBe(before[res] - amount)
		end
		local view = assert(sim:buildingView(id))
		expect(view.placedBy).toBe(1)
		local look = view.cframe.LookVector
		local yaw = math.atan2(-look.X, -look.Z) % (2 * math.pi)
		expect(math.abs(yaw - math.pi) < 1e-6).toBe(true) -- rot 2 = 180°, whatever way the keep lies
		expect({ invoke(env, p1, "Build.CanPlace", "house", spot, 0) }).toEqual({ false, "blocked" }) -- taken now
	end)

	it("refuses bad input before it reaches the kingdom and charges nothing", function()
		local env, _, match, treasury = boot()
		local p1 = env.mock.players:add({ userId = 1 })
		env.mock:advance(0.5)
		local before = treasury:get("crimson")
		expect(invoke(env, p1, "Build.Place", "house", Vector3.new(0, 0, 0), 4)).toBeNil() -- rot 0..3
		expect(invoke(env, p1, "Build.Place", "castle", Vector3.new(0, 0, 0), 0)).toBeNil() -- not a G2 type
		expect(invoke(env, p1, "Build.Place", "house", Vector3.new(9000, 0, 0), 0)).toBeNil() -- off the world
		expect(invoke(env, p1, "Build.Place", "house", CFrame.new(), 0)).toBeNil() -- no CFrame on the wire
		env.mock:advance(3) -- those spent Build.Place's burst (4); let the bucket refill
		expect({ invoke(env, p1, "Build.Place", "keep", Vector3.new(0, 0, 0), 0) }).toEqual({ nil, "not_placeable" })
		expect({ invoke(env, p1, "Build.Place", "house", Vector3.new(0, 0, 0), 0) }).toEqual({
			nil,
			"out_of_territory",
		})
		expect(treasury:get("crimson")).toEqual(before)
		local spectator = env.mock.players:add({ userId = 99 })
		for userId = 2, 16 do
			env.mock.players:add({ userId = userId })
		end
		local extra = env.mock.players:add({ userId = 100 })
		expect({ invoke(env, extra, "Build.CanPlace", "house", Vector3.new(0, 0, 0), 0) }).toEqual({
			false,
			"not_in_match",
		})
		expect(spectator).toBeTruthy()
		expect(match).toBeTruthy()
	end)

	it("upgrades a building the player's kingdom owns, and nobody else's", function()
		local env, _, match = boot()
		local p1 = env.mock.players:add({ userId = 1 })
		local p2 = env.mock.players:add({ userId = 2 })
		env.mock:advance(0.5)
		local sim = match.host.match.sim
		local keep = sim.kingdoms.crimson.keepId
		expect({ invoke(env, p2, "Build.Upgrade", keep) }).toEqual({ false, "not_owner" })
		expect({ invoke(env, p1, "Build.Upgrade", keep) }).toEqual({ false, "cannot_afford" })
		sim.treasury:deposit("crimson", "wood", 500, "spec:wood", "spec")
		sim.treasury:deposit("crimson", "stone", 500, "spec:stone", "spec")
		expect({ invoke(env, p1, "Build.Upgrade", keep) }).toEqual({ true })
		expect(sim.buildings[keep].pendingLevel).toBe(2)
	end)

	it("broadcasts changed buildings at most twice a second and answers GetBuildings with all of them", function()
		local env, _, match = boot()
		local p1 = env.mock.players:add({ userId = 1 })
		env.mock:advance(1)
		local sim = match.host.match.sim
		local all = invoke(env, p1, "Build.GetBuildings")
		expect(#all).toBe(#sim:buildingViews())
		expect(#all).toBe(4 * 5) -- keep, storehouse, farm, lumber camp and quarry per kingdom
		local first = broadcasts(env)
		expect(#first >= 1).toBe(true)
		local seen = 0
		for _, list in first do
			seen += #list
		end
		expect(seen).toBe(#all) -- everything once at the start, nothing repeated while nothing changes
		env.mock:advance(5)
		expect(#broadcasts(env)).toBe(#first)
		local spot = freeSpot(sim, sim.kingdoms.crimson, "house")
		local id = invoke(env, p1, "Build.Place", "house", spot, 0)
		env.mock:advance(2)
		local later = broadcasts(env)
		expect(#later > #first and #later <= #first + 4).toBe(true) -- ≤ 2 per second
		local found = false
		for i = #first + 1, #later do
			for _, view in later[i] do
				if view.id == id then
					found = true
				end
			end
		end
		expect(found).toBe(true)
	end)
end)
