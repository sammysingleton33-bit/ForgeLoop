"""FL-0061 mutation rows, run by ../mutations.py (FL-0061 only: `mutations.py FL-0061`).

One row: (task, file, old, new, spec filter, expected failing test, project). The path prefixes
S, C, X, G, C2 and F come from mutations.py. Add rows for FL-0061 here only (D-038 (7)).
"""
M = [
 ("FL-0061", G+"src/server/Services/PacingService.luau", 'if slice.Lobby ~= 0 then', 'if false then', "PacingService", "validation catches each broken rule", "game"),
 ("FL-0061", G+"src/server/Services/PacingService.luau", 'if minutes < limits.matchMinMinutes or minutes > limits.matchMaxMinutes then', 'if false then', "PacingService", "validation catches each broken rule", "game"),
 ("FL-0061", G+"src/server/Services/PacingService.luau", '		config = Def.DEFAULTS\n', '', "PacingService", "an invalid config never breaks the match", "game"),
 ("FL-0061", G+"src/server/Services/PacingService.luau", 'if durations == nil or not table.find(Def.MODES, mode) then', 'if false then', "PacingService", "rejects an unknown mode", "game"),
 ("FL-0061", G+"src/server/Services/PacingService.luau", '	"firstAnswerSec",\n', '', "PacingService", "validation catches each broken rule", "game"),
 ("FL-0061", G+"src/server/Services/PacingService.luau", 'if not table.find(Def.IDLE_PHASES, key) then', 'if false then', "PacingService", "validation catches each broken rule", "game"),
 ("FL-0061", G+"src/server/Services/PacingService.luau", 'local idle = self._config.idleSec or Def.DEFAULTS.idleSec\n	return idle[phase]', 'return nil', "PacingService", "serves the dead-air threshold per playing phase", "game"),
 ("FL-0061", G+"config/Pacing.luau", 'firstInspectSec = 30,', 'firstInspectSec = 95,', "PacingService", "ships a valid config", "game"),
 ("FL-0061", G+"src/server/Services/PacingService.luau", 'elseif not seconds(value) or value <= 0 or value == math.huge then', 'elseif type(value) ~= "number" or value <= 0 or value == math.huge then', 'PacingService', 'validation catches each broken rule', "game"),
 ("FL-0061", G+"src/server/Services/PacingService.luau", 'if not seconds(value) or value == math.huge or value <= previous then', 'if type(value) ~= "number" or value <= previous then', 'PacingService', 'validation catches each broken rule', "game"),
]
