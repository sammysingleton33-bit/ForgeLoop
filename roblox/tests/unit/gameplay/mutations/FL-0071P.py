"""FL-0071P mutation rows (Crown Arena pose sanity: the speed / teleport bound in Services/ArenaService `_guard`).
Run by ../mutations.py (`mutations.py FL-0071P`). One row: (task, file, old, new, spec filter, expected failing test).
G is games/game-001/.
"""
AS = G + "src/server/Services/ArenaService.luau"
CF = G + "config/Arena.luau"
M = [
 ("FL-0071P", AS, 'if moved > allowed then', 'if false then', "sim/ArenaService", "puts a champion who teleports back"),
 ("FL-0071P", AS, 'if moved > allowed then', 'if moved > allowed * 100 then', "sim/ArenaService", "puts a champion who teleports back"),
 ("FL-0071P", AS, 'math.max(now - last.t, 0)', '0', "sim/ArenaService", "allows the distance a lag spike covers"),
 ("FL-0071P", AS, 'math.max(now - last.t, 0)', 'math.min(now - last.t, 0.001)', "sim/ArenaService", "allows the distance a lag spike covers"),
 ("FL-0071P", AS, 'last.x,\n\t\t\t\t\tlast.z,', 'position.X,\n\t\t\t\t\tposition.Z,', "sim/ArenaService", "puts a champion who teleports back"),
 ("FL-0071P", AS, 'held.last = { x = position.X, z = position.Z, t = now }', 'local _ = 0', "sim/ArenaService", "measures a teleport from the last accepted pose"),
 ("FL-0071P", CF, 'speedSlack = 1.5', 'speedSlack = 0.5', "sim/ArenaService", "allows the distance a lag spike covers"),
 ("FL-0071P", CF, 'teleportAllowance = 3', 'teleportAllowance = 300', "sim/ArenaService", "puts a champion who teleports back"),
]
