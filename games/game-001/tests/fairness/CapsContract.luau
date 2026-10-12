--!strict
--[[
	CapsContract — CONTRACTS G12.3 (Crown Arena fairness caps) as data (FL-0076, owner FORGE-05).

	The single copy the fairness harness and the caps spec use. Caps.spec.luau checks it against the
	G12.3 table in games/game-001/CONTRACTS.md, so a cap changes only when FORGE-00 changes the contract
	(which needs a DECISIONS entry) and then this file, never this file alone.

	Fractions: 0.05 = +5 %. Healing is a fraction of max HP. Seconds are duel time.
]]

return table.freeze({
	-- Mechanical caps (design §6.1-§6.7)
	passivePerStat = 0.05, -- tier blessing + Fine Wares on one stat
	passiveCombined = 0.08, -- all passive bonuses added up
	maxTriggers = 3, -- perks + Crowd Rally per duel, each fires at most once
	triggerMaxSeconds = 8,
	triggerMaxMagnitude = 0.10, -- damage reduction, damage, stamina regeneration
	totalPerStat = 0.15, -- passive + the strongest active trigger on one stat, at any moment
	healPerDuel = 0.10,
	healPerTrigger = 0.08,
	quietStartSeconds = 10,
	stats = table.freeze({ "damageReduction", "damage", "staminaRegen" }),

	-- Outcome caps measured by the harness (PROVISIONAL, BRIEF §16.9d)
	outcome = table.freeze({
		supportMatters = table.freeze({ min = 0.55, max = 0.65 }), -- equal skill, Adoring vs Hostile
		skillStillWins = 0.60, -- one skill tier better with Hostile beats Adoring at least this often
		noAutoWin = 0.70, -- no setup beats the equal-skill baseline more often than this
	}),
})
