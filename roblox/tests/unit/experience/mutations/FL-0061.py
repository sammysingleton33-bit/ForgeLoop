"""FL-0061 mutation rows, run by ../mutations.py (FL-0061 only: `mutations.py FL-0061`).

One row: (task, file, old, new, spec filter, expected failing test, project). The path prefixes
S, C, X, G, C2 and F come from mutations.py. Add rows for FL-0061 here only (D-038 (7)).
"""
M = [
 ("FL-0061", G+"src/server/Services/PacingService.luau", 'if slice.Lobby ~= 0 then', 'if false then', "PacingService", "validation catches each broken rule", "game"),
 ("FL-0061", G+"src/server/Services/PacingService.luau", 'if minutes < limits.matchMinMinutes or minutes > limits.matchMaxMinutes then', 'if false then', "PacingService", "validation catches each broken rule", "game"),
 ("FL-0061", G+"src/server/Services/PacingService.luau", '		config = Def.DEFAULTS\n', '', "PacingService", "an invalid config never breaks the match", "game"),
 ("FL-0061", G+"src/server/Services/PacingService.luau", 'if durations == nil or not table.find(Def.MODES, mode) then', 'if false then', "PacingService", "rejects an unknown mode", "game"),
]
