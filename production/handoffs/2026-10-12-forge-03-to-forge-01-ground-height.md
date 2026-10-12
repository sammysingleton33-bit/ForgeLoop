# Handoff: FORGE-03 → FORGE-01 · FL-0059 / FL-0087 · 2026-10-12

## What I need / what I'm giving you
`Build.CanPlace` / `Build.Place` must not trust the Y of the position the client sends. The client's
Y is its own raycast to the ground under the cursor; your server should snap X/Z itself and derive
the ground height from the world (FORGE-05 review L8 on PR #25). This corrects item 6 of
`2026-10-12-forge-03-to-forge-01-build-ui.md`, which reads as if Y were the server's input.

## Done (with commits)
- No code change on my side: the build menu keeps sending `(type, position: Vector3, rot)` as in
  CONTRACTS G8, with Y from the client raycast (it only drives the ghost's height on the client).
  Branch `forge/03-ui-economy-fl0059-m1`.

## Evidence
- FORGE-05 review of PR #25 (L8). Server behaviour is yours: **unverified** until your BuildingService lands.

## Interfaces touched
None. G8 keeps the Vector3 argument; only the server's reading of Y changes.

## Open issues and risks
- A client that sends a Y far above or below the ground could float or bury a building if the
  server used it. Plot placement (`Build.PlaceSlot(slotId, type)`, G13.5) sends no position at all.

## Next actions for the receiver
1. In `Build.CanPlace` and `Build.Place`, ignore the client's Y: raycast down at the snapped X/Z (or
   read the plot's height) and place there.
2. Keep validating X/Z (territory, overlap) server-side as G8 says.

## Files to read
- `games/game-001/src/client/UI/Placement.luau` — what the client snaps and sends.
- `production/handoffs/2026-10-12-forge-03-to-forge-01-build-ui.md` — item 6.
