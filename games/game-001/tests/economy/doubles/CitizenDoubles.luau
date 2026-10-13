--[[
	CitizenDoubles — stand-ins for FORGE-01's citizen and conversation remotes (CONTRACTS G8 `Sim.Inspect`,
	G13.2 CitizenView, G13.3 `Kingdom.Converse` / `Kingdom.Choose`) for the FL-0088 specs and the UI
	snapshot scenes. Plug into doubles/KingdomWorld through its options:

		local world = KingdomWorld.new({
			remotes = CitizenDoubles.REMOTES,                 -- appended to the Sim (new) and Kingdom areas
			services = { CitizenDoubles.service },            -- the server double below
			clientDefinitions = { ... },
		})
		local citizens = world.server:get("CitizenService")
		citizens.calls                                       -- { { name = "Inspect" | "Converse" | "Choose", args } }
		citizens:setScenario(entityId, CitizenDoubles.SCENARIOS.three)   -- or nil: nothing to say
		citizens.refuse = "not_eligible"                     -- the next Choose answers (false, nil, reason)
		citizens.latency = 0.2                               -- seconds Choose / Converse take to answer
		citizens.inspectDelay[41] = 0.3                      -- seconds Sim.Inspect takes for one citizen
		citizens.drop = true                                 -- the next Choose returns nil (a dropped call)

	Double rules (stand-ins, not the game's rules): only the caller's kingdom's citizens can be
	inspected or talked to (else nil / "not_yours"); Choose checks the scenario id and the response
	id ("not_eligible" / "unknown_response"), spends the response's `cost` through the real
	TreasuryService ("cost"), adds its loyalty to the citizen, records a memory, clears the request,
	and answers the response's reaction and effects. A repeated Choose for the same showing returns the
	stored answer (idempotent per (entityId, scenarioId) showing, G13.3).

	The sample names and lines below are spec fixtures. In the game every line comes from the content
	library (G13.1) through FORGE-01's server; the UI never contains them.
]]

local V = require("@game/ReplicatedStorage/Forge/Core/Validate")

local CitizenDoubles = {}

-- FORGE-01's declarations as CONTRACTS G8/G13.3 describe them (kinds, arguments, rates). Sim is a new
-- area in KingdomWorld; Kingdom exists and is appended to. Sim.Inspect and Kingdom.Choose have no rate
-- in the contract: these are FORGE-03's proposals (handoff).
CitizenDoubles.REMOTES = {
	Sim = {
		{
			name = "Sim.Inspect",
			kind = "function",
			args = { V.integer(1, 65535) },
			rate = { burst = 6, perSecond = 3 },
		},
	},
	Kingdom = {
		{
			name = "Kingdom.Converse",
			kind = "function",
			args = { V.integer(1, 65535) },
			rate = { burst = 4, perSecond = 2 },
		},
		{
			name = "Kingdom.Choose",
			kind = "function",
			args = { V.integer(1, 65535), V.string(1, 48), V.string(1, 48) },
			rate = { burst = 4, perSecond = 2 },
		},
	},
}

local LOOK = { skin = 2, hair = 1, hairColor = 3, outfit = 1 }

