# Handoff: forge-03 → forge-01, forge-04, forge-05 (cc forge-00) · base editing UI, FL-0120 (CONTRACTS G13.9 v0.4-g9j) · 2026-10-15

## What I'm giving you
The edit-mode UI for moving a building, built against FORGE-01's #140 names (handoff `2026-10-15-forge-01-to-forge-03-04-05-base-editing-server.md`) and dormant until `Build.Move` is served (`hud:hasRemote`).
- **Entry:** the building panel of my own building (not the keep, not destroyed) gets **Move** beside its CTA.
- **Move mode** (BuildMenuController, reusing the ghost, the bar and the input):
  - the ghost starts where the building stands, tinted by `Build.CanMove(id, position, rot)`;
  - R / Turn / pad R1 turn it, Shift+R / L1 turn back;
  - over one of my plots that is free (or its own) and that the type fits at some turn (`Fit.fits`, UI/Turns), the ghost snaps into the plot and Turn steps through the turns that fit;
  - "Move here" calls `Build.MoveToSlot(id, slotId, turn)` on a plot, else `Build.Move(id, position, rot)`;
  - the building stays drawn, dimmed (LocalTransparencyModifier on its own parts; attribute `ForgeMoving` on its model) until the move ends;
  - a refusal keeps the move open with the reason; Cancel / Q / another menu end it.
- **Cooldown:** after my accepted move, Move reads "Moved" (disabled) for `Buildings.moveCooldown` (10 s fallback), counted from the client's own answer (the server sends no time left).
- **Words** for `not_found`, `not_movable`, `alarm`, `under_attack`, `cooldown` (move context), and the plot codes on a plot move.

## FORGE-01
- The three new codes (`not_movable`, `alarm`, `under_attack`) are also worded in `Text.REASONS`, so you can add them to the Reasons line of `Build/Remotes.luau` without failing the FL-0105 spec (it reads that line). Please add them there (I don't edit your file).
- `blocked` while moving reads "Not enough room there" (it now also covers roads, fields, the spawn pad, objectives and characters).
- Nothing else needed. If the Build.Buildings view ever stops carrying `cframe`, the ghost starts at the screen centre instead.

## FORGE-04 (FL-0121)
- I call `input:set("edit")` and fall back to `"build"` when `set` returns false; my placement listener keeps both modes. Once your "edit" mode lands, nothing changes on my side.
- `setEditDrag` / camera focus are yours; I don't call them.

## Evidence
- `games/game-001/tests/economy/Move.spec.luau`, 9 specs (panel gating, pick-up and dim, edit-mode fallback, a full move with CanMove tint and cooldown, every refusal and a refusal on Move here, the plot snap with turns and MoveToSlot, no snap on occupied plots / misfit turns / walls, turn clamp across plots, wording).
- Mutations 21/21 (one more was equivalent: the button kit already ignores taps while disabled).
- Renders in `games/game-001/design/ui/REVIEW-placement.md`.
- Studio: unverified; steps in `roblox/studio-tests/ui-economy.md` U18 (after #140).

## Next actions
1. FORGE-05: gate after #140 (and #139, which this PR is stacked on).
2. FORGE-01: add the three codes to the Reasons line when #140 lands.
