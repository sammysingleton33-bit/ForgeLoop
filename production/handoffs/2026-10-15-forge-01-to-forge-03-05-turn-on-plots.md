# Handoff: FORGE-01 → FORGE-03, FORGE-05 · turning a building on a plot (CONTRACTS v0.4-g9h) · 2026-10-15

## What I need / what I'm giving you
The user's playtest said buildings and walls cannot rotate. The server side of turning on a build plot is
ready: `Build.PlaceSlot` takes an optional `turn`, and `Build/Fit` can say which turns fit. FORGE-03 can show
a Turn control on the plot picker and the ghost, built against the names below. Nothing changes for a client
that does not send `turn`.

## Done (with commits)
- PR from `forge/01-gameplay-rotation` (the link is in the PR list of `agents/forge-01/STATUS.md`).

## Evidence
- Headless Lune specs and mutations only (counts in the PR). **Unverified in Studio**: nobody has seen a
  turned building or the Turn control on screen yet.

## Interfaces touched
Additive, no breaking change:
1. **`Build.PlaceSlot(slotId, type, turn?)`**, `turn` = `Validate.optional(Validate.integer(0, 3))`.
   - `turn` is quarter turns from the slot's street facing, in the same convention as `Build.Place`'s `rot`:
     yaw = slot rot + turn × 90° in `CFrame.Angles(0, yaw, 0)`.
     Seen from above that turns counter-clockwise.
   - `nil` and `0` are today's behaviour. A `turn` outside 0..3 or not an integer is dropped by the remote's
     validation (no reply, nothing charged).
   - The turned building must still fit the slot: else `nil, "does_not_fit"`, nothing charged. It stays
     centred on the slot.
2. **`Fit.fits(type, size, turn?)`**: an odd turn swaps the footprint's X and Y. Turns wrap (`4` is `0`,
   `-1` is `3`). With no `turn` it is the old call.
3. **`Fit.turns(type, size) -> { number }`**: the turns 0..3 that fit, ascending, `{}` when the type does not
   fit at all. A Turn control can cycle through exactly this list. A half turn (2) always fits when 0 does.
   Present today (from the Kit footprints at each type's largest level):
   - house on S (24×20): `{0, 2}`;
   - barracks on M (36×30): `{0, 2}`;
   - storehouse, lumber camp, quarry on M, farm on L, watchtower on S: all four, per FORGE-03's run;
     the spec checks the rule, not these lists.

   FORGE-03's capability check (`Fit.turns ~= nil`) works: it exists in the same PR as the remote.

## Walls and the Build rail
- `Build.Place(type, position, rot)` already turns **any** free-placed building, walls and gates included, in
  90° steps. A new spec proves it for walls: each `rot` faces `rot` × 90°, the wall's placement rectangle turns
  with it, and a crosswise wall is refused where a parallel one fits.
- **45° wall lines are planned, not built.** If the user wants diagonal walls, the smallest additive change is
  an optional boolean `diagonal` argument on `Build.CanPlace` / `Build.Place` that adds 45° for walls and gates
  only. I'd do that after the move/edit API unless FORGE-00 raises it.
- `Buildings.wallGap` (so walls join without the 2-stud hole) is **next, in its own small PR**.

## Open issues and risks
- Plot slots are sized for a building's largest level; a turned building keeps inside its slot, so slot
  neighbours are unaffected. Buildings on the rail are unchanged.
- The ghost preview for a slot should use the slot's rot + turn × 90° (FORGE-03's formula already does).

## Next actions for the receiver
1. **FORGE-03:**
   - Show the Turn control on the plot picker when `#Fit.turns(type, size) > 1`, cycling through that list.
   - Send the chosen `turn` as the third argument of `Build.PlaceSlot`.
   - Map `does_not_fit` for a turn that no longer fits (it can only happen if the slot or type changed).
2. **FORGE-05:** review the PR. Gate it with the slot specs in `BuildingService.spec` and `Fit.spec`.

## Files to read
- `games/game-001/src/shared/Build/Fit.luau`: `fits`, `turns`.
- `games/game-001/src/server/Services/BuildingService.luau`: `placeSlot`.
- `games/game-001/src/shared/Build/Remotes.luau`: the `Build.PlaceSlot` row and its header.
