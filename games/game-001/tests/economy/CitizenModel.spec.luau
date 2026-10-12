-- FL-0088 pure view models: UI/CitizenModel (card, conversation, effects, outcomes, geometry) and
-- UI/CitizenText (refusal reasons). Server text must pass through untouched; only labels are made here.
local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local CitizenDoubles = require("./doubles/CitizenDoubles")
local CitizenModel = require("@game/StarterPlayer/StarterPlayerScripts/Game/UI/CitizenModel")
local CitizenText = require("@game/StarterPlayer/StarterPlayerScripts/Game/UI/CitizenText")
local Layout = require("@game/StarterPlayer/StarterPlayerScripts/Game/UI/Layout")

local EDDA = CitizenDoubles.CITIZENS[1]

local function payload(scenario, entityId)
	local options = {}
	for _, r in scenario.responses do
		table.insert(options, { id = r.id, text = r.text })
	end
	return {
		entityId = entityId or 41,
		scenarioId = scenario.scenarioId,
		speaker = { name = "Edda Thornbury", occupation = "Farmer" },
		question = scenario.question,
		options = options,
	}
end

describe("CitizenModel.card", function()
	it("passes the CitizenView through and adds only labels", function()
		local card = CitizenModel.card(EDDA)
		expect(card.name).toBe("Edda Thornbury")
		expect(card.firstName).toBe("Edda")
		expect(card.initial).toBe("E")
		expect(card.sub).toBe("Farmer")
		expect(card.request).toBe(true)
		expect(card.talk).toEqual({ text = "Talk", variant = "primary" })
		expect(#card.stats).toBe(3)
		expect(card.stats[1].id).toBe("loyalty")
		expect(card.stats[1].text).toBe("72")
		expect(card.stats[2].band).toBe("Content")
		expect(card.intent).toBe(EDDA.intent)
		expect(card.intentIcon).toBe("farm")
		expect(card.traits).toEqual(EDDA.traits)
		expect(card.relations[1]).toEqual({
			id = "family",
			label = "Family",
			names = EDDA.family,
			rival = false,
		})
		expect(card.relations[3].label).toBe("Rival")
		expect(card.relations[3].rival).toBe(true)
		expect(card.lastMemory).toBe("You visited the farms at dawn")
		-- the last memory is not repeated in the list
		expect(card.memories).toEqual({
			"The harvest came in early",
			"Bran fell ill and got better",
			"Soldiers marched through the east field",
		})
	end)

	it("names the job when it differs from the occupation and pluralises relations", function()
		local lise = CitizenModel.card(CitizenDoubles.CITIZENS[3])
		expect(lise.sub).toBe("Elder · Idle")
		expect(lise.relations[#lise.relations].label).toBe("Rivals")
		local quiet = CitizenModel.card(CitizenDoubles.CITIZENS[4])
		expect(quiet.request).toBe(false)
		expect(quiet.talk).toEqual({ text = "Ask", variant = "secondary" })
		for _, r in quiet.relations do
			expect(r.id).never.toBe("rivals") -- empty lists leave no row
		end
	end)

	it("accepts a G5-only inspect result (no loyalty, obedience or traits)", function()
		local card =
			CitizenModel.card({ name = "Ada", job = "miner", mood = 12.4, intent = "Mining", lastMemory = nil })
		expect(card.sub).toBe("Miner")
		expect(#card.stats).toBe(1)
		expect(card.stats[1]).toEqual({
			id = "mood",
			label = "Mood",
			value = 12,
			text = "12",
			band = "Miserable",
			fill = "gold",
		})
		expect(#card.traits).toBe(0)
		expect(#card.relations).toBe(0)
		expect(card.request).toBe(false)
	end)

	it("clamps numbers, skips non-strings and caps traits", function()
		local card = CitizenModel.card({
			name = "Ödön Ray",
			loyalty = 140,
			obedience = -3,
			traits = { "A", 5, "", "B", "C", "D", "E", "F", "G" },
			family = { "X", false },
		})
		expect(card.initial).toBe("Ö")
		expect(card.stats[1].value).toBe(100)
		expect(card.stats[2].value).toBe(0)
		expect(card.traits).toEqual({ "A", "B", "C", "D", "E", "F" })
		expect(card.relations[1].names).toEqual({ "X" })
		expect(card.sub).toBe("Citizen")
	end)

	it("is nil for anything that is not a named citizen", function()
		expect(CitizenModel.card(nil)).toBeNil()
		expect(CitizenModel.card({ entityId = 3 })).toBeNil()
		expect(CitizenModel.card({ name = "" })).toBeNil()
	end)

	it("mood bands", function()
		expect(CitizenModel.moodBand(0)).toBe("Miserable")
		expect(CitizenModel.moodBand(20)).toBe("Unhappy")
		expect(CitizenModel.moodBand(40)).toBe("Calm")
		expect(CitizenModel.moodBand(60)).toBe("Content")
		expect(CitizenModel.moodBand(80)).toBe("Joyful")
		expect(CitizenModel.moodBand(100)).toBe("Joyful")
	end)
end)

describe("CitizenModel.conversation", function()
	it("keeps the server's question and options, in order", function()
		for _, key in { "two", "three", "four", "long" } do
			local scenario = CitizenDoubles.SCENARIOS[key]
			local c = CitizenModel.conversation(payload(scenario))
			expect(c.scenarioId).toBe(scenario.scenarioId)
			expect(c.question).toBe(scenario.question)
			expect(#c.options).toBe(#scenario.responses)
			for i, o in c.options do
				expect(o.id).toBe(scenario.responses[i].id)
				expect(o.text).toBe(scenario.responses[i].text)
				expect(o.index).toBe(i)
			end
			expect(c.speaker).toEqual({ name = "Edda Thornbury", occupation = "Farmer", initial = "E" })
		end
	end)

	it("drops malformed and duplicate options, and is nil without anything to answer", function()
		local c = CitizenModel.conversation({
			scenarioId = "s",
			question = "Q?",
			options = {
				{ id = "a", text = "A" },
				{ id = "a", text = "again" },
				{ id = "", text = "x" },
				{ id = "b" },
				"c",
				{ id = "d", text = "D" },
			},
		})
		expect(#c.options).toBe(2)
		expect(c.options[2]).toEqual({ id = "d", text = "D", index = 2 })
		expect(CitizenModel.conversation(nil)).toBeNil()
		expect(CitizenModel.conversation({ scenarioId = "s", question = "Q?", options = {} })).toBeNil()
		expect(CitizenModel.conversation({ scenarioId = "s", options = { { id = "a", text = "A" } } })).toBeNil()
		expect(CitizenModel.conversation({ question = "Q?", options = { { id = "a", text = "A" } } })).toBeNil()
	end)

	it("names the speaker from the card when the payload has no speaker", function()
		local p = payload(CitizenDoubles.SCENARIOS.two)
		p.speaker = nil
		expect(CitizenModel.conversation(p, { name = "Bran Thornbury", occupation = "Hauler" }).speaker).toEqual({
			name = "Bran Thornbury",
			occupation = "Hauler",
			initial = "B",
		})
		expect(CitizenModel.conversation(p).speaker.name).toBe("Your citizen")
	end)
end)

describe("CitizenModel.effect and outcome", function()
	it("maps kinds to icons and keeps the server's text", function()
		local wood = CitizenModel.effect({ kind = "wood", text = "−20 Wood" })
		expect(wood).toEqual({
			kind = "wood",
			text = "−20 Wood",
			icon = "wood",
			tint = "resource:wood",
			tone = "down",
		})
		expect(CitizenModel.effect({ kind = "loyalty", text = "+8 Loyalty" }).icon).toBe("heart")
		expect(CitizenModel.effect({ kind = "loyalty", text = "+8 Loyalty" }).tone).toBe("up")
		expect(CitizenModel.effect({ kind = "reputation", text = "+3 Compassion" }).icon).toBe("laurel")
		expect(CitizenModel.effect({ kind = "fear", text = "+3 Fear" }).icon).toBe("laurel")
		expect(CitizenModel.effect({ kind = "morale", text = "-5 Army morale" }).tone).toBe("down")
		local unknown = CitizenModel.effect({ kind = "rumour", text = "The quarry crew grumbles" })
		expect(unknown.icon).toBe("info")
		expect(unknown.tone).toBe("neutral")
		expect(unknown.text).toBe("The quarry crew grumbles")
		expect(CitizenModel.effect({ kind = "wood" })).toBeNil()
		expect(CitizenModel.effect("wood")).toBeNil()
	end)

	it("outcome: answered, refused or failed", function()
		local result = CitizenDoubles.SCENARIOS.three.responses[1]
		local answered = CitizenModel.outcome(true, true, { reaction = result.reaction, effects = result.effects })
		expect(answered.phase).toBe("answered")
		expect(answered.reaction).toBe(result.reaction)
		expect(#answered.effects).toBe(#result.effects)
		local bare = CitizenModel.outcome(true, true, nil)
		expect(bare).toEqual({ phase = "answered", reaction = nil, effects = {} })
		local refused = CitizenModel.outcome(true, false, nil, "answered")
		expect(refused.phase).toBe("refused")
		expect(refused.message).toBe(CitizenText.reason("answered"))
		expect(CitizenModel.outcome(true, nil).phase).toBe("failed")
		expect(CitizenModel.outcome(false, "boom").phase).toBe("failed")
	end)

	it("CitizenText: known codes as sentences, unknown codes generic, never the raw code", function()
		expect(CitizenText.reason("not_eligible")).toBe("They've moved on from that. Ask again later.")
		expect(CitizenText.reason("cost")).toBe("The treasury can't pay for that answer.")
		expect(CitizenText.reason("weird_code")).toBe(CitizenText.GENERIC)
		expect(CitizenText.reason(nil)).toBe(CitizenText.GENERIC)
	end)
end)

describe("CitizenModel geometry", function()
	local function state(key, phase, extra)
		local s = {
			phase = phase or "asking",
			conversation = CitizenModel.conversation(payload(CitizenDoubles.SCENARIOS[key])),
		}
		for k, v in extra or {} do
			s[k] = v
		end
		return s
	end

	it("card: the drawer on phones, a fitted panel on tablet and desktop", function()
		local phone = Layout.compute(750, 311)
		expect(CitizenModel.cardRect(phone).height).toBe(phone.drawer.height)
		local desktop = Layout.compute(1920, 1022)
		local rect = CitizenModel.cardRect(desktop)
		expect(rect.height).toBe(CitizenModel.CARD_HEIGHT)
		expect(rect.x).toBe(desktop.drawer.x)
	end)

	it("conversation: the drawer on tablet/desktop, a wide sheet below the pills on phones", function()
		local desktop = Layout.compute(1920, 1022)
		expect(CitizenModel.conversationRect(desktop)).toEqual({
			x = desktop.drawer.x,
			y = desktop.drawer.y,
			width = desktop.drawer.width,
			height = desktop.drawer.height,
		})
		local phone = Layout.compute(750, 311)
		local r = CitizenModel.conversationRect(phone)
		expect(r.x).toBe(phone.margin)
		expect(r.y).toBe(phone.hud.bottom + 16)
		expect(r.x + r.width).toBe(phone.drawer.x + phone.drawer.width) -- left of the rail
		expect(r.y + r.height).toBe(phone.height - phone.margin)
	end)

	it("fitted heights grow with the text and never exceed the space", function()
		for _, size in { { 1920, 1022 }, { 1024, 690 }, { 750, 311 } } do
			local m = Layout.compute(size[1], size[2])
			local phone = m.breakpoint == "phone"
			local r = CitizenModel.conversationRect(m)
			local two = CitizenModel.conversationHeight(state("two"), r, phone)
			local four = CitizenModel.conversationHeight(state("four"), r, phone)
			local long = CitizenModel.conversationHeight(state("long"), r, phone)
			expect(four).toBeGreaterThan(two)
			expect(long).toBeGreaterThan(two)
			expect(long).toBeLessThanOrEqual(r.height)
			expect(two).toBe(math.floor(two)) -- whole pixels (UDim offsets are integers)
			local result = CitizenDoubles.SCENARIOS.three.responses[1]
			local answered = state("three", "answered", {
				picked = "help",
				outcome = CitizenModel.outcome(true, true, { reaction = result.reaction, effects = result.effects }),
			})
			local fewer = state("three", "answered", {
				picked = "help",
				outcome = CitizenModel.outcome(
					true,
					true,
					{ reaction = result.reaction, effects = { result.effects[1] } }
				),
			})
			expect(CitizenModel.conversationHeight(answered, r, phone)).toBeGreaterThanOrEqual(
				CitizenModel.conversationHeight(fewer, r, phone)
			)
		end
	end)

	it("lines: greedy word wrap", function()
		expect(CitizenModel.lines("one two three", 1000, 7)).toBe(1)
		expect(CitizenModel.lines("aaaa bbbb cccc", 63, 7)).toBe(2) -- two 28 px words and a space fit in 63 px
		expect(CitizenModel.lines("", 100, 7)).toBe(1)
	end)
end)
