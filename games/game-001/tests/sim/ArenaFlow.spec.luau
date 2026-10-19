--[[
	Arena/ArenaFlow (FL-0071; CONTRACTS G12.1/G12.4, design §2/§4): the stage flow as a pure state machine. Who becomes
	champion (vote, leadership, lowest id, AI), what each stage accepts and refuses, the loadout rules, the timings, the
	skips (no vote, no loadout, coronation), forfeits and cancels.
]]

local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local ArenaConfig = require("@game/ReplicatedStorage/Forge/Config/Arena")
local ArenaFlow = require("@game/ReplicatedStorage/Game/Arena/ArenaFlow")

local function offer(trigger: string, citizen: string?, role: string?)
	return {
		trigger = trigger,
		citizenId = if citizen then 100 else nil,
		citizenName = citizen,
		role = role,
		loyalty = if citizen then 90 else nil,
		power = "pledged",
		condition = "when",
		effect = "effect",
	}
end

-- rulers: { crimson = {1, 2}, azure = {} }; leadership: { [userId] = number }
local function setup(rulers: any, leadership: any?, slots: number?)
	return {
		qualifiers = { "crimson", "azure" },
		rulersOf = function(kingdom: string)
			return table.clone(rulers[kingdom] or {})
		end,
		leadership = function(userId: number, _kingdom: string)
			return (leadership or {})[userId] or 0
		end,
		support = function(userId: number?, kingdom: string)
			return {
				score = if userId then 70 else 50,
				tier = if userId then "loyal" else "divided",
				offers = { offer("reforge", "Mara", "blacksmith"), offer("fieldRemedy", "Bram", "healer") },
				slots = slots or 2,
				reasons = { `{kingdom} reason 1`, `{kingdom} reason 2` },
			}
		end,
	}
end

describe("ArenaFlow: the stands", function()
	it("shows each kingdom's living citizens when the arena starts, and nothing without a source", function()
		local plain = ArenaFlow.new(setup({ crimson = { 1 }, azure = { 2 } }), 0)
		expect(plain:state().a.citizens).toBeNil()
		local counts = { crimson = 41, azure = 17.8 }
		local withCount = setup({ crimson = { 1 }, azure = { 2 } })
		withCount.citizens = function(kingdom: string)
			return counts[kingdom]
		end
		local flow = ArenaFlow.new(withCount, 0)
		expect(flow:state().a.citizens).toBe(41)
		expect(flow:state().b.citizens).toBe(17) -- whole citizens
		counts.crimson = 3
		expect(flow:state().a.citizens).toBe(41) -- read once, when the arena starts
		local odd = setup({ crimson = { 1 }, azure = { 2 } })
		odd.citizens = function(kingdom: string): any
			return if kingdom == "crimson" then -5 else 0 / 0
		end
		local clamped = ArenaFlow.new(odd, 0)
		expect(clamped:state().a.citizens).toBe(0)
		expect(clamped:state().b.citizens).toBeNil()
	end)
end)

local function stageNames(flow: any, from: number, to: number, step: number): { string }
	local out = {}
	local last = ""
	for now = from, to, step do
		flow:step(now)
		if flow:stage() ~= last then
			last = flow:stage()
			table.insert(out, last)
		end
	end
	return out
end

