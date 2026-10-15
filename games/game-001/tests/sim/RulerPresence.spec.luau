--[[
	MatchHost ruler position clamp (D-050 (6b), FL-0122, FORGE-07's audit M-b). A ruler's character is simulated
	by its owner's client, so the position the simulation uses for objective capture and gather range is not
	taken as reported: it follows the report at most Match.rulerMaxSpeed studs per second. A teleport to a
	capture zone arrives after the walk; a normal sprint is never held back; a character the server itself moves
	(spawn, respawn: host:snapRuler) counts where it stands at once.
]]

local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect, afterEach = T.describe, T.it, T.expect, T.afterEach

local MockEnv = require("../../../../roblox/tests/mocks/MockEnv")
local GameEvents = require("@game/ReplicatedStorage/Forge/Contracts/GameEvents")
local KingdomRemotes = require("@game/ReplicatedStorage/Game/Kingdom/Remotes")
local MatchConfig = require("@game/ReplicatedStorage/Forge/Config/Match")
local MatchHost = require("@game/ReplicatedStorage/Game/Kingdom/MatchHost")
local MatchRemotes = require("@game/ReplicatedStorage/Game/Match/Remotes")
local RemoteServiceDef = require("@game/ServerScriptService/Forge/Services/RemoteService")

local positions = {} -- userId -> { x, z }: characters do not exist in Lune

local function setup()
	table.clear(positions)
	local env = MockEnv.new({
		seed = 3,
		sharedModules = { Remotes = { Kingdom = KingdomRemotes, Match = MatchRemotes } },
	})
	local remotes = RemoteServiceDef.new(env, {})
	local host = MatchHost.new(env, remotes, {
		seed = 7,
		match = { mode = "slice" },
		positionOf = function(player)
			local p = positions[player.UserId]
			if p then
				return p.x, p.z
			end
			return nil, nil
		end,
	})
	host:start()
	return env, host
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

local function distance(a, b): number
	return math.sqrt((a.x - b.x) ^ 2 + (a.z - b.z) ^ 2)
end

afterEach(function()
	GameEvents.disconnectAll()
end)

describe("MatchHost ruler position clamp (D-050 (6b))", function()
	it("a ruler who reports the capture zone from far away does not capture it until the walk is done", function()
		local env, host = setup()
		local p1 = env.mock.players:add({ userId = 1 })
		local sim = host.match.sim
		local keep = sim.buildings[sim.kingdoms.crimson.keepId]
		local tower = sim.objectives.list[1]
		positions[1] = { x = keep.x, z = keep.z }
		env.mock:advance(1) -- the first sample is taken as it is
		expect(sim.rulerPositions[1]).toEqual({ x = keep.x, z = keep.z })
		-- the next report is standing in the zone, hundreds of studs away
		positions[1] = { x = tower.x, z = tower.z }
		local walk = distance(keep, tower) / MatchConfig.rulerMaxSpeed
		expect(walk > tower.captureSeconds * 0.4).toBe(true) -- far enough that this matters
		env.mock:advance(walk / 2)
		expect(distance(sim.rulerPositions[1], tower) > tower.radius).toBe(true) -- half way: not in the zone yet
		env.mock:advance(tower.captureSeconds - walk / 2)
		expect(tower.owner).toBeNil() -- an unclamped position would have captured it by now
		expect(host.match.state).never.toBe("Results")
		-- the walk, then the capture time: it does happen, as it would for a ruler who ran there
		env.mock:advance(walk + tower.captureSeconds + 2)
		expect(tower.owner).toBe("crimson")
		expect(p1.UserId).toBe(1)
	end)

	it("a ruler at sprint speed is never held back: the sim sees every report as it is", function()
		local env, host = setup()
		env.mock.players:add({ userId = 1 })
		local sim = host.match.sim
		local keep = sim.buildings[sim.kingdoms.crimson.keepId]
		local sprint = 24 -- RulerController's sprintSpeed
		local x = keep.x
		positions[1] = { x = x, z = keep.z }
		env.mock:advance(0.5)
		for _ = 1, 60 do
			x += sprint * 0.5
			positions[1] = { x = x, z = keep.z }
			env.mock:advance(0.5)
			expect(sim.rulerPositions[1].x).toBeNear(x, 1e-6)
		end
	end)

	it("a jump the server made itself (host:snapRuler: spawn, respawn) is taken at once", function()
		local env, host = setup()
		env.mock.players:add({ userId = 1 })
		local sim = host.match.sim
		positions[1] = { x = -300, z = -300 }
		env.mock:advance(1)
		positions[1] = { x = 200, z = 100 } -- the server pivoted the character to the spawn
		host:snapRuler(1)
		env.mock:advance(0.5)
		expect(sim.rulerPositions[1]).toEqual({ x = 200, z = 100 })
		-- ... once: the next jump is clamped again
		positions[1] = { x = -300, z = -300 }
		env.mock:advance(0.5)
		expect(distance(sim.rulerPositions[1], { x = 200, z = 100 }) < MatchConfig.rulerMaxSpeed).toBe(true)
	end)

	it(
		"Kingdom.Gather uses the clamped position: a teleport next to a tree can't gather until the walk is done",
		function()
			local env, host = setup()
			local p1 = env.mock.players:add({ userId = 1 })
			local sim = host.match.sim
			local k = sim.kingdoms.crimson
			local keep = sim.buildings[k.keepId]
			local tree
			for _, nid in k.nearNodes do
				local node = sim.nodes[nid]
				if node.resource == "wood" and node.amount >= 10 and distance(node, keep) > 60 then
					tree = node
					break
				end
			end
			assert(tree, "a tree 60 studs or more from the keep")
			positions[1] = { x = keep.x, z = keep.z }
			env.mock:advance(1)
			positions[1] = { x = tree.x + 3, z = tree.z }
			expect({ invoke(env, p1, "Kingdom.Gather", tree.id) }).toEqual({ false, "too_far" })
			env.mock:advance(distance(keep, tree) / MatchConfig.rulerMaxSpeed + 1)
			expect({ invoke(env, p1, "Kingdom.Gather", tree.id) }).toEqual({ true, "wood", 2 })
		end
	)

	it("a character that disappears for a moment does not reset the clamp", function()
		local env, host = setup()
		env.mock.players:add({ userId = 1 })
		local sim = host.match.sim
		local keep = sim.buildings[sim.kingdoms.crimson.keepId]
		local tower = sim.objectives.list[1]
		positions[1] = { x = keep.x, z = keep.z }
		env.mock:advance(1)
		positions[1] = nil -- no character this tick
		env.mock:advance(0.5)
		expect(sim.rulerPositions[1]).toBeNil()
		positions[1] = { x = tower.x, z = tower.z } -- back, in the zone
		env.mock:advance(0.5)
		expect(distance(sim.rulerPositions[1], tower) > tower.radius).toBe(true)
	end)

	it("a ruler who left is forgotten, and a newcomer's first sample is taken as it is", function()
		local env, host = setup()
		local p1 = env.mock.players:add({ userId = 1 })
		positions[1] = { x = 10, z = 10 }
		env.mock:advance(1)
		env.mock.players:remove(p1)
		env.mock:advance(1)
		expect(host._accepted[1]).toBeNil()
		env.mock.players:add({ userId = 1 })
		positions[1] = { x = 500, z = 500 }
		env.mock:advance(1)
		expect(host.match.sim.rulerPositions[1]).toEqual({ x = 500, z = 500 })
	end)
end)
