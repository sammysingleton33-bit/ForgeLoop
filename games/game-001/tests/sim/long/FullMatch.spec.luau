--[[
	FullMatch (FL-0125, D-053): the shipped defaults play the real match. Four AI kingdoms, no human, the real phase
	lengths of config Pacing / Match (Lobby 20 s, Founding 480, Expansion 720, Conflict 900, Endgame 600, Results 30),
	stepped at the server's own tick (config Match.tickSeconds) the way MatchHost does. The run is deterministic
	(seeded Random, injected clock).

	What it pins:
	  - the defaults are the full match: mode "match", PvP on, AI governors on, starting citizens in every kingdom;
	  - the phases come in order at the real times;
	  - wars are declared only once Conflict has begun, and a war is fought: units die;
	  - the match ends exactly once (a kingdom takes the rest by conquest, or the Crown Points rule at the end of
	    Endgame decides), with a ranking of all four kingdoms;
	  - a fallen kingdom is gone cleanly (no citizens, units or buildings; its treasury audits);
	  - the cost of a server tick at the busiest stretch (BRIEF §14: <= 4 ms at p99 per tick, 300 entities).
	The measured numbers are printed once per run, so the PR / FORGE-05's B20 record can quote them.
]]

local T = require("../../../../../roblox/tests/harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local Match = require("@game/ReplicatedStorage/Game/Kingdom/Match")
local MatchConfig = require("@game/ReplicatedStorage/Forge/Config/Match")

local TICK = MatchConfig.tickSeconds
local BUDGET_MS = 4 -- BRIEF §14: server sim <= 4 ms at p99 per tick at 300 entities
-- What the spec enforces: twice the target, because the gate's machine is shared and the clock here is CPU time of a
-- headless Lune process, not a Studio server. The measured value is printed, and a drift above BUDGET_MS shows up in
-- the PR / B20 record long before it trips this.
local CANARY_MS = 2 * BUDGET_MS
local BUDGET_ENTITIES = 300 -- BRIEF §14: entities per server (about 75 per kingdom)
-- D-055: 60 citizens + 15 soldiers per kingdom keep the server at BUDGET_ENTITIES (4 x 75). The cap holds the line;
-- raising it needs a measured Studio or private-test run, never a headless one.
local BUSY_ENTITIES = 250 -- a tick counts as "peak" at this many citizens + soldiers

local function percentile(sorted: { number }, p: number): number
	return sorted[math.max(1, math.ceil(#sorted * p))]
end

describe("FullMatch: the shipped defaults play the real match (FL-0125, D-053)", function()
	it("plays four AI kingdoms through every phase: wars in Conflict, battles, one end", function()
		local match = Match.new({
			random = Random.new(11),
			minPlayers = 0, -- nobody joins: every kingdom is a governor's
			now = function()
				return 1700000000
			end,
		})
		local sim = match.sim
		local phaseAt: { [string]: number } = {}
		local counts: { [string]: number } = {}
		local wars: { { time: number, phase: string } } = {}
		local eliminated: { string } = {}
		local ended = 0
		local ms: { number } = {}
		local busy: { number } = {}
		local peakEntities, peakEntitiesMs, peakBuildings = 0, 0, 0
		local slowest: { { ms: number, time: number, entities: number } } = {}
		local steps = 0
		while match.state ~= "Results" and steps < 200000 do
			local started = os.clock()
			match:update(TICK)
			local cost = (os.clock() - started) * 1000
			steps += 1
			for _, event in match:drainEvents() do
				counts[event.name] = (counts[event.name] or 0) + 1
				if event.name == "MatchPhaseChanged" then
					phaseAt[event.phase] = sim.time
				elseif event.name == "WarDeclared" then
					table.insert(wars, { time = sim.time, phase = match.state })
				elseif event.name == "KingdomEliminated" then
					table.insert(eliminated, event.kingdomId)
				elseif event.name == "MatchEnded" then
					ended += 1
				end
			end
			if sim.active then
				local entities = #sim.citizenOrder + #sim.unitOrder
				table.insert(ms, cost)
				if entities >= BUSY_ENTITIES then
					table.insert(busy, cost)
				end
				if entities > peakEntities then
					peakEntities, peakEntitiesMs = entities, cost
				end
				peakBuildings = math.max(peakBuildings, #sim.buildingOrder)
				if cost > 6 then -- keep the few slow ones (for the report: when, and how many rigs)
					table.insert(slowest, { ms = cost, time = sim.time, entities = entities })
				end
			end
		end

		-- the phases, in order, at the real times (the Lobby countdown does not run the simulation)
		expect(match.state).toBe("Results")
		local D = match.durations
		expect(phaseAt.Founding).toBe(0)
		expect(math.abs(phaseAt.Expansion - D.Founding) < 0.2).toBe(true)
		expect(math.abs(phaseAt.Conflict - (D.Founding + D.Expansion)) < 0.2).toBe(true)
		expect(math.abs(phaseAt.Endgame - (D.Founding + D.Expansion + D.Conflict)) < 0.2).toBe(true)
		-- Results: at the end of Endgame, or earlier if a kingdom took the rest by conquest
		expect(phaseAt.Results <= D.Founding + D.Expansion + D.Conflict + D.Endgame + 0.2).toBe(true)
		expect(phaseAt.Results > phaseAt.Conflict).toBe(true)

		-- wars: none before Conflict, at least one in it; and they are fought
		expect(#wars >= 1).toBe(true)
		for _, war in wars do
			expect(war.time >= phaseAt.Conflict - 0.2).toBe(true)
			expect(war.phase == "Conflict" or war.phase == "Endgame").toBe(true)
		end
		expect((counts.UnitKilled or 0) >= 1).toBe(true)
		expect((counts.UnitRecruited or 0) >= 4).toBe(true)

		-- one end, with all four kingdoms ranked
		expect(ended).toBe(1)
		expect(counts.MatchEnded).toBe(1)
		local summary = match:summary()
		expect(#summary.ranking).toBe(4)
		expect(summary.reason == "time" or summary.reason == "conquest").toBe(true)
		expect(#summary.winnerKingdomIds >= 1).toBe(true)
		for _, row in summary.ranking do
			expect(type(row.crownPoints)).toBe("number")
			expect(row.placement >= 1 and row.placement <= 4).toBe(true)
		end

		-- fallen kingdoms are gone cleanly; the standing ones still audit
		expect(#eliminated).toBe(counts.KingdomEliminated or 0)
		local citizens, units = 0, 0
		for _, kid in sim.kingdomOrder do
			local kingdom = sim.kingdoms[kid]
			citizens += #kingdom.citizenIds
			units += #kingdom.unitIds
			expect(sim.treasury:audit(kid)).toBe(true)
			if not kingdom.alive then
				expect(table.find(eliminated, kid)).never.toBeNil()
				expect(#kingdom.citizenIds).toBe(0)
				expect(#kingdom.unitIds).toBe(0)
				expect(#kingdom.buildingIds).toBe(0)
			end
		end
		expect(#sim.citizenOrder).toBe(citizens) -- nobody is left behind in the simulation
		expect(#sim.unitOrder).toBe(units)

		-- the cost of a server tick (BRIEF §14), over the busy stretch
		table.sort(ms)
		table.sort(busy)
		local sample = if #busy >= 50 then busy else ms
		local p99 = percentile(sample, 0.99)
		print(
			`FullMatch: {steps} ticks of {TICK * 1000}ms, wars {#wars}, kills {counts.UnitKilled or 0}, `
				.. `fallen {#eliminated}, peak {peakEntities} entities (that tick {string.format("%.2f", peakEntitiesMs)} ms), `
				.. `p99 {string.format("%.2f", p99)} ms / worst {string.format("%.2f", sample[#sample])} ms over {#sample} ticks `
				.. `with {BUSY_ENTITIES}+ entities (BRIEF {BUDGET_MS} ms p99 at {BUDGET_ENTITIES}), `
				.. `median {string.format("%.2f", percentile(ms, 0.5))} ms; headless Lune, sim step only (no snapshot encode)`
		)
		table.sort(slowest, function(a, b)
			return a.ms > b.ms
		end)
		local worstFive = {}
		for i = 1, math.min(5, #slowest) do
			table.insert(
				worstFive,
				`{string.format("%.1f", slowest[i].ms)} ms at sim {string.format("%.1f", slowest[i].time)} s ({slowest[i].entities} rigs)`
			)
		end
		print(
			`FullMatch: rigs (citizens + soldiers) peak {peakEntities}, buildings peak {peakBuildings}; `
				.. `{#slowest} ticks over 6 ms; slowest: {if #worstFive > 0
					then table.concat(worstFive, "; ")
					else "none"}`
		)
		expect(p99 <= CANARY_MS).toBe(true)
		expect(peakEntities <= BUDGET_ENTITIES).toBe(true) -- D-055
	end)
end)
