"""FL-0134 mutation rows (G9 war events and the conversation tags they raise): Sim/WarWatch siege and raid
start/end, the keep-hit hook in Military, and ConversationService's tags.

Run by ../mutations.py (`mutations.py FL-0134`). One row: (task, file, old, new, spec filter, expected failing test).
G is games/game-001/.
"""
WW = G + "src/shared/Sim/WarWatch.luau"
MIL = G + "src/shared/Sim/Military.luau"
CONV = G + "src/server/Services/ConversationService.luau"
M = [
 # --- siege
 ("FL-0134", WW, 'if building.kind ~= "keep" or building.kingdomId == attackerId then', 'if building.kingdomId == attackerId then', "sim/WarWatch", "counts only enemy hits on a keep"),
 ("FL-0134", WW, 'if building.kind ~= "keep" or building.kingdomId == attackerId then', 'if building.kind ~= "keep" then', "sim/WarWatch", "counts only enemy hits on a keep"),
 ("FL-0134", WW, '	siege.lastHit = sim.time\n	siege.by[attackerId] = true', '	siege.by[attackerId] = true', "sim/WarWatch", "starts with the first enemy hit on a keep"),
 ("FL-0134", WW, 'sim.time - state.siege.lastHit >= setting(sim, "siegeQuietSeconds")', 'false', "sim/WarWatch", "starts with the first enemy hit on a keep"),
 ("FL-0134", WW, 'siegeQuietSeconds = 20', 'siegeQuietSeconds = 2', "sim/WarWatch", "starts with the first enemy hit on a keep"),
 ("FL-0134", MIL, '		WarWatch.keepHit(sim, target, u.kingdomId)\n', '', "sim/WarWatch", "is started by a real ram blow on the keep"),
 ("FL-0134", WW, '			if state then\n				sim.warWatch[kid] = nil -- a fallen', '			if false then\n				sim.warWatch[kid] = nil -- a fallen', "sim/WarWatch", "ends nothing when the kingdom falls"),
 # --- raid
 ("FL-0134", WW, '			if raid == nil then\n				raid = { lastSeen', '			if true then\n				raid = { lastSeen', "sim/WarWatch", "starts when threats appear"),
 ("FL-0134", WW, 'raidQuietSeconds = 10', 'raidQuietSeconds = 1', "sim/WarWatch", "a short gap does not end the raid"),
 ("FL-0134", WW, 'sim.time - state.raid.lastSeen >= setting(sim, "raidQuietSeconds")', 'true', "sim/WarWatch", "starts when threats appear"),
 ("FL-0134", WW, 'x += t.x\n		z += t.z', 'x += t.x\n		z += t.x', "sim/WarWatch", "starts when threats appear"),
 ("FL-0134", WW, '				raid.lastSeen = sim.time\n', '', "sim/WarWatch", "starts when threats appear"),
 # --- conversation tags
 ("FL-0134", CONV, '		self:_raise(event.targetId, "war_declared")\n', '', "sim/ConversationService", "raises war_declared for both sides"),
 ("FL-0134", CONV, '	elseif name == "SiegeChanged" and event.on then', '	elseif name == "SiegeChanged" then', "sim/ConversationService", "raises siege and raid when they start"),
 ("FL-0134", CONV, '	elseif name == "RaidChanged" and event.on then', '	elseif name == "RaidChanged" then', "sim/ConversationService", "raises siege and raid when they start"),
 ("FL-0134", CONV, 'if event.previousOwner ~= nil and event.previousOwner ~= event.kingdomId then', 'if false then', "sim/ConversationService", "raises objective_lost"),
 ("FL-0134", CONV, 'if on and (rule == "strike" or rule == "riot") then', 'if (rule == "strike" or rule == "riot") then', "sim/ConversationService", "raises strike and riot when ConsequenceService starts them"),
 ("FL-0134", CONV, 'if on and (rule == "strike" or rule == "riot") then', 'if on then', "sim/ConversationService", "raises strike and riot when ConsequenceService starts them"),
]