describe("ArenaFlow: champions", function()
	it("one human ruler per kingdom needs no vote: straight to the loadout with those champions", function()
		local flow = ArenaFlow.new(setup({ crimson = { 1 }, azure = { 2 } }), 100)
		expect(flow:stage()).toBe("loadout")
		local state = flow:state()
		expect(state.a.userId).toBe(1)
		expect(state.a.kingdom).toBe("crimson")
		expect(state.a.isAI).toBe(false)
		expect(state.b.userId).toBe(2)
		expect(state.endsAt).toBe(100 + ArenaConfig.loadoutSeconds)
		expect(state.coronation).toBeNil()
		expect(state.winner).toBeNil()
	end)

	it("co-rulers vote: the most votes wins the champion's place", function()
		local flow = ArenaFlow.new(setup({ crimson = { 1, 2, 3 }, azure = { 9 } }, { [1] = 99 }), 0)
		expect(flow:stage()).toBe("vote")
		expect(flow:state().endsAt).toBe(ArenaConfig.voteSeconds)
		expect(flow:state().a).toBeNil() -- champions are not named until the vote closes
		expect((flow:vote(1, 3))).toBe(true)
		expect((flow:vote(2, 3))).toBe(true)
		expect((flow:vote(3, 2))).toBe(true)
		flow:step(ArenaConfig.voteSeconds)
		expect(flow:state().a.userId).toBe(3) -- two votes beat leadership 99
	end)

	it("closes the vote early once every ruler of a contested kingdom has voted", function()
		local flow = ArenaFlow.new(setup({ crimson = { 1, 2 }, azure = { 9 } }), 0)
		flow:vote(1, 1)
		expect(flow:stage()).toBe("vote")
		flow:vote(2, 1)
		expect(flow:step(1)).toBe(true)
		expect(flow:stage()).toBe("loadout")
		expect(flow:state().a.userId).toBe(1)
	end)

	it("a tied or empty vote goes to the higher leadership, then to the lower userId", function()
		local tie = ArenaFlow.new(setup({ crimson = { 4, 5 }, azure = { 9 } }, { [4] = 10, [5] = 30 }), 0)
		tie:vote(4, 4)
		tie:vote(5, 5)
		tie:step(ArenaConfig.voteSeconds)
		expect(tie:state().a.userId).toBe(5)
		local none = ArenaFlow.new(setup({ crimson = { 4, 5 }, azure = { 9 } }, { [4] = 30, [5] = 10 }), 0)
		none:step(ArenaConfig.voteSeconds)
		expect(none:state().a.userId).toBe(4)
		local equal = ArenaFlow.new(setup({ crimson = { 8, 5 }, azure = { 9 } }, {}), 0)
		equal:step(ArenaConfig.voteSeconds)
		expect(equal:state().a.userId).toBe(5)
	end)

	it("a kingdom with no human ruler fields an AI champion with a negative id", function()
		local flow = ArenaFlow.new(setup({ crimson = { 1 }, azure = {} }), 0)
		local state = flow:state()
		expect(state.b.isAI).toBe(true)
		expect(state.b.userId).toBe(ArenaFlow.AI_USER_ID.b)
		expect(state.b.tier).toBe("divided")
		expect(state.b.weapon).toBe(ArenaConfig.ai.weapon)
		local reverse = ArenaFlow.new(setup({ crimson = {}, azure = { 2 } }), 0)
		expect(reverse:state().a.userId).toBe(ArenaFlow.AI_USER_ID.a)
		expect(reverse:state().a.isAI).toBe(true)
	end)

	it("two AI champions skip the loadout and the vote: straight to the intro", function()
		local flow = ArenaFlow.new(setup({ crimson = {}, azure = {} }), 50)
		expect(flow:stage()).toBe("intro")
		expect(flow:state().endsAt).toBe(50 + ArenaConfig.introSeconds)
	end)

	it("a ruler outside the arena, or a vote for someone who is not a candidate, is refused", function()
		local flow = ArenaFlow.new(setup({ crimson = { 1, 2 }, azure = { 9 } }), 0)
		local ok, reason = flow:vote(77, 1)
		expect(ok).toBe(false)
		expect(reason).toBe("not_a_voter")
		ok, reason = flow:vote(1, 9) -- azure's ruler is not crimson's candidate
		expect(ok).toBe(false)
		expect(reason).toBe("not_a_candidate")
		ok, reason = flow:vote(1, 0 / 0)
		expect(ok).toBe(false)
		expect(reason).toBe("bad_arguments")
		ok, reason = flow:vote("1" :: any, 1)
		expect(ok).toBe(false)
		expect(reason).toBe("bad_arguments")
		flow:step(ArenaConfig.voteSeconds)
		ok, reason = flow:vote(1, 2)
		expect(ok).toBe(false)
		expect(reason).toBe("not_vote_stage")
	end)

	it("the latest vote counts", function()
		local flow = ArenaFlow.new(setup({ crimson = { 1, 2, 3 }, azure = { 9 } }), 0)
		flow:vote(1, 2)
		flow:vote(2, 2)
		flow:vote(1, 3)
		flow:vote(3, 3)
		flow:step(ArenaConfig.voteSeconds)
		expect(flow:state().a.userId).toBe(3)
	end)
end)

