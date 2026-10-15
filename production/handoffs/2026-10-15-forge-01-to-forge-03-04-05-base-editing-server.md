# Handoff: FORGE-01 → FORGE-03, FORGE-04, FORGE-05 · base editing, server side (CONTRACTS G13.9 v0.4-g9j, FL-0119) · 2026-10-15

## What I need / what I'm giving you
The server side of moving a building is ready (FL-0119). FORGE-03 can build the edit-mode UI (FL-0120) and
FORGE-04 the input mode and camera (FL-0121) against the names below. Nothing changes for a client that never
calls them, except the placement rules in "Rules that changed for Build.Place" (those apply to everyone).

## Done (with commits)
- PR from `forge/01-gameplay-basemove`, stacked on the plot-turn PR (`forge/01-gameplay-rotation`) and the wall-gap PR
  (`forge/01-gameplay-wallgap`). The link is in the PR list of `agents/forge-01/STATUS.md`.

## Evidence
- Headless Lune specs and mutation rows only (counts in the PR). **Unverified in Studio**: nobody has moved a
  building on screen yet; the checklist is in `roblox/studio-tests/gameplay.md` ("Base editing").

## Interfaces touched
Additive to the contract you already have (v0.4-g9j); no breaking change.

1. **Remotes (area Build, `Build/Remotes.luau`)**
   - `Build.CanMove(buildingId: integer(1,1e6), position: Vector3, rot: integer(0,3)) -> (boolean, reason?)` burst 10, 10/s. The ghost tint.
   - `Build.Move(buildingId, position, rot) -> (boolean, reason?)` burst 4, 2/s. `rot` is absolute, yaw = rot × 90° as for `Build.Place`.
   - `Build.MoveToSlot(buildingId, slotId: string(1,32), turn: integer(0,3)?) -> (boolean, reason?)` burst 4, 2/s. Position is the slot centre, yaw = slot rot + turn × 90° (as `Build.PlaceSlot`), `Fit.fits(type, size, turn)`.
   - A move to the same spot and facing answers `true` and does nothing (no event, no cooldown).
   - Bad arguments (wrong type, `rot` outside 0..3, an off-world position, a CFrame) get no reply at all (the remote validation drops them), exactly as `Build.Place`.
2. **Reasons these three can answer** (not in the Reasons line of `Build/Remotes.luau` on purpose: your FL-0105 spec reads that line, and a code added there fails it until it is worded. Please word them in FL-0120 and add them to that line yourself, or tell me to):
   - the `Build.Place` / `Build.PlaceSlot` ones (`blocked`, `out_of_territory`, `out_of_bounds`, `unknown_slot`, `slot_occupied`, `does_not_fit`, `not_on_plot`, `not_owner`, `match_not_active`, `kingdom_eliminated`, `not_in_match`), except limits, keep level and cost, which a move never checks;
   - `not_found` (no such building, or destroyed), `not_movable` (the keep);
   - `alarm` (the bell is ringing);
   - `under_attack`: one reason for several causes: the building is targeted or focused by an at-war unit, an at-war unit is within its range + 30 of where it stands or would stand, it was damaged in the last 10 s, it is burning, **or a war was just declared or ended (30 s lockout for both kingdoms)**;
   - `cooldown` (10 s of sim time since this building's last move; the server does not send the time left, so the UI can only count from its own successful answer).
3. **`blocked` now also means** (for `Build.Place`, `Build.PlaceSlot` and moves alike, so the ghost tint of `Build.CanPlace` and `Build.CanMove` shows them):
   - a crop field, a plot road (avenue from the keep door to the gate, cross street) or a spawn pad. `Layout.reservedAreas()` lists them; the rectangles are the world roads' segments within 130 studs of a keep at the road's drawn width, the 3 fields of each plot, and a 16 × 16 square around each ruler spawn point;
   - an objective's zone (its radius + the placement gap);
   - a soldier of any kingdom standing inside the shape, or a ruler's character within 3 studs of it (**the placing ruler's own character too**: step back before you build);
   - a slot reads occupied when any standing building is within the placement gap of it, so a slot never reads free while `PlaceSlot` there would be refused.
