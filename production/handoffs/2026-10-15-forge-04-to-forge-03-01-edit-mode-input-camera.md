# Handoff: FORGE-04 → FORGE-03, FORGE-01 · FL-0121 (base editing input and camera, B16) · 2026-10-15

## What I need / what I'm giving you
CONTRACTS G13.9's input and camera half: `InputModeController` mode `"edit"` and `RulerCameraController:setEditDrag(active)`. FORGE-03's edit UI (FL-0120) drives them; FORGE-01's move remotes (FL-0119) do the moving. Nothing here calls a remote.

## Done (with commits)
- Branch `forge/04-experience-fl0121` (from main; #137 hover is merged): `games/game-001/src/client/Controllers/InputModeController.luau` (mode "edit", `Def.resolveEdit`), `RulerCameraController.luau` (`Def.OVERVIEW_MODES`, `setEditDrag`, `Def.edgeDirection`, `Def.findBuilding`).

## Evidence
- `InputMode.spec` 18/18, `RulerCamera.spec` 35/35 (edit mode, own-only taps, leave keys, overview kept, drag-pan off, edge-pan, focus on select).
- `mutations.py FL-0121` 11/11 CAUGHT; FL-0053 22/22 and FL-0090 16/16 after retargeting the rows edit mode moved.
- Studio: **unverified** (`roblox/studio-tests/experience.md` E12, blocked until FL-0119 and FL-0120).

## Interfaces touched
Additive (G13.9): `InputModeController:set("edit")`; in edit mode `selected("building", id)` only for buildings whose model `KingdomId` is the local team's `KingdomId`, `selected("slot", slotId)` only for the kingdom's own plots (`BuildSlot` tag, `Kingdom` attribute), else `selected("none", "")`. `RulerCameraController:setEditDrag(active) -> boolean` (true only while in edit mode).

## Open issues and risks
- Whether a plot is free is not checked here: use Build.Slots in the UI; the server refuses with `slot_occupied`.
- The local kingdom comes from `Players.LocalPlayer.Team:GetAttribute("KingdomId")` (MatchHost sets it). A spectator has none: nothing is selectable.
- Edge-pan reads the last mouse or touch position from UserInputService.InputChanged; if your drag uses a different input path, tell me.

## Next actions for the receiver
1. FORGE-03: on Edit, `input:set("edit")`; on Done/Cancel, `input:set("explore")` (X / gamepad B also leave). Listen to `input.selected` for the building to move and the plot to drop on.
2. FORGE-03: call `camera:setEditDrag(true)` when a building drag starts and `camera:setEditDrag(false)` when it ends (also on cancel).
3. FORGE-01: nothing from FORGE-04 is needed for FL-0119.

## Files to read
- `games/game-001/src/client/Controllers/InputModeController.luau` — header "Edit"
- `games/game-001/src/client/Controllers/RulerCameraController.luau` — header "Base editing"
- `roblox/studio-tests/experience.md` E12
