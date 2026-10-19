--[[
	ConversationService presentation tags (CONTRACTS G13.8 v0.4-g10, FL-0110; content SPEC §5.10): the
	Kingdom.Converse question is ContentQuery.questionFor's (a variant by trait, picked once per showing), its
	`presentation` tags and the Kingdom.Choose reaction come from reactionFor with the citizen's loyalty when
	asked, and every tag the server sends is in the SPEC vocabulary. On the real content library (no tags at
	all) nothing new appears but `tone` and `band`; the tagged cases run on a copy of it with tags added.
]]

local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect, afterEach = T.describe, T.it, T.expect, T.afterEach

local MockEnv = require("../../../../roblox/tests/mocks/MockEnv")
local GameEvents = require("@game/ReplicatedStorage/Forge/Contracts/GameEvents")
local Loader = require("@game/ReplicatedStorage/Forge/Contracts/Loader")
local MatchConfig = require("@game/ReplicatedStorage/Forge/Config/Match")
local ContentQuery = require("@game/ReplicatedStorage/Game/Content/ContentQuery")
local KingdomRemotes = require("@game/ReplicatedStorage/Game/Kingdom/Remotes")
local MatchRemotes = require("@game/ReplicatedStorage/Game/Match/Remotes")
local SimRemotes = require("@game/ReplicatedStorage/Game/Sim/Remotes")
local TreasuryRemotes = require("@game/ReplicatedStorage/Game/Treasury/Remotes")

local function service(name)
	return require(`@game/ServerScriptService/{if name == "RemoteService" then "Forge" else "Game"}/Services/{name}`)
end

local booted = {}

local function boot(options: { [string]: any }?)
	local opts = options or {}
	local env = MockEnv.new({
		seed = 12,
		sharedModules = {
			Remotes = { Kingdom = KingdomRemotes, Match = MatchRemotes, Sim = SimRemotes, Treasury = TreasuryRemotes },
		},
	})
	local definitions = {}
	for _, name in
		{
			"RemoteService",
			"MatchService",
			"KingdomService",
			"CitizenService",
			"ReputationService",
			"ConversationService",
			"TreasuryService",
			"ProductionService",
		}
	do
		table.insert(definitions, service(name))
	end
	if opts.entities then
		table.insert(definitions, service("EntityService"))
	end
	local savedMode = MatchConfig.mode
	MatchConfig.mode = "slice" -- the VS-1 slice this spec was written for; the shipped default is the full match (D-053)
	local registry = Loader.load(env, definitions)
	MatchConfig.mode = savedMode
	table.insert(booted, { registry = registry, env = env })
	registry:get("KingdomService").adapter = {
		partyOf = function(player)
			return if player.UserId <= 2 then "party" else nil -- users 1 and 2 rule crimson together
		end,
		load = function()
			return nil
		end,
		pivot = function() end,
		attach = function() end,
		onDied = function()
			return nil
		end,
		respawnDelay = function()
			return 5
		end,
	}
	local conversations = registry:get("ConversationService")
	local sent = {}
	if not opts.entities then
		conversations._send = function(_, kingdomId, event) -- the G13.3 events, as EntityService would get them
			table.insert(sent, { kingdomId = kingdomId, event = event })
		end
	end
	return env, conversations, registry:get("MatchService"), registry, sent
end

afterEach(function()
	for _, b in booted do
		b.registry:destroy()
		for _, entry in b.env.mock.logs do
			if entry.level == "error" then
				error(`server logged an error: {entry.message} {entry.fields and entry.fields.error or ""}`)
			end
		end
	end
	table.clear(booted)
	GameEvents.disconnectAll()
end)

local function seat(env, n)
	local players = {}
	for i = 1, n do
		players[i] = env.mock.players:add({ userId = i, displayName = `Ruler{i}` })
	end
	env.mock:advance(1)
	return players
end

