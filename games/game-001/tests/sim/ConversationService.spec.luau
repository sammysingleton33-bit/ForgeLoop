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
local Vfx = require("@game/ReplicatedStorage/Forge/Config/Vfx")
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

describe("ConversationService: every real scenario (G13.1 v0.4-g7, #83 review L1)", function()
	it(
		"shows every scenario through Converse with the names this server builds: all filled, risks { text, chance }",
		function()
			local env, conversations, match = boot()
			local p1 = seat(env, 1)[1]
			local sim = match.host.match.sim
			local ids = sim.kingdoms.crimson.citizenIds
			local c = sim.citizens[ids[1]]
			-- every relation a scenario may name
			c.profile.family = { ids[2] }
			c.profile.friends = { ids[3] }
			c.profile.rivals = { ids[4] }
			for _, resource in { "food", "wood", "stone", "gold" } do
				sim:deposit("crimson", resource, 1000, `test:{resource}`, "test")
			end
			local function filled(text)
				return type(text) == "string" and #text > 0 and string.find(text, "{", 1, true) == nil
			end
			local shown, risks = 0, 0
			for _, scenarioId in ContentQuery.data.dialogue.order do
				local scenario = ContentQuery.data.dialogue.scenarios[scenarioId]
				c.profile.occupation = scenario.occupation or c.profile.occupation
				conversations._showing[c.id] = nil
				assert(conversations:debugRequest("crimson", c.id, scenarioId))
				local payload = conversations:converse(p1, c.id)
				expect(payload).never.toBeNil()
				expect(payload.scenarioId).toBe(scenarioId)
				expect(filled(payload.question)).toBe(true)
				expect(#payload.options).toBe(#scenario.responses)
				local responses = {}
				for _, r in scenario.responses do
					responses[r.id] = r
				end
				for _, option in payload.options do
					expect(filled(option.text)).toBe(true)
					local expected = 0 -- every risk is shown before choosing (model decision 7)
					for _, id in ContentQuery.data.decisions[responses[option.id].decision].consequences do
						if ContentQuery.data.consequences[id].chance < 1 then
							expected += 1
						end
					end
					expect(#(option.risks or {})).toBe(expected)
					risks += expected
					for resource, amount in option.cost or {} do
						expect(type(resource)).toBe("string")
						expect(amount > 0).toBe(true)
					end
					for _, risk in option.risks or {} do
						expect(filled(risk.text)).toBe(true)
						expect(string.find(risk.text, "Risk (", 1, true)).toBeNil() -- the panel shows the chance
						expect(risk.chance > 0 and risk.chance < 1).toBe(true)
					end
				end
				shown += 1
			end
			expect(shown).toBe(#ContentQuery.data.dialogue.order)
			expect(risks > 0).toBe(true)
			expect(env.mock:hasLog("warn", "cannot be shown")).toBe(false)
		end
	)

	it("a scenario whose text the names cannot fill is refused quietly, not as a failed remote", function()
		local env, conversations, match = boot()
		local p1 = seat(env, 1)[1]
		local sim = match.host.match.sim
		local c = sim.citizens[sim.kingdoms.crimson.citizenIds[1]]
		local original = ContentQuery.choicePreview
		local ok, err = pcall(function()
			ContentQuery.choicePreview = function()
				error("ContentQuery.choiceRisks: no fill for {sibling}")
			end
			assert(conversations:debugRequest("crimson", c.id, ContentQuery.data.dialogue.order[1]))
			expect(conversations:converse(p1, c.id)).toBeNil()
		end)
		ContentQuery.choicePreview = original
		assert(ok, err)
		expect(env.mock:hasLog("warn", "cannot be shown")).toBe(true)
		env.mock:clearLogs()
	end)
end)

describe("ConversationService: Studio debug hooks (G13.7)", function()
	local function presets(env, registry)
		local Def = require("@game/ServerScriptService/Game/Services/DebugPresetService")
		return Def.new(env, registry)
	end

	it("citizen.request forces a request: shown on Converse and answerable though its trigger does not hold", function()
		local env, conversations, match, registry, sent = boot()
		local p1 = seat(env, 1)[1]
		local sim = match.host.match.sim
		local farmer
		for _, id in sim.kingdoms.crimson.citizenIds do
			if sim.citizens[id].profile.occupation == "farmer" then
				farmer = sim.citizens[id]
				break
			end
		end
		farmer.hunger = 0 -- well fed: farmer_hungry_grain does not hold
		for _, resource in { "food", "wood", "stone" } do
			sim:deposit("crimson", resource, 300, `test:{resource}`, "test")
		end
		expect(conversations:converse(p1, farmer.id)).toBeNil()
		local message = presets(env, registry):_hook("request", "crimson", farmer.id, "farmer_hungry_grain")
		expect(message).toContain("farmer_hungry_grain")
		local thought = sent[#sent].event
		expect({ thought.type, thought.id, thought.scenarioId }).toEqual({ "thought", farmer.id, "farmer_hungry_grain" })
		conversations:refresh() -- a forced request is never closed for not holding
		expect(conversations:openRequests("crimson")[1]).toEqual({
			entityId = farmer.id,
			scenarioId = "farmer_hungry_grain",
		})
		local shown = assert(conversations:converse(p1, farmer.id))
		expect(shown.scenarioId).toBe("farmer_hungry_grain")
		expect(assert(conversations:converse(p1, farmer.id)).scenarioId).toBe("farmer_hungry_grain") -- asked again
		local ok, _, reason = choose(conversations, p1, farmer, "farmer_hungry_grain", "farmer_hungry_grain_open_store")
		expect(reason).toBeNil()
		expect(ok).toBe(true)
		-- refusals name the problem
		expect({ conversations:debugRequest("crimson", farmer.id, "no_such_scenario") }).toEqual({
			false,
			"unknown scenario no_such_scenario",
		})
		local other = sim.kingdoms.azure.citizenIds[1]
		expect(conversations:debugRequest("crimson", other, "any")).toBe(false)
		expect(conversations:debugRequest("violet", 0, "any")).toBe(false)
	end)

	it("citizen.request 0 any: the hook picks a citizen and its first eligible scenario", function()
		local env, conversations, match, registry, sent = boot()
		local p1 = seat(env, 1)[1]
		local farmer = hungryFarmer(match, registry)
		local message = presets(env, registry):_hook("request", "crimson", 0, "any")
		expect(message).toContain("raises")
		local request = conversations:openRequests("crimson")[1]
		expect(request).never.toBeNil()
		local thought = sent[#sent].event
		expect({ thought.type, thought.id, thought.scenarioId }).toEqual({
			"thought",
			request.entityId,
			request.scenarioId,
		})
		expect(assert(conversations:converse(p1, request.entityId)).scenarioId).toBe(request.scenarioId)
		expect(farmer).never.toBeNil()
	end)

	it("strike.start: the occupation strikes, its strike events go out once each way", function()
		local env, conversations, match, registry, sent = boot()
		seat(env, 1)
		local sim = match.host.match.sim
		local citizens = registry:get("CitizenService")
		local farmers = {}
		for _, id in sim.kingdoms.crimson.citizenIds do
			if sim.citizens[id].profile.occupation == "farmer" then
				table.insert(farmers, id)
			end
		end
		local function strikes(from)
			local out = {}
			for i = from, #sent do
				if sent[i].event.type == "strike" then
					table.insert(out, { on = sent[i].event.on, ids = sent[i].event.entityIds })
				end
			end
			return out
		end
		expect(presets(env, registry):_hook("strike", "crimson", "farmer", true)).toContain("on strike")
		for _, id in farmers do
			expect(sim:isStriking(sim.citizens[id])).toBe(true)
		end
		expect(strikes(1)).toEqual({ { on = true, ids = farmers } })
		local mark = #sent + 1
		local ok, message = citizens:debugStrike("crimson", "farmer", false)
		expect({ ok, message }).toEqual({ true, `{#farmers} farmer back at work` })
		env.mock:advance(3) -- the watcher sees them back at work: no second "off"
		expect(strikes(mark)).toEqual({ { on = false, ids = farmers } })
		-- a strike that runs out ends on its own, once
		mark = #sent + 1
		citizens:debugStrike("crimson", "farmer", true)
		env.mock:advance(service("CitizenService").DEBUG_STRIKE_SECONDS + 2)
		expect(strikes(mark)).toEqual({ { on = true, ids = farmers }, { on = false, ids = farmers } })
		expect(conversations).never.toBeNil()
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
		-- the next refresh sends every request that is still open again (G13.3: the bubble keeps showing)
		table.clear(sent)
		conversations:refresh()
		local again = {}
		for _, entry in sent do
			if entry.event.type == "thought" then
				again[entry.event.id] = (again[entry.event.id] or 0) + 1
			end
		end
		for _, r in conversations:openRequests("crimson") do
			expect(again[r.entityId]).toBe(1)
		end
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

describe("ConversationService: thought bubbles stay up while the request is open (#77 B1)", function()
	it("sends an open request's thought on every refresh, never further apart than Vfx thoughtSec", function()
		local env, conversations, match, registry = boot()
		seat(env, 1)
		local farmer, sim = hungryFarmer(match, registry)
		local thoughtSec = Vfx.bubbles.thoughtSec
		expect(Society.requestRefreshSeconds < thoughtSec).toBe(true)
		local times = {}
		conversations._send = function(_, kingdomId, event)
			if event.type == "thought" and event.id == farmer.id then
				expect(kingdomId).toBe("crimson")
				table.insert(times, sim.time)
			end
		end
		-- a request that holds whatever the state does (the G13.7 hook's forced request)
		assert(conversations:debugRequest("crimson", farmer.id, "farmer_hungry_grain"))
		local opened = sim.time
		while sim.time < opened + 90 do
			env.mock:advance(1) -- the service's own loop refreshes every Society.requestRefreshSeconds
			local open = conversations:openRequests("crimson")
			expect(#open >= 1).toBe(true)
			-- the bubble is up: the last thought for the farmer is younger than the client's thoughtSec
			expect(sim.time - times[#times] < thoughtSec).toBe(true)
		end
		expect(#times >= math.floor(90 / Society.requestRefreshSeconds)).toBe(true)
		for i = 2, #times do
			expect(times[i] - times[i - 1] <= Society.requestRefreshSeconds + 1).toBe(true)
		end
	end)
end)

describe("ConversationService: FORGE-05 verdict on #77 (M1, M2, L1, L2, L3, L5)", function()
	-- a crimson builder whose builder_overworked showing is open for ruler 1
	local function overworked()
		local env, conversations, match, registry, sent = boot()
		local p1 = seat(env, 1)[1]
		local _, sim = hungryFarmer(match, registry)
		local builder
		for _, id in sim.kingdoms.crimson.citizenIds do
			local c = sim.citizens[id]
			if c.profile.occupation == "builder" then
				builder = c
				break
			end
		end
		conversations:_raise("crimson", "building_completed")
		builder.hunger = 0.9 -- mood < 60
		expect(assert(conversations:converse(p1, builder.id)).scenarioId).toBe("builder_overworked")
		return env, conversations, sim, p1, builder, sent, registry
	end

	-- runs fn with the match's random answering `roll` to every NextNumber (consequence chances)
	local function withRoll(sim, roll: number, fn: () -> ...any): ...any
		local real = sim.rng
		sim.rng = {
			NextNumber = function()
				return roll
			end,
		}
		local results = table.pack(pcall(fn))
		sim.rng = real
		assert(results[1], results[2])
		return table.unpack(results, 2, results.n)
	end

	it("M1 + L5: a walk-out risk that wins its roll lands beside a boost; one that loses does nothing", function()
		local env, conversations, sim, p1, builder, sent = overworked()
		local risk = ContentQuery.data.consequences.speaker_walkout_risk
		expect(risk.magnitude <= -1).toBe(true)
		expect(risk.chance < 1).toBe(true)
		local ok, result = withRoll(sim, 0, function() -- 0 < chance: the risk fires (rolled at Choose)
			return choose(conversations, p1, builder, "builder_overworked", "builder_overworked_push_on")
		end)
		expect(ok).toBe(true)
		expect(#result.effects).toBe(3) -- push, unrest and the walk-out: every consequence fired
		env.mock:advance(risk.delay_s + 1)
		expect(sim:productivityOf(builder) > 1).toBe(true) -- builders_push (+0.1) is on the builder too
		expect(sim:isStriking(builder)).toBe(true) -- and still the walk-out holds
		local on = {}
		for _, entry in sent do
			if entry.event.type == "strike" and entry.event.on then
				table.insert(on, entry.event.entityIds)
			end
		end
		expect(on).toEqual({ { builder.id } })
		env.mock:advance(risk.duration_s + 1)
		expect(sim:isStriking(builder)).toBe(false) -- back at work once it ends

		-- the same answer whose roll loses: no walk-out, no strike event, no notice for it
		local env2, conversations2, sim2, p2, builder2, sent2 = overworked()
		local ok2, result2 = withRoll(sim2, 0.99, function()
			return choose(conversations2, p2, builder2, "builder_overworked", "builder_overworked_push_on")
		end)
		expect(ok2).toBe(true)
		expect(#result2.effects).toBe(2) -- push and unrest only
		env2.mock:advance(risk.delay_s + 1)
		expect(sim2:isStriking(builder2)).toBe(false)
		for _, entry in sent2 do
			expect(entry.event.type).never.toBe("strike")
		end
	end)

	it("D-042: promise_sacks_break's refusal to work lands on a boosted farmer; the boost resumes after", function()
		local env, conversations, match, registry, sent = boot()
		seat(env, 1)
		local farmer, sim = hungryFarmer(match, registry)
		local consequences = ContentQuery.data.consequences
		expect(table.find(ContentQuery.data.decisions.promise_sacks_break.consequences, "speaker_refuses_work")).never.toBeNil()
		conversations:_applyConsequence("crimson", farmer, consequences.farmers_work_up) -- +0.15, 120 s
		conversations:_applyConsequence("crimson", farmer, consequences.speaker_refuses_work) -- -1, 60 s
		expect(sim:isStriking(farmer)).toBe(true)
		local on = {}
		for _, entry in sent do
			if entry.event.type == "strike" and entry.event.on then
				table.insert(on, entry.event.entityIds)
			end
		end
		expect(on).toEqual({ { farmer.id } })
		env.mock:advance(consequences.speaker_refuses_work.duration_s + 1)
		expect(sim:isStriking(farmer)).toBe(false)
		expect(sim:productivityOf(farmer)).toBeNear(1.15, 1e-9) -- back under the boost still running
	end)

	it("M2: CitizenView.hasRequest is true exactly while the citizen has an open request", function()
		local env, conversations, match, registry = boot()
		local p1 = seat(env, 1)[1]
		local farmer = hungryFarmer(match, registry)
		local citizens = registry:get("CitizenService")
		expect(assert(citizens:inspect(farmer.id)).hasRequest).toBe(false)
		conversations:refresh()
		expect(conversations:hasRequest("crimson", farmer.id)).toBe(true)
		expect(assert(citizens:inspect(farmer.id)).hasRequest).toBe(true)
		local open = conversations:openRequests("crimson")
		for _, id in match.host.match.sim.kingdoms.crimson.citizenIds do
			local listed = false
			for _, r in open do
				listed = listed or r.entityId == id
			end
			expect(assert(citizens:inspect(id)).hasRequest).toBe(listed)
		end
		assert(conversations:converse(p1, farmer.id)) -- talking keeps the request until it is answered (N3)
		expect(assert(citizens:inspect(farmer.id)).hasRequest).toBe(true)
		assert(choose(conversations, p1, farmer, "farmer_hungry_grain", "farmer_hungry_grain_open_store"))
		expect(assert(citizens:inspect(farmer.id)).hasRequest).toBe(false) -- answered: settled
	end)

	it("N3: Talk, then close without answering: the request and its thought stay; asking again shows it", function()
		local env, conversations, match, registry, sent = boot()
		local p1 = seat(env, 1)[1]
		local farmer = hungryFarmer(match, registry)
		conversations:refresh()
		expect(conversations:hasRequest("crimson", farmer.id)).toBe(true)
		local view = assert(conversations:converse(p1, farmer.id)) -- the panel opens, then closes unanswered
		table.clear(sent)
		for _ = 1, 3 do -- three refreshes (the scenario is on its shown cooldown now)
			conversations:refresh()
		end
		expect(conversations:hasRequest("crimson", farmer.id)).toBe(true)
		local thoughts = 0
		for _, entry in sent do
			if entry.event.type == "thought" and entry.event.id == farmer.id then
				thoughts += 1
			end
		end
		expect(thoughts).toBe(3) -- the bubble is still re-sent every refresh
		local again = assert(conversations:converse(p1, farmer.id))
		expect(again.scenarioId).toBe(view.scenarioId)
		-- answered: the request closes and the next refresh does not bring it back
		assert(choose(conversations, p1, farmer, view.scenarioId, "farmer_hungry_grain_open_store"))
		expect(conversations:hasRequest("crimson", farmer.id)).toBe(false)
		conversations:refresh()
		expect(conversations:hasRequest("crimson", farmer.id)).toBe(false)
	end)

	it("N2: a walk-out downs tools at once, even with a load in hand", function()
		local env, conversations, match, registry = boot()
		seat(env, 1)
		local _, sim = hungryFarmer(match, registry)
		local k = sim.kingdoms.crimson
		-- a citizen in the middle of gathering, carrying part of a load
		local worker
		for _ = 1, 600 do
			env.mock:advance(0.25)
			for _, id in k.citizenIds do
				local c = sim.citizens[id]
				if c.activity == "Gather" and c.phase == "Work" and c.carrying and c.carrying.amount > 0 then
					worker = c
					break
				end
			end
			if worker then
				break
			end
		end
		assert(worker, "no citizen was gathering")
		local carried = worker.carrying.amount
		conversations:_applyConsequence("crimson", worker, ContentQuery.data.consequences.speaker_refuses_work)
		env.mock:advance(1)
		expect(sim:isStriking(worker)).toBe(true)
		expect(worker.activity).toBe("Idle") -- re-planned at once: on strike
		expect(worker.carrying == nil or worker.carrying.amount <= carried).toBe(true) -- gathered nothing more
	end)

	it("L1: a timed condition, unrest or desertion consequence comes off again after its duration", function()
		local env, conversations, match, registry = boot()
		seat(env, 1)
		local farmer, sim = hungryFarmer(match, registry)
		local k = sim.kingdoms.crimson
		local festive = ContentQuery.data.consequences.kingdom_festive -- happiness +5 for 300 s
		local unrest = ContentQuery.data.consequences.builders_unrest -- unrest +8 for 300 s
		expect(festive.duration_s).toBe(unrest.duration_s)
		k.conditions.happiness = 50
		local pressure = k.unrestPressure or 0
		conversations:_applyConsequence("crimson", farmer, festive)
		conversations:_applyConsequence("crimson", farmer, unrest)
		expect(k.conditions.happiness).toBe(50 + festive.magnitude)
		expect(k.unrestPressure).toBe(pressure + unrest.magnitude)
		env.mock:advance(festive.duration_s - 2)
		expect(k.unrestPressure).toBe(pressure + unrest.magnitude) -- still in force
		-- (the conditions also drift on their own, a fraction of a point in these seconds)
		local happiness = k.conditions.happiness
		env.mock:advance(3)
		expect(k.conditions.happiness).toBeNear(happiness - festive.magnitude, 0.5) -- what was applied
		expect(k.unrestPressure).toBe(pressure)
		-- a clamped change comes off only as far as it went
		k.conditions.happiness = 98
		conversations:_applyConsequence("crimson", farmer, festive)
		expect(k.conditions.happiness).toBe(100)
		env.mock:advance(festive.duration_s - 2)
		k.conditions.happiness = 100
		env.mock:advance(3)
		expect(k.conditions.happiness).toBeNear(98, 0.5) -- 2 came off, not 5
		-- desertion_risk on the soldiers (none in the slice: nothing to undo, nothing fails)
		conversations:_applyConsequence("crimson", farmer, ContentQuery.data.consequences.soldiers_desertion_pressure)
		env.mock:advance(301)
	end)

	it("L2: a decision the server cannot apply refunds its payment and leaves the showing open", function()
		local env, conversations, match, registry = boot()
		local p1 = seat(env, 1)[1]
		local farmer, sim = hungryFarmer(match, registry)
		local food = sim:balance("crimson", "food")
		assert(conversations:converse(p1, farmer.id))
		local real = ContentQuery.fireDecision
		ContentQuery.fireDecision = function()
			error("broken content")
		end
		local ok, okResult, _, reason =
			pcall(choose, conversations, p1, farmer, "farmer_hungry_grain", "farmer_hungry_grain_open_store")
		ContentQuery.fireDecision = real
		assert(ok, okResult)
		expect(okResult).toBe(false)
		expect(reason).toBe("unknown_response")
		expect(sim:balance("crimson", "food")).toBe(food) -- paid, then refunded
		local warned = false
		for _, entry in env.mock.logs do
			warned = warned
				or (entry.level == "warn" and string.find(entry.message, "cannot be applied", 1, true) ~= nil)
		end
		expect(warned).toBe(true)
		-- the showing stays open: the answer goes through once the content works, charged once
		expect((choose(conversations, p1, farmer, "farmer_hungry_grain", "farmer_hungry_grain_open_store"))).toBe(true)
		expect(sim:balance("crimson", "food")).toBe(food - 25)
	end)

	it("L3: outside an active phase Converse shows nothing and Choose answers phase", function()
		local env, conversations, match, registry = boot()
		local p1 = seat(env, 1)[1]
		local farmer, sim = hungryFarmer(match, registry)
		assert(conversations:converse(p1, farmer.id))
		local food = sim:balance("crimson", "food")
		sim.active = false -- Lobby or Results
		expect(conversations:converse(p1, farmer.id)).toBeNil()
		expect({ choose(conversations, p1, farmer, "farmer_hungry_grain", "farmer_hungry_grain_open_store") }).toEqual({
			false,
			nil,
			"phase",
		})
		expect(sim:balance("crimson", "food")).toBe(food)
		sim.active = true
		expect((choose(conversations, p1, farmer, "farmer_hungry_grain", "farmer_hungry_grain_open_store"))).toBe(true)
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
