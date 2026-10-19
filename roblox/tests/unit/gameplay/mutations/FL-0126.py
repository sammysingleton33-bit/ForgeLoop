"""FL-0126 mutation rows (siege viability): the siege numbers (config Military / Buildings), the governors' assault
logic (Sim/RulerAI) and the long outcome spec. Run by ../mutations.py (`mutations.py FL-0126`).
One row: (task, file, old, new, spec filter, expected failing test). G is games/game-001/.
"""
MIL = G + "config/Military.luau"
BLD = G + "config/Buildings.luau"
AI = G + "src/shared/Sim/RulerAI.luau"
M = [
 # --- the numbers
 ("FL-0126", MIL, 'siege = 4,', 'siege = 1,', "sim/Siege", "take an undefended level 2 keep in 3 to 5 minutes"),
 ("FL-0126", MIL, 'hp = 1200,', 'hp = 400,', "sim/Siege", "take an undefended level 2 keep in 3 to 5 minutes"),
 ("FL-0126", MIL, 'siege = 0.25,', 'siege = 1,', "sim/Siege", "take an undefended level 2 keep in 3 to 5 minutes"),
 ("FL-0126", BLD, 'hp = 18000,', 'hp = 9000,', "sim/Siege", "take an undefended level 2 keep in 3 to 5 minutes"),
 # --- the governors' assault
 ("FL-0126", AI, '			and rams >= 1\n', '', "sim/RulerAI", "does not launch without a ram"),
 ("FL-0126", AI, 'local ASSAULT_MIN = 8', 'local ASSAULT_MIN = 30', "sim/RulerAI", "launches the whole army"),
 ("FL-0126", AI, 'elseif fighters < ASSAULT_BREAK then', 'elseif false then', "sim/RulerAI", "pulls back below 4 fighters"),
 ("FL-0126", AI, 'elseif marching < army and fighters >= ASSAULT_BREAK then', 'elseif false then', "sim/RulerAI", "sends fresh recruits"),
 ("FL-0126", AI, '			if sim.units[uid].order.kind == "Move" then', '			if false then', "sim/RulerAI", "calls off a march on a capture point"),
 # --- the whole thing: governors with rams fell kingdoms
 ("FL-0126", AI, '"Recruit", "ram", 1)', '"Recruit", "soldier", 1)', "sim/long/WarOutcome", "a kingdom falls in Conflict or Endgame"),
]
