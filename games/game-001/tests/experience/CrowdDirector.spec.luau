local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local Crowd = require("@game/ReplicatedStorage/Forge/Config/Crowd")
local Sounds = require("@game/ReplicatedStorage/Forge/Config/Sounds")
local CrowdDirector = require("@game/ReplicatedStorage/Game/Feedback/CrowdDirector")
local ArenaText = require("@game/StarterPlayer/StarterPlayerScripts/Game/UI/ArenaText") -- FORGE-03's HUD names

local TIERS = { "adoring", "loyal", "divided", "restless", "hostile" }

local function director(tierA, tierB, extra)
	extra = extra or {}
	return CrowdDirector.new(Crowd, {
		a = { tier = tierA, kingdom = extra.kingdomA or "crimson", rulerName = extra.nameA },
		b = { tier = tierB, kingdom = extra.kingdomB or "azure", rulerName = extra.nameB },
	})
end

local function kinds(reactions)
	local out = {}
	for _, reaction in reactions do
		table.insert(out, `{reaction.stand}:{reaction.kind}`)
	end
	return out
end

local function ev(kind, side, data)
	return { t = 0, kind = kind, side = side, data = data }
end

describe("CrowdDirector: the stands are the population (FL-0074, design §7)", function()
	it("one figure per two citizens, at most 60 a stand and 120 in the arena; nonsense counts are 0", function()
		expect(CrowdDirector.figures(0, Crowd)).toBe(0)
		expect(CrowdDirector.figures(1, Crowd)).toBe(1)
		expect(CrowdDirector.figures(41, Crowd)).toBe(21)
		expect(CrowdDirector.figures(120, Crowd)).toBe(60)
		expect(CrowdDirector.figures(500, Crowd)).toBe(60)
		expect(CrowdDirector.figures(-5, Crowd)).toBe(0)
		expect(CrowdDirector.figures(0 / 0, Crowd)).toBe(0)
		expect(CrowdDirector.figures("60", Crowd)).toBe(0)
		local a, b = CrowdDirector.stands(400, 400, Crowd)
		expect(a + b <= Crowd.maxTotal).toBe(true)
		expect({ a, b }).toEqual({ 60, 60 })
		local tight = table.clone(Crowd)
		tight.maxTotal = 70
		a, b = CrowdDirector.stands(120, 30, tight)
		expect(a + b).toBe(70)
		expect(b).toBe(15) -- the smaller stand keeps its figures; the bigger one gives way
		a, b = CrowdDirector.stands(120, 120, tight)
		expect({ a, b }).toEqual({ 35, 35 })
	end)

	it("a lower tier leaves more seats empty; an unknown tier counts as divided", function()
		local last = math.huge
		for _, tier in TIERS do
			local seated = CrowdDirector.seated(60, tier, Crowd)
			expect(seated <= last).toBe(true)
			last = seated
		end
		expect(CrowdDirector.seated(60, "adoring", Crowd)).toBe(60)
		expect(CrowdDirector.seated(60, "hostile", Crowd) < CrowdDirector.seated(60, "restless", Crowd)).toBe(true)
		expect(CrowdDirector.seated(60, "nonsense", Crowd)).toBe(CrowdDirector.seated(60, "divided", Crowd))
	end)
end)

