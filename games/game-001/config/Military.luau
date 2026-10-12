--!strict
--[[
	Military (ReplicatedStorage.Forge.Config.Military) — unit types. Owner: FORGE-01.

	soldier is the VS-1 unit (CONTRACTS G8 unitType "soldier"); archer, knight and ram are VS-2.
	cost/trainTime are the local double of FORGE-03's Costs.unit (requested in a handoff).
	siege multiplies damage against buildings; attacksUnits = false means buildings only.
]]

return {
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
			siege = 1,
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
			siege = 0.5,
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
			siege = 1,
			attacksUnits = true,
			requiresBarracksLevel = 2,
		},
		ram = {
			id = "ram",
			name = "Battering Ram",
			cost = { wood = 120, stone = 20 },
			trainTime = 20,
			hp = 400,
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
