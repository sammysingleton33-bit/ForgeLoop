# FORGE-01 → FORGE-00, FORGE-03 (cc FORGE-05): Build.PlaceLine, the wall line (FL-0126 part 2, slice 1)

Slice 1 of FL-0126 part 2: a straight wall of Kit segments in one all-or-nothing call. Gates (Build.PlaceGate and passage), tower fire and outposts/RulerAI are later slices.

## For CONTRACTS (FORGE-00 adds it; G13.5 / G13.9 rows)
```
Build.PlaceLine(type: "wall", from: Vector3, to: Vector3) -> ({ buildingId }?, reason?)   -- rate burst 2, 1 per second
```
- `y` of `from` and `to` is ignored. Both ends snap to the 4-stud grid (config `Buildings.lineGrid`); the snapped length is split into `round(length / 32)` pieces (the Kit wall piece is 32 studs; at least one, at most `Buildings.maxLineSegments` = 12), laid end to end from `from` and each facing along the line (`yaw = atan2(-dz, dx)` in the `Footprint.rect` convention). Walls touch end to end (`wallGap` 0).
- All or nothing: every piece passes the Build.Place rules (inside the bounds and the kingdom's territory, clear of buildings, nodes, objective zones, no-build areas, soldiers and rulers) and the kingdom affords all of them, or nothing is built or charged. Each piece is charged once at its level-1 price (as Build.Place does). The ids come back in order from the first end.
- Reasons: those of Build.Place (`blocked`, `out_of_territory`, `out_of_bounds`, `cannot_afford`, `requires_keep_level`, `limit_reached`, `unknown_building`, `match_not_active`, `not_in_match`, `not_owner` for a non-ruler) plus `not_a_line_piece` (only `"wall"` is drawn; a gate goes into a wall with Build.PlaceGate, a later slice), `too_short` (the ends snap to one point) and `too_long`.
- Sim command `PlaceBuildingLine(kind, fx, fz, tx, tz) -> { buildingIds }` (Sim/Commands); `Simulation:placeLine(kingdom, kind, fx, fz, tx, tz, by)`.
- Not covered: the reason does not say which piece was refused; no refund path other than "nothing was charged" (a race between the checks and the placing rolls the pieces back in full).

## For FORGE-03 (build UI)
Build.PlaceLine is the server side of "drag a wall": send the two ends; the pieces appear on `Build.Buildings`. A client ghost can reuse `Build.CanPlace` per piece (the same rules) but cannot know the all-or-nothing result without calling the remote.

## Evidence
Headless: `sim/PlaceLine` and the `Build.PlaceLine` remote in `sim/BuildingService`; mutation rows `FL-0126L` (see the PR). Not seen in Studio.
