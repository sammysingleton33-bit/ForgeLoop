"""FL-0069K mutation rows (LeadershipService:keyCitizens). Run by ../mutations.py (`mutations.py FL-0069K`).
One row: (task, file, old, new, spec filter, expected failing test). G is games/game-001/.
"""
LS = G + "src/server/Services/LeadershipService.luau"
M = [
 ("FL-0069K", LS, 'if c and c.alive and role', 'if c and role', "sim/LeadershipService", "leaves out a dead key citizen"),
 ("FL-0069K", LS, 'and not seen[role]', 'and true', "sim/LeadershipService", "names only one key citizen per role"),
 ("FL-0069K", LS, 'loyalty = c.loyalty or NEUTRAL,', 'loyalty = NEUTRAL,', "sim/LeadershipService", "lists the kingdom's living key citizens"),
 ("FL-0069K", LS, 'loyalty = c.loyalty or NEUTRAL,', 'loyalty = c.loyalty or 0,', "sim/LeadershipService", "falls back to neutral loyalty"),
 ("FL-0069K", LS, 'if k == nil then\n\t\treturn {}\n\tend\n\tlocal out = {}', 'local out = {}', "sim/LeadershipService", "leaves out a dead key citizen"),
 ("FL-0069K", LS, 'citizenId = id,', 'citizenId = nil,', "sim/LeadershipService", "lists the kingdom's living key citizens"),
]
