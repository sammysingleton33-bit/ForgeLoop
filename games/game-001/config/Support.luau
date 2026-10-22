--!strict
--[[
	Support (ReplicatedStorage.Forge.Config.Support) — the Crown Arena support score, tiers, key-citizen perks and the
	ruler decisions that feed them (design `crown-arena.md` §3-§4; CONTRACTS G12). Owner: FORGE-01.

	PROVISIONAL weights (BRIEF §16.9); every value is inside the G12.3 caps (Arena/Caps). tests/sim/SupportModel.spec
	asserts that for every tier x pick set x power (FORGE-05's caps spec checks the design fixture, not this file).
	Read by Arena/SupportModel (pure) and LeadershipService (acts, rules).

	components[c].weight        share of the score (sums to 100)
	sampling                    LeadershipService samples every `intervalSeconds` of simulation time, checking every
	                            `pollSeconds` of wall time; the score weights the whole match
	                            `wholeMatchShare` and the last `recentSeconds` the rest (later samples count more)
	tiers[t]                    min score, passive blessing (stat -> fraction), trigger slots, the Crowd Rally flag
	roles[r]                    the key citizen's perk, the building that brings them, and the petition text
	perks[p]                    kind / stat / pledged and empowered magnitude / duration / condition / effect text
	crowdRally                  the Adoring tier's clutch trigger (two effects, one slot)
	offer                       loyalty needed for a perk (pledged) and for the stronger one (empowered)
	acts[id]                    a ruler decision LeadershipService records: component, signed delta, pre-authored text
	valourCapPerMinute          valour gained per minute is capped, so fighting nonstop is not required
	rules                       thresholds LeadershipService reads to record acts from the simulation's own state:
	                            fedKept (fed ratio held at least `atLeast` through a whole phase in `phases` →
	                            fedRatioKept), starvation (fed ratio below `below` for more than `seconds` →
	                            starvation, once per episode), conscription (soldiers above `soldierShareAbove` of
	                            soldiers + citizens for more than `seconds` → overConscription, once per episode)
	reputationCategories        the ReputationService categories whose mean is the kingdom's reputation component
	                            (fear is left out: a feared ruler is not a loved one)
]]

return {
	components = {
		reputation = { weight = 15, scope = "kingdom" },
		happiness = { weight = 15, scope = "kingdom" },
		stability = { weight = 15, scope = "kingdom" },
		morale = { weight = 10, scope = "kingdom" },
		loyalty = { weight = 20, scope = "kingdom" },
		conduct = { weight = 15, scope = "ruler" },
		valour = { weight = 10, scope = "ruler" },
	},
	componentOrder = { "reputation", "happiness", "stability", "morale", "loyalty", "conduct", "valour" },
	sampling = { intervalSeconds = 30, pollSeconds = 2, wholeMatchShare = 0.4, recentSeconds = 900 },
	trendSeconds = 300, -- the trend compares the last 5 minutes with the 5 before them

	tierOrder = { "adoring", "loyal", "divided", "restless", "hostile" },
	tiers = {
		adoring = { min = 85, passive = { damageReduction = 0.01, staminaRegen = 0.01 }, slots = 3, crowdRally = true },
		loyal = { min = 65, passive = { damageReduction = 0.01, staminaRegen = 0.01 }, slots = 3, crowdRally = false },
		divided = { min = 40, passive = {}, slots = 2, crowdRally = false },
		restless = { min = 20, passive = {}, slots = 1, crowdRally = false },
		hostile = { min = 0, passive = {}, slots = 0, crowdRally = false },
	},

	offer = { pledgedLoyalty = 80, empoweredLoyalty = 95 },
	roleOrder = { "blacksmith", "healer", "captain", "provisioner", "elder", "merchant" },
	roles = {
		blacksmith = { perk = "reforge", building = "blacksmith", petition = "Bring stone to reinforce the forge" },
		healer = { perk = "fieldRemedy", building = "infirmary", petition = "Gather herbs from the forest edge" },
		captain = { perk = "calledWarning", building = "barracks", petition = "Drill the recruits in the yard" },
		provisioner = { perk = "heartyRations", building = "granary", petition = "Keep the granary stocked" },
		elder = { perk = "rallyingHymn", building = "shrine", petition = "Hold a feast" },
		merchant = { perk = "fineWares", building = "market", petition = "Protect the trade road" },
	},
	perks = {
		reforge = {
			kind = "trigger",
			stat = "damageReduction",
			pledged = 0.06,
			empowered = 0.10,
			duration = 6,
			condition = "hpBelow:0.5",
			effect = "Damage taken -{magnitude} for 6 s",
			when = "your HP first drops below 50 %",
		},
		fieldRemedy = {
			kind = "heal",
			pledged = 0.03,
			empowered = 0.05,
			duration = 4,
			condition = "hpBelow:0.35",
			effect = "Regain {magnitude} of your HP over 4 s",
			when = "your HP first drops below 35 %",
		},
		calledWarning = {
			kind = "telegraph",
			pledged = 0.15,
			empowered = 0.25,
			duration = 8,
			uses = { pledged = 2, empowered = 3 }, -- heavy attacks covered, per tier
			condition = "opponentHeavy",
			effect = "Their first {uses} heavy attacks are telegraphed sooner",
			when = "the opponent's first heavy attack",
		},
		heartyRations = {
			kind = "trigger",
			stat = "staminaRegen",
			pledged = 0.06,
			empowered = 0.10,
			duration = 8,
			condition = "staminaOut",
			effect = "Stamina regeneration +{magnitude} for 8 s",
			when = "your stamina first runs out",
		},
		rallyingHymn = {
			kind = "trigger",
			stat = "damage",
			pledged = 0.03,
			empowered = 0.05,
			duration = 5,
			condition = "hype",
			effect = "Damage +{magnitude} for 5 s",
			when = "the crowd's excitement is full",
		},
		fineWares = {
			kind = "passive",
			stat = "damageReduction",
			pledged = 0.02,
			empowered = 0.03,
			effect = "Damage taken -{magnitude} all duel",
			when = "before the duel",
		},
	},
	crowdRally = {
		duration = 5,
		damageReduction = 0.05,
		staminaRegen = 0.10,
		condition = "hpBelow:0.2",
		effect = "The stand roars: damage taken -5 %, stamina regeneration +10 % for 5 s",
		when = "your HP first drops below 20 %",
	},

	valourCapPerMinute = 6,
	rules = {
		fedKept = { atLeast = 0.9, phases = { Expansion = true, Conflict = true, Endgame = true } },
		starvation = { below = 0.5, seconds = 60 },
		conscription = { soldierShareAbove = 0.35, seconds = 60 },
	},
	reputationCategories = { "compassion", "honor", "competence", "courage", "authority" },
	acts = {
		-- reputation (public acts)
		keepUpgraded = { component = "reputation", delta = 2, text = "Raised the keep for all to see" },
		objectiveDefended = { component = "reputation", delta = 3, text = "Held an objective against the rivals" },
		-- conduct: protect (+)
		fedRatioKept = { component = "conduct", delta = 4, text = "Kept the kingdom fed through the phase" },
		defendedRaid = { component = "conduct", delta = 3, text = "Stood with the citizens during a raid" },
		petitionFulfilled = { component = "conduct", delta = 3, text = "Heard a citizen's petition" },
		shelteredCitizens = { component = "conduct", delta = 2, text = "Built houses before the barracks grew" },
		rebuiltRaidDamage = { component = "conduct", delta = 2, text = "Rebuilt what the raid broke" },
		-- conduct: exploit (-)
		starvation = { component = "conduct", delta = -5, text = "Let the kingdom go hungry" },
		abandonedRegion = { component = "conduct", delta = -4, text = "Left a raided region to its fate" },
		petitionIgnored = { component = "conduct", delta = -3, text = "Let a petition expire unheard" },
		overwork = { component = "conduct", delta = -3, text = "Worked the people past their strength" },
		overConscription = {
			component = "conduct",
			delta = -3,
			text = "Called up more soldiers than the land could spare",
		},
		-- valour
		defendedOwnLand = { component = "valour", delta = 4, text = "Defended the land in person" },
		capturedInPerson = { component = "valour", delta = 4, text = "Captured an objective in person" },
		foughtBesideTroops = { component = "valour", delta = 3, text = "Fought beside the troops" },
	},
}
