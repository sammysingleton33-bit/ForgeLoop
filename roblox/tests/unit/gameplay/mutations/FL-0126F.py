"""FL-0126F mutation rows (RulerAI fortifying: the palisade ring and the gate; slice 4 of FL-0126 part 2).
Run by ../mutations.py (`mutations.py FL-0126F`). One row: (task, file, old, new, spec filter, expected failing test).
G is games/game-001/.
"""
RA = G + "src/shared/Sim/RulerAI.luau"
M = [
 ("FL-0126F", RA, '\t\t\taggression >= FORTIFY_AGGRESSION\n', '\t\t\ttrue\n', "sim/RulerFortify", "only a governor with aggression >= 0.5 fortifies"),
 ("FL-0126F", RA, '\t\t\tand sim:keepLevel(kingdom) >= 2\n\t\t\tand count(sim, kingdom, "watchtower", true) >= 2\n', '\t\t\tand count(sim, kingdom, "watchtower", true) >= 2\n', "sim/RulerFortify", "only a governor with aggression >= 0.5 fortifies"),
 ("FL-0126F", RA, '\t\t\tand count(sim, kingdom, "watchtower", true) >= 2\n\t\t\tand not hasSite(sim, kingdom, "wall")', '\t\t\tand not hasSite(sim, kingdom, "wall")', "sim/RulerFortify", "only a governor with aggression >= 0.5 fortifies"),
 ("FL-0126F", RA, 'and sim:balance(kingdom.id, "wood") >= FORTIFY_WOOD_RESERVE', 'and sim:balance(kingdom.id, "wood") >= 0', "sim/RulerFortify", "never builds a palisade out of the last wood"),
 ("FL-0126F", RA, '\t\t\tand not hasSite(sim, kingdom, "wall")\n', '', "sim/RulerFortify", "builds one piece at a time"),
 ("FL-0126F", RA, 'local FORTIFY_RING = 64', 'local FORTIFY_RING = 60', "sim/RulerFortify", "rings the keep with wall pieces 64 studs out"),
 ("FL-0126F", RA, 'local GATE_RING = 66', 'local GATE_RING = 64', "sim/RulerFortify", "puts the one gate in the slot that faces the nearest other keep"),
 ("FL-0126F", RA, 'local GATE_AFTER = 6', 'local GATE_AFTER = 1', "sim/RulerFortify", "keeps the gate for the last"),
 ("FL-0126F", RA, 'local yaw = math.atan2(-math.cos(angle), -math.sin(angle))', 'local yaw = math.atan2(math.cos(angle), -math.sin(angle))', "sim/RulerFortify", "rings the keep with wall pieces 64 studs out"),
 ("FL-0126F", RA, '\t\tif slot ~= reserved then\n', '\t\tif true then\n', "sim/RulerFortify", "nearly the whole ring and the gate fit"),
 ("FL-0126F", RA, '\t\tlocal d = (x - rival.x) ^ 2 + (z - rival.z) ^ 2\n\t\tif d < bestDistance then', '\t\tlocal d = (x - rival.x) ^ 2 + (z - rival.z) ^ 2\n\t\tif d > bestDistance and bestDistance < math.huge or bestDistance == math.huge then', "sim/RulerFortify", "puts the one gate in the slot that faces the nearest other keep"),
]