describe("CrowdDirector: reactions follow the tier and the duel (design §3, §7)", function()
	it("a big hit: the hitter's stand reacts by its tier's good, the other by its tier's bad", function()
		local d = director("adoring", "hostile")
		expect(kinds(d:onEvent(ev("hit", "a", { damageShare = 0.2 }), 10))).toEqual({ "a:roar", "b:turnBack" })
		local e = director("loyal", "restless")
		expect(kinds(e:onEvent(ev("hit", "b", { heavy = true }), 10))).toEqual({ "b:scattered", "a:gasp" })
		local reactions = director("divided", "divided"):onEvent(ev("parry", "a"), 0)
		expect(kinds(reactions)).toEqual({ "a:mixed", "b:mutter" })
		expect(reactions[1].major).toBe(true)
		expect(reactions[1].caption).toBe("(Half the stand cheers)")
		expect(reactions[1].sound).toBe("crowd.mixed")
	end)

	it("a hostile stand boos or turns its back on its own ruler, never cheers them", function()
		local d = director("hostile", "adoring")
		expect(kinds(d:onEvent(ev("stagger", "a"), 0))).toEqual({ "a:turnBack", "b:roar" })
		expect(kinds(d:onEvent(ev("parry", "a"), 5))).toEqual({ "a:silence", "b:gasp" })
		expect(d:idle("a").kind).toBe("boo")
		expect(d:idle("b").kind).toBe("chant")
		expect(d:idle("c")).toBeNil()
	end)

	it("small hits are minor: only the hitter's stand, at most one per stand every minorGapSec", function()
		local d = director("loyal", "loyal")
		local first = d:onEvent(ev("hit", "a", { damageShare = 0.05 }), 0)
		expect(kinds(first)).toEqual({ "a:cheer" })
		expect(first[1].major).toBe(false)
		expect(#d:onEvent(ev("hit", "a", { damageShare = 0.05 }), Crowd.minorGapSec - 0.1)).toBe(0)
		expect(kinds(d:onEvent(ev("hit", "b", { damageShare = 0.05 }), 0.1))).toEqual({ "b:cheer" })
		expect(#d:onEvent(ev("hit", "a", { damageShare = 0.05 }), Crowd.minorGapSec + 0.01)).toBe(1)
		expect(kinds(d:onEvent(ev("staminaOut", "b"), 5))).toEqual({ "b:gasp" })
		expect(kinds(d:onEvent(ev("heavyWindup", "a"), 5))).toEqual({ "a:murmur" })
	end)

	it("at most one major reaction every 3 s; one arriving sooner is dropped, not queued", function()
		local d = director("adoring", "loyal")
		expect(#d:onEvent(ev("parry", "a"), 10)).toBe(2)
		expect(#d:onEvent(ev("parry", "b"), 10 + Crowd.majorGapSec - 0.01)).toBe(0)
		expect(#d:onEvent(ev("stagger", "a"), 11)).toBe(0)
		expect(#d:onEvent(ev("parry", "b"), 10 + Crowd.majorGapSec)).toBe(2)
		expect(Crowd.majorGapSec).toBe(3)
	end)

	it("perk moments always win: they play inside the gap, restart it, and duck the crowd", function()
		local d = director("adoring", "divided")
		d:onEvent(ev("parry", "b"), 20)
		local perk = d:onEvent(
			ev("triggerFired", "a", { source = "perk:reforge", trigger = "reforge", citizenName = "Mara" }),
			20.5
		)
		expect(kinds(perk)).toEqual({ "a:perk" })
		expect(perk[1].priority).toBe(true)
		expect(perk[1].caption).toBe("Mara steps up: Reforge!")
		expect(d:volume(20.6)).toBe(Crowd.duck.volume)
		expect(d:volume(20.5 + Crowd.duck.perkSec + 0.01)).toBe(1)
		expect(#d:onEvent(ev("parry", "a"), 23)).toBe(0) -- the perk restarted the gap
		local rally = d:onEvent(ev("triggerFired", "a", { source = "crowdRally", trigger = "crowdRally" }), 23.1)
		expect(kinds(rally)).toEqual({ "a:rally" })
		local anonymous = director("loyal", "loyal"):onEvent(ev("triggerFired", "b", { trigger = "fineWares" }), 0)
		expect(anonymous[1].caption).toBe("A citizen steps up: Fine Wares!")
	end)

	it("a triggerFired names its perk from `trigger`, else from `source`, never a raw id (FORGE-01's relay)", function()
		local function caption(data)
			return director("loyal", "loyal"):onEvent(ev("triggerFired", "a", data), 0)[1]
		end
		expect(caption({ source = "perk:fieldRemedy", citizenName = "Ivo" }).caption).toBe(
			"Ivo steps up: Field Remedy!"
		)
		expect(caption({ source = "crowdRally" }).kind).toBe("rally") -- no trigger: the source says it
		expect(caption({ source = "perk:somethingNew" }).caption).toBe("A citizen steps up: their pledge!")
		expect(caption({ citizenName = 7 }).caption).toBe("A citizen steps up: their pledge!")
		-- an empty or blank name is no name (FORGE-00: it captioned " steps up: Reforge!")
		expect(caption({ trigger = "reforge", citizenName = "" }).caption).toBe("A citizen steps up: Reforge!")
		expect(caption({ trigger = "reforge", citizenName = "   " }).caption).toBe("A citizen steps up: Reforge!")
		-- every TriggerId of CONTRACTS G12.1 has a name
		for _, id in
			{ "reforge", "fieldRemedy", "calledWarning", "heartyRations", "rallyingHymn", "fineWares", "crowdRally" }
		do
			expect(type(Crowd.triggerNames[id])).toBe("string")
		end
		-- the crowd's caption and FORGE-03's arena HUD (#214) name every perk the same way
		for id, entry in ArenaText.TRIGGERS do
			expect(Crowd.triggerNames[id]).toBe(entry.name)
		end
		for id in Crowd.triggerNames do
			expect(ArenaText.TRIGGERS[id] ~= nil).toBe(true)
		end
	end)

	it(
		"DuelModel's raw hit data: targetHpShare still drives near-death, raw damage points are not a share (#221 L1)",
		function()
			local d = director("loyal", "adoring")
			-- 30 HP points of a 100 HP champion, read as a share, would be a big hit: it must stay minor
			expect(kinds(d:onEvent(ev("hit", "b", { damage = 30, targetHp = 70, targetHpShare = 0.7 }), 0))).toEqual({
				"b:roar",
			})
			-- the target falls below nearDeath on the model's own field: both stands react
			local near = d:onEvent(ev("hit", "b", { damage = 55, targetHp = 15, targetHpShare = 0.15 }), 4)
			expect(kinds(near)).toEqual({ "a:gasp", "b:roar" })
			-- hpShare wins when the relay sends both
			local e = director("loyal", "loyal")
			expect(#e:onEvent(ev("hit", "b", { hpShare = 0.9, targetHpShare = 0.1 }), 0)).toBe(1) -- minor: 0.9 is not near death
		end
	)

	it("near-death once per champion, and a comeback when the trailing champion takes the lead", function()
		local d = director("loyal", "adoring")
		-- b hits a down to 15 %: near-death for a (bad for a)
		expect(kinds(d:onEvent(ev("hit", "b", { damageShare = 0.05, hpShare = 0.15 }), 0))).toEqual({
			"a:gasp",
			"b:roar",
		})
		expect(kinds(d:onEvent(ev("hit", "b", { damageShare = 0.02, hpShare = 0.1 }), 4))).toEqual({ "b:roar" }) -- minor now
		-- a fights back: b falls from 100 % to 5 %, below a's 10 %: a comeback for a
		local back = d:onEvent(ev("hit", "a", { damageShare = 0.05, hpShare = 0.05 }), 8)
		expect(kinds(back)).toEqual({ "a:cheer", "b:gasp" })
		local zero = director("loyal", "loyal")
		expect(#zero:onEvent(ev("hit", "a", { damageShare = 0.05, hpShare = 0 }), 0)).toBe(1) -- the finish is `ended`
		expect(#zero:onEvent(ev("hit", "a", { damageShare = 0.05, hpShare = 0 / 0 }), 5)).toBe(1)
	end)

	it(
		"a hype event (sent only when the meter is full) chants for a chanting tier only, with the ruler's name",
		function()
			local d = director("adoring", "restless", { nameA = "Sam", kingdomA = "emerald" })
			local first = d:onEvent(ev("hype", "a", nil), 0)
			expect(kinds(first)).toEqual({ "a:chant" })
			expect(first[1].caption).toBe("Emerald stands!")
			local second = d:onEvent(ev("hype", "a", nil), 3)
			expect(second[1].caption).toBe("Strong as the oak, Sam!")
			expect(#d:onEvent(ev("hype", "b", nil), 6)).toBe(0) -- restless does not chant
			expect(#d:onEvent(ev("hype", "a", nil), 5.5)).toBe(0) -- rationed as a major
			expect(CrowdDirector.chant("nowhere", 2, nil, Crowd)).toBe("For the kingdom!") -- no name, no {ruler}
			expect(CrowdDirector.chant("gold", 2, "%1", Crowd)).toBe("Shine, %1!") -- a name is never a pattern
		end
	)

	it("four endings: win or loss x high or low support, both stands, once (design §7)", function()
		expect(CrowdDirector.ending(true, "adoring", Crowd)).toBe("flood")
		expect(CrowdDirector.ending(true, "loyal", Crowd)).toBe("flood")
		expect(CrowdDirector.ending(true, "divided", Crowd)).toBe("thinCrowning")
		expect(CrowdDirector.ending(false, "loyal", Crowd)).toBe("salute")
		expect(CrowdDirector.ending(false, "hostile", Crowd)).toBe("empty")
		local d = director("hostile", "adoring")
		d:onEvent(ev("parry", "a"), 0)
		local ending = d:onEvent(ev("ended", "a"), 0.5)
		expect(kinds(ending)).toEqual({ "a:thinCrowning", "b:salute" })
		expect(ending[1].priority).toBe(true)
		expect(ending[2].caption).toBe("They fought for us! (The stand salutes)")
		expect(#d:finish("b", 1)).toBe(0)
		expect(#d:onEvent(ev("parry", "b"), 10)).toBe(0) -- nothing after the end
	end)

	it("a duel with no winner or a draw is called off, once, with no payoff (#193 L1, FORGE-00)", function()
		local d = director("adoring", "hostile")
		expect(kinds(d:finish(nil, 10))).toEqual({ "a:calledOff", "b:calledOff" })
		expect(#d:onEvent(ev("parry", "a"), 20)).toBe(0) -- nothing after the end
		expect(#d:finish("a", 21)).toBe(0)
		local e = director("loyal", "loyal")
		local off = e:onEvent({ t = 0, kind = "ended", side = "draw", data = { reason = "draw" } }, 5)
		expect(kinds(off)).toEqual({ "a:calledOff", "b:calledOff" })
		expect(off[1].priority).toBe(true)
		expect(off[1].caption).toBe("(The duel was called off)")
		expect(off[1].sound).toBeNil()
		expect(#e:onEvent(ev("hit", "a", { heavy = true }), 9)).toBe(0)
		local g = director("loyal", "loyal")
		expect(kinds(g:onEvent({ t = 0, kind = "ended" }, 0))).toEqual({ "a:calledOff", "b:calledOff" }) -- no side
		local f = director("loyal", "loyal")
		expect(#f:finish("c", 0)).toBe(0) -- a side that does not exist ends nothing
		expect(#f:onEvent(ev("parry", "a"), 1)).toBe(2)
	end)

	it("ignores unknown kinds, sides and data; an unknown tier is divided", function()
		local d = director("glorious", nil)
		expect(#d:onEvent(ev("dance", "a"), 0)).toBe(0)
		expect(#d:onEvent(ev("parry", "c"), 0)).toBe(0)
		expect(#d:onEvent("parry", 0)).toBe(0)
		expect(kinds(d:onEvent({ kind = "parry", side = "a", data = "x" }, 0))).toEqual({ "a:mixed", "b:mutter" })
		d:duck(0, 0 / 0)
		d:duck(0, -1)
		expect(d:volume(0)).toBe(1)
		d:duck(0, 1e9)
		expect(d:volume(31)).toBe(1) -- a duck never lasts more than 30 s
	end)
end)

describe("Crowd config (FL-0074)", function()
	it("every tier has every reaction it names, with a subtitle or a chant line; sounds exist", function()
		local known = {}
		for _, entry in Sounds do
			known[entry.id] = entry
		end
		for _, tier in TIERS do
			local row = Crowd.tiers[tier]
			assert(row ~= nil, tier)
			for _, key in { "idle", "good", "bad" } do
				local reaction = Crowd.reactions[row[key]]
				assert(reaction ~= nil, `{tier}.{key} = {row[key]} is a reaction`)
				assert(reaction.caption ~= nil or row[key] == "chant", `{row[key]} has a subtitle`)
			end
		end
		for name, reaction in Crowd.reactions do
			assert(reaction.sound == nil or known[reaction.sound], `{name}: sound {reaction.sound} is in Sounds.luau`)
		end
		for name, ending in Crowd.endings do
			assert(type(ending.caption) == "string", `{name} has a subtitle`)
			assert(ending.sound == nil or known[ending.sound], `{name}: sound {ending.sound} is in Sounds.luau`)
		end
		for kingdom, lines in Crowd.chants do
			assert(#lines >= 2, `{kingdom} has chants`)
		end
	end)
end)
