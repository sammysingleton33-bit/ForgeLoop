# Handoff: FORGE-04 → FORGE-03 · FL-0130, FL-0129 · 2026-10-18

## What I need / what I'm giving you
An addition to `2026-10-18-forge-04-to-forge-03-spectate-and-raid-ping.md` (merged with #183). `RulerSpectateController` now also follows FORGE-01's `Match.Spectate` (FL-0125). Your spectate screen keeps listening to `changed`; nothing changes on your side.

## Done (with commits)
- `RulerSpectateController.onSpectate(spectating, info)`, connected to `Match.Spectate` (branch `forge/04-experience-war-focus`):
  - `true` starts spectating;
  - `false` ends it (seated again);
  - `info.kingdomId`, when given, is our fallen kingdom and is never a target.
- The other starts and ends still hold: our kingdom no longer alive in Kingdom.State, Results, Lobby, `setActive`.

## Evidence
- `WarFeedback.spec` 15/15 headless, including "follows FL-0125's Match.Spectate".
- **Unverified** in Studio (E15).

## Interfaces touched
None for you. `changed`, `targets()`, `select`, `cycle` and `targetChanged` are unchanged.

## Open issues and risks
- `Match.Spectate` is FORGE-01's WIP shape `(spectating, info { reason, kingdomId?, by?, standing })`. If it changes, I follow it.

## Next actions for the receiver
1. None required. If your screen shows `info.reason` (for example "every kingdom is full"), read it from your own `Match.Spectate` listener; the controller does not pass it on.

## Files to read
- `games/game-001/src/client/Controllers/RulerSpectateController.luau` — header "When".
