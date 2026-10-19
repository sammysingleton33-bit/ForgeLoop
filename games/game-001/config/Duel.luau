--!strict
--[[
	Duel (ReplicatedStorage.Forge.Config.Duel) — the Crown Arena duel numbers (design `crown-arena.md` §5; CONTRACTS
	G12). Owner: FORGE-01. Read by Arena/DuelModel.

	PROVISIONAL: the starting point is FORGE-05's harness double (tests/fairness/DuelDouble). Every weapon and armour is a
	sidegrade; FORGE-05's fairness harness (FL-0076) measures the real model and these values are tuned from its report,
	never by feel. The support caps are not here: they are the contract (Arena/Caps).

	rules
		maxHp, maxStamina        both duellists start full
		staminaRegen             per second while idle, recovering or staggered (armour `regen` scales it)
		lightCost, heavyCost     stamina to start an attack; blockHitCost x weapon guardDamage per blocked hit
		parryCost, parryWindow   a parry costs stamina and lasts parryWindow seconds
		dodgeTime                seconds of a dodge (the armour sets its stamina cost)
		staggerTime, guardBreakTime   a parried attacker, a guard that ran out of stamina
		lightRecover, heavyRecover    seconds after an attack lands or misses
		timeCap                  at the cap the higher HP wins; a tie goes to sudden death
		suddenDeathDamage        damage multiplier for both after a tied timeCap
		hardCap                  seconds; the duel is a draw (the match falls back to Crown Points)
		quietStart               no support trigger in the first quietStart seconds (the contract's 10 s)
		hypeParry, hypeHit, hypeCombo, comboWindow   the crowd meter; a full meter (100) is a "hype" event
	weapons[w]: light, heavy damage; lightWindup, heavyWindup seconds; blockFactor (damage that gets through a block);
		guardDamage (stamina a blocked hit costs, x blockHitCost)
	armour[a]: reduction (damage taken), regen (stamina regeneration factor), dodgeCost (stamina)
]]

return {
	rules = {
		maxHp = 100,
		maxStamina = 100,
		staminaRegen = 16,
		lightCost = 10,
		heavyCost = 22,
		blockHitCost = 8,
		parryCost = 6,
		parryWindow = 0.25,
		dodgeTime = 0.35,
		staggerTime = 1.0,
		guardBreakTime = 0.8,
		lightRecover = 0.25,
		heavyRecover = 0.5,
		timeCap = 120,
		suddenDeathDamage = 1.2,
		hardCap = 180,
		quietStart = 10,
		hypeParry = 40,
		hypeHit = 10,
		hypeCombo = 15,
		comboWindow = 2,
	},
	weapons = {
		swordShield = {
			light = 6,
			heavy = 14,
			lightWindup = 0.30,
			heavyWindup = 0.80,
			blockFactor = 0.20,
			guardDamage = 1,
		},
		greatsword = {
			light = 7,
			heavy = 17,
			lightWindup = 0.36,
			heavyWindup = 0.90,
			blockFactor = 0.35,
			guardDamage = 1.2,
		},
		spear = { light = 6, heavy = 15, lightWindup = 0.26, heavyWindup = 0.80, blockFactor = 0.30, guardDamage = 1 },
		mace = { light = 6, heavy = 16, lightWindup = 0.32, heavyWindup = 0.85, blockFactor = 0.30, guardDamage = 1.5 },
	},
	armour = {
		light = { reduction = 0.00, regen = 1.10, dodgeCost = 14 },
		medium = { reduction = 0.06, regen = 1.00, dodgeCost = 18 },
		heavy = { reduction = 0.12, regen = 0.88, dodgeCost = 24 },
	},
}
