# Handoff: FORGE-05 → FORGE-01, FORGE-02, FORGE-03, FORGE-04 · FL-0068 · 2026-10-12

## What I need / what I'm giving you
The Studio debug panel (F8) exists. Each VS-1 playtest row starts from a **preset** the user presses.
Please register the commands and presets for your rows from your own services (no file of mine to edit).

## Done (with commits)
- `roblox/src/shared/Debug/DebugCommands.luau` (registry), `DebugServer.luau` (Studio-only remotes
  `ReplicatedStorage.ForgeDebug.List/Run`, rate-limited), `DebugPanel.luau` (client UI, F8); started by
  `Main.server` / `Main.client`. Branch `forge/05-integration-fl0068` (PR link in STATUS.md).

## Evidence
- Debug.spec: 7 cases; "outside Studio creates no remotes" and "fail-closed arguments" each proven able
  to fail. `check.sh` 9/9 PASS.

## Interfaces touched
Additive (framework): `Debug/DebugCommands` API — see the module header and `games/game-001/README.md`.

## Requested commands and presets (name → owner)
| Name | Kind | Owner | Purpose |
|---|---|---|---|
| `treasury.grant` (amount) | command | FORGE-03 | add `amount` of every resource to the presser's kingdom |
| `build.finish` | command | FORGE-01 | finish every construction in the presser's kingdom |
| `build.barracks` | command | FORGE-01 | place a completed Barracks on the presser's first free plot |
| `sim.spawn` (count) | command | FORGE-01 | spawn `count` test citizens/soldiers near the presser |
| `match.phase` (phase) | command | FORGE-01 | set the match phase (Founding/Expansion/Conflict/Endgame) |
| `vs1.row1`, `vs1.row3`, `vs1.row4`, `vs1.row5` | presets | FORGE-01 (row 1 with FORGE-02's world) | start state for rows 1, 3, 4, 5 |
| `vs1.row6`, `vs1.row7` | presets | FORGE-01 (uses `treasury.grant`) | start state for rows 6 and 7 |
| `ui.*`, `fx.*` (optional) | commands | FORGE-03 / FORGE-04 | e.g. show every HUD panel, play every sound |

Built in (FORGE-05): `forge.buildInfo`, `forge.services`.

## Open issues and risks
- Commands with arguments appear in the panel as text (no input boxes in v0): wrap them in presets
  with fixed arguments for playtests.
- Register in `start()` (not `new()`), once; a duplicate name errors at boot.

## Next actions for the receiver
1. Register your commands/presets in your next PR; note them in your `roblox/studio-tests/<area>.md`.

## Files to read
- `roblox/src/shared/Debug/DebugCommands.luau`, `games/game-001/README.md` ("Studio debug commands")
