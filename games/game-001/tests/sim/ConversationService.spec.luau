--[[
	ConversationService (CONTRACTS G13.3, FL-0079) on the real content library and services: eligibility from
	real state, Converse/Choose (effects exactly once, decay on repeats, forged or stale answers refused),
	consequences (productivity, strikes and walk-outs, unlocks, memories, delays), thought bubbles.
]]

local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect, afterEach = T.describe, T.it, T.expect, T.afterEach

local MockEnv = require("../../../../roblox/tests/mocks/MockEnv")
local GameEvents = require("@game/ReplicatedStorage/Forge/Contracts/GameEvents")
local Loader = require("@game/ReplicatedStorage/Forge/Contracts/Loader")
local Society = require("@game/ReplicatedStorage/Forge/Config/Society")
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
	local registry = Loader.load(env, definitions)
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

describe("ConversationService: Converse (G13.3)", function()
	it("offers farmer_hungry_grain only while its trigger holds in the real state", function()
		local env, conversations, match, registry = boot()
		local p1 = seat(env, 1)[1]
		local farmer, sim = hungryFarmer(match, registry)
		local view = assert(conversations:converse(p1, farmer.id))
		expect(view.scenarioId).toBe("farmer_hungry_grain")
		expect(view.entityId).toBe(farmer.id)
		expect(view.speaker.name).toBe(farmer.name)
		expect(view.speaker.occupation).toBe("Farmer")
		expect(string.find(view.question, "{", 1, true)).toBeNil() -- placeholders filled
		expect(#view.options >= 2 and #view.options <= 4).toBe(true)
		local open = view.options[1]
		expect(open.id).toBe("farmer_hungry_grain_open_store")
		expect(open.cost).toEqual({ food = 25 }) -- ContentQuery.choicePreview
		-- asked again before answering: the same showing
		expect(assert(conversations:converse(p1, farmer.id)).scenarioId).toBe("farmer_hungry_grain")
		-- a well-fed kingdom: the trigger no longer holds and nothing else applies to this farmer
		registry:get("CitizenService"):setFedRatio("crimson", 1)
		expect(conversations:converse(p1, farmer.id)).toBeNil()
		expect(sim.kingdoms.crimson.fedRatio).toBe(1)
	end)

	it("answers only a ruler of the citizen's kingdom", function()
		local env, conversations, match, registry = boot()
		local players = seat(env, 3) -- 1 and 2 crimson, 3 elsewhere
		local farmer = hungryFarmer(match, registry)
		expect(conversations:converse(players[3], farmer.id)).toBeNil()
		expect(conversations:converse(players[1], 999)).toBeNil()
		local remote = env.ReplicatedStorage.ForgeRemotes.Kingdom:FindFirstChild("Converse")
		local result
		env.mock.remotes:asClient(players[1], function()
			result = remote:InvokeServer("x")
		end)
		expect(result).toBeNil() -- refused by validation
		env.mock.remotes:asClient(players[1], function()
			result = remote:InvokeServer(farmer.id)
		end)
		expect(result.scenarioId).toBe("farmer_hungry_grain")
	end)
end)

describe("ConversationService: Choose (G13.3)", function()
	it("applies every effect exactly once: cost, reputation, loyalty, conditions, consequences, reaction", function()
		local env, conversations, match, registry, sent = boot()
		local p1 = seat(env, 1)[1]
		local farmer, sim = hungryFarmer(match, registry)
		local reputation = registry:get("ReputationService")
		local k = sim.kingdoms.crimson
		local food = sim:balance("crimson", "food")
		local loyalty = farmer.loyalty
		local compassion = reputation:get(1).values.compassion
		local stability = k.conditions.stability
		assert(conversations:converse(p1, farmer.id))
		local family = sim.citizens[farmer.profile.family[1]]
		-- after Converse (its RulerVisited already moved the speaker)
		-- the decision's audience (occupation): another farmer with no tie to the speaker; others do not hear
		local function arrival(job)
			local c = sim:_spawnCitizen(k, job, farmer.x, farmer.z)
			k.stats.born += 1
			sim.profiler.birth(sim, k, c) -- an arrival: no family, friends or rivals
			return c
		end
		local peer, stranger = arrival(farmer.job), arrival("woodcutter")
		expect(peer.profile.occupation).toBe(farmer.profile.occupation)
		expect(stranger.profile.occupation).never.toBe(farmer.profile.occupation)
		local before = {
			speaker = farmer.loyalty,
			family = family.loyalty,
			peer = peer.loyalty,
			stranger = stranger.loyalty,
		}
		local expected = { -- fireDecision's listeners, applied as given (first firing: multiplier 1)
			speaker = ContentQuery.decisionLoyalty(
				"grain_open_store",
				farmer.profile.traits,
				"speaker",
				farmer.chemistry,
				1
			),
			family = ContentQuery.decisionLoyalty(
				"grain_open_store",
				family.profile.traits,
				"family",
				family.chemistry,
				1
			),
		}
		local ok, result, reason =
			choose(conversations, p1, farmer, "farmer_hungry_grain", "farmer_hungry_grain_open_store")
		expect(reason).toBeNil()
		expect(ok).toBe(true)
		expect(type(result.reaction)).toBe("string")
		expect(sim:balance("crimson", "food")).toBe(food - 25)
		expect(reputation:get(1).values.compassion).toBe(compassion + 3)
		expect(farmer.loyalty > loyalty).toBe(true)
		expect(farmer.loyalty).toBeNear(math.clamp(before.speaker + expected.speaker, 0, 100), 1e-9)
		expect(family.loyalty).toBeNear(math.clamp(before.family + expected.family, 0, 100), 1e-9)
		local heard =
			ContentQuery.decisionLoyalty("grain_open_store", peer.profile.traits, "kingdom", peer.chemistry, 1)
		expect(heard ~= 0).toBe(true)
		expect(peer.loyalty).toBeNear(math.clamp(before.peer + heard, 0, 100), 1e-9)
		expect(stranger.loyalty).toBe(before.stranger)
		expect(math.abs(expected.speaker) <= ContentQuery.LOYALTY_CLAMP.speaker).toBe(true)
		local decision = ContentQuery.data.decisions.grain_open_store
		expect(k.conditions.stability).toBeNear(stability + decision.kingdom.stability, 1e-9)
		expect(sim:productivityOf(farmer)).toBeNear(1.15, 1e-9) -- farmers_work_up (occupation:farmer)
		expect(family.pinned.fed_by_ruler).toBe(true) -- family_remembers_bread
		local reactions, cues = 0, {}
		for _, entry in sent do
			if entry.event.type == "reaction" then
				reactions += 1
				expect(entry.event.id).toBe(farmer.id)
			elseif entry.event.type == "kcue" then
				table.insert(cues, entry.event.cue)
			end
		end
		expect(reactions).toBe(1)
		table.sort(cues)
		expect(cues).toEqual({ "celebrate", "work_fast" })
		-- the same showing cannot be answered twice
		local again, _, why = choose(conversations, p1, farmer, "farmer_hungry_grain", "farmer_hungry_grain_open_store")
		expect(again).toBe(false)
		expect(why).toBe("not_offered")
		expect(sim:balance("crimson", "food")).toBe(food - 25)
		expect(reputation:get(1).values.compassion).toBe(compassion + 3)
		-- shown: its cooldown keeps the farmer quiet for now
		expect(conversations:converse(p1, farmer.id)).toBeNil()
	end)

	it("an unaffordable answer records no firing: paying later still earns full gains", function()
		local env, conversations, match, registry = boot()
		local p1 = seat(env, 1)[1]
		local farmer, sim = hungryFarmer(match, registry)
		local reputation = registry:get("ReputationService")
		local compassion = reputation:get(1).values.compassion
		local food = sim:balance("crimson", "food")
		assert(conversations:converse(p1, farmer.id))
		sim:spend("crimson", { food = food }, "test:empty", "test")
		local ok, _, why = choose(conversations, p1, farmer, "farmer_hungry_grain", "farmer_hungry_grain_open_store")
		expect(ok).toBe(false)
		expect(why).toBe("cost")
		sim:deposit("crimson", "food", food, "test:refill", "test")
		assert(choose(conversations, p1, farmer, "farmer_hungry_grain", "farmer_hungry_grain_open_store"))
		expect(reputation:get(1).values.compassion).toBe(compassion + 3) -- not decayed by the refusal
	end)

	it("a repeated decision decays its gains; its cost stays full", function()
		local env, conversations, match, registry = boot()
		local p1 = seat(env, 1)[1]
		local farmer, sim = hungryFarmer(match, registry)
		local reputation = registry:get("ReputationService")
		local decision = ContentQuery.data.decisions.grain_open_store
		local compassion = reputation:get(1).values.compassion
		assert(conversations:converse(p1, farmer.id))
		assert(choose(conversations, p1, farmer, "farmer_hungry_grain", "farmer_hungry_grain_open_store"))
		env.mock:advance(ContentQuery.data.dialogue.scenarios.farmer_hungry_grain.cooldown_s + 1)
		farmer.hunger = 0.5
		registry:get("CitizenService"):setFedRatio("crimson", 0.6)
		local food = sim:balance("crimson", "food")
		assert(conversations:converse(p1, farmer.id))
		assert(choose(conversations, p1, farmer, "farmer_hungry_grain", "farmer_hungry_grain_open_store"))
		expect(sim:balance("crimson", "food")).toBe(food - 25)
		expect(reputation:get(1).values.compassion).toBeNear(
			compassion + decision.rep.compassion * (1 + decision.repeat_decay),
			1e-9
		)
	end)

	it("refuses forged and stale answers with stable reasons", function()
		local env, conversations, match, registry = boot()
		local players = seat(env, 3)
		local p1, p2, p3 = players[1], players[2], players[3]
		local farmer, sim = hungryFarmer(match, registry)
		local food = sim:balance("crimson", "food")
		local function reason(player, scenarioId, responseId)
			local ok, result, why = choose(conversations, player, farmer, scenarioId, responseId)
			expect(ok).toBe(false)
			expect(result).toBeNil()
			return why
		end
		expect(reason(p1, "farmer_hungry_grain", "farmer_hungry_grain_open_store")).toBe("not_offered") -- never opened
		assert(conversations:converse(p1, farmer.id))
		expect(reason(p2, "farmer_hungry_grain", "farmer_hungry_grain_open_store")).toBe("not_offered") -- p1's showing
		expect(reason(p3, "farmer_hungry_grain", "farmer_hungry_grain_open_store")).toBe("unknown_citizen")
		expect(reason(p1, "builder_overworked", "builder_overworked_rest")).toBe("not_offered")
		expect(reason(p1, "farmer_hungry_grain", "builder_overworked_rest")).toBe("unknown_response")
		sim:spend("crimson", { food = sim:balance("crimson", "food") }, "test:empty", "test")
		expect(reason(p1, "farmer_hungry_grain", "farmer_hungry_grain_open_store")).toBe("cost") -- showing stays
		sim:deposit("crimson", "food", food, "test:refill", "test")
		registry:get("CitizenService"):setFedRatio("crimson", 1) -- the need is gone before the answer
		expect(reason(p1, "farmer_hungry_grain", "farmer_hungry_grain_open_store")).toBe("not_eligible")
		expect(reason(p1, "farmer_hungry_grain", "farmer_hungry_grain_open_store")).toBe("not_offered") -- closed
		expect(sim:balance("crimson", "food")).toBe(food)
		local remote = env.ReplicatedStorage.ForgeRemotes.Kingdom:FindFirstChild("Choose")
		local result
		env.mock.remotes:asClient(p1, function()
			result = table.pack(remote:InvokeServer(farmer.id, string.rep("x", 49), "a"))
		end)
		expect(result[1]).toBeNil() -- refused by validation (string(1,48))
	end)

	it("a promise unlocks its follow-up, which then comes due", function()
		local env, conversations, match, registry = boot()
		local p1 = seat(env, 1)[1]
		local farmer = hungryFarmer(match, registry)
		assert(conversations:converse(p1, farmer.id))
		assert(choose(conversations, p1, farmer, "farmer_hungry_grain", "farmer_hungry_grain_promise_harvest"))
		expect(farmer.unlocked.farmer_promise_due).toBe(true)
		expect(farmer.pinned.promised_harvest).toBe(true)
		registry:get("CitizenService"):setFedRatio("crimson", 0.9) -- the harvest came in
		local due = assert(conversations:converse(p1, farmer.id))
		expect(due.scenarioId).toBe("farmer_promise_due")
	end)

	it("consequences: a delayed walk-out risk, and builders resting then refreshed", function()
		local env, conversations, match, registry = boot()
		local p1 = seat(env, 1)[1]
		local _, sim = hungryFarmer(match, registry)
		local k = sim.kingdoms.crimson
		local builder
		for _, id in k.citizenIds do
			local c = sim.citizens[id]
			if c.profile.occupation == "builder" then
				builder = c
				break
			end
		end
		conversations:_raise("crimson", "building_completed")
		builder.hunger = 0.9 -- mood < 60
		expect(assert(conversations:converse(p1, builder.id)).scenarioId).toBe("builder_overworked")
		assert(choose(conversations, p1, builder, "builder_overworked", "builder_overworked_rest"))
		expect(sim:productivityOf(builder)).toBeNear(0.5, 1e-9) -- builders_rest −0.5 for 60 s
		env.mock:advance(61) -- builders_refreshed (+0.2) arrives after its 60 s delay
		expect(sim:productivityOf(builder)).toBeNear(1.2, 1e-9)
	end)
end)

describe("ConversationService: strikes on the wire (G13.3 v0.4-g6)", function()
	local function strikes(sent, from)
		local out = {}
		for i = from or 1, #sent do
			local e = sent[i].event
			if e.type == "strike" then
				table.insert(out, { occupation = e.occupation, on = e.on, ids = e.entityIds })
			end
		end
		return out
	end

	it("a walk-out sends strike on, then off, for exactly the speaker, with its placard cue", function()
		local env, conversations, match, registry, sent = boot()
		seat(env, 1)
		local farmer, sim = hungryFarmer(match, registry)
		local walkout = ContentQuery.data.consequences.speaker_refuses_work -- productivity −1 for 60 s
		conversations:_applyConsequence("crimson", farmer, walkout)
		expect(sim:isStriking(farmer)).toBe(true)
		expect(strikes(sent)).toEqual({ { occupation = farmer.profile.occupation, on = true, ids = { farmer.id } } })
		local cue = sent[#sent].event
		expect({ cue.type, cue.id, cue.cue }).toEqual({ "kcue", farmer.id, "strike_placard" })
		local mark = #sent + 1
		conversations:_applyConsequence("crimson", farmer, walkout) -- already out: no second "on"
		expect(strikes(sent, mark)).toEqual({})
		env.mock:advance(walkout.duration_s + 1.5)
		expect(sim:isStriking(farmer)).toBe(false)
		expect(strikes(sent, mark)).toEqual({
			{ occupation = farmer.profile.occupation, on = false, ids = { farmer.id } },
		})
		-- productivity that leaves the citizen working is no strike
		mark = #sent + 1
		conversations:_applyConsequence("crimson", farmer, ContentQuery.data.consequences.farmers_work_up)
		expect(strikes(sent, mark)).toEqual({})
	end)

	it("a strike lists only the least loyal share it struck; an extended strike ends later on its own", function()
		local env, conversations, match, registry, sent = boot()
		seat(env, 1)
		local farmer, sim = hungryFarmer(match, registry)
		local k = sim.kingdoms.crimson
		local occupation = farmer.profile.occupation
		for _ = 1, 3 do -- four or more of the occupation
			local c = sim:_spawnCitizen(k, farmer.job, farmer.x, farmer.z)
			k.stats.born += 1
			sim.profiler.birth(sim, k, c)
		end
		local same = {}
		for _, id in k.citizenIds do
			local c = sim.citizens[id]
			if c.profile.occupation == occupation then
				table.insert(same, c)
			end
		end
		for i, c in same do
			c.loyalty = 10 * i -- same[1] is the least loyal
		end
		local strike = {
			id = "test_strike",
			kind = "strike",
			target = `occupation:{occupation}`,
			magnitude = 0.5,
			duration_s = 30,
			delay_s = 0,
			chance = 1,
			cue_id = "strike_placard",
		}
		conversations:_applyConsequence("crimson", farmer, strike)
		local count = math.floor(#same * 0.5 + 0.5)
		local struck = {}
		for i = 1, count do
			table.insert(struck, same[i].id)
		end
		expect(strikes(sent)).toEqual({ { occupation = occupation, on = true, ids = struck } })
		local cue = sent[#sent].event
		expect({ cue.type, cue.cue, cue.occupation, cue.entityIds }).toEqual({
			"kcue",
			"strike_placard",
			occupation,
			struck,
		})
		sim:strike(same[1], 100) -- a longer strike on top for the least loyal
		local mark = #sent + 1
		env.mock:advance(31.5)
		local rest = table.clone(struck)
		table.remove(rest, 1)
		expect(strikes(sent, mark)).toEqual({ { occupation = occupation, on = false, ids = rest } })
		mark = #sent + 1
		env.mock:advance(70)
		expect(strikes(sent, mark)).toEqual({ { occupation = occupation, on = false, ids = { same[1].id } } })
		mark = #sent + 1
		env.mock:advance(5)
		expect(strikes(sent, mark)).toEqual({}) -- each change once
	end)
end)

describe("ConversationService: thought bubbles", function()
	it("opens up to Society.openRequests requests, highest priority first, and closes stale ones", function()
		local env, conversations, match, registry, sent = boot()
		seat(env, 1)
		local farmer, sim = hungryFarmer(match, registry)
		conversations:refresh()
		local open = conversations:openRequests("crimson")
		expect(#open <= Society.openRequests).toBe(true)
		expect(#open >= 1).toBe(true)
		local thoughts = 0
		for _, entry in sent do
			if entry.event.type == "thought" then
				thoughts += 1
				expect(entry.kingdomId).toBe("crimson")
				expect(string.find(entry.event.text, "{", 1, true)).toBeNil()
			end
		end
		expect(thoughts).toBe(#open)
		local mine = false
		for _, r in open do
			mine = mine or r.entityId == farmer.id
		end
		expect(mine).toBe(true)
		registry:get("CitizenService"):setFedRatio("crimson", 1)
		conversations:refresh()
		for _, r in conversations:openRequests("crimson") do
			expect(r.scenarioId).never.toBe("farmer_hungry_grain")
		end
		expect(sim.kingdoms.azure and #conversations:openRequests("azure")).toBe(0) -- no ruler, no bubbles
	end)
end)

describe("ConversationService: events on the wire (EntityService, G13.3)", function()
	it("members of the kingdom receive the thought, the reaction and the cues; nobody else does", function()
		local EventCodec = require("@game/ReplicatedStorage/Game/Sim/EventCodec")
		local env, conversations, match, registry = boot({ entities = true })
		local players = seat(env, 3) -- 1 and 2 crimson, 3 elsewhere
		local farmer = hungryFarmer(match, registry)
		conversations:refresh()
		assert(conversations:converse(players[1], farmer.id))
		assert(choose(conversations, players[1], farmer, "farmer_hungry_grain", "farmer_hungry_grain_open_store"))
		env.mock:advance(0.5)
		local remote = env.ReplicatedStorage.ForgeRemotes.Sim:FindFirstChild("Events")
		local function kindsFor(player)
			local kinds = {}
			for _, entry in env.mock.remotes:sent(remote) do
				if entry.player == player then
					for _, e in assert(EventCodec.decode(entry.args[1])).events do
						kinds[e.type] = (kinds[e.type] or 0) + 1
					end
				end
			end
			return kinds
		end
		local mine, cruler, theirs = kindsFor(players[1]), kindsFor(players[2]), kindsFor(players[3])
		expect(mine.thought >= 1).toBe(true)
		expect(mine.reaction).toBe(1)
		expect(mine.kcue).toBe(2) -- work_fast (farmers) and celebrate (speaker)
		expect(cruler.reaction).toBe(1) -- every member of the kingdom
		expect(theirs.reaction).toBeNil()
		expect(theirs.kcue).toBeNil()
		local dropped = 0
		for _, entry in env.mock.logs do
			if entry.level == "error" then
				dropped += 1
			end
		end
		expect(dropped).toBe(0)
	end)

	it("never sends a value the wire refuses: unknown icon or tone fall back, unknown cues stay home", function()
		local _, conversations = boot({ entities = true })
		local queued = {}
		conversations._registry = {
			find = function(_, name)
				return if name == "EntityService"
					then {
						sendKingdomEvent = function(_, _, event)
							table.insert(queued, event)
						end,
					}
					else nil
			end,
		}
		conversations:_send("crimson", { type = "thought", id = 1, scenarioId = "s", text = "t", icon = "shout" })
		conversations:_send("crimson", { type = "reaction", id = 1, text = "t", tone = "furious" })
		conversations:_send("crimson", { type = "kcue", id = 1, cue = "dance" })
		conversations:_send("crimson", { type = "kcue", id = 1, cue = "salute" })
		expect(#queued).toBe(3)
		expect(queued[1].icon).toBe("request")
		expect(queued[2].tone).toBe("neutral")
		expect(queued[3].cue).toBe("salute")
	end)
end)
