# Handoff: FORGE-02 → FORGE-01 · FL-0072 · 2026-10-19

## What I need / what I'm giving you
`Kit.arenaDress(model, colorA, colorB)` now behaves correctly when the arena stands where `WorldService` placed it, so `ArenaService` can call it at the Arena phase. This note also corrects two numbers in `2026-10-18-forge-02-to-forge-01-04-fl0072-arena.md` (that file is a closed handoff; this one supersedes it where they differ).

## Done (with commits)
- Branch `forge/02-blender-fl0072-fix` (PR link in the task log once open):
  - **Placement.** The rebuilt `DressA` / `DressB` used to come out in the Kit's build frame, ignoring where the arena stands (repro on main 63f834d2: the `DressA` centre moved from (140.8, 13.7, -40.2) to (0, 15.5, -13.7)). The rebuilt dress is now moved to the model's pivot, so it lands on the same stands as the first dress.
  - **Decoration physics.** The first dress gets `WorldService` decoration rules (CanTouch off; CanCollide off above `base + COLLIDE_HEIGHT`). The rebuilt one did not (67 of 103 parts CanTouch on, 48 high parts colliding). `WorldService` now sets two attributes on the arena model, `KitDecorBase` (number) and `KitCollideHeight` (number); when both exist `Kit.arenaDress` applies the same two rules to every part of the new dress. Without the attributes (Kit previews, specs) the dress keeps the Kit's own physics.
  - **KitCharacterMesh budget scan.** It never planned `blacksmith`, `merchant`, `healer`, `soldier_archer` or `soldier_knight`; it now plans all nine citizen jobs, the three soldier kinds against four kingdoms and neutral, and the governor (`1728 * 29` plans).
  - **KitReach numbers (handoff 2026-10-18, "Arena" section).** The attribute values in code are: swordShield **4.72** / 1 hand, greatsword **7.84** / 2, spear **9.5** / 2, mace **5.5** / 1 (the old note said swordShield 4.9 and mace 3.8). The highest point of the built geometry is within about 0.25 studs of each (the sword's rotated tip is at about 4.9); `KitGear.spec` pins both.

## Evidence
- `lune run roblox/tests/harness/run.luau --project games/game-001/default.project.json --specs games/game-001/tests/world ArenaLayout` → 23 passed / 0 failed. Two new specs: the dress keeps its place (XZ centre within 1.5 studs, Y within 3, every dress part within footprint + 8 of the pivot) and the rebuilt dress has decoration physics (CanTouch off on all dress parts, high parts non-colliding, `_decorate` on the result changes no part state).
- Mutants (no placement shift; no CanTouch) each fail exactly one new spec; both restored.
- `KitCharacterMesh` spec → 48 passed / 0 failed (runs about 27 s).
- Studio / in-game arena phase: **unverified** (headless only).

## Interfaces touched
Additive: two attributes on the arena model (`KitDecorBase`, `KitCollideHeight`), set by `WorldService`, read by `Kit.arenaDress`. No signature changes.

## Open issues and risks
- `Kit.arenaDress` must be called on the server on the model `WorldService` placed (not a clone built elsewhere) for the physics attributes to be present; a clone that keeps the attributes works.
- Calling it more than once is fine (each call destroys and rebuilds the two dress sub-models).

## Next actions for the receiver
1. FORGE-01: `ArenaService` calls `Kit.arenaDress(model, colorA, colorB)` at the Arena phase on the `WorldService` arena model.
2. Studio (owner or QA): run the arena phase once, check both stands show the kingdoms' caps, banners and rugs where the stands are, and that a player is not blocked by dress props higher than the collide height (7 studs).

## Files to read
- `games/game-001/src/shared/Kit/Arena.luau` — `Arena.dress`
- `games/game-001/src/server/Services/WorldService.luau` — where the two attributes are set
- `games/game-001/tests/world/ArenaLayout.spec.luau` — the new specs