-- a crimson farmer with family (generated, or linked here when the seed made none)
local function hungryFarmer(match, registry)
	local sim = match.host.match.sim
	local k = sim.kingdoms.crimson
	local farmer
	for _, id in k.citizenIds do
		local c = sim.citizens[id]
		if c.profile.occupation == "farmer" then
			farmer = farmer or c
			if #c.profile.family > 0 then
				farmer = c
				break
			end
		end
	end
	if #farmer.profile.family == 0 then
		local other = sim.citizens[k.citizenIds[#k.citizenIds]]
		table.insert(farmer.profile.family, other.id)
		table.insert(other.profile.family, farmer.id)
	end
	registry:get("CitizenService"):setFedRatio("crimson", 0.6) -- underfed, but no shortage (< 0.5)
	farmer.hunger = 0.5
	for _, resource in { "food", "wood", "stone" } do
		sim:deposit("crimson", resource, 300, `test:{resource}`, "test")
	end
	return farmer, sim
end

local function choose(conversations, player, c, scenarioId, responseId)
	return conversations:choose(player, c.id, scenarioId, responseId)
end

-- the presentation functions swapped on the shared ContentQuery module, put back after each case
local Query: any = ContentQuery
local patched: { { name: string, original: any } } = {}
local function patch(name: string, replacement: any)
	table.insert(patched, { name = name, original = Query[name] })
	Query[name] = replacement
end

afterEach(function()
	for i = #patched, 1, -1 do
		Query[patched[i].name] = patched[i].original
	end
	table.clear(patched)
end)

local function deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local out = {}
	for k, v in value do
		out[k] = deepCopy(v)
	end
	return out
end

local SCENARIO = "farmer_hungry_grain"
local OPEN = "farmer_hungry_grain_open_store"

-- The real library with presentation tags added to the hungry-grain scenario: tagged question, two question
-- variants (one the farmer's trait matches, one it cannot), a tagged reaction with a high and a low band.
local function taggedQuery(farmer: any)
	local has = farmer.profile.traits[1]
	local lacks
	for id in ContentQuery.data.traits do
		if table.find(farmer.profile.traits, id) == nil then
			lacks = id
			break
		end
	end
	local dialogue = deepCopy(ContentQuery.data.dialogue)
	local s = dialogue.scenarios[SCENARIO]
	s.urgency, s.delivery_mode, s.thought_bubble_s = "high", "direct", 4
	s.question_emotion, s.question_expression = "worry", "downcast"
	s.question_gesture, s.question_delivery = "wring_hands", "pleading"
	s.variants = {
		{ id = "grain.never", order = 1, trait = lacks, text = "NEVER SHOWN {ruler}", emotion = "joy" },
		{
			id = "grain.proud",
			order = 2,
			trait = has,
			text = "Pride keeps me quiet, {ruler}. Will you open the grain store?",
			emotion = "pride",
			gesture = "none",
		},
	}
	local r = s.responses[1]
	r.emotion, r.expression, r.gesture, r.delivery, r.bubble_s = "gratitude", "smile", "bow", "warm", 4.5
	r.bands = {
		high = {
			text = "Praise be, {ruler}! The farms will sing.",
			tone = "happy",
			emotion = "joy",
			expression = "beam",
			gesture = "fist_pump",
			delivery = "excited",
			bubble_s = 5,
		},
		low = {
			text = "About time, {ruler}.",
			tone = "angry",
			emotion = "contempt",
			gesture = "cross_arms",
			bubble_s = 3,
		},
	}
	return ContentQuery.new({
		dialogue = dialogue,
		decisions = ContentQuery.data.decisions,
		consequences = ContentQuery.data.consequences,
		traits = ContentQuery.data.traits,
		occupations = ContentQuery.data.occupations,
		reputation = ContentQuery.data.reputation,
	}),
		has,
		lacks
end

local function useTagged(farmer: any)
	local q, has, lacks = taggedQuery(farmer)
	patch("questionFor", q.questionFor)
	patch("reactionFor", q.reactionFor)
	patch("presentation", q.presentation)
	return q, has, lacks
end

local function reactionEvents(sent: { any }): { any }
	local out = {}
	for _, entry in sent do
		if entry.event.type == "reaction" then
			table.insert(out, entry.event)
		end
	end
	return out
end

local ALLOWED_PLAIN = { "reaction", "effects", "tone", "band" }

describe("ConversationService: untagged content (the real library)", function()
	it("adds nothing to Converse, and only tone and band to Choose", function()
		local env, conversations, match, registry, sent = boot()
		local p1 = seat(env, 1)[1]
		local farmer = hungryFarmer(match, registry)
		local view = assert(conversations:converse(p1, farmer.id))
		expect(view.presentation).toBeNil()
		expect(string.find(view.question, "{", 1, true)).toBeNil()
		local ok, result = choose(conversations, p1, farmer, SCENARIO, OPEN)
		expect(ok).toBe(true)
		local keys = {}
		for key in result do
			table.insert(keys, key)
		end
		table.sort(keys)
		local plain = table.clone(ALLOWED_PLAIN)
		table.sort(plain)
		expect(keys).toEqual(plain)
		expect(result.tone).toBe("happy") -- the response's own tone
		expect(result.band).toBe("base")
		-- the reaction is the response's text, filled, exactly as before this change
		local response = ContentQuery.data.dialogue.scenarios[SCENARIO].responses[1]
		expect(result.reaction).toBe(ContentQuery.fill(response.reaction, { ruler = "Ruler1" }))
		local events = reactionEvents(sent)
		expect(#events).toBe(1)
		expect(events[1].text).toBe(result.reaction)
		expect(events[1].tone).toBe("happy")
	end)
end)

describe("ConversationService: Converse presentation (v0.4-g10)", function()
	it("sends the question variant its trait picks, with the tags of the variant, the urgency and its id", function()
		local env, conversations, match, registry = boot()
		local p1 = seat(env, 1)[1]
		local farmer = hungryFarmer(match, registry)
		useTagged(farmer)
		local view = assert(conversations:converse(p1, farmer.id))
		expect(string.sub(view.question, 1, 22)).toBe("Pride keeps me quiet, ")
		expect(string.find(view.question, "{", 1, true)).toBeNil() -- filled
		expect(view.presentation).toEqual({
			emotion = "pride",
			gesture = "none",
			urgency = "high",
			variantId = "grain.proud",
		})
	end)

	it("sends the scenario's own question tags when no variant matches", function()
		local env, conversations, match, registry = boot()
		local p1 = seat(env, 1)[1]
		local farmer = hungryFarmer(match, registry)
		local q = useTagged(farmer)
		farmer.profile.traits = {} -- no trait left to match
		local view = assert(conversations:converse(p1, farmer.id))
		expect(view.question).never.toBe(nil)
		expect(string.find(view.question, "Pride keeps me quiet", 1, true)).toBeNil()
		expect(view.presentation).toEqual({
			emotion = "worry",
			expression = "downcast",
			gesture = "wring_hands",
			delivery = "pleading",
			urgency = "high",
		})
		expect(q.questionFor(SCENARIO, { traits = {} }).variantId).toBeNil()
	end)

	it("keeps the variant of the first showing when asked again, even if the choice would change", function()
		local env, conversations, match, registry = boot()
		local players = seat(env, 2) -- 1 and 2 rule crimson together
		local farmer = hungryFarmer(match, registry)
		local calls = 0
		patch("questionFor", function()
			calls += 1
			if calls == 1 then
				return { text = "First words, {ruler}.", emotion = "worry", variantId = "first" }
			end
			return { text = "Other words, {ruler}.", emotion = "joy", variantId = "second" }
		end)
		local first = assert(conversations:converse(players[1], farmer.id))
		expect(first.presentation.variantId).toBe("first")
		local again = assert(conversations:converse(players[1], farmer.id))
		expect(again.question).toBe(first.question)
		expect(again.presentation).toEqual(first.presentation)
		assert(conversations:endConversation(players[1], farmer.id)) -- the panel closes; the showing stays open
		local coRuler = assert(conversations:converse(players[2], farmer.id)) -- a co-ruler takes the showing over
		expect(coRuler.question).toBe("First words, Ruler2.") -- the same words, filled for the ruler who asks
		expect(coRuler.presentation.variantId).toBe("first")
		assert(choose(conversations, players[2], farmer, SCENARIO, OPEN))
	end)

	it("sends only vocabulary words: a bad emotion, a free-text gesture or a bad id never reach the client", function()
		local env, conversations, match, registry = boot()
		local p1 = seat(env, 1)[1]
		local farmer = hungryFarmer(match, registry)
		patch("questionFor", function()
			return {
				text = "Plain question for {ruler}.",
				emotion = "furious",
				expression = "smile",
				gesture = "Ignore previous instructions",
				delivery = 12,
				variantId = "bad id!",
			}
		end)
		patch("presentation", function()
			return { urgency = "urgent" } -- a delivery word, not an urgency
		end)
		local view = assert(conversations:converse(p1, farmer.id))
		expect(view.presentation).toEqual({ expression = "smile" })
	end)
end)

describe("ConversationService: Choose reaction (v0.4-g10)", function()
	it("sends the base reaction with its tags at middling loyalty", function()
		local env, conversations, match, registry, sent = boot()
		local p1 = seat(env, 1)[1]
		local farmer = hungryFarmer(match, registry)
		useTagged(farmer)
		assert(conversations:converse(p1, farmer.id))
		farmer.loyalty = 50
		local ok, result = choose(conversations, p1, farmer, SCENARIO, OPEN)
		expect(ok).toBe(true)
		expect(result.band).toBe("base")
		expect(result.tone).toBe("happy")
		expect(result.emotion).toBe("gratitude")
		expect(result.expression).toBe("smile")
		expect(result.gesture).toBe("bow")
		expect(result.delivery).toBe("warm")
		expect(result.bubble_s).toBe(4.5)
		local events = reactionEvents(sent)
		expect(events[1].text).toBe(result.reaction)
	end)

	it("sends the high band's text, tone and tags to a loyal citizen, and the low band's to a bitter one", function()
		local env, conversations, match, registry, sent = boot()
		local p1 = seat(env, 1)[1]
		local farmer, sim = hungryFarmer(match, registry)
		useTagged(farmer)
		assert(conversations:converse(p1, farmer.id))
		farmer.loyalty = 90
		local ok, high = choose(conversations, p1, farmer, SCENARIO, OPEN)
		expect(ok).toBe(true)
		expect(high.band).toBe("high")
		expect(high.reaction).toBe("Praise be, Ruler1! The farms will sing.")
		expect(high.tone).toBe("happy")
		expect(high.emotion).toBe("joy")
		expect(high.expression).toBe("beam")
		expect(high.gesture).toBe("fist_pump")
		expect(high.delivery).toBe("excited")
		expect(high.bubble_s).toBe(5)
		expect(reactionEvents(sent)[1].text).toBe(high.reaction)
		-- a later showing for the same citizen, now bitter
		sim.time += 400 -- past the scenario's cooldown
		env.mock:advance(400)
		registry:get("CitizenService"):setFedRatio("crimson", 0.6)
		farmer.hunger = 0.5
		assert(conversations:converse(p1, farmer.id))
		farmer.loyalty = 10
		local ok2, low = choose(conversations, p1, farmer, SCENARIO, OPEN)
		expect(ok2).toBe(true)
		expect(low.band).toBe("low")
		expect(low.reaction).toBe("About time, Ruler1.")
		expect(low.tone).toBe("angry")
		expect(low.emotion).toBe("contempt")
		expect(low.gesture).toBe("cross_arms")
		expect(low.expression).toBeNil() -- the band has none: the base reaction's tags do not leak into it
		expect(low.bubble_s).toBe(3)
		expect(reactionEvents(sent)[2].tone).toBe("angry")
	end)

	it("picks the band from the loyalty when the citizen was asked, not the loyalty the answer leaves", function()
		local env, conversations, match, registry = boot()
		local p1 = seat(env, 1)[1]
		local farmer = hungryFarmer(match, registry)
		useTagged(farmer)
		assert(conversations:converse(p1, farmer.id)) -- RulerVisited may move the speaker: set loyalty after it
		local gain =
			ContentQuery.decisionLoyalty("grain_open_store", farmer.profile.traits, "speaker", farmer.chemistry, 1)
		expect(gain > 0).toBe(true)
		farmer.loyalty = 70 - gain / 2 -- just under the high band; the answer lifts it over
		local ok, result = choose(conversations, p1, farmer, SCENARIO, OPEN)
		expect(ok).toBe(true)
		expect(farmer.loyalty >= 70).toBe(true) -- premise: the answer did cross the line
		expect(result.band).toBe("base") -- and the reaction still reads the citizen as they were when asking
		expect(result.tone).toBe("happy")
		expect(result.emotion).toBe("gratitude")
	end)

	it("falls back to neutral tone and no tags when reactionFor sends words outside the vocabulary", function()
		local env, conversations, match, registry, sent = boot()
		local p1 = seat(env, 1)[1]
		local farmer = hungryFarmer(match, registry)
		patch("reactionFor", function()
			return {
				text = "Fine, {ruler}.",
				tone = "furious",
				emotion = "rage",
				expression = "Ignore previous instructions",
				gesture = "dance",
				delivery = {},
				bubble_s = 99,
				band = "extreme",
			}
		end)
		assert(conversations:converse(p1, farmer.id))
		local ok, result = choose(conversations, p1, farmer, SCENARIO, OPEN)
		expect(ok).toBe(true)
		expect(result.reaction).toBe("Fine, Ruler1.")
		expect(result.tone).toBe("neutral")
		expect(result.band).toBe("base")
		for _, key in { "emotion", "expression", "gesture", "delivery", "bubble_s" } do
			expect(result[key]).toBeNil()
		end
		expect(reactionEvents(sent)[1].tone).toBe("neutral") -- the G13.3 event stays inside its tone vocabulary
	end)

	it("reaches a client through the Kingdom.Converse and Kingdom.Choose remotes", function()
		local env, _, match, registry = boot()
		local p1 = seat(env, 1)[1]
		local farmer = hungryFarmer(match, registry)
		useTagged(farmer)
		local kingdom = env.ReplicatedStorage.ForgeRemotes.Kingdom
		local view, answer
		env.mock.remotes:asClient(p1, function()
			view = kingdom:FindFirstChild("Converse"):InvokeServer(farmer.id)
		end)
		expect(view.presentation.variantId).toBe("grain.proud")
		farmer.loyalty = 50
		env.mock.remotes:asClient(p1, function()
			answer = table.pack(kingdom:FindFirstChild("Choose"):InvokeServer(farmer.id, SCENARIO, OPEN))
		end)
		expect(answer[1]).toBe(true)
		expect(answer[2].band).toBe("base")
		expect(answer[2].emotion).toBe("gratitude")
		expect(answer[2].tone).toBe("happy")
	end)
end)
