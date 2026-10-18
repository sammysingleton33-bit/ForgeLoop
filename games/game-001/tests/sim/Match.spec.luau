local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local F = require("./KingdomFixtures")
local Match = require("@game/ReplicatedStorage/Game/Kingdom/Match")
local MatchConfig = require("@game/ReplicatedStorage/Forge/Config/Match")
local PacingConfig = require("@game/ReplicatedStorage/Forge/Config/Pacing")
local Military = require("@game/ReplicatedStorage/Game/Sim/Military")
local Snapshot = require("@game/ReplicatedStorage/Game/Sim/Snapshot")
local Layout = require("@game/ReplicatedStorage/Game/Kingdom/Layout")
local Types = require("@game/ReplicatedStorage/Game/Kingdom/Types")

-- every active phase lasts `each` seconds unless overridden
local function durations(each)
	return { Founding = each, Expansion = each, Conflict = each, Endgame = each }
end

local function newMatch(options)
	local opts = {
		random = Random.new(9),
		mode = "match", -- the full match; slice-mode specs pass mode = "slice"
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

	it("debugSetPhase jumps to an active phase now and re-times the rest (Studio match.phase)", function()
		local match = newMatch({ phaseDurations = durations(10) })
		match:join(1)
		match:update(0.25)
		expect(match.state).toBe("Lobby")
		expect(match:debugSetPhase("Conflict")).toBe(true)
		expect(match.state).toBe("Conflict")
		expect(match.sim.active).toBe(true)
		expect(match:remaining()).toBeNear(10, 1e-6)
		local phases = {}
		for _, e in match:drainEvents() do
			if e.name == "MatchPhaseChanged" then
				table.insert(phases, e.phase)
			end
		end
		expect(phases).toEqual({ "Founding", "Conflict" })
		run(match, 10)
		expect(match.state).toBe("Endgame")
		expect({ match:debugSetPhase("Results") }).toEqual({ false, "not an active phase" })
		run(match, 10)
		expect(match.state).toBe("Results")
		expect({ match:debugSetPhase("Founding") }).toEqual({ false, "the match is over" })
	end)

	it("uses the config defaults per mode without PacingService: match 20 s Lobby + 45 min + 30 s Results", function()
		local plain = { random = Random.new(1) }
		local full = Match.new({ random = Random.new(1), mode = "match" })
		expect(full.durations).toEqual({
			Lobby = 20,
			Founding = 480,
			Expansion = 720,
			Conflict = 900,
			Endgame = 600,
			Results = 30,
		})
		local slice = Match.new({ random = Random.new(1), mode = "slice" })
		expect(slice.durations.Lobby).toBe(0)
		for _, phase in { "Founding", "Expansion", "Conflict", "Endgame", "Results" } do
			expect(slice.durations[phase]).toBe(math.huge)
		end
		expect(Match.new(plain).mode).toBe("match") -- config Match.mode: the full match is the default (D-053 (1))
		expect(function()
			Match.new({ random = Random.new(1), mode = "siege" })
		end).toThrow("mode must be")
	end)

	it("accepts a six-phase table from PacingService and rejects unusable lengths", function()
		local paced = { Lobby = 4, Founding = 6, Expansion = 6, Conflict = 6, Endgame = 6, Results = 2 }
		local match = Match.new({ random = Random.new(1), mode = "match", phaseDurations = paced })
		expect(match.durations).toEqual(paced)
		expect(Match.checkDurations(paced)).toBeNil()
		local untimed = table.clone(paced)
		untimed.Founding = math.huge
		expect(Match.checkDurations(untimed)).toBeNil()
		for phase, bad in { Founding = 0, Conflict = -1, Lobby = -1, Results = 0 / 0 } do
			local broken = table.clone(paced)
			broken[phase] = bad
			expect(Match.checkDurations(broken)).toContain(phase)
		end
		local missing = table.clone(paced)
		missing.Endgame = nil
		expect(Match.checkDurations(missing)).toContain("Endgame")
		expect(Match.checkDurations("x")).toContain("table")
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

	it("has PvP on by default (D-053 (2)); pvp = false is the VS-1 minimum: no war commands exist", function()
		local on = newMatch({ phaseDurations = durations(10), aiRulers = false })
		expect(on.options.pvp).toBe(true)
		expect(on.sim.diplomacy).never.toBeNil()
		local match = newMatch({ phaseDurations = durations(10), aiRulers = false, pvp = false })
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

describe("Kingdom/Match: VS-1 slice mode (PROVISIONAL, CONTRACTS G3)", function()
	local function newSlice(options)
		local opts = { random = Random.new(9), mode = "slice" }
		for k, v in options or {} do
			opts[k] = v
		end
		return Match.new(opts)
	end

	local function citizensOf(match, kingdomId)
		return #match.sim.kingdoms[kingdomId].citizenIds
	end

	it("starts Founding on the first join, without a countdown, and never times a phase", function()
		local match = newSlice()
		run(match, 5)
		expect(match.state).toBe("Lobby") -- nobody here yet
		match:join(1)
		match:update(0.25)
		expect(match.state).toBe("Founding")
		expect(match.sim.active).toBe(true)
		expect(match:remaining()).toBeNil()
		expect(phaseEvents(match)).toEqual({ "Founding" }) -- no CountdownChanged
		run(match, 3600)
		expect(match.state).toBe("Founding")
		expect(match:remaining()).toBeNil()
	end)

	it("spawns a kingdom's starting citizens with its first ruler; empty kingdoms stay empty and idle", function()
		local match = newSlice()
		for _, kid in match.sim.kingdomOrder do
			expect(citizensOf(match, kid)).toBe(0)
			expect(#match.sim.kingdoms[kid].buildingIds).toBeGreaterThan(0) -- starting buildings for all four
		end
		match:join(1) -- crimson
		expect(citizensOf(match, "crimson")).toBe(12)
		run(match, 30)
		match:join(2) -- late joiner, azure
		expect(match:kingdomOf(2)).toBe("azure")
		expect(citizensOf(match, "azure")).toBe(12)
		match:join(3, "crimson") -- a second ruler brings nobody
		expect(citizensOf(match, "crimson")).toBeGreaterThanOrEqual(12)
		local goldBuildings = #match.sim.kingdoms.gold.buildingIds
		run(match, 240)
		expect(citizensOf(match, "emerald")).toBe(0) -- no births without citizens
		expect(citizensOf(match, "gold")).toBe(0)
		expect(#match.sim.kingdoms.gold.buildingIds).toBe(goldBuildings) -- no AI governor builds
		expect(match.sim.kingdoms.gold.stats.gathered.food).toBe(0)
		F.assertInvariants(match.sim)
	end)

	it("ends the slice on the first capture: MatchEnded { winner = capturer } once, then Results stays", function()
		local match = newSlice()
		match:join(1)
		match:update(0.25)
		match:drainEvents()
		local tower = match.sim.objectives.list[1]
		match.sim:setRulerPosition(1, tower.x, tower.z)
		local ended = {}
		for _ = 1, (tower.captureSeconds + 2) * 4 do
			match:update(0.25)
			match.sim:setRulerPosition(1, tower.x, tower.z)
			for _, e in match:drainEvents() do
				if e.name == "MatchEnded" then
					table.insert(ended, e)
				end
			end
		end
		expect(match.state).toBe("Results")
		expect(#ended).toBe(1)
		expect(ended[1].winner).toBe("crimson")
		expect(ended[1].reason).toBe("objective")
		expect(ended[1].winnerKingdomIds).toEqual({ "crimson" })
		expect(match:summary().winner).toBe("crimson")
		expect(match:remaining()).toBeNil()
		run(match, 600)
		expect(match.state).toBe("Results") -- untimed: the slice is over
		for _, e in match:drainEvents() do
			expect(e.name).never.toBe("MatchEnded")
		end
	end)

	it("in match mode a capture does not end the match", function()
		local match = newMatch({ phaseDurations = durations(600), aiRulers = false })
		match:join(1)
		run(match, 3)
		local tower = match.sim.objectives.list[1]
		for _ = 1, (tower.captureSeconds + 2) * 4 do
			match.sim:setRulerPosition(1, tower.x, tower.z)
			match:update(0.25)
		end
		expect(tower.owner).toBe("crimson")
		expect(match.state).toBe("Founding")
	end)

	it("a long march follows the world roads over the bridge (Sim/Nav)", function()
		local match = newSlice()
		match:join(1)
		match:update(0.25)
		local sim = match.sim
		local k = sim.kingdoms.crimson
		local unit = Military.spawnUnit(sim, k, "soldier", k.x, k.z)
		local tower = sim.objectives.list[1]
		assert(match:command(1, "ArmyOrder", "Move", tower.x, tower.z))
		local bridge = Layout.WORLD.features.river.bridges[1].at
		local nearest = math.huge
		for _ = 1, 120 * 4 do
			match:update(0.25)
			nearest = math.min(nearest, math.sqrt((unit.x - bridge.X) ^ 2 + (unit.z - bridge.Y) ^ 2))
		end
		expect(nearest < 15).toBe(true) -- crossed the river at the bridge
		expect(math.sqrt((unit.x - tower.x) ^ 2 + (unit.z - tower.z) ^ 2) < 20).toBe(true) -- and arrived
	end)

	it("puts the kingdoms and the watchtower where the world Layout puts them (G10.1)", function()
		local match = newSlice()
		for _, kid in match.sim.kingdomOrder do
			local k = match.sim.kingdoms[kid]
			local keep = Layout.WORLD.plots[kid].anchors.keep.Position
			expect(k.x).toBeNear(keep.X, 1e-6)
			expect(k.z).toBeNear(keep.Z, 1e-6)
		end
		local tower = match.sim.objectives.list[1]
		local world = Layout.WORLD.objectives[1]
		expect(tower.id).toBe(world.id)
		expect(tower.x).toBeNear(world.cframe.Position.X, 1e-6)
		expect(tower.radius).toBe(world.radius)
		expect(tower.regionId).toBe(world.regionId)
	end)

	it("stands entities on the world surface (Layout.groundY); the square layout stays flat", function()
		expect(newSlice().sim.groundY).toBe(Layout.groundY)
		expect(newMatch({ spacing = 200 }).sim.groundY).toBeNil()
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

-- The rulers of a kingdom whose keep falls (D-053 (3), FL-0125). Military.eliminate is what a destroyed keep runs.
describe("Kingdom/Match: elimination and spectators", function()
	local function eliminate(match, kingdomId, by)
		Military.eliminate(match.sim, match.sim.kingdoms[kingdomId], by)
	end

	local function names(match)
		local out = {}
		for _, e in match:drainEvents() do
			table.insert(out, e.name)
		end
		return out
	end

	it(
		"takes a fallen kingdom's rulers out of it as spectators: no commands, no way back in, the rest play on",
		function()
			local match = newMatch({ phaseDurations = durations(60), aiRulers = false, pvp = true })
			for userId = 1, 3 do
				match:join(userId) -- crimson, azure, emerald
			end
			run(match, 3)
			match:drainEvents()
			eliminate(match, "crimson", "azure")
			match:update(0.25)
			local events = match:drainEvents()
			local fallen
			for _, e in events do
				if e.name == "RulerEliminated" then
					fallen = e
				end
			end
			expect(fallen).never.toBeNil()
			expect(fallen.userId).toBe(1)
			expect(fallen.kingdomId).toBe("crimson")
			expect(fallen.byKingdomId).toBe("azure")
			expect(match:kingdomOf(1)).toBeNil()
			expect(match.sim.kingdoms.crimson.rulers).toEqual({})
			local spectator = match:spectatorOf(1)
			expect(spectator.kingdomId).toBe("crimson")
			expect(spectator.by).toBe("azure")
			expect(match:spectatorOf(2)).toBeNil()
			-- no command rights; and no way back in, not by joining, not by leaving and joining again, not as a party
			local ok = match:command(1, "SetAlarm", true)
			expect(ok).toBe(false)
			expect({ match:join(1) }).toEqual({ false, "eliminated" })
			match:leave(1)
			expect({ match:join(1) }).toEqual({ false, "eliminated" })
			expect(match:joinParty({ 1 }, "azure")).toBe(true)
			expect(match:kingdomOf(1)).toBeNil()
			-- the others carry on, and the spectator is still one of the match's players
			expect(match:kingdomOf(2)).toBe("azure")
			expect(match:kingdomOf(3)).toBe("emerald")
			expect(match.state).toBe("Founding")
			run(match, 5)
			expect(match.state).toBe("Founding")
		end
	)

	it("seats late joiners only in kingdoms still standing, and answers match_full when none has room", function()
		local match = newMatch({ phaseDurations = durations(60), aiRulers = false })
		match:join(1)
		run(match, 3)
		eliminate(match, "emerald")
		match:update(0.25)
		for userId = 10, 20 do
			local ok, kingdomId = match:join(userId)
			expect(ok).toBe(true)
			expect(kingdomId).never.toBe("emerald") -- three standing kingdoms: 3 x 4 = 12 seats, user 1 has one
		end
		local rulers = #match.sim.kingdoms.crimson.rulers
			+ #match.sim.kingdoms.azure.rulers
			+ #match.sim.kingdoms.gold.rulers
		expect(rulers).toBe(12)
		expect({ match:join(21) }).toEqual({ false, "match_full" })
		expect(match:spectatorOf(21)).toBeNil() -- a full server is not an elimination: the host keeps them watching
	end)

	it("seats a player who was turned away (match_full) in the next match when a seat is free (FORGE-07 M1)", function()
		local match = newMatch({ phaseDurations = durations(60), aiRulers = false })
		for userId = 1, 16 do
			expect((match:join(userId))).toBe(true) -- 4 x 4
		end
		run(match, 3)
		eliminate(match, "crimson", "azure") -- users 1, 5, 9, 13 become spectators
		match:update(0.25)
		match:leave(1)
		match:leave(5)
		expect({ match:join(100) }).toEqual({ false, "match_full" }) -- 12 rulers in 12 seats
		eliminate(match, "azure", "gold")
		eliminate(match, "emerald", "gold")
		match:update(0.25)
		expect(match.state).toBe("Results")
		run(match, 30)
		expect(match.state).toBe("Lobby")
		expect(match:kingdomOf(100)).never.toBeNil() -- 16 seats, 14 players before them
		expect(match:kingdomOf(9)).never.toBeNil()
		expect(match:spectatorOf(9)).toBeNil()
		local seated = 0
		for _, kingdom in match.sim.kingdoms do
			seated += #kingdom.rulers
		end
		expect(seated).toBe(15)
		expect(#match.waiting).toBe(0)
	end)

	it("keeps those who still find no room waiting, in order, and forgets a waiting player who leaves", function()
		local match = newMatch({ phaseDurations = durations(60), aiRulers = false })
		for userId = 1, 16 do
			match:join(userId)
		end
		expect({ match:join(100) }).toEqual({ false, "match_full" })
		expect({ match:join(101) }).toEqual({ false, "match_full" })
		expect({ match:join(100) }).toEqual({ false, "match_full" }) -- asking again does not queue twice
		expect(match.waiting).toEqual({ 100, 101 })
		match:leave(101)
		expect(match.waiting).toEqual({ 100 })
		match:restart() -- a new world: 16 players fill it again, 100 still waits
		expect(match:kingdomOf(100)).toBeNil()
		expect(match.waiting).toEqual({ 100 })
		match:leave(3)
		match:restart()
		expect(match:kingdomOf(100)).never.toBeNil()
		expect(match.waiting).toEqual({})
	end)

	it("ends the match at once when one kingdom is left (conquest), ranking the fallen by who fell last", function()
		local match = newMatch({ phaseDurations = durations(60), aiRulers = false })
		match:join(1)
		run(match, 3)
		eliminate(match, "gold", "crimson")
		match:update(0.25)
		eliminate(match, "emerald", "crimson")
		match:update(0.25)
		expect(match.state).toBe("Founding")
		eliminate(match, "azure", "crimson")
		match:update(0.25)
		expect(match.state).toBe("Results")
		local summary = match:summary()
		expect(summary.reason).toBe("conquest")
		expect(summary.winner).toBe("crimson")
		local order = {}
		for _, row in summary.ranking do
			table.insert(order, row.kingdomId)
		end
		expect(order).toEqual({ "crimson", "azure", "emerald", "gold" })
		expect(summary.ranking[1].placement).toBe(1)
	end)

	it("lets every keep fall in one tick: a draw with no winner, still exactly one MatchEnded", function()
		local match = newMatch({ phaseDurations = durations(60), aiRulers = false })
		match:join(1)
		run(match, 3)
		match:drainEvents()
		for _, kid in match.sim.kingdomOrder do
			eliminate(match, kid)
		end
		match:update(0.25)
		expect(match.state).toBe("Results")
		expect(match:summary().winner).toBeNil()
		expect(#match:summary().winnerKingdomIds).toBe(0)
		local ended = 0
		for _, name in names(match) do
			if name == "MatchEnded" then
				ended += 1
			end
		end
		expect(ended).toBe(1)
		expect(match:result().winners).toEqual({})
	end)

	it("forgets the spectators when the next world begins: everyone is seated again", function()
		local match = newMatch({ phaseDurations = durations(60), aiRulers = false, resultsSec = 3 })
		match:join(1)
		match:join(2)
		run(match, 3)
		for _, kid in { "azure", "emerald", "gold" } do
			eliminate(match, kid, "crimson")
		end
		match:update(0.25)
		expect(match.state).toBe("Results")
		expect(match:spectatorOf(2)).never.toBeNil()
		run(match, 3.5)
		expect(match.state).toBe("Lobby")
		expect(match:spectatorOf(2)).toBeNil()
		expect(match:kingdomOf(1)).never.toBeNil()
		expect(match:kingdomOf(2)).never.toBeNil()
		expect(match.sim.time).toBe(0)
	end)

	it("makes a command that arrives in the tick the keep falls a refusal, not a half-applied change", function()
		local match = newMatch({ phaseDurations = durations(60), aiRulers = false })
		match:join(1)
		run(match, 3)
		eliminate(match, "crimson", "azure")
		local ok, err = match:command(1, "PlaceBuilding", "house", 30, 30)
		expect(ok).toBe(false)
		expect(err == "kingdom_eliminated" or err == "not_ruler").toBe(true)
		expect(match.sim:balance("crimson", "wood")).toBe(0) -- plundered by the fall, and nothing charged after it
		expect(#match.sim.kingdoms.crimson.buildingIds).toBe(0)
		expect(match.sim.treasury:audit("crimson")).toBe(true)
	end)
end)

-- The Crown Arena hooks (FL-0125); FL-0071's ArenaService is the real host.
describe("Kingdom/Match: Crown Arena hooks", function()
	-- a host that records what it is asked; `answer` is what beginArena returns
	local function arenaHost(answer: any)
		local host = { began = {}, cancelled = {} }
		host.beginArena = function(qualifiers)
			table.insert(host.began, qualifiers)
			if answer == "throw" then
				error("the arena is not ready")
			end
			return answer
		end
		host.cancelArena = function(reason)
			table.insert(host.cancelled, reason)
		end
		return host
	end

	-- a one-human match run to the last second of Endgame, with Crown Points: gold 50 > azure 30 > crimson 10
	local function atEndgame(host, extra)
		local options = { phaseDurations = durations(4), aiRulers = false, arena = host }
		for k, v in extra or {} do
			options[k] = v
		end
		local match = newMatch(options)
		match:join(1)
		match.sim:addCrownPoints("gold", 50, "spec")
		match.sim:addCrownPoints("azure", 30, "spec")
		match.sim:addCrownPoints("crimson", 10, "spec")
		return match
	end

	it("hears a host that reports the result from inside beginArena (FORGE-07 L1)", function()
		local match
		local host = arenaHost(true)
		host.beginArena = function(qualifiers)
			table.insert(host.began, qualifiers)
			expect(match:arenaEnded(qualifiers[2])).toBe(true)
			return true
		end
		match = atEndgame(host)
		run(match, 2 + 16 + 0.5)
		expect(match.state).toBe("Results")
		expect(match:summary().reason).toBe("arena")
		expect(match:summary().winner).toBe("azure")
		expect(match:inArena()).toBe(false)
	end)

	it("drops the arena again when the host declines or throws, so a later arenaEnded is refused", function()
		for _, answer in { false, "throw" } do
			local host = arenaHost(answer)
			local match = atEndgame(host)
			run(match, 2 + 16 + 0.5)
			expect(match.state).toBe("Results")
			expect(match:summary().reason).toBe("time")
			expect(match:inArena()).toBe(false)
		end
	end)

	it("asks the host to begin the duel between the top two by Crown Points, and waits for arenaEnded", function()
		local host = arenaHost(true)
		local match = atEndgame(host)
		run(match, 2 + 16 + 0.5)
		expect(match.state).toBe("Endgame")
		expect(host.began).toEqual({ { "gold", "azure" } })
		expect(match:inArena()).toBe(true)
		run(match, 30) -- the arena takes as long as it takes (up to arenaMaxSeconds): the match waits
		expect(match.state).toBe("Endgame")
		expect(#host.began).toBe(1) -- asked once, not every tick
		match:drainEvents()
		expect(match:arenaEnded("azure")).toBe(true)
		expect(match.state).toBe("Results")
		local summary = match:summary()
		expect(summary.reason).toBe("arena")
		expect(summary.winner).toBe("azure")
		expect(summary.ranking[1].kingdomId).toBe("azure") -- the champion's kingdom first, whatever the points
		expect(summary.ranking[1].placement).toBe(1)
		expect(summary.ranking[2].kingdomId).toBe("gold")
		expect(summary.ranking[2].placement).toBe(2)
		expect(#summary.ranking).toBe(4)
		expect(match:inArena()).toBe(false)
		expect(match:arenaEnded("gold")).toBe(false) -- nothing is running any more
	end)

	it("falls back to the Crown Points result when the duel has no winner or names a kingdom outside it", function()
		for _, winner in { "nobody", "crimson", "" } do
			local match = atEndgame(arenaHost(true))
			run(match, 2 + 16 + 0.5)
			expect(match:inArena()).toBe(true)
			expect(match:arenaEnded(winner)).toBe(true)
			expect(match:summary().reason).toBe("time")
			expect(match:summary().winner).toBe("gold") -- most Crown Points
		end
		local match = atEndgame(arenaHost(true))
		run(match, 2 + 16 + 0.5)
		expect(match:arenaEnded(nil)).toBe(true) -- a draw
		expect(match:summary().winner).toBe("gold")
	end)

	it("gives the Crown Points result at once when there is no host, the host declines, or it fails", function()
		for _, answer in { false, "throw", "yes" } do
			local host = arenaHost(answer)
			local match = atEndgame(host)
			run(match, 2 + 16 + 0.5)
			expect(match.state).toBe("Results")
			expect(match:summary().reason).toBe("time")
			expect(match:summary().winner).toBe("gold")
			expect(#host.began).toBe(1)
			expect(match:inArena()).toBe(false)
		end
		local none = atEndgame(nil)
		run(none, 2 + 16 + 0.5)
		expect(none.state).toBe("Results")
		expect(none:summary().reason).toBe("time")
	end)

	it("cuts off an arena that never reports after arenaMaxSeconds, and tells the host", function()
		local host = arenaHost(true)
		local match = atEndgame(host, { arenaMaxSeconds = 20 })
		run(match, 2 + 16 + 0.5)
		expect(match:inArena()).toBe(true)
		run(match, 19)
		expect(match.state).toBe("Endgame")
		run(match, 2)
		expect(match.state).toBe("Results")
		expect(match:summary().reason).toBe("time")
		expect(match:summary().winner).toBe("gold")
		expect(host.cancelled).toEqual({ "timeout" })
	end)

	it("ends by conquest, not by duel, when a kingdom takes the rest during the arena; the host is told", function()
		local host = arenaHost(true)
		local match = atEndgame(host)
		run(match, 2 + 16 + 0.5)
		expect(match:inArena()).toBe(true)
		for _, kid in { "azure", "emerald", "crimson" } do
			Military.eliminate(match.sim, match.sim.kingdoms[kid], "gold")
		end
		match:update(0.25)
		expect(match.state).toBe("Results")
		expect(match:summary().reason).toBe("conquest")
		expect(match:summary().winner).toBe("gold")
		expect(host.cancelled).toEqual({ "conquest" })
		expect(match:arenaEnded("gold")).toBe(false)
	end)

	it("never asks for a duel when the match was already decided by conquest", function()
		local host = arenaHost(true)
		local match = atEndgame(host)
		run(match, 3) -- past the Lobby countdown
		for _, kid in { "azure", "emerald", "crimson" } do
			Military.eliminate(match.sim, match.sim.kingdoms[kid], "gold")
		end
		match:update(0.25)
		expect(match.state).toBe("Results")
		expect(host.began).toEqual({})
		expect(host.cancelled).toEqual({})
	end)

	it(
		"never asks for a duel with fewer than two kingdoms standing (conquest off): the survivor takes it on points",
		function()
			local host = arenaHost(true)
			local match = atEndgame(host, { victory = { conquest = false, crownPointsAtEnd = true } })
			run(match, 3)
			for _, kid in { "azure", "emerald", "crimson" } do
				Military.eliminate(match.sim, match.sim.kingdoms[kid], "gold")
			end
			match:update(0.25)
			expect(match.state).never.toBe("Results") -- with conquest off the match plays on to the end of Endgame
			run(match, 2 + 16 + 0.5)
			expect(match.state).toBe("Results")
			expect(host.began).toEqual({})
			expect(match:summary().reason).toBe("time")
			expect(match:summary().winner).toBe("gold")
		end
	)

	it("lets the host be set after the match is built, and a new world forgets the duel", function()
		local host = arenaHost(true)
		local match = atEndgame(nil, { resultsSec = 2 })
		match:setArenaHost(host)
		run(match, 2 + 16 + 0.5)
		expect(#host.began).toBe(1)
		expect(match:arenaEnded("gold")).toBe(true)
		run(match, 2.5)
		expect(match.state).toBe("Lobby")
		expect(match:inArena()).toBe(false)
		expect(#match:arenaQualifiers()).toBe(2) -- the fresh world has four kingdoms standing
	end)
end)

describe("Kingdom/Match: restart and the debug phase jump", function()
	it("restarts in another mode with a fresh world, the players seated again", function()
		local match = newMatch({ phaseDurations = durations(60) }) -- the mode's own defaults: governors on
		match:join(1)
		match:join(2)
		run(match, 30)
		expect(match.state).toBe("Founding")
		local oldSim = match.sim
		match:drainEvents()
		match:restart("slice")
		expect(match.mode).toBe("slice")
		expect(match.state).toBe("Lobby")
		expect(rawequal(match.sim, oldSim)).toBe(false)
		expect(match.sim.time).toBe(0)
		expect(match:kingdomOf(1)).never.toBeNil()
		expect(match:kingdomOf(2)).never.toBeNil()
		expect(match.durations.Founding).toBe(math.huge)
		expect(match.options.aiRulers).toBe(false) -- slice: the AI kingdoms stay idle
		expect(match.options.pvp).toBe(true) -- (PvP is its own setting; the slice never reaches Conflict)
		local flagged = false
		for _, e in match:drainEvents() do
			if e.name == "MatchPhaseChanged" and e.phase == "Lobby" and e.newWorld then
				flagged = true -- the host rebuilds its view and teams on this
			end
		end
		expect(flagged).toBe(true)
		-- slice rules: starting citizens appear with the first ruler; Founding starts without the Endgame wait
		run(match, 3) -- (the Lobby countdown of 2 s is this spec's countdownSec override)
		expect(match.state).toBe("Founding")
		-- and back to the full match: all four kingdoms populated, governors on, PvP on
		match:restart("match")
		expect(match.mode).toBe("match")
		expect(match.options.aiRulers).toBe(true)
		expect(match.options.pvp).toBe(true)
		expect(match.sim.diplomacy).never.toBeNil()
		for _, kid in match.sim.kingdomOrder do
			expect(#match.sim.kingdoms[kid].citizenIds >= 12).toBe(true)
		end
		expect(function()
			match:restart("siege")
		end).toThrow("mode must be")
	end)

	it("moves Diplomacy's war grace with the phase jump: war is open the moment Conflict is jumped to", function()
		local match = newMatch({ aiRulers = false, pvp = true })
		match:join(1)
		run(match, 3)
		expect(match.state).toBe("Founding")
		expect({ match:command(1, "DeclareWar", "azure") }).toEqual({ false, "grace_period" })
		expect(match:debugSetPhase("Conflict")).toBe(true)
		expect(match.state).toBe("Conflict")
		expect(match:command(1, "DeclareWar", "azure")).toBe(true)
		-- jumping back closes it again for a kingdom not yet at war
		local other = newMatch({ aiRulers = false, pvp = true })
		other:join(1)
		run(other, 3)
		other:debugSetPhase("Endgame")
		other:debugSetPhase("Founding")
		expect({ other:command(1, "DeclareWar", "azure") }).toEqual({ false, "grace_period" })
	end)
end)

describe("Kingdom/Match: the shipped defaults (FL-0125, D-053)", function()
	it("is the full match by default: match mode, PvP, governors, citizens in all four kingdoms", function()
		expect(MatchConfig.mode).toBe("match")
		expect(MatchConfig.pvp.enabled).toBe(true)
		local match = Match.new({ random = Random.new(1) })
		expect(match.mode).toBe("match")
		expect(match.options.pvp).toBe(true)
		expect(match.options.aiRulers).toBe(true)
		expect(match.options.populateOnJoin).toBe(false)
		expect(match.options.endOnFirstCapture).toBe(false)
		expect(match.sim.diplomacy).never.toBeNil()
		expect(match.sim.rulerAI).never.toBeNil()
		for _, kid in match.sim.kingdomOrder do
			expect(#match.sim.kingdoms[kid].citizenIds >= 12).toBe(true) -- Founding does not wait for a human
		end
		-- and the real phase lengths are Pacing's
		for phase, seconds in PacingConfig.modes.match do
			expect(match.durations[phase]).toBe(seconds)
		end
	end)
end)