-- CitizenView (G13.2) samples. 41-45 belong to crimson (the spec player's kingdom), 51 to azure.
CitizenDoubles.CITIZENS = {
	{
		entityId = 41,
		kingdom = "crimson",
		name = "Edda Thornbury",
		occupation = "Farmer",
		job = "farmer",
		traits = { "Hard-working", "Generous", "Stubborn" },
		mood = 64,
		loyalty = 72,
		obedience = 48,
		intent = "Carrying wheat to the storehouse",
		lastMemory = "You visited the farms at dawn",
		memories = {
			"You visited the farms at dawn",
			"The harvest came in early",
			"Bran fell ill and got better",
			"Soldiers marched through the east field",
		},
		family = { "Bran Thornbury", "Lise Thornbury" },
		friends = { "Osric Vale", "Mara Quill" },
		rivals = { "Tomas Reed" },
		hasRequest = true,
		look = LOOK,
	},
	{
		entityId = 42,
		kingdom = "crimson",
		name = "Bran Thornbury",
		occupation = "Hauler",
		job = "hauler",
		traits = { "Cheerful", "Clumsy" },
		mood = 55,
		loyalty = 60,
		obedience = 62,
		intent = "Taking planks to the house site",
		lastMemory = nil,
		memories = {},
		family = { "Edda Thornbury", "Lise Thornbury" },
		friends = { "Osric Vale" },
		rivals = {},
		hasRequest = true,
		look = LOOK,
	},
	{
		entityId = 43,
		kingdom = "crimson",
		name = "Lise Thornbury",
		occupation = "Elder",
		job = "idle",
		traits = { "Wise", "Proud", "Pious" },
		mood = 81,
		loyalty = 88,
		obedience = 35,
		intent = "Telling stories by the well",
		lastMemory = "The keep was raised to level 2",
		memories = { "The keep was raised to level 2" },
		family = { "Edda Thornbury", "Bran Thornbury" },
		friends = {},
		rivals = { "Tomas Reed", "Gerd Reed" },
		hasRequest = true,
		look = LOOK,
	},
	{
		entityId = 44,
		kingdom = "crimson",
		name = "Osric Vale",
		occupation = "Woodcutter",
		job = "woodcutter",
		traits = { "Cautious", "Loyal" },
		mood = 38,
		loyalty = 55,
		obedience = 70,
		intent = "Felling pines by the river",
		lastMemory = "The quarry was raided",
		memories = { "The quarry was raided" },
		family = { "Ada Vale" },
		friends = { "Edda Thornbury" },
		rivals = {},
		hasRequest = false,
		look = LOOK,
	},
	{
		entityId = 45,
		kingdom = "crimson",
		name = "Mara Quill",
		occupation = "Farmer",
		job = "farmer",
		traits = { "Outspoken", "Generous" },
		mood = 22,
		loyalty = 40,
		obedience = 52,
		intent = "Replanting the trampled wheat",
		lastMemory = "Soldiers trampled the east field",
		memories = { "Soldiers trampled the east field" },
		family = {},
		friends = { "Edda Thornbury" },
		rivals = {},
		hasRequest = true,
		look = LOOK,
	},
	{
		entityId = 51,
		kingdom = "azure",
		name = "Hild Frost",
		occupation = "Miner",
		job = "miner",
		traits = { "Greedy" },
		mood = 50,
		loyalty = 50,
		obedience = 50,
		intent = "Digging stone",
		memories = {},
		family = {},
		friends = {},
		rivals = {},
		hasRequest = false,
		look = LOOK,
	},
}

-- Scenarios with 2, 3 and 4 answers and a very long question. Each response: text (shown), and the
-- double's own consequences: cost (ResourceBag), loyalty, reaction and effects (the server's texts).
CitizenDoubles.SCENARIOS = {
	two = {
		scenarioId = "roof_leak",
		question = "My lord, the storehouse roof leaks. Shall I patch it with the spare planks?",
		responses = {
			{
				id = "patch",
				text = "Yes, use the planks.",
				cost = { wood = 10 },
				loyalty = 4,
				reaction = "Right away, my lord. Not a grain will get wet.",
				effects = { { kind = "wood", text = "−10 Wood" }, { kind = "loyalty", text = "+4 Loyalty" } },
			},
			{
				id = "wait",
				text = "Not now. The planks are for the barracks.",
				loyalty = -3,
				reaction = "As you wish. I'll move the sacks to the dry corner.",
				effects = { { kind = "loyalty", text = "−3 Loyalty" } },
			},
		},
	},
	three = {
		scenarioId = "flooded_field",
		question = "My lord, the east field flooded overnight. Without help we lose a week of wheat. What should we do?",
		responses = {
			{
				id = "help",
				text = "Take workers from the quarry and save the field.",
				cost = { wood = 20 },
				loyalty = 8,
				reaction = "Bless you, my lord! We'll have the field drained by nightfall.",
				effects = {
					{ kind = "wood", text = "−20 Wood" },
					{ kind = "loyalty", text = "+8 Loyalty: Edda and family" },
					{ kind = "reputation", text = "+3 Compassion" },
					{ kind = "morale", text = "Farmers work faster for 60 s" },
					{ kind = "rumour", text = "The quarry crew grumbles" },
				},
			},
			{
				id = "bread",
				text = "Give her family extra bread from the storehouse.",
				cost = { food = 15 },
				loyalty = 5,
				reaction = "Thank you. The children will eat well tonight.",
				effects = { { kind = "food", text = "−15 Food" }, { kind = "loyalty", text = "+5 Loyalty" } },
			},
			{
				id = "work",
				text = "Farmers deal with floods. Get back to work.",
				loyalty = -6,
				reaction = "...Yes, my lord.",
				effects = { { kind = "loyalty", text = "−6 Loyalty" }, { kind = "authority", text = "+2 Authority" } },
			},
		},
	},
	four = {
		scenarioId = "river_plot",
		question = "Two families both claim the plot by the river. Who should have it?",
		responses = {
			{
				id = "thornbury",
				text = "The Thornburys. They were here first.",
				loyalty = 6,
				reaction = "A fair ruling.",
				effects = { { kind = "honor", text = "+2 Honor" } },
			},
			{
				id = "reed",
				text = "The Reeds. They have more children.",
				loyalty = -4,
				reaction = "Hmph.",
				effects = {},
			},
			{
				id = "split",
				text = "Split it between them.",
				loyalty = 1,
				reaction = "Neither family is happy, but nobody is angry.",
				effects = {},
			},
			{
				id = "crown",
				text = "Neither. It belongs to the crown.",
				cost = {},
				loyalty = -8,
				reaction = "The crown takes everything.",
				effects = { { kind = "fear", text = "+3 Fear" }, { kind = "gold", text = "+5 Gold" } },
			},
		},
	},
	long = {
		scenarioId = "trampled_wheat",
		question = "Forgive me for speaking out of turn, my lord, but the soldiers who marched through the east field last night trampled half of the young wheat, and my husband says that if nobody pays for the seed we will not have enough to feed the children this winter, let alone the storehouse. What will you do about it?",
		responses = {
			{
				id = "pay",
				text = "The crown pays for new seed, and the captain will apologise to your family in person before the next muster.",
				loyalty = 10,
				reaction = "I never thought a ruler would listen to a farmer. Thank you.",
				effects = {
					{ kind = "loyalty", text = "+10 Loyalty" },
					{ kind = "compassion", text = "+4 Compassion" },
				},
			},
			{
				id = "soldiers",
				text = "Send the soldiers to replant the field themselves.",
				loyalty = 6,
				reaction = "That will teach them to watch their boots.",
				effects = { { kind = "morale", text = "−5 Army morale" } },
			},
			{
				id = "nothing",
				text = "The army comes first. Plant what you can.",
				loyalty = -10,
				reaction = "Then we will go hungry.",
				effects = { { kind = "loyalty", text = "−10 Loyalty" } },
			},
		},
	},
}

