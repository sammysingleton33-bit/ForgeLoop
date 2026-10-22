-- The Crown Arena UI models (FL-0073, design crown-arena.md §3-§7): the loadout and perk choice, the intro card,
-- the duel HUD. Pure: the G12 shapes in, the view out (support numbers from ArenaDoubles' stub).
local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local ArenaDoubles = require("./doubles/ArenaDoubles")
local ArenaHudModel = require("@game/StarterPlayer/StarterPlayerScripts/Game/UI/ArenaHudModel")
local ArenaIntroModel = require("@game/StarterPlayer/StarterPlayerScripts/Game/UI/ArenaIntroModel")
local ArenaText = require("@game/StarterPlayer/StarterPlayerScripts/Game/UI/ArenaText")
local LoadoutModel = require("@game/StarterPlayer/StarterPlayerScripts/Game/UI/LoadoutModel")

local function arena(stage, extra)
	local st = {
		stage = stage,
		endsAt = 120,
		a = ArenaDoubles.duellist(1, "crimson", "adoring"),
		b = ArenaDoubles.duellist(7, "azure", "divided"),
	}
	for k, v in extra or {} do
		st[k] = v
	end
	return st
end

local LOOKUP = {
	kingdom = function(id)
		return ({ crimson = { id = "crimson", name = "Emberhold" }, azure = { id = "azure", name = "Frostmere" } })[id]
	end,
	name = function(userId)
		return ({ [1] = "Sam", [7] = "Rowan" })[userId]
	end,
}

describe("UI/LoadoutModel (FL-0073)", function()
	it("only a champion in the loadout stage gets the picker; the side follows the user id", function()
		local support = ArenaDoubles.support("adoring", 1)
		local choice = LoadoutModel.choice(nil, support)
		expect(LoadoutModel.view(arena("intro"), support, 1, choice, 100)).toBeNil()
		expect(LoadoutModel.view(arena("loadout"), support, 99, choice, 100)).toBeNil() -- a spectator
		expect(LoadoutModel.view(arena("loadout"), support, 7, choice, 100).side).toBe("b")
		-- an AI champion never matches a player (AI duellists carry a placeholder user id)
		local ai = arena("loadout")
		ai.a.isAI = true
		expect(LoadoutModel.side(ai, 1)).toBeNil()
	end)

	it("starts on the defaults and the first offers up to the slots; toggling respects the slots", function()
		local support = ArenaDoubles.support("divided", 1) -- 2 slots, 3 offers
		local choice = LoadoutModel.choice(nil, support)
		expect(choice.weapon).toBe("swordShield")
		expect(choice.armour).toBe("medium")
		expect(#choice.triggers).toBe(2)
		local view = LoadoutModel.view(arena("loadout"), support, 1, choice, 110)
		expect(view.slotsText).toBe("Perks 2 of 2")
		expect(view.offers[3].locked).toBe(true) -- full: the third must wait
		expect(view.offers[1].selected).toBe(true)
		-- a full set refuses a new one; dropping one frees a slot
		local same = LoadoutModel.toggle(choice, view.offers[3].trigger, support)
		expect(#same.triggers).toBe(2)
		expect(table.find(same.triggers, view.offers[3].trigger)).toBeNil()
		local fewer = LoadoutModel.toggle(choice, choice.triggers[1], support)
		expect(#fewer.triggers).toBe(1)
		local swapped = LoadoutModel.toggle(fewer, view.offers[3].trigger, support)
		expect(#swapped.triggers).toBe(2)
		-- never a perk that is not offered
		expect(#LoadoutModel.toggle(fewer, "crowdRally", support).triggers).toBe(1)
	end)

	it("offers show the citizen, loyalty, power, effect and condition; Crowd Rally only for Adoring", function()
		local adoring = ArenaDoubles.support("adoring", 1)
		local view = LoadoutModel.view(arena("loadout"), adoring, 1, LoadoutModel.choice(nil, adoring), 110)
		local reforge = view.offers[1]
		expect(reforge.name).toBe("Reforge")
		expect(reforge.citizen).toBe("Bram · Blacksmith")
		expect(reforge.loyalty).toBe(88)
		expect(reforge.power).toBe("Pledged")
		expect(reforge.condition).toBe("Your HP first drops below 50%")
		local rally = view.offers[#view.offers]
		expect(rally.trigger).toBe("crowdRally")
		expect(rally.crowd).toBe(true)
		expect(rally.citizen).toBeNil()
		expect(view.tier.name).toBe("Adoring")
		local loyal = ArenaDoubles.support("loyal", 1)
		for _, o in LoadoutModel.view(arena("loadout"), loyal, 1, LoadoutModel.choice(nil, loyal), 110).offers do
			expect(o.trigger).never.toBe("crowdRally")
		end
	end)

	it("Hostile support says there are no slots; the clock turns urgent in the last 5 s", function()
		local hostile = ArenaDoubles.support("hostile", 1)
		local view = LoadoutModel.view(arena("loadout"), hostile, 1, LoadoutModel.choice(nil, hostile), 116)
		expect(#view.offers).toBe(0)
		expect(view.noOffers).toBe("Hostile support: no perk slots this duel")
		expect(view.slotsText).toBe("No perk slots")
		expect(view.clock).toBe("0:04")
		expect(view.urgent).toBe(true)
		expect(LoadoutModel.view(arena("loadout"), hostile, 1, LoadoutModel.choice(nil, hostile), 110).urgent).toBe(
			false
		)
	end)

	it("the Ready status follows the server's answer in words", function()
		local s = ArenaDoubles.support("loyal", 1)
		local c = LoadoutModel.choice(nil, s)
		local st = arena("loadout")
		expect(LoadoutModel.view(st, s, 1, c, 100, { pending = true }).confirm.enabled).toBe(false)
		local ok = LoadoutModel.view(st, s, 1, c, 100, { ok = true })
		expect(ok.confirm.label).toBe("Ready ✓")
		expect(ok.status).toContain("You can still change it")
		expect(LoadoutModel.view(st, s, 1, c, 100, { ok = false, reason = "too_many" }).status).toBe(
			"Too many perks for your slots"
		)
		local w, a, t = LoadoutModel.args(c)
		expect(w).toBe("swordShield")
		expect(a).toBe("medium")
		expect(#t).toBe(3)
	end)
end)

describe("UI/ArenaText (FL-0073)", function()
	it("each tier's blessing and slots follow config Support (no stale literal)", function()
		local Support = require("@game/ReplicatedStorage/Forge/Config/Support")
		for _, id in Support.tierOrder do
			local t = Support.tiers[id]
			local best = 0
			for _, v in t.passive do
				best = math.max(best, v)
			end
			local expected = if best > 0 then `Blessing +{math.floor(best * 100 + 0.5)}%` else nil
			expect(ArenaText.tier(id).blessing).toBe(expected)
			expect(ArenaText.tier(id).slots).toBe(t.slots)
		end
		expect(ArenaText.blessing({ damageReduction = 0.02, staminaRegen = 0.01 })).toBe("Blessing +2%")
		expect(ArenaText.blessing({})).toBeNil()
	end)
end)

describe("UI/ArenaIntroModel (FL-0073)", function()
	it("the local champion on the left; tier, three reasons, loadout and perks per side", function()
		local st = arena("intro")
		st.a.triggers = { "reforge", "crowdRally" }
		st.a.weapon, st.a.armour = "spear", "light"
		st.a.triggerCitizens = { reforge = { name = "Bram", role = "blacksmith" } }
		st.b.reasons = {}
		local view = ArenaIntroModel.view(st, LOOKUP, 7, 110) -- Rowan is b
		expect(view.mine).toBe(true)
		expect(view.left.side).toBe("b")
		expect(view.left.champion).toBe("Rowan")
		expect(view.left.noReasons).toBe("No deeds remembered yet")
		expect(view.right.kingdomName).toBe("Emberhold")
		expect(view.right.tier.name).toBe("Adoring")
		expect(#view.right.reasons).toBe(3)
		expect(view.right.weapon.name).toBe("Spear")
		expect(view.right.triggers[1].citizen).toBe("Bram · Blacksmith")
		expect(view.right.triggers[2].citizen).toBeNil() -- the Crowd Rally has no citizen
		expect(view.left.noTriggers).toBe("No perks")
		expect(view.clock).toBe("0:10")
		-- a spectator sees a on the left; nothing outside the intro stage
		expect(ArenaIntroModel.view(st, LOOKUP, 99, 110).left.side).toBe("a")
		expect(ArenaIntroModel.view(arena("duel"), LOOKUP, 7, 110)).toBeNil()
	end)

	it("an AI champion is named for its kingdom", function()
		local st = arena("intro")
		st.b.isAI = true
		expect(ArenaIntroModel.view(st, LOOKUP, 1, 110).right.champion).toBe("Frostmere's champion")
	end)
end)

describe("UI/ArenaHudModel (FL-0073)", function()
	it(
		"says how the duel ended and who won, instead of a clock running into the crowning (D-059 arena pass)",
		function()
			local st = arena("duel", { endsAt = 40 })
			local function endedView(userId, winner, reason)
				local track = ArenaHudModel.new()
				ArenaHudModel.view(track, st, LOOKUP, userId, 0)
				ArenaHudModel.apply(track, { t = 5, kind = "ended", side = winner, data = { reason = reason } }, 5)
				return ArenaHudModel.view(track, st, LOOKUP, userId, 5)
			end
			local won = endedView(1, "a", "ko")
			expect(won.clock).toBe("KO")
			expect(won.note).toBe("You win")
			expect(won.urgent).toBe(false)
			expect(endedView(1, "b", "timeCap").clock).toBe("Time")
			expect(endedView(1, "b", "timeCap").note).toBe("You lost")
			local watched = endedView(99, "b", "forfeit") -- a spectator: the winner's kingdom
			expect(watched.clock).toBe("Forfeit")
			expect(watched.note).toBe(`{watched.right.kingdomName} wins`)
			local draw = endedView(1, "draw", "draw")
			expect(draw.clock).toBe("Draw")
			expect(draw.note).toBe("No winner")
			local running = ArenaHudModel.view(ArenaHudModel.new(), st, LOOKUP, 1, 0)
			expect(running.clock).toBe("0:40")
			expect(running.note).toBe("Duel")
		end
	)

	it("hits, snapshots and stamina-out move the bars; triggers go armed → active → spent", function()
		local st = arena("duel")
		st.a.triggers = { "reforge", "fieldRemedy" }
		st.b.triggers = { "heartyRations" }
		local track = ArenaHudModel.new()
		local view = ArenaHudModel.view(track, st, LOOKUP, 1, 0)
		expect(view.left.hp).toBe(1)
		expect(view.left.stamina).toBeNil() -- unknown until a snapshot
		ArenaHudModel.apply(track, { t = 3, kind = "hit", side = "b", data = { targetHpShare = 0.72 } }, 3)
		-- the hit alone moves the struck side (b hit a), before any snapshot
		local afterHit = ArenaHudModel.view(track, st, LOOKUP, 1, 3)
		expect(afterHit.left.hp).toBe(0.72)
		expect(afterHit.right.hp).toBe(1)
		ArenaHudModel.apply(track, {
			t = 3.2,
			kind = "snapshot",
			side = "a",
			data = { a = { hpShare = 0.72, staminaShare = 0.4 }, b = { hpShare = 0.9, staminaShare = 0.8 } },
		}, 3.2)
		ArenaHudModel.apply(track, { t = 4, kind = "staminaOut", side = "b" }, 4)
		ArenaHudModel.apply(
			track,
			{ t = 12, kind = "triggerFired", side = "a", data = { source = "perk:reforge" } },
			12
		)
		view = ArenaHudModel.view(track, st, LOOKUP, 1, 13)
		expect(view.left.hpText).toBe("72%")
		expect(view.left.stamina).toBe(0.4)
		expect(view.right.stamina).toBe(0)
		expect(view.right.hp).toBe(0.9)
		expect(view.left.triggers[1].state).toBe("active")
		expect(view.left.triggers[2].state).toBe("armed")
		expect(view.right.triggers[1].state).toBe("armed") -- the opponent's perks are visible too
		expect(ArenaHudModel.view(track, st, LOOKUP, 1, 12 + ArenaHudModel.ACTIVE_SEC).left.triggers[1].state).toBe(
			"spent"
		)
		-- a second fire of the same trigger never restarts it (each fires once)
		ArenaHudModel.apply(
			track,
			{ t = 30, kind = "triggerFired", side = "a", data = { source = "perk:reforge" } },
			30
		)
		expect(ArenaHudModel.view(track, st, LOOKUP, 1, 31).left.triggers[1].state).toBe("spent")
	end)

	it("the viewer's side is on the left; low HP flags; a new pair starts a fresh track", function()
		local st = arena("duel")
		local track = ArenaHudModel.new()
		ArenaHudModel.view(track, st, LOOKUP, 7, 0)
		ArenaHudModel.apply(track, { t = 50, kind = "hit", side = "a", data = { targetHpShare = 0.2 } }, 50)
		local view = ArenaHudModel.view(track, st, LOOKUP, 7, 50)
		expect(view.left.side).toBe("b")
		expect(view.left.low).toBe(true)
		expect(view.left.name).toBe("Rowan")
		expect(view.urgent).toBe(false)
		expect(ArenaHudModel.view(track, st, LOOKUP, 7, 110).urgent).toBe(true)
		local next = arena("duel")
		next.b = ArenaDoubles.duellist(9, "emerald", "loyal")
		expect(ArenaHudModel.view(track, next, LOOKUP, 1, 60).right.hp).toBe(1)
		expect(ArenaHudModel.view(track, arena("intro"), LOOKUP, 1, 60)).toBeNil()
	end)

	it("a passive perk (Fine Wares) is active from the start: it never fires", function()
		local st = arena("duel")
		st.a.triggers = { "fineWares", "reforge" }
		local view = ArenaHudModel.view(ArenaHudModel.new(), st, LOOKUP, 1, 0)
		expect(view.left.triggers[1].state).toBe("active")
		expect(view.left.triggers[2].state).toBe("armed")
	end)

	it("a new deadline keeps the triggers the server already holds", function()
		local support = ArenaDoubles.support("adoring", 1)
		local d = ArenaDoubles.duellist(1, "crimson", "adoring", { triggers = { "crowdRally" }, weapon = "mace" })
		local c = LoadoutModel.choice(d, support)
		expect(c.weapon).toBe("mace")
		expect(#c.triggers).toBe(1)
		expect(c.triggers[1]).toBe("crowdRally")
	end)

	it("ended and sudden death are carried; an unknown trigger source is ignored", function()
		local st = arena("duel")
		local track = ArenaHudModel.new()
		ArenaHudModel.view(track, st, LOOKUP, 1, 0)
		ArenaHudModel.apply(track, { t = 1, kind = "triggerFired", side = "a", data = { source = "perk:nonsense" } }, 1)
		ArenaHudModel.apply(track, { t = 120, kind = "snapshot", data = { suddenDeath = true } }, 120)
		ArenaHudModel.apply(track, {
			t = 125,
			kind = "ended",
			side = "a",
			data = { winner = "a", reason = "ko", hpA = 30, hpB = 0 },
		}, 125)
		local view = ArenaHudModel.view(track, st, LOOKUP, 1, 125)
		expect(view.suddenDeath).toBe(true)
		expect(view.ended.winner).toBe("a")
		expect(view.right.hp).toBe(0)
		expect(ArenaText.triggerFromSource("crowdRally")).toBe("crowdRally")
		expect(ArenaText.triggerFromSource("perk:nonsense")).toBeNil()
	end)
end)
