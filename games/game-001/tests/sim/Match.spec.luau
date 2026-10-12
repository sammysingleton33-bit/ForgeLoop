local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local F = require("./KingdomFixtures")
local Match = require("@game/ReplicatedStorage/Game/Kingdom/Match")
local Military = require("@game/ReplicatedStorage/Game/Sim/Military")
local Snapshot = require("@game/ReplicatedStorage/Game/Sim/Snapshot")
local Types = require("@game/ReplicatedStorage/Game/Kingdom/Types")

-- every active phase lasts `each` seconds unless overridden
local function durations(each)
	return { Founding = each, Expansion = each, Conflict = each, Endgame = each }
end

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

local function phaseEvents(match)
	local out = {}
	for _, e in match:drainEvents() do
		if e.name == "MatchPhaseChanged" then
			table.insert(out, e.phase)
		elseif e.name == "CountdownChanged" then
			table.insert(out, if e.running then "countdown" else "cancelled")
		end
	end
	return out
end

describe("Kingdom/Match: phases", function()
	it("starts in the Lobby with four frozen kingdoms until enough players join", function()
		local match = newMatch({ minPlayers = 2 })
		expect(match.state).toBe("Lobby")
		expect(#match.sim.kingdomOrder).toBe(4)
		expect(match.sim.kingdomOrder).toEqual({ "crimson", "azure", "emerald", "gold" })
		expect(match.sim.active).toBe(false)
		match:join(1)
		run(match, 5)
		expect(match.state).toBe("Lobby")
		expect(match:remaining()).toBeNil()
		expect(match.sim.time).toBe(0)
	end)

	it("counts down in the Lobby, then runs Founding -> Expansion -> Conflict -> Endgame -> Results", function()
		local match = newMatch({ phaseDurations = durations(5), resultsSec = 3 })
		match:join(1)
		run(match, 0.25)
		expect(match.state).toBe("Lobby")
		expect(match:remaining()).toBeNear(2)
		run(match, 2)
		expect(match.state).toBe("Founding")
		expect(match.sim.active).toBe(true)
		expect(match:remaining()).toBeNear(5)
		run(match, 5)
		expect(match.state).toBe("Expansion")
		run(match, 10)
		expect(match.state).toBe("Endgame")
		run(match, 5)
		expect(match.state).toBe("Results")
		expect(phaseEvents(match)).toEqual({ "countdown", "Founding", "Expansion", "Conflict", "Endgame", "Results" })
		expect(match.sim.time).toBeNear(20, 0.26)
	end)

	it("takes default phase lengths of 8/12/15/10 minutes (45 min) and rejects bad ones", function()
		local match = newMatch()
		expect(match.phaseEnds).toEqual({ Founding = 480, Expansion = 1200, Conflict = 2100, Endgame = 2700 })
		expect(function()
			newMatch({ phaseDurations = { Siege = 5 } })
		end).toThrow("unknown phase")
		expect(function()
			newMatch({ phaseDurations = { Founding = 0 } })
		end).toThrow("must be > 0")
	end)

	it("cancels the countdown when players drop below the minimum", function()
		local match = newMatch({ minPlayers = 2 })
		match:join(1)
		match:join(2)
		run(match, 1)
		expect(match:remaining()).toBeTruthy()
		match:leave(2)
		expect(match:remaining()).toBeNil()
		expect(phaseEvents(match)).toEqual({ "countdown", "cancelled" })
		run(match, 5)
		expect(match.state).toBe("Lobby")
	end)

	it("only uses the contract MatchPhase names", function()
		local match = newMatch({ phaseDurations = durations(2), resultsSec = 1 })
		match:join(1)
		local seen = {}
		for _ = 1, 80 do
			match:update(0.25)
			seen[match.state] = true
		end
		for state in seen do
			expect(Types.is("MATCH_PHASES", state)).toBe(true)
		end
		expect(seen.Results).toBe(true)
	end)

	it("keeps PvP off by default (PROVISIONAL, BRIEF §16.2): no war commands exist", function()
		local match = newMatch({ phaseDurations = durations(10), aiRulers = false })
		match:join(1)
		run(match, 25)
		expect(match.state).toBe("Conflict")
		expect({ match:command(1, "DeclareWar", "azure") }).toEqual({ false, "unknown_command" })
		expect(match.sim.diplomacy).toBeNil()
	end)

	it("with PvP enabled, opens war declarations only from Conflict on", function()
		local match = newMatch({ phaseDurations = durations(10), aiRulers = false, pvp = true })
		match:join(1)
		run(match, 2.25)
		expect({ match:command(1, "DeclareWar", "azure") }).toEqual({ false, "grace_period" })
		run(match, 20) -- Founding + Expansion
		expect(match.state).toBe("Conflict")
		expect(match:command(1, "DeclareWar", "azure")).toBe(true)
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

	it("balances 1..16 players evenly and refuses the seventeenth", function()
		local match = newMatch()
		for n = 1, 16 do
			assert(match:join(n))
			local counts = {}
			for _, kid in match.sim.kingdomOrder do
				counts[kid] = #match.sim.kingdoms[kid].rulers
			end
			local lo, hi = math.huge, 0
			for _, c in counts do
				lo, hi = math.min(lo, c), math.max(hi, c)
			end
			expect(hi - lo <= 1).toBe(true)
		end
		expect({ match:join(17) }).toEqual({ false, "match_full" })
	end)

	it("keeps a party together when one kingdom has room for all of them", function()
		local match = newMatch()
		match:join(1)
		match:join(2)
		match:join(3)
		local ok, seated = match:joinParty({ 10, 11, 12 })
		expect(ok).toBe(true)
		expect(seated[10]).toBe(seated[11])
		expect(seated[11]).toBe(seated[12])
		expect(seated[10]).toBe("gold") -- the empty kingdom
		expect({ match:joinParty({ 20, 21, 22, 23, 24 }) }).toEqual({ false, "party_too_large" })
	end)

	it("splits a party only when no kingdom can take it whole", function()
		local match = newMatch({ maxRulersPerKingdom = 2 })
		for n = 1, 6 do
			match:join(n) -- 2, 2, 1, 1
		end
		local ok, seated = match:joinParty({ 30, 31 })
		expect(ok).toBe(true)
		expect(seated[30]).never.toBe(seated[31])
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
		match:join(1) -- crimson
		match:join(2) -- azure
		match:leave(2)
		match:join(3) -- azure is the emptiest -> azure
		match:join(2)
		expect(match:kingdomOf(2)).toBe("azure")
	end)

	it("joining and leaving change nothing but the ruler lists", function()
		local match = newMatch()
		match:join(1)
		run(match, 60)
		local function world()
			local out = {}
			for _, kid in match.sim.kingdomOrder do
				local s = Snapshot.kingdom(match.sim, kid, 0)
				s.kingdom.rulers = nil
				s.kingdom.isAI = nil
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

	it("switches kingdom only in the Lobby", function()
		local match = newMatch()
		match:join(1)
		expect({ match:choose(1, "emerald") }).toEqual({ true, "emerald" })
		expect(match.sim.kingdoms.crimson.rulers).toEqual({})
		expect(match.sim.kingdoms.emerald.rulers).toEqual({ 1 })
		expect({ match:choose(2, "emerald") }).toEqual({ false, "not_in_match" })
		expect({ match:choose(1, "nowhere") }).toEqual({ false, "unknown_kingdom" })
		run(match, 3)
		expect(match.state).toBe("Founding")
		expect({ match:choose(1, "azure") }).toEqual({ false, "too_late" })
	end)

	it("routes commands to the player's kingdom and refuses them outside active phases", function()
		local match = newMatch()
		match:join(1)
		expect({ match:command(1, "SetAlarm", true) }).toEqual({ false, "match_not_active" })
		run(match, 3)
		local ok, err, result = match:command(1, "SetPriority", "wood", 3)
		expect(err).toBeNil()
		expect(ok).toBe(true)
		expect(result).toEqual({ resource = "wood", weight = 3 })
		expect(match.sim.kingdoms.crimson.priorities.wood).toBe(3)
		expect({ match:command(99, "SetPriority", "wood", 3) }).toEqual({ false, "not_ruler" })
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
		expect(summary.winner).toBe("crimson")
		expect(summary.winnerKingdomIds).toEqual({ "crimson" })
		expect(summary.standings[1]).toEqual({ kingdom = "crimson", crownPoints = sim.kingdoms.crimson.crownPoints })
		expect(sim.kingdoms.crimson.crownPoints).toBeGreaterThanOrEqual(3 * sim.catalog.crown.conquest)
		expect(summary.durationSec).toBe(math.floor(sim.time))
		local result = match:result()
		expect(result.mode).toBe("kingdoms")
		expect(result.winners).toEqual({ 10 })
		-- simultaneous falls rank by kingdom order: azure 2nd, emerald 3rd, gold 4th
		expect(result.participants).toEqual({
			{ userId = 10, placement = 1, eliminations = 3, survivedSec = math.floor(sim.time) },
			{ userId = 20, placement = 2, eliminations = 0, survivedSec = math.floor(sim.kingdoms.azure.eliminatedAt) },
		})
		local ended = 0
		for _, e in match:drainEvents() do
			if e.name == "MatchEnded" then
				ended += 1
				expect(e.reason).toBe("conquest")
				expect(e.winner).toBe("crimson")
			end
		end
		expect(ended).toBe(1)
		expect(sim.active).toBe(false)
	end)

	it("time: the most Crown Points wins when Endgame ends; fallen kingdoms rank last", function()
		local match = newMatch({ phaseDurations = durations(5), aiRulers = false })
		match:join(1)
		run(match, 2.25)
		local sim = match.sim
		sim:addCrownPoints("emerald", 50, "test")
		Military.eliminate(sim, sim.kingdoms.gold, "emerald")
		run(match, 21)
		expect(match.state).toBe("Results")
		local summary = match:summary()
		expect(summary.reason).toBe("time")
		expect(summary.winner).toBe("emerald")
		local last = summary.ranking[#summary.ranking]
		expect(last.kingdomId).toBe("gold")
		expect(last.alive).toBe(false)
		expect(match:result().winners).toEqual({}) -- player 1 ruled crimson, not the winner
	end)

	it("honours the PROVISIONAL victory flags (BRIEF §16.4): no conquest win when it is off", function()
		local match = newMatch({
			phaseDurations = durations(3),
			aiRulers = false,
			victory = { conquest = false, crownPointsAtEnd = true },
		})
		match:join(1)
		run(match, 2.25)
		local sim = match.sim
		for _, kid in { "azure", "emerald", "gold" } do
			Military.eliminate(sim, sim.kingdoms[kid], "crimson")
		end
		run(match, 1)
		expect(match.state).never.toBe("Results") -- keeps playing to the timer
		run(match, 12)
		expect(match:summary().reason).toBe("time")
	end)

	it("equal top Crown Points share the win (no single winner)", function()
		local match = newMatch({ phaseDurations = durations(2), aiRulers = false })
		for i = 1, 4 do
			match:join(i)
		end
		run(match, 2.25)
		-- identical kingdoms with no orders: freeze them so nobody earns points
		for _, kid in match.sim.kingdomOrder do
			for _, cid in match.sim.kingdoms[kid].citizenIds do
				match.sim.citizens[cid].thinkAt = math.huge
			end
		end
		run(match, 9)
		local summary = match:summary()
		expect(summary.reason).toBe("time")
		expect(summary.winner).toBeNil()
		expect(#summary.winnerKingdomIds).toBe(4)
		for _, row in summary.ranking do
			expect(row.placement).toBe(1)
		end
		expect(#match:result().winners).toBe(4)
	end)

	it("a ruler who left before the end is not listed as a winner", function()
		local match = newMatch({ phaseDurations = durations(2), aiRulers = false })
		match:join(1)
		match:join(2, "crimson")
		run(match, 2.25)
		match.sim:addCrownPoints("crimson", 10, "test")
		match:leave(2)
		run(match, 9)
		expect(match:result().winners).toEqual({ 1 })
		expect(#match:result().participants).toBe(2)
	end)

	it("starts a fresh world after Results and re-seats the connected players", function()
		local match = newMatch({ phaseDurations = durations(2), resultsSec = 2 })
		match:join(1)
		match:join(2)
		run(match, 11)
		expect(match.state).toBe("Results")
		local oldSim = match.sim
		run(match, 2.25)
		expect(match.sim).never.toBe(oldSim)
		expect(match.state).toBe("Lobby")
		expect(match.roundId).toBe("km-2")
		expect(match:kingdomOf(1)).toBe("crimson")
		expect(match:kingdomOf(2)).toBe("azure")
		expect(match.sim.time).toBe(0)
		expect(match:result()).toBeNil()
		F.assertInvariants(match.sim)
	end)
end)

describe("Kingdom/Match: a whole AI match", function()
	it("plays a full 45-minute match of four AI kingdoms to a result with every invariant intact", function()
		local match = newMatch({ countdownSec = 1 })
		match:join(1)
		local checked = 0
		for i = 1, (2700 + 5) * 4 do
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
		expect(match.sim.time <= 2700 + 0.25).toBe(true)
	end)
end)
