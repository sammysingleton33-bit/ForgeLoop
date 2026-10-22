"""FL-0126L mutation rows (Build.PlaceLine: Simulation:placeLine, Commands.PlaceBuildingLine, BuildingService.placeLine).
Run by ../mutations.py (`mutations.py FL-0126L`). One row: (task, file, old, new, spec filter, expected failing test).
G is games/game-001/.
"""
SM = G + "src/shared/Sim/Simulation.luau"
CM = G + "src/shared/Sim/Commands.luau"
BS = G + "src/server/Services/BuildingService.luau"
M = [
 ("FL-0126L", SM, 'if kind ~= "wall" or def.placeSize == nil then', 'if def.placeSize == nil then', "sim/PlaceLine", "refuses a line that is too short, too long, or not a wall"),
 ("FL-0126L", SM, 'local count = math.max(1, math.floor(length / segment + 0.5))', 'local count = math.max(1, math.floor(length / segment))', "sim/PlaceLine", "splits the length into the nearest whole number of pieces"),
 ("FL-0126L", SM, 'local count = math.max(1, math.floor(length / segment + 0.5))', 'local count = math.max(1, math.ceil(length / segment))', "sim/PlaceLine", "splits the length into the nearest whole number of pieces"),
 ("FL-0126L", SM, 'if count > tuning.maxLineSegments then', 'if count > tuning.maxLineSegments + 5 then', "sim/PlaceLine", "refuses a line that is too short, too long, or not a wall"),
 ("FL-0126L", SM, 'if length < grid then', 'if length < 0 then', "sim/PlaceLine", "refuses a line that is too short, too long, or not a wall"),
 ("FL-0126L", SM, 'return math.floor(v / grid + 0.5) * grid', 'return v', "sim/PlaceLine", "snaps both ends to the grid"),
 ("FL-0126L", SM, 'local yaw = math.atan2(-uz, ux)', 'local yaw = math.atan2(uz, ux)', "sim/PlaceLine", "lays a diagonal line with each piece along it"),
 ("FL-0126L", SM, 'local at = (i - 0.5) * segment', 'local at = i * segment', "sim/PlaceLine", "lays round(length / segment) wall pieces end to end"),
 ("FL-0126L", CM, 'local ids, err = sim:placeLine(kingdom, kind, fx, fz, tx, tz, by)', 'local ids, err = sim:placeLine(kingdom, kind, fx, fz, tx, tz, nil)', "sim/BuildingService", "Build.PlaceLine lays a wall line all or nothing"),
 ("FL-0126L", BS, '"PlaceBuildingLine", kind, from.X, from.Z, to.X, to.Z', '"PlaceBuildingLine", kind, from.X, from.Z, to.X, from.Z', "sim/BuildingService", "Build.PlaceLine lays a wall line all or nothing"),
]
