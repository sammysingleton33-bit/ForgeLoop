--[[
	WarOutcome (FL-0126, siege viability; FORGE-07's #187 numbers: three wars and 532 kills felled no kingdom).
	War must be able to decide something. One real four-governor match (seed 13, the shipped durations): at least one
	kingdom falls, none before Conflict, and the fall comes after a siege on its keep (SiegeChanged) by a kingdom it was
	at war with. The wider evidence, 8 seeds, is in the PR / handoff (headless probe, same code); this spec pins one.
	~40 s of CPU, like FullMatch.
]]

local T = require("../../../../../roblox/tests/harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local Match = require("@game/ReplicatedStorage/Game/Kingdom/Match")
local MatchConfig = require("@game/ReplicatedStorage/Forge/Config/Match")

describe("WarOutcome: a war decides something (FL-0126)", function()
	it("four governors: a kingdom falls in Conflict or Endgame, after a siege, never before Conflict", function()
		local match = Match.new({
			random = Random.new(13),
			minPlayers = 0,
			now = function()
				return 1700000000
			end,
		})
		local sim = match.sim
		local conflictAt = nil :: number?
		local fallen: { { kingdomId: string, by: string?, time: number } } = {}
		local sieged: { [string]: boolean } = {}
		local steps = 0
		while match.state ~= "Results" and steps < 200000 do
			match:update(MatchConfig.tickSeconds)
			steps += 1
			for _, event in match:drainEvents() do
				if event.name == "MatchPhaseChanged" and event.phase == "Conflict" then
					conflictAt = sim.time
				elseif event.name == "SiegeChanged" and event.on then
					sieged[event.kingdomId] = true
				elseif event.name == "KingdomEliminated" then
					table.insert(fallen, { kingdomId = event.kingdomId, by = event.byKingdomId, time = sim.time })
				end
			end
		end
		expect(conflictAt).never.toBeNil()
		expect(#fallen >= 1).toBe(true)
		for _, row in fallen do
			expect(row.time >= (conflictAt :: number)).toBe(true) -- no snowball before Conflict
			expect(row.by).never.toBeNil()
			expect(sieged[row.kingdomId]).toBe(true) -- its keep was besieged first
		end
		print(`WarOutcome: {#fallen} fallen: {table.concat(
			(function()
				local out = {}
				for _, row in fallen do
					table.insert(out, `{row.kingdomId} by {row.by} at {math.floor(row.time)} s`)
				end
				return out
			end)(),
			", "
		)}; Conflict began at {math.floor(conflictAt :: number)} s`)
	end)
end)
