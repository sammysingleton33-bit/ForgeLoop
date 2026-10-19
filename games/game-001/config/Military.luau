--!strict
--[[
	Military (ReplicatedStorage.Forge.Config.Military) — unit types. Owner: FORGE-01.

	Siege (FL-0126, FORGE-07's #187 numbers): `siege` multiplies damage against buildings. Soldiers and archers barely
	scratch a keep (soldier 2 hp/s), a ram does the work (60 x 4 / 3 s = 80 hp/s) and is sturdy (1200 hp): a keep's own
	fire (config Buildings) kills the soldiers in about two minutes and the ram in about two more. With keep hp 12000 /
	18000 / 24000, 13 soldiers and one ram take an UNDEFENDED level 2 keep in about 3.5 minutes (Siege.spec), soldiers
	alone never do, and a defended keep holds against a comparable force.

	soldier is the VS-1 unit (CONTRACTS G8 unitType "soldier"); archer, knight and ram are VS-2.
	cost/trainTime are the local double of FORGE-03's Costs.unit (requested in a handoff).
	siege multiplies damage against buildings; attacksUnits = false means buildings only.
]]

return {
	-- D-055 (1): at most this many standing soldiers (units, living + in training) per kingdom; Recruit answers
	-- army_cap beyond it. 60 citizens + 15 soldiers = 75 per kingdom, 300 per server (BRIEF §14).
	maxSoldiers = 15,
	unitOrder = { "soldier", "archer", "knight", "ram" },
	units = {
		soldier = {
			id = "soldier",
			name = "Soldier",
			cost = { food = 30, wood = 10 },
			trainTime = 8,
			hp = 80,
			damage = 8,
			range = 5,
			cooldown = 1,
			speed = 14,
			siege = 0.25,
			attacksUnits = true,
			requiresBarracksLevel = 1,
		},
		archer = {
			id = "archer",
			name = "Archer",
			cost = { food = 30, wood = 30 },
			trainTime = 10,
			hp = 50,
			damage = 7,
			range = 35,
			cooldown = 1.5,
			speed = 13,
			siege = 0.25,
			attacksUnits = true,
			requiresBarracksLevel = 1,
		},
		knight = {
			id = "knight",
			name = "Knight",
			cost = { food = 50, gold = 40 },
			trainTime = 14,
			hp = 180,
			damage = 14,
			range = 6,
			cooldown = 1.2,
			speed = 20,
			siege = 0.5,
			attacksUnits = true,
			requiresBarracksLevel = 2,
		},
		ram = {
			id = "ram",
			name = "Battering Ram",
			cost = { wood = 200 }, -- wood only: stone is the scarce resource, and a lost ram must be replaceable (FL-0126)
			trainTime = 20,
			hp = 1200,
			damage = 60,
			range = 7,
			cooldown = 3,
			speed = 6,
			siege = 4,
			attacksUnits = false,
			requiresBarracksLevel = 2,
		},
	},
}
