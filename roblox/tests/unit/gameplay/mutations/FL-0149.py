"""FL-0149 mutation rows (the key-citizen building gate in LeadershipService; RulerAI's support-building builder).
Run by ../mutations.py (`mutations.py FL-0149`). One row: (task, file, old, new, spec filter, expected failing test).
G is games/game-001/.
"""
LS = G + "src/server/Services/LeadershipService.luau"
RA = G + "src/shared/Sim/RulerAI.luau"
M = [
 ("FL-0149", LS, 'if b and not b.destroyed and b.kind == building and b.level >= 1 then', 'if b and b.kind == building and b.level >= 1 then', "sim/LeadershipService", "offers a role only while a finished building"),
 ("FL-0149", LS, 'if b and not b.destroyed and b.kind == building and b.level >= 1 then', 'if b and not b.destroyed and b.kind == building then', "sim/LeadershipService", "offers a role only while a finished building"),
 ("FL-0149", LS, 'if b and not b.destroyed and b.kind == building and b.level >= 1 then', 'if b and not b.destroyed and b.level >= 1 then', "sim/LeadershipService", "offers a role only while a finished building"),
 ("FL-0149", LS, 'local building = config.roles[role].building', 'local building = "blacksmith"', "sim/LeadershipService", "offers a role only while a finished building"),
 ("FL-0149", RA, 'if day < SUPPORT_DAY or sim:keepLevel(kingdom) < 2 then', 'if sim:keepLevel(kingdom) < 2 then', "sim/RulerSupport", "waits for day 3"),
 ("FL-0149", RA, 'if day < SUPPORT_DAY or sim:keepLevel(kingdom) < 2 then', 'if day < SUPPORT_DAY then', "sim/RulerSupport", "waits for a level-2 keep"),
 ("FL-0149", RA, 'for _, kind in { "storehouse", "lumbercamp", "quarry" } do\n\t\tif count(sim, kingdom, kind, false) == 0 then\n\t\t\treturn nil', 'for _, kind in { "storehouse", "lumbercamp" } do\n\t\tif count(sim, kingdom, kind, false) == 0 then\n\t\t\treturn nil', "sim/RulerSupport", "waits for the storehouse, the lumber camp and the quarry"),
 ("FL-0149", RA, '\t\tif hasSite(sim, kingdom, kind) then\n\t\t\treturn nil -- one at a time', '\t\tif false then\n\t\t\treturn nil -- one at a time', "sim/RulerSupport", "one at a time"),
 ("FL-0149", RA, '\tif gateWanted(sim, kingdom, aggression) then\n\t\treturn nil', '\tif false then\n\t\treturn nil', "sim/RulerSupport", "leaves the stone to the palisade"),
 ("FL-0149", RA, 'and alive[kind] then', 'and true then', "sim/RulerSupport", "only for a role whose key citizen is alive"),
 ("FL-0149", RA, 'local SUPPORT_MARGIN = { wood = 60 }', 'local SUPPORT_MARGIN = { wood = 0 }', "sim/RulerSupport", "keeps wood in hand"),
 ("FL-0149", RA, 'local SUPPORT_ORDER = { "blacksmith", "infirmary", "granary", "shrine" }', 'local SUPPORT_ORDER = { "infirmary", "blacksmith", "granary", "shrine" }', "sim/RulerSupport", "in order, one at a time"),
 ("FL-0149", RA, 'if aggression < FORTIFY_AGGRESSION or sim:keepLevel(kingdom) < 2 then\n\t\treturn false', 'if sim:keepLevel(kingdom) < 2 then\n\t\treturn false', "sim/RulerSupport", "leaves the stone to the palisade"),
]
