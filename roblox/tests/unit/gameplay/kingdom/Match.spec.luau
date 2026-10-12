local T = require("../../../harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local F = require("./KingdomFixtures")
local Match = require("@game/ReplicatedStorage/Forge/Gameplay/Kingdom/Match")
local Military = require("@game/ReplicatedStorage/Forge/Gameplay/Kingdom/Military")
local Types = require("@game/ReplicatedStorage/Forge/Contracts/Types")

local function newMatch(options)
	local opts = {
		random = Random.new(9),
		countdownSec = 2,
		now = function()
			return 1700000000
		end,
	}
	for k, v in options or {} do
		opts[k] = v
	end
	return Match.new(opts)
end

local function run(match, seconds, dt)
	local step = dt or 0.25
	local t = 0
	while t < seconds - 1e-9 do
		match:update(step)
		t += step
	end
end

local function stateEvents(match)
	local out = {}
	for _, e in match:drainEvents() do
		if e.name == "MatchStateChanged" then
			table.insert(out, e.state)
		end
	end
	return out
end

describe("Kingdom/Match: phases", function()
	it("starts in Lobby with four kingdoms, frozen until enough players join", function()
		local match = newMatch({ minPlayers = 2 })
		expect(match.state).toBe("Lobby")
		expect(#match.sim.kingdomOrder).toBe(4)
		expect(match.sim.active).toBe(false)
		match:join(1)
		run(match, 5)
		expect(match.state).toBe("Lobby")
		expect(match.sim.time).toBe(0)
	end)

	it("counts down, then runs the simulation while Active", function()
		local match = newMatch()
		match:join(1)
		run(match, 0.25)
		expect(match.state).toBe("Countdown")
		expect(match:remaining()).toBeNear(2) -- the countdown starts on the update that enters it
		run(match, 2)
		expect(match.state).toBe("Active")
		expect(match.sim.active).toBe(true)
		run(match, 10)
		expect(match.sim.time).toBeNear(10)
		expect(match:remaining()).toBeNear(2400 - 10)
		expect(stateEvents(match)).toEqual({ "Countdown", "Active" })
	end)

	it("aborts the countdown when players drop below the minimum", function()
		local match = newMatch({ minPlayers = 2 })
		match:join(1)
		match:join(2)
		run(match, 1)
		expect(match.state).toBe("Countdown")
		match:leave(2)
		expect(match.state).toBe("Lobby")
		expect(stateEvents(match)).toEqual({ "Countdown", "Lobby" })
	end)

	it("only uses the declared round state names", function()
		local match = newMatch({ durationSec = 5, resultsSec = 1 })
		match:join(1)
		local seen = {}
		for _ = 1, 80 do
			match:update(0.25)
			seen[match.state] = true
		end
		for state in seen do
			expect(Types.isRoundState(state)).toBe(true)
		end
		expect(seen.Results).toBe(true)
	end)
end)

describe("Kingdom/Match: players", function()
	it("balances joiners across kingdoms and honours a preferred kingdom", function()
		local match = newMatch()
		expect({ match:join(1) }).toEqual({ true, "crimson" })
		expect({ match:join(2) }).toEqual({ true, "azure" })
		expect({ match:join(3, "crimson") }).toEqual({ true, "crimson" })
		expect({ match:join(4) }).toEqual({ true, "emerald" })
		expect({ match:join(1) }).toEqual({ false, "already_joined" })
	end)

	it("caps rulers per kingdom and reports a full match", function()
		local match = newMatch({ maxRulersPerKingdom = 1 })
		for i = 1, 4 do
			expect(match:join(i)).toBe(true)
		end
		expect({ match:join(5) }).toEqual({ false, "match_full" })
		expect({ match:join(6, "azure") }).toEqual({ false, "match_full" })
	end)

	it("gives a returning player their old kingdom back", function()
		local match = newMatch()
		match:join(1) -- k1
		match:join(2) -- k2
		match:leave(2)
		match:join(3) -- k2 is the emptiest after k1? k2 (0) -> k2
		match:join(2)
		expect(match:kingdomOf(2)).toBe("azure")
	end)

	it("joining changes nothing but the ruler list", function()
		local match = newMatch()
		match:join(1)
		run(match, 60)
		local Snapshot = require("@game/ReplicatedStorage/Forge/Gameplay/Kingdom/Snapshot")
		local function world()
			local out = {}
			for _, kid in match.sim.kingdomOrder do
				local s = Snapshot.kingdom(match.sim, kid, 0)
				s.kingdom.rulers = nil
				out[kid] = s
			end
			return out
		end
		local before = world()
		match:join(2)
		match:join(3)
		match:leave(1)
		expect(world()).toEqual(before)
	end)

	it("switches kingdom only before the match is Active", function()
		local match = newMatch()
		match:join(1)
		expect({ match:choose(1, "emerald") }).toEqual({ true, "emerald" })
		expect(match.sim.kingdoms.crimson.rulers).toEqual({})
		expect(match.sim.kingdoms.emerald.rulers).toEqual({ 1 })
		expect({ match:choose(2, "emerald") }).toEqual({ false, "not_in_match" })
		expect({ match:choose(1, "k9") }).toEqual({ false, "unknown_kingdom" })
		run(match, 3)
		expect({ match:choose(1, "azure") }).toEqual({ false, "too_late" })
	end)

	it("routes commands to the player's kingdom", function()
		local match = newMatch()
		match:join(1)
		run(match, 3)
		local ok, err, result = match:command(1, "SetPriority", "wood", 3)
		expect(err).toBeNil()
		expect(ok).toBe(true)
		expect(result).toEqual({ resource = "wood", weight = 3 })
		expect(match.sim.kingdoms.crimson.priorities.wood).toBe(3)
		expect({ match:command(99, "SetPriority", "wood", 3) }).toEqual({ false, "not_ruler" })
	end)

	it("rejects commands outside the Active phase", function()
		local match = newMatch()
		match:join(1)
		expect({ match:command(1, "SetAlarm", true) }).toEqual({ false, "match_not_active" })
	end)
end)

describe("Kingdom/Match: victory and results", function()
	it("conquest: the last kingdom standing wins at once", function()
		local match = newMatch()
		match:join(10)
		match:join(20)
		run(match, 3)
		local sim = match.sim
		Military.eliminate(sim, sim.kingdoms.azure, "crimson")
		Military.eliminate(sim, sim.kingdoms.emerald, "crimson")
		Military.eliminate(sim, sim.kingdoms.gold, "crimson")
		run(match, 0.25)
		expect(match.state).toBe("Results")
		local summary = match:summary()
		expect(summary.reason).toBe("conquest")
		expect(summary.winnerKingdomIds).toEqual({ "crimson" })
		expect(summary.ranking[1].kingdomId).toBe("crimson")
		local result = match:result()
		expect(result.mode).toBe("kingdoms")
		expect(result.winners).toEqual({ 10 })
		-- player 20 ruled k2, eliminated first in table order of the three simultaneous falls:
		-- simultaneous eliminations rank by kingdom index (k2 2nd, k3 3rd, k4 4th)
		expect(result.participants).toEqual({
			{ userId = 10, placement = 1, eliminations = 3, survivedSec = math.floor(sim.time) },
			{ userId = 20, placement = 2, eliminations = 0, survivedSec = math.floor(sim.kingdoms.azure.eliminatedAt) },
		})
		local ended = 0
		for _, e in match:drainEvents() do
			if e.name == "MatchEnded" then
				ended += 1
				expect(e.reason).toBe("conquest")
			end
		end
		expect(ended).toBe(1)
		expect(sim.active).toBe(false)
	end)

	it("time: the highest score wins when the clock runs out; eliminated kingdoms rank last", function()
		local match = newMatch({ durationSec = 30, aiRulers = false })
		match:join(1)
		run(match, 2.25)
		local sim = match.sim
		-- give k3 a clear lead and knock out k4 early
		sim.kingdoms.emerald.stats.conquered = 1
		Military.eliminate(sim, sim.kingdoms.gold, "emerald")
		run(match, 31)
		expect(match.state).toBe("Results")
		local summary = match:summary()
		expect(summary.reason).toBe("time")
		expect(summary.winnerKingdomIds).toEqual({ "emerald" })
		local last = summary.ranking[#summary.ranking]
		expect(last.kingdomId).toBe("gold")
		expect(last.alive).toBe(false)
		expect(match:result().winners).toEqual({}) -- player 1 ruled k1, not the winner
	end)

	it("equal top scores share the win", function()
		local match = newMatch({ durationSec = 5, aiRulers = false })
		match:join(1)
		match:join(2)
		match:join(3)
		match:join(4)
		run(match, 2.25)
		-- identical kingdoms with no orders: freeze them so their scores stay equal
		for _, kid in match.sim.kingdomOrder do
			for _, cid in match.sim.kingdoms[kid].citizenIds do
				match.sim.citizens[cid].thinkAt = math.huge
			end
		end
		run(match, 6)
		local summary = match:summary()
		expect(summary.reason).toBe("time")
		expect(#summary.winnerKingdomIds).toBe(4)
		for _, row in summary.ranking do
			expect(row.placement).toBe(1)
		end
		expect(#match:result().winners).toBe(4)
	end)

	it("a ruler who left before the end is not listed as a winner", function()
		local match = newMatch({ durationSec = 5, aiRulers = false })
		match:join(1)
		match:join(2, "crimson")
		run(match, 2.25)
		match.sim.kingdoms.crimson.stats.conquered = 1
		match:leave(2)
		run(match, 6)
		expect(match:result().winners).toEqual({ 1 })
		expect(#match:result().participants).toBe(2)
	end)

	it("starts a fresh world after Results and re-seats the connected players", function()
		local match = newMatch({ durationSec = 5, resultsSec = 2 })
		match:join(1)
		match:join(2)
		run(match, 8)
		expect(match.state).toBe("Results")
		local oldSim = match.sim
		run(match, 2.25)
		expect(match.sim).never.toBe(oldSim)
		expect(match.roundId).toBe("km-2")
		expect(match:kingdomOf(1)).toBe("crimson")
		expect(match:kingdomOf(2)).toBe("azure")
		expect(match.sim.time).toBe(0)
		expect(match:result()).toBeNil()
		F.assertInvariants(match.sim)
	end)
end)

describe("Kingdom/Match: a whole AI match", function()
	it("plays 40 minutes of four AI kingdoms to a result with every invariant intact", function()
		local match = newMatch({ countdownSec = 1 })
		match:join(1)
		local checked = 0
		for i = 1, (2400 + 5) * 4 do
			match:update(0.25)
			if i % 40 == 0 then
				F.assertInvariants(match.sim)
				checked += 1
			end
			if match.state == "Results" then
				break
			end
		end
		expect(match.state).toBe("Results")
		expect(checked).toBeGreaterThan(100)
		local summary = match:summary()
		expect(#summary.winnerKingdomIds).toBeGreaterThanOrEqual(1)
		expect(match.sim.time <= 2400 + 0.25).toBe(true)
	end)
end)