4. **Moves only inside the keep's own circle** (never a claimed region). Every plot slot is inside it at keep level 1, and every placeable type that fits can be moved onto every slot (spec `NoBuildAreas`).
5. **Settling:** a moved storehouse, lumber camp or quarry takes no deliveries and gives no gather bonus for 30 s (carriers walk to the next drop-off, the keep at worst). Moving it again restarts the 30 s. Nothing is sent to the client for this; a UI hint ("settling") would need a field, say so.
6. **Replication:** `Build.Buildings` re-sends a moved building (its signature gained x, z and yaw). The server's WorldView re-pivots the same Kit model without rebuilding it; clients get the new place through part replication.
7. **Event:** `GameEvents.BuildingMoved(building, player?, from: { position, rot }, slotId?)`, once per accepted move, never `BuildingPlaced` again. `from.rot` is the old yaw in radians. It reaches the bus on the host's next tick, not inside the remote call.
8. **Config (Buildings.luau):** `moveCooldown` 10, `moveSettle` 30, `moveLockout` 30, `moveDamageWindow` 10, `moveThreatReach` 30, `rulerClearance` 3.

## What stays with a moved building
Id, kind, level, hit points, construction/upgrade progress and paid cost, `placedBy`, recruit queue, workers' claims. Nothing is charged, refunded, completed or re-placed. Builders, farm workers and sleepers at it walk to its new place. A free move frees its slot id; `MoveToSlot` takes the new slot in the same command.

## For FORGE-02 (via FORGE-00)
`Layout.keepOutAreas()` returns every slot, build zone and crop field a generated node keeps out of (what `clearSpot` uses), for the dressing-clearance spec to read instead of a copy. `Layout.reservedAreas()` is a different list: the no-build areas of CONTRACTS g9j (crop fields, plot roads, spawn pads).

## Rules that changed for Build.Place (FORGE-03/04/05 please read)
- The yard crossroads and the avenue straight ahead of the keep door are now `blocked`. `FirstPlayable.spec` placed its house at keep + (30, 30): that overlaps crimson's spawn pad and the first avenue segment (checked), so it now asks the sim for a free spot (that spec is mine).
- **Please check hard-coded placement positions** in your tutorials, onboarding and QA scripts (`config/Onboarding.luau` steps, any "place a house here" hint): if one points at the avenue, a crop field or the spawn pad, it will answer `blocked`.

## What I did not do / assumptions to confirm (FORGE-00)
- The spawn pad is my reading: a 16-stud square around the ruler spawn point, turned with the plot. Tell me if FORGE-02 draws it differently.
- Plot roads are every road segment with both ends within 130 studs of a keep (the avenue and the cross street), at the drawn width (12 and 10). The valley roads beyond the gate are not no-build areas.
- Unit clearance counts soldiers (sim units), not citizens.
- The war lockout answers `under_attack` (no new reason code).
- `b.burning` comes from the consequence PR (#125): the move check already reads it and ignores it while nothing sets it.
- Wall drag, multi-select and layout presets are phase 2 (not in this PR).

## Needed from you
- **FORGE-03 (FL-0120):** the edit-mode UI: Move on a selected own building (hidden on the keep), the ghost tinted by `Build.CanMove`, R to turn, a slot snap through `Build.MoveToSlot` with the Turn list from `Fit.turns`, Confirm/Cancel; the original stays drawn (dimmed) until the server answers; wording for `not_found`, `not_movable`, `alarm`, `under_attack`, `cooldown`.
- **FORGE-04 (FL-0121):** the `"edit"` input mode (own buildings and free slots only), the camera staying in overview, `setEditDrag`.
- **FORGE-05:** the Studio gate checklist below; the `GameEvents.BuildingMoved` consumer check (Feedback/Signals ignore it today).

## Studio checklist (for the user / FORGE-05)
1. Move a house, a farm with workers on it, a barracks with a queue, a building site that is half built: each keeps its progress/queue/workers.
2. Re-turn a house on its own plot (half turn), move it to another free plot (the old plot shows free).
3. Try to move onto a tree, another building, an avenue, a crop field, the spawn point, a captured tower's zone, outside your territory: all refused (`blocked` / `out_of_territory`).
4. Stand a character inside the target spot: refused. Walk away: accepted.
5. Move a lumber camp: carriers walk to the keep for 30 s, then to the camp again.
6. Ring the alarm / declare war (needs a rival): moves refused.
7. Move the same building twice in 10 s: the second says `cooldown`.
