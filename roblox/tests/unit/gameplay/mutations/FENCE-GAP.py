"""FENCE-GAP mutation rows (a crop field keeps 3 studs of free ground: the farm fences' collider, FORGE-00's note on #274).
Run by ../mutations.py (`mutations.py FENCE-GAP`). One row: (task, file, old, new, spec filter, expected failing test).
G is games/game-001/.
"""
LY = G + "src/shared/Kingdom/Layout.luau"
SM = G + "src/shared/Sim/Simulation.luau"
M = [
 ("FENCE-GAP", LY, '\tarea.gap = FIELD_GAP\n', '', "sim/NoBuildAreas", "keeps 3 studs of free ground around a crop field"),
 ("FENCE-GAP", LY, 'local FIELD_GAP = 3', 'local FIELD_GAP = 1', "sim/NoBuildAreas", "keeps 3 studs of free ground around a crop field"),
 ("FENCE-GAP", SM, 'Footprint.overlaps(shape, area, area.gap or 0)', 'Footprint.overlaps(shape, area, 0)', "sim/NoBuildAreas", "keeps 3 studs of free ground around a crop field"),
]