describe("ArenaFlow: the loadout", function()
	local function loadout()
		return ArenaFlow.new(setup({ crimson = { 1 }, azure = { 2 } }), 0)
	end

	it("starts with the config defaults and the offered perks up to the slots", function()
		local flow = ArenaFlow.new(setup({ crimson = { 1 }, azure = { 2 } }, nil, 1), 0)
		local a = flow:state().a
		expect(a.weapon).toBe(ArenaConfig.defaultWeapon)
		expect(a.armour).toBe(ArenaConfig.defaultArmour)
		expect(a.triggers).toEqual({ "reforge" }) -- one slot
		local wide = ArenaFlow.new(setup({ crimson = { 1 }, azure = { 2 } }, nil, 3), 0)
		expect(wide:state().a.triggers).toEqual({ "reforge", "fieldRemedy" }) -- only two offers exist
	end)

	it("accepts a valid choice and shows it, with the citizens behind the chosen perks", function()
		local flow = loadout()
		local ok, reason = flow:choose(1, "mace", "heavy", { "fieldRemedy" })
		expect(ok).toBe(true)
		expect(reason).toBeNil()
		local a = flow:state().a
		expect(a.weapon).toBe("mace")
		expect(a.armour).toBe("heavy")
		expect(a.triggers).toEqual({ "fieldRemedy" })
		expect(a.triggerCitizens).toEqual({ fieldRemedy = { name = "Bram", role = "healer" } })
		expect(a.reasons).toEqual({ "crimson reason 1", "crimson reason 2" })
		flow:choose(1, "spear", "light", {})
		expect(flow:state().a.triggers).toEqual({})
		expect(flow:state().a.triggerCitizens).toBeNil()
	end)

	it("refuses a weapon or armour outside the config, a non-table list, and non-string perks", function()
		local flow = loadout()
		local function refused(reason: string, ...: any)
			local ok, why = flow:choose(...)
			expect(ok).toBe(false)
			expect(why).toBe(reason)
		end
		refused("bad_weapon", 1, "laser", "light", {})
		refused("bad_weapon", 1, 5, "light", {})
		refused("bad_armour", 1, "mace", "plate", {})
		refused("bad_armour", 1, "mace", nil, {})
		refused("bad_arguments", 1, "mace", "light", "reforge")
		refused("bad_arguments", 1, "mace", "light", { 7 })
		expect(flow:state().a.weapon).toBe(ArenaConfig.defaultWeapon) -- nothing changed
	end)

	it("refuses repeated perks, perks nobody offers, and more perks than slots", function()
		local flow = loadout()
		local ok, reason = flow:choose(1, "mace", "light", { "reforge", "reforge" })
		expect(reason).toBe("duplicate")
		ok, reason = flow:choose(1, "mace", "light", { "heavyRations" })
		expect(reason).toBe("not_offered")
		ok, reason = flow:choose(1, "mace", "light", { "crowdRally" })
		expect(reason).toBe("not_offered") -- not in this champion's offers
		ok, reason = flow:choose(1, "mace", "light", { "reforge", "fieldRemedy", "reforge" })
		expect(reason).toBe("too_many")
		expect(ok).toBe(false)
		local single = ArenaFlow.new(setup({ crimson = { 1 }, azure = { 2 } }, nil, 1), 0)
		ok, reason = single:choose(1, "mace", "light", { "reforge", "fieldRemedy" })
		expect(reason).toBe("too_many")
		-- never more than the contract's 3, whatever the slots
		local huge = ArenaFlow.new(setup({ crimson = { 1 }, azure = { 2 } }, nil, 9), 0)
		huge._champions.a.support.offers = {
			offer("reforge", "A", "blacksmith"),
			offer("fieldRemedy", "B", "healer"),
			offer("calledWarning", "C", "captain"),
			offer("heartyRations", "D", "provisioner"),
		}
		ok, reason = huge:choose(1, "mace", "light", { "reforge", "fieldRemedy", "calledWarning", "heartyRations" })
		expect(reason).toBe("too_many")
		expect((huge:choose(1, "mace", "light", { "reforge", "fieldRemedy", "calledWarning" }))).toBe(true)
	end)

	it("an AI champion's id never chooses", function()
		local flow = ArenaFlow.new(setup({ crimson = { 1 }, azure = {} }), 0)
		expect(flow:stage()).toBe("loadout")
		local ok, reason = flow:choose(ArenaFlow.AI_USER_ID.b, "mace", "light", {})
		expect(ok).toBe(false)
		expect(reason).toBe("not_champion")
		expect(flow:state().b.weapon).toBe(ArenaConfig.ai.weapon)
	end)

	it("only the champion chooses, only for themselves, and only in the loadout stage", function()
		local flow = ArenaFlow.new(setup({ crimson = { 1, 3 }, azure = { 2 } }), 0)
		local ok, reason = flow:choose(3, "mace", "light", {})
		expect(reason).toBe("not_loadout_stage") -- still voting
		flow:vote(1, 1)
		flow:vote(3, 1)
		flow:step(1)
		ok, reason = flow:choose(3, "mace", "light", {}) -- a co-ruler who lost the vote
		expect(reason).toBe("not_champion")
		ok, reason = flow:choose(77, "mace", "light", {})
		expect(reason).toBe("not_champion")
		ok, reason = flow:choose(ArenaFlow.AI_USER_ID.a, "mace", "light", {})
		expect(reason).toBe("not_champion") -- AI ids never choose
		ok, reason = flow:choose("1" :: any, "mace", "light", {})
		expect(reason).toBe("not_champion")
		expect((flow:choose(1, "mace", "light", {}))).toBe(true)
		flow:step(ArenaConfig.loadoutSeconds + 1)
		ok, reason = flow:choose(1, "spear", "light", {})
		expect(ok).toBe(false)
		expect(reason).toBe("not_loadout_stage")
		expect(flow:state().a.weapon).toBe("mace")
	end)
end)

