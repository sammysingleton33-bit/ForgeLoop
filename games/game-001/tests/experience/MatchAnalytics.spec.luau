local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect, beforeEach = T.describe, T.it, T.expect, T.beforeEach

-- FL-0063: the VS-1 funnel, sessions, MatchEnded and PhaseLeft through the real framework
-- AnalyticsService with game-001's config/Analytics.luau, on the real GameEvents bus (G9).
local MockEnv = require("../../../../roblox/tests/mocks/MockEnv")
local Loader = require("@game/ReplicatedStorage/Forge/Contracts/Loader")
local GameEvents = require("@game/ReplicatedStorage/Forge/Contracts/GameEvents")
local AnalyticsDef = require("@game/ServerScriptService/Forge/Services/AnalyticsService")
local MatchAnalyticsDef = require("@game/ServerScriptService/Game/Services/MatchAnalyticsService")

describe("VS-1 analytics (FL-0063)", function()
	local env, roblox, registry, kingdoms, crimson1, crimson2, frost

	local function boot(extra)
		local defs = { AnalyticsDef, MatchAnalyticsDef }
		for _, def in extra or {} do
			table.insert(defs, def)
		end
		registry = Loader.load(env, defs)
	end

	local function kingdomService()
		return {
			name = "KingdomService",
			new = function()
				return {
					getKingdom = function(_, id)
						local rulers = {}
						for userId, kingdom in kingdoms do
							if kingdom == id then
								table.insert(rulers, userId)
							end
						end
						table.sort(rulers)
						return { id = id, rulers = rulers }
					end,
					getKingdomOf = function(_, player)
						return kingdoms[player.UserId]
					end,
				}
			end,
		}
	end

	local function matchService(mode)
		return {
			name = "MatchService",
			new = function()
				return { mode = mode }
			end,
		}
	end

	-- G13.2 CitizenService double: inspect(entityId).occupation
	local function citizenService(occupations)
		return {
			name = "CitizenService",
			new = function()
				return {
					inspect = function(_, entityId)
						local occupation = occupations[entityId]
						return if occupation then { entityId = entityId, occupation = occupation } else nil
					end,
				}
			end,
		}
	end

	-- FirstMatch steps logged per user id: { [userId] = { stepName, ... } }
	local function vs1()
		local out = {}
		for _, call in roblox:callsTo("LogFunnelStepEvent") do
			if call.args[1] == "FirstMatch" then
				out[call.userId] = out[call.userId] or {}
				table.insert(out[call.userId], call.args[4])
			end
		end
		return out
	end

	local function custom(name)
		local out = {}
		for _, call in roblox:callsTo("LogCustomEvent") do
			if call.args[1] == name then
				table.insert(out, call)
			end
		end
		return out
	end

	local function join(player, kingdom)
		kingdoms[player.UserId] = kingdom
		GameEvents.KingdomJoined:fire(player, kingdom)
	end

	beforeEach(function()
		GameEvents.disconnectAll()
		env = MockEnv.new({ seed = 63, startTime = 1700000000 })
		roblox = env.AnalyticsService
		kingdoms = {}
		crimson1 = env.mock.players:add({ userId = 631 })
		crimson2 = env.mock.players:add({ userId = 632 })
		frost = env.mock.players:add({ userId = 633 })
	end)

	it("runs the BRIEF §13 funnel from the G9 events with the G9 attribution", function()
		boot({ kingdomService(), matchService("slice") })
		join(crimson1, "crimson")
		join(crimson2, "crimson")
		join(frost, "frost")
		GameEvents.ResourceGathered:fire(nil, "crimson", "wood", 5, "citizen") -- citizens: every member
		GameEvents.BuildingPlaced:fire(
			{ id = 1, type = "house", level = 1, kingdom = "crimson", placedBy = crimson2.UserId },
			crimson2
		)
		GameEvents.BuildingCompleted:fire({ id = 1, type = "house", level = 1, kingdom = "crimson" }, nil)
		GameEvents.UnitsRecruited:fire(crimson1, "crimson", 3)
		GameEvents.ObjectiveCaptured:fire("watchtower", "crimson")
		GameEvents.UnitsRecruited:fire(crimson2, "crimson", 2)
		GameEvents.ObjectiveCaptured:fire("bridge", "crimson")
		local steps = vs1()
		-- inOrder (FORGE-00's #64 ruling): crimson1 never placed, so the kingdom's completion, their own
		-- recruit and the captures do not move them past FirstGather (Roblox counts skipped steps as done)
		expect(steps[631]).toEqual({ "Spawn", "FirstGather" })
		expect(steps[632]).toEqual({
			"Spawn",
			"FirstGather",
			"FirstBuildPlaced",
			"FirstBuildingComplete",
			"FirstRecruit",
			"FirstCapture",
		})
		expect(steps[633]).toEqual({ "Spawn" }) -- a rival gets none of crimson's credit
		expect(registry:get("AnalyticsService").stats.dropped.outOfOrder).toBeGreaterThan(0)
	end)

	it("times each FirstMatch step after Spawn: MilestoneReached, seconds since the session started (M7)", function()
		boot({ kingdomService(), matchService("match30") })
		join(crimson1, "crimson")
		env.wait(30)
		GameEvents.ResourceGathered:fire(crimson1, "crimson", "wood", 5, "ruler")
		env.wait(45)
		GameEvents.BuildingPlaced:fire(
			{ id = 1, type = "house", level = 1, kingdom = "crimson", placedBy = crimson1.UserId },
			crimson1
		)
		GameEvents.ResourceGathered:fire(crimson1, "crimson", "wood", 5, "ruler") -- a repeat: no second time
		local timed = {}
		for _, call in custom("MilestoneReached") do
			table.insert(timed, { userId = call.userId, value = call.args[2], fields = call.args[3] })
		end
		expect(timed).toEqual({
			{ userId = 631, value = 30, fields = { CustomField01 = "FirstGather", CustomField02 = "match30" } },
			{ userId = 631, value = 75, fields = { CustomField01 = "FirstBuildPlaced", CustomField02 = "match30" } },
		})
	end)

	it("logs each funnel step once per player, however often the event repeats", function()
		boot({ kingdomService() })
		join(crimson1, "crimson")
		for _ = 1, 20 do
			GameEvents.ResourceGathered:fire(nil, "crimson", "food", 2, "citizen")
		end
		GameEvents.ResourceGathered:fire(crimson1, "crimson", "wood", 1, "ruler")
		expect(vs1()[631]).toEqual({ "Spawn", "FirstGather" })
		-- repeats are counted, never logged (FORGE-05 #64 M1: they flooded Output at about 430 lines a minute)
		local lines = 0
		for _, entry in env.mock.logs do
			lines += if string.find(entry.message, "analytics funnel FirstMatch", 1, true) then 1 else 0
		end
		expect(lines).toBe(2)
		expect(registry:get("AnalyticsService").stats.dropped.duplicate).toBe(20)
	end)

	it("starts the session on KingdomJoined (VS-1 has no PlayerReady), once per server visit", function()
		boot({ kingdomService() })
		join(crimson1, "crimson")
		join(crimson1, "crimson") -- a new match re-joins the kingdom
		local starts = custom("SessionStart")
		expect(#starts).toBe(1)
		expect(starts[1].userId).toBe(631)
		expect(starts[1].args[3]).toEqual({ CustomField01 = "unknown" }) -- no DataService in VS-1 (D-027)
	end)

	it("SessionEnd keeps the player's own last step, not the citizens' endless gathering", function()
		boot({ kingdomService() })
		join(crimson1, "crimson")
		GameEvents.ResourceGathered:fire(nil, "crimson", "food", 2, "citizen")
		GameEvents.BuildingPlaced:fire(
			{ id = 3, type = "farm", level = 1, kingdom = "crimson", placedBy = crimson1.UserId },
			crimson1
		)
		for _ = 1, 5 do
			GameEvents.ResourceGathered:fire(nil, "crimson", "food", 2, "citizen")
		end
		env.mock.players:remove(crimson1)
		local ends = custom("SessionEnd")
		expect(#ends).toBe(1)
		expect(ends[1].args[3]).toEqual({ CustomField01 = "BuildingPlaced" })
	end)

	it("logs MatchEnded per ruler still here: won, the phase it was decided in, the mode", function()
		boot({ kingdomService(), matchService("match30") })
		join(crimson1, "crimson")
		join(frost, "frost")
		local spectator = env.mock.players:add({ userId = 639 })
		for _, phase in { "Founding", "Expansion", "Conflict", "Results" } do
			GameEvents.MatchPhaseChanged:fire(phase)
		end
		GameEvents.MatchEnded:fire({ winner = "crimson", standings = {}, durationSec = 1500 })
		local byUser = {}
		for _, call in custom("MatchEnded") do
			byUser[call.userId] = { value = call.args[2], fields = call.args[3] }
		end
		expect(byUser[631]).toEqual({
			value = 1500,
			fields = { CustomField01 = "true", CustomField02 = "Conflict", CustomField03 = "match30" },
		})
		expect(byUser[633].fields.CustomField01).toBe("false")
		expect(byUser[spectator.UserId]).toBeNil()
		expect(registry:get("MatchAnalyticsService").ended).toBe(1)
	end)

	it(
		"logs PhaseLeft (minute, phase) before SessionEnd when a ruler leaves mid-match; not in Lobby or Results, not for spectators",
		function()
			boot({ kingdomService() })
			join(crimson1, "crimson")
			join(crimson2, "crimson")
			join(frost, "frost")
			local spectator = env.mock.players:add({ userId = 639 })
			GameEvents.MatchPhaseChanged:fire("Lobby")
			env.mock.players:remove(frost) -- the Lobby: not a disconnect from a match
			GameEvents.MatchPhaseChanged:fire("Founding")
			env.wait(130)
			GameEvents.MatchPhaseChanged:fire("Expansion")
			env.mock.players:remove(spectator) -- not a ruler
			env.mock.players:remove(crimson1)
			GameEvents.MatchPhaseChanged:fire("Results")
			env.mock.players:remove(crimson2) -- the match is over
			local names = {}
			for _, call in roblox:callsTo("LogCustomEvent") do
				if call.userId == 631 then
					table.insert(names, call.args[1])
				end
			end
			expect(names[#names - 1]).toBe("PhaseLeft")
			expect(names[#names]).toBe("SessionEnd")
			local left = custom("PhaseLeft")
			expect(#left).toBe(1)
			expect(left[1].userId).toBe(631)
			expect(left[1].args[2]).toBe(2)
			expect(left[1].args[3]).toEqual({ CustomField01 = "Expansion" })
			local crimsonEnd
			for _, call in custom("SessionEnd") do
				if call.userId == 631 then
					crimsonEnd = call
				end
			end
			expect(crimsonEnd.args[3]).toEqual({ CustomField01 = "KingdomJoined" }) -- not "PhaseLeft"
		end
	)

	it(
		"a draw is logged as won = draw, never a loss; a ruler who rejoins as a spectator is not counted (#64 lows)",
		function()
			boot({ kingdomService(), matchService("match") })
			join(crimson1, "crimson")
			join(frost, "frost")
			GameEvents.MatchPhaseChanged:fire("Founding")
			env.mock.players:remove(frost)
			local back = env.mock.players:add({ userId = 633 }) -- back in the server, no kingdom this time
			env.mock:advance(0.1) -- PlayerAdded handlers run in their own thread
			GameEvents.MatchPhaseChanged:fire("Results")
			GameEvents.MatchEnded:fire({ standings = {}, durationSec = 900 }) -- no single winner
			local byUser = {}
			for _, call in custom("MatchEnded") do
				byUser[call.userId] = call.args[3]
			end
			expect(byUser[631].CustomField01).toBe("draw")
			expect(byUser[back.UserId]).toBeNil()
			GameEvents.MatchPhaseChanged:fire("Founding")
			expect(registry:get("MatchAnalyticsService"):leftInfo(back)).toBeNil() -- a spectator has no PhaseLeft
		end
	)

	it("a new match restarts the clock and forgets rulers who left (#64 lows)", function()
		boot({ kingdomService() })
		join(crimson1, "crimson")
		join(frost, "frost")
		local service = registry:get("MatchAnalyticsService")
		GameEvents.MatchPhaseChanged:fire("Founding")
		env.wait(300)
		env.mock.players:remove(frost)
		GameEvents.MatchPhaseChanged:fire("Results")
		GameEvents.MatchPhaseChanged:fire("Lobby")
		GameEvents.MatchPhaseChanged:fire("Founding") -- the next match
		expect(service._kingdomOf[633]).toBeNil() -- frost left: forgotten
		expect(service._kingdomOf[631]).toBe("crimson")
		env.wait(61)
		expect(service:leftInfo(crimson1)).toEqual({ phase = "Founding", minute = 1 }) -- from the new Founding
	end)

	it("logs ConversationAnswered from G9 CitizenAnswered: secondsOpen, occupation, decision (FL-0108)", function()
		boot({ kingdomService(), citizenService({ [7] = "farmer" }) })
		join(crimson1, "crimson")
		join(crimson2, "crimson")
		GameEvents.CitizenAnswered:fire(crimson2, "crimson", 7, "handout_food", 12.5)
		local answered = custom("ConversationAnswered")
		expect(#answered).toBe(1)
		expect(answered[1].userId).toBe(632) -- the ruler who answered, never the co-ruler
		expect(answered[1].args[2]).toBe(12.5)
		expect(answered[1].args[3]).toEqual({ CustomField01 = "farmer", CustomField02 = "handout_food" })
		-- the answer removed its citizen, and there was no bubble: still logged, without those two
		GameEvents.CitizenAnswered:fire(crimson1, "crimson", 99, "firm_ruling", nil)
		answered = custom("ConversationAnswered")
		expect(#answered).toBe(2)
		expect(answered[2].userId).toBe(631)
		expect(answered[2].args[2]).toBe(1) -- no secondsOpen: Roblox's default value
		expect(answered[2].args[3]).toEqual({ CustomField02 = "firm_ruling" })
		GameEvents.CitizenAnswered:fire(nil, "crimson", 7, "threat", 3) -- no player: nothing
		expect(#custom("ConversationAnswered")).toBe(2)
		expect(env.mock.threadErrors).toEqual({})
	end)

	it("boots without KingdomService and MatchService (headless): nothing kingdom-scoped, no errors", function()
		boot(nil)
		join(crimson1, "crimson")
		GameEvents.ObjectiveCaptured:fire("watchtower", "crimson")
		GameEvents.MatchPhaseChanged:fire("Founding")
		GameEvents.MatchEnded:fire({ winner = "crimson", standings = {}, durationSec = 60 })
		expect(vs1()[631]).toEqual({ "Spawn" })
		local ended = custom("MatchEnded")
		expect(#ended).toBe(1)
		expect(ended[1].args[3].CustomField03).toBe("unknown")
		expect(env.mock.threadErrors).toEqual({})
	end)
end)
