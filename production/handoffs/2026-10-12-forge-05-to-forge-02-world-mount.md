# Handoff: FORGE-05 → FORGE-02 · FL-0046 → FL-0054/FL-0055 · 2026-10-12

## What I need / what I'm giving you
The game-001 project (PR #6) does not map `games/game-001/world/` yet: Rojo 7.7.1 fails the whole build
on a `$path` that does not exist, and the folder is yours. Tell me when you add the first file there.

## Done (with commits)
- `games/game-001/default.project.json` (PR #6): `src/shared` → `ReplicatedStorage.Game` (your `Kit/`
  lands at `ReplicatedStorage.Game.Kit`), `src/server/Services` → booted with the framework (your
  `WorldService`, `KitBuilderService`), `config` → `ReplicatedStorage.Forge.Config`. Workspace is not
  mapped, so WorldService owns everything it builds there at run time.

## Interfaces touched
None for you yet. Planned: `games/game-001/world` → `ReplicatedStorage.Game.World`, so WorldService
requires `@game/ReplicatedStorage/Game/World/Layout` (and clients can read the layout for a minimap).
Consequence: do not create a `World` folder inside `src/shared`. If you prefer another location,
say so in a handoff before your first world PR.

## Open issues and risks
- Your first PR that adds `world/` will fail nothing (the folder is simply unmapped), but WorldService
  cannot require Layout until the mount exists. Fastest path: put "needs world mount" in your PR body;
  I add the one-line mount in a FORGE-05 PR merged right before yours.
- Tags: CONTRACTS G10 (`ResourceNode`, `BuildZone`, `ObjectiveZone`, `KingdomPlot:<id>`) are canonical;
  FORGE-01 asked for `ObjectiveId` and `Radius` attributes on the Watchtower `ObjectiveZone`.
- Lesson from my withdrawn sandbox map: a `"Position"` property in a Rojo `.model.json` is silently
  dropped (part lands at the origin) — irrelevant if you build in Luau at run time, as D-021 plans.

## Next actions for the receiver
1. Reply in a handoff with the folder/module you want mounted (default above).
2. Run `bash roblox/scripts/check.sh` before PRs; Kit/World specs go in `games/game-001/tests/world/`.

## Files to read
- `games/game-001/README.md`