describe("ArenaFlow: time and the end", function()
	it("walks vote, loadout, intro, duel, crowning, done on its clock", function()
		local flow = ArenaFlow.new(setup({ crimson = { 1, 2 }, azure = { 9 } }), 0)
		local seen = stageNames(flow, 0, 400, 1)
		expect(seen).toEqual({ "vote", "loadout", "intro", "duel", "crowning", "done" })
		local result = flow:result()
		expect(result.kind).toBe("draw") -- nobody reported a duel result: the safety clock
		expect(result.reason).toBe("duel_clock")
		expect(flow:winnerKingdom()).toBeNil()
	end)

	it("each stage lasts its configured time, and a late step catches up through the stages it missed", function()
		local flow = ArenaFlow.new(setup({ crimson = { 1 }, azure = { 2 } }), 0)
		expect(flow:state().endsAt).toBe(ArenaConfig.loadoutSeconds)
		flow:step(ArenaConfig.loadoutSeconds)
		expect(flow:stage()).toBe("intro")
		expect(flow:state().endsAt).toBe(ArenaConfig.loadoutSeconds + ArenaConfig.introSeconds)
		flow:step(ArenaConfig.loadoutSeconds + ArenaConfig.introSeconds)
		expect(flow:stage()).toBe("duel")
		local duelStart = ArenaConfig.loadoutSeconds + ArenaConfig.introSeconds
		expect(flow:state().endsAt).toBe(duelStart + ArenaConfig.duelMaxSeconds)
		local late = ArenaFlow.new(setup({ crimson = { 1 }, azure = { 2 } }), 0)
		late:step(10000)
		expect(late:stage()).toBe("done")
		expect(late:state().endsAt).toBeNil()
	end)

	it("step reports a change only when something changed", function()
		local flow = ArenaFlow.new(setup({ crimson = { 1 }, azure = { 2 } }), 0)
		expect(flow:step(1)).toBe(false)
		expect(flow:step(ArenaConfig.loadoutSeconds)).toBe(true)
		expect(flow:step(ArenaConfig.loadoutSeconds)).toBe(false)
	end)

	it("a duel result starts the crowning with the winner's kingdom and champion", function()
		local flow = ArenaFlow.new(setup({ crimson = { 1 }, azure = { 2 } }), 0)
		flow:step(ArenaConfig.loadoutSeconds + ArenaConfig.introSeconds)
		expect(flow:endDuel("b", 70)).toBe(true)
		local state = flow:state()
		expect(state.stage).toBe("crowning")
		expect(state.winner).toBe(2)
		expect(state.endsAt).toBe(70 + ArenaConfig.crowningSeconds)
		expect(flow:winnerKingdom()).toBe("azure")
		expect(flow:state().coronation).toBeNil() -- a coronation is only for the last keep standing
		expect(flow:result().kind).toBe("duel")
		expect(flow:endDuel("a", 71)).toBe(false) -- only once
		flow:step(70 + ArenaConfig.crowningSeconds)
		expect(flow:stage()).toBe("done")
		expect(flow:winnerKingdom()).toBe("azure") -- the result outlives the stage
	end)

	it("a drawn duel has no winner, so the match falls back to Crown Points", function()
		local flow = ArenaFlow.new(setup({ crimson = { 1 }, azure = { 2 } }), 0)
		flow:step(ArenaConfig.loadoutSeconds + ArenaConfig.introSeconds)
		flow:endDuel("draw", 80)
		expect(flow:stage()).toBe("crowning")
		expect(flow:state().winner).toBeNil()
		expect(flow:winnerKingdom()).toBeNil()
		expect(flow:result().kind).toBe("draw")
	end)

	it("an unknown duel result is a draw, never a winner", function()
		local flow = ArenaFlow.new(setup({ crimson = { 1 }, azure = { 2 } }), 0)
		flow:step(ArenaConfig.loadoutSeconds + ArenaConfig.introSeconds)
		expect(flow:endDuel("x", 5)).toBe(true)
		expect(flow:state().winner).toBeNil()
		expect(flow:winnerKingdom()).toBeNil()
		expect(flow:result().kind).toBe("draw")
	end)

	it("a duel result outside the duel stage is ignored", function()
		local flow = ArenaFlow.new(setup({ crimson = { 1 }, azure = { 2 } }), 0)
		expect(flow:endDuel("a", 1)).toBe(false)
		expect(flow:stage()).toBe("loadout")
	end)

	it("last keep standing is a coronation: no duel, the crowning at once", function()
		local flow = ArenaFlow.new({
			qualifiers = { "gold" },
			rulersOf = function()
				return { 5 }
			end,
			leadership = function()
				return 0
			end,
			support = function()
				error("a coronation needs no support")
			end,
		}, 10)
		local state = flow:state()
		expect(state.stage).toBe("crowning")
		expect(state.coronation).toBe("gold")
		expect(state.a).toBeNil()
		expect(state.endsAt).toBe(10 + ArenaConfig.crowningSeconds)
		expect(flow:winnerKingdom()).toBe("gold")
		expect(flow:result().kind).toBe("coronation")
		flow:step(10 + ArenaConfig.crowningSeconds)
		expect(flow:stage()).toBe("done")
	end)

	it("needs one or two qualifiers", function()
		expect(function()
			ArenaFlow.new({ qualifiers = {} }, 0)
		end).toThrow("1 or 2 qualifiers")
		expect(function()
			ArenaFlow.new({ qualifiers = { "a", "b", "c" } }, 0)
		end).toThrow("1 or 2 qualifiers")
	end)
end)

