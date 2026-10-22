"""FL-0126F mutation rows (RulerAI fortifying: the palisade arc and the gate; slice 4 of FL-0126 part 2).
Run by ../mutations.py (`mutations.py FL-0126F`). One row: (task, file, old, new, spec filter, expected failing test).
G is games/game-001/. Equivalent mutants dropped: `finished` counting sites (a site holds the whole pass first).
"""
RA = G + "src/shared/Sim/RulerAI.luau"
M = [
 ("FL-0126F", RA, '\t\t\taggression >= FORTIFY_AGGRESSION\n\t\t\tand sim:keepLevel(kingdom) >= 2\n\t\t\tand count(sim, kingdom, "watchtower", true) >= 2\n', '\t\t\ttrue\n\t\t\tand sim:keepLevel(kingdom) >= 2\n\t\t\tand count(sim, kingdom, "watchtower", true) >= 2\n', "sim/RulerFortify", "only a governor with aggression >= 0.5 fortifies"),
 ("FL-0126F", RA, '\t\t\tand sim:keepLevel(kingdom) >= 2\n\t\t\tand count(sim, kingdom, "watchtower", true) >= 2\n', '\t\t\tand count(sim, kingdom, "watchtower", true) >= 2\n', "sim/RulerFortify", "only a governor with aggression >= 0.5 fortifies"),
 ("FL-0126F", RA, '\t\t\tand count(sim, kingdom, "watchtower", true) >= 2\n\t\t\tand not hasSite(sim, kingdom, "wall")', '\t\t\tand not hasSite(sim, kingdom, "wall")', "sim/RulerFortify", "only a governor with aggression >= 0.5 fortifies"),
 ("FL-0126F", RA, 'and sim:balance(kingdom.id, "wood") >= FORTIFY_WOOD_RESERVE', 'and sim:balance(kingdom.id, "wood") >= 0', "sim/RulerFortify", "never builds a palisade out of the last wood"),
 ("FL-0126F", RA, '\t\t\tand not hasSite(sim, kingdom, "wall")\n', '', "sim/RulerFortify", "builds one piece at a time"),
 ("FL-0126F", RA, '\t\tand not hasSite(sim, kingdom, "gate")\n\tthen\n\t\tlocal issued = makeGate', '\tthen\n\t\tlocal issued = makeGate', "sim/RulerFortify", "holds the next wall while the gate is still a site"),
 ("FL-0126F", RA, 'local FORTIFY_RING = 132', 'local FORTIFY_RING = 100', "sim/RulerFortify", "walls the approach"),
 ("FL-0126F", RA, 'local GATE_AFTER = 6', 'local GATE_AFTER = 1', "sim/RulerFortify", "keeps the gate for the last"),
 ("FL-0126F", RA, 'local yaw = math.atan2(-math.cos(angle), -math.sin(angle))', 'local yaw = math.atan2(math.cos(angle), -math.sin(angle))', "sim/RulerFortify", "walls the approach"),
 ("FL-0126F", RA, 'if not slotTaken(pieces, keep, angle) then', 'if true then', "sim/RulerFortify", "nearly the whole arc and the gate fit"),
 ("FL-0126F", RA, 'if b.kind == "wall" or b.kind == "gate" then\n\t\t\ttable.insert(pieces, b)', 'if b.kind == "wall" then\n\t\t\ttable.insert(pieces, b)', "sim/RulerFortify", "puts the one gate in the middle of the arc"),
 ("FL-0126F", RA, 'resting[key] = sim.time + NO_SPOT_RETRY -- every free slot', 'resting[key] = nil -- every free slot', "sim/RulerFortify", "rests for a minute"),
 ("FL-0126F", RA, 'if other ~= kingdom and other.alive then', 'if other ~= kingdom then', "sim/RulerFortify", "a fallen rival no longer draws the arc"),
 ("FL-0126F", RA, 'return centre + (slot - (FORTIFY_SLOTS + 1) / 2 + 0.5) * ARC_STEP', 'return (slot - (FORTIFY_SLOTS + 1) / 2 + 0.5) * ARC_STEP', "sim/RulerFortify", "faces the nearest living keep"),
 ("FL-0126F", RA, 'if turn < ARC_STEP / 2 and math.abs(radius - FORTIFY_RING) <= 24 then', 'if false then', "sim/RulerFortify", "builds one piece at a time"),
 ("FL-0126F", RA, 'return offCentre(l) < offCentre(r)', 'return offCentre(l) > offCentre(r)', "sim/RulerFortify", "puts the one gate in the middle of the arc"),
 ("FL-0126F", RA, 'if sim.time - since < GATE_PATIENCE then\n\t\treturn "wait"', 'if false then\n\t\treturn "wait"', "sim/RulerFortify", "holds its other pieces for the gate"),
]