local function clone(t)
	local out = {}
	for k, v in t do
		out[k] = if type(v) == "table" then clone(v) else v
	end
	return out
end

-- The server double: register with KingdomWorld `services = { CitizenDoubles.service }`.
function CitizenDoubles.service(world)
	return {
		name = "CitizenService",
		dependencies = { "RemoteService", "TreasuryService", "KingdomService" },
		new = function(_, registry)
			local remotes = registry:get("RemoteService")
			local treasury = registry:get("TreasuryService")
			local kingdoms = registry:get("KingdomService")
			local svc = {
				citizens = {} :: { [number]: any },
				scenarios = {} :: { [number]: any },
				answers = {} :: { [string]: any },
				calls = {} :: { any },
				latency = 0,
				inspectDelay = {} :: { [number]: number },
				refuse = nil :: string?,
				drop = false,
			}
			for _, c in CitizenDoubles.CITIZENS do
				svc.citizens[c.entityId] = clone(c)
			end
			svc.scenarios[41] = CitizenDoubles.SCENARIOS.three
			svc.scenarios[42] = CitizenDoubles.SCENARIOS.two
			svc.scenarios[43] = CitizenDoubles.SCENARIOS.four
			svc.scenarios[45] = CitizenDoubles.SCENARIOS.long
			function svc:setScenario(entityId, scenario)
				self.scenarios[entityId] = scenario
				self.citizens[entityId].hasRequest = scenario ~= nil
			end
			function svc:callsNamed(name)
				local out = {}
				for _, call in self.calls do
					if call.name == name then
						table.insert(out, call)
					end
				end
				return out
			end
			local function own(player, entityId)
				local c = svc.citizens[entityId]
				return c ~= nil and c.kingdom == kingdoms:getKingdomOf(player), c
			end
			local function view(c)
				local v = clone(c)
				v.kingdom = nil -- not a CitizenView field
				return v
			end
			function svc:start()
				remotes:handle("Sim.Inspect", function(player, entityId)
					table.insert(self.calls, { name = "Inspect", args = { entityId } })
					local delay = self.inspectDelay[entityId]
					if delay and delay > 0 then
						world.env.wait(delay)
					end
					local mine, c = own(player, entityId)
					return if mine then view(c) else nil
				end)
				remotes:handle("Kingdom.Converse", function(player, entityId)
					table.insert(self.calls, { name = "Converse", args = { entityId } })
					if self.latency > 0 then
						world.env.wait(self.latency)
					end
					local mine, c = own(player, entityId)
					local scenario = self.scenarios[entityId]
					if not mine or scenario == nil then
						return nil
					end
					local options = {}
					for _, r in scenario.responses do
						table.insert(options, { id = r.id, text = r.text })
					end
					return {
						entityId = entityId,
						scenarioId = scenario.scenarioId,
						speaker = { name = c.name, occupation = c.occupation },
						question = scenario.question,
						options = options,
					}
				end)
				remotes:handle("Kingdom.Choose", function(player, entityId, scenarioId, responseId)
					table.insert(self.calls, { name = "Choose", args = { entityId, scenarioId, responseId } })
					if self.latency > 0 then
						world.env.wait(self.latency)
					end
					if self.drop then
						self.drop = false
						return nil
					end
					if self.refuse then
						local reason = self.refuse
						self.refuse = nil
						return false, nil, reason
					end
					local key = `{entityId}:{scenarioId}`
					if self.answers[key] then
						return true, self.answers[key] -- idempotent per showing
					end
					local mine, c = own(player, entityId)
					if not mine then
						return false, nil, "not_yours"
					end
					local scenario = self.scenarios[entityId]
					if scenario == nil or scenario.scenarioId ~= scenarioId then
						return false, nil, "not_eligible"
					end
					local response = nil
					for _, r in scenario.responses do
						if r.id == responseId then
							response = r
						end
					end
					if response == nil then
						return false, nil, "unknown_response"
					end
					local kingdom = kingdoms:getKingdomOf(player)
					if
						response.cost
						and next(response.cost)
						and not treasury:spend(kingdom, response.cost, "choose:" .. key, "decision")
					then
						return false, nil, "cost"
					end
					c.loyalty = math.clamp(c.loyalty + (response.loyalty or 0), 0, 100)
					table.insert(c.memories, 1, response.text)
					c.lastMemory = response.text
					c.hasRequest = false
					self.scenarios[entityId] = nil
					local result = { reaction = response.reaction, effects = clone(response.effects or {}) }
					self.answers[key] = result
					return true, result
				end)
			end
			return svc
		end,
	}
end

return CitizenDoubles