describe("ArenaFlow: leavers and cancels", function()
	it("a champion who leaves before the crowning forfeits: the other side wins", function()
		local flow = ArenaFlow.new(setup({ crimson = { 1 }, azure = { 2 } }), 0)
		expect(flow:forfeit(1, 5)).toBe(true)
		expect(flow:stage()).toBe("crowning")
		expect(flow:winnerKingdom()).toBe("azure")
		expect(flow:state().winner).toBe(2)
		expect(flow:result().kind).toBe("forfeit")
		expect(flow:forfeit(2, 6)).toBe(false) -- already crowning
	end)

	it("a champion who leaves during the duel forfeits too, and an AI opponent wins by it", function()
		local flow = ArenaFlow.new(setup({ crimson = { 1 }, azure = {} }), 0)
		flow:step(ArenaConfig.loadoutSeconds + ArenaConfig.introSeconds)
		expect(flow:stage()).toBe("duel")
		expect(flow:forfeit(1, 60)).toBe(true)
		expect(flow:winnerKingdom()).toBe("azure")
		expect(flow:state().winner).toBe(ArenaFlow.AI_USER_ID.b)
	end)

	it("both champions gone is a draw; a stranger leaving changes nothing", function()
		local flow = ArenaFlow.new(setup({ crimson = { 1 }, azure = { 2 } }), 0)
		expect(flow:forfeit(77, 1)).toBe(false)
		expect(flow:stage()).toBe("loadout")
		expect(flow:forfeit(1, 2)).toBe(true)
		expect(flow:result().kind).toBe("forfeit")
		expect(flow:forfeit(2, 2 + ArenaConfig.simultaneousSeconds)).toBe(true) -- the same moment
		expect(flow:winnerKingdom()).toBeNil()
		expect(flow:result().kind).toBe("draw")
		expect(flow:result().reason).toBe("both_left")
		expect(flow:state().winner).toBeNil()
	end)

	it("the second champion leaving after the moment has passed changes nothing", function()
		local flow = ArenaFlow.new(setup({ crimson = { 1 }, azure = { 2 } }), 0)
		expect(flow:forfeit(1, 2)).toBe(true)
		expect(flow:forfeit(1, 2.1)).toBe(false) -- the one who already left cannot make it a draw
		expect(flow:forfeit(77, 2.1)).toBe(false)
		expect(flow:forfeit(2, 2 + ArenaConfig.simultaneousSeconds + 0.01)).toBe(false)
		expect(flow:winnerKingdom()).toBe("azure")
		expect(flow:result().kind).toBe("forfeit")
	end)

	it("an AI champion's id is not a leaver", function()
		local flow = ArenaFlow.new(setup({ crimson = { 1 }, azure = {} }), 0)
		expect(flow:forfeit(1, 2)).toBe(true)
		expect(flow:forfeit(ArenaFlow.AI_USER_ID.b, 2.1)).toBe(false)
		expect(flow:result().kind).toBe("forfeit")
	end)

	it("a trigger list that is not a plain array is refused", function()
		local flow = ArenaFlow.new(setup({ crimson = { 1 }, azure = { 2 } }), 0)
		local dictionary: any = { a = "x", b = "y", c = "z", d = "w", e = "v" }
		local ok, reason = flow:choose(1, "mace", "light", dictionary)
		expect(ok).toBe(false)
		expect(reason).toBe("bad_arguments")
		local sparse: any = { [1] = "x", [3] = "y" }
		ok, reason = flow:choose(1, "mace", "light", sparse)
		expect(ok).toBe(false)
		expect(reason).toBe("bad_arguments")
	end)

	it("a ruler who leaves during the vote drops out; nobody left means an AI champion", function()
		local flow = ArenaFlow.new(setup({ crimson = { 1, 2 }, azure = { 9 } }), 0)
		flow:vote(2, 2)
		expect(flow:forfeit(2, 1)).toBe(true)
		expect(flow:candidates("a")).toEqual({ 1 })
		flow:step(ArenaConfig.voteSeconds)
		expect(flow:state().a.userId).toBe(1)
		local alone = ArenaFlow.new(setup({ crimson = { 1, 2 }, azure = { 9 } }), 0)
		alone:forfeit(1, 1)
		alone:forfeit(2, 1)
		alone:step(ArenaConfig.voteSeconds)
		expect(alone:state().a.isAI).toBe(true)
		-- votes for a ruler who left do not count for anyone
		local votes = ArenaFlow.new(setup({ crimson = { 1, 2, 3 }, azure = { 9 } }, { [3] = 5 }), 0)
		votes:vote(1, 2)
		votes:forfeit(2, 1)
		votes:step(ArenaConfig.voteSeconds)
		expect(votes:state().a.userId).toBe(3) -- the vote for 2 is void: leadership decides
	end)

	it("cancel ends the arena with no winner, once", function()
		local flow = ArenaFlow.new(setup({ crimson = { 1 }, azure = { 2 } }), 0)
		expect(flow:cancel("match_over")).toBe(true)
		expect(flow:stage()).toBe("done")
		expect(flow:winnerKingdom()).toBeNil()
		expect(flow:result().kind).toBe("cancelled")
		expect(flow:result().reason).toBe("match_over")
		expect(flow:cancel("again")).toBe(false)
		expect(flow:step(10000)).toBe(false)
	end)

	it("a cancel during the crowning takes the winner back: the match falls back to Crown Points", function()
		local flow = ArenaFlow.new(setup({ crimson = { 1 }, azure = { 2 } }), 0)
		flow:step(ArenaConfig.loadoutSeconds + ArenaConfig.introSeconds)
		flow:endDuel("a", 50)
		expect(flow:winnerKingdom()).toBe("crimson")
		expect(flow:cancel("match_over")).toBe(true)
		expect(flow:winnerKingdom()).toBeNil()
		expect(flow:state().winner).toBeNil()
		expect(flow:state().coronation).toBeNil()
		local last = ArenaFlow.new({
			qualifiers = { "gold" },
			rulersOf = function()
				return {}
			end,
			leadership = function()
				return 0
			end,
			support = function()
				error("unused")
			end,
		}, 0)
		last:cancel("match_over")
		expect(last:state().coronation).toBeNil()
		expect(last:winnerKingdom()).toBeNil()
	end)

	it("the revision moves with every visible change, and only then", function()
		local flow = ArenaFlow.new(setup({ crimson = { 1, 2 }, azure = { 9 } }), 0)
		local rev = flow:rev()
		flow:vote(1, 1)
		expect(flow:rev() > rev).toBe(true)
		rev = flow:rev()
		flow:vote(77, 1) -- refused
		flow:step(1)
		expect(flow:rev()).toBe(rev)
	end)
end)
