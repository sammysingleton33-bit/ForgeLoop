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

## Per-kingdom caps (D-047)
The D-047 part ceiling (26,402 of 27,000 all-built, `tests/world/KitCeiling.spec`) counts 12 wall segments and one gate per kingdom. Config `Buildings` now carries `wall.maxCount = 12` and `gate.maxCount = 1`, so Build.Place, Build.PlaceSlot and Build.PlaceLine all answer `limit_reached` beyond them (PlaceLine counts what stands plus the new pieces). With the cap, the all-built count is unchanged (26,402). If FORGE-00 wants longer walls, that is a D-047 amendment (parts), not a code change.

## Slice 2: Build.PlaceGate (for CONTRACTS, G13.5)
```
Build.PlaceGate(wallId: integer) -> (gateId?, reason?)   -- rate burst 2, 1 per second
```
One of the player's kingdom's wall pieces becomes a gate, in place and facing the same way. The wall is removed and half its level-1 price comes back (the cancel share, `cancelRefund`); the gate is a new site charged its level-1 price (the refund counts towards affording it). One gate per kingdom (`gate.maxCount = 1`). Reasons: `not_found`, `not_owner`, `not_a_wall`, `limit_reached`, `busy` (the wall is being upgraded), `under_attack`, `blocked` / `out_of_territory` / `out_of_bounds` (the gate is 12 studs thick, the wall 8), `cannot_afford`, `match_not_active`. Sim command `PlaceGate(wallId) -> { buildingId }`; `Simulation:placeGate`.
**Passage:** a gate lets nobody through that a wall does not. Only an at-war enemy's buildings stop a unit (`Sim/Military.moveUnit`), so the owner's units and citizens (and anyone at peace) already walk through every piece of a wall, gate or not, and an enemy at war meets a gate as a wall and must break it. Pinned in `sim/Gate`. If walls are to block the owner's own people someday, the gate's passage is the pathing change (Sim/Nav); not done here.
