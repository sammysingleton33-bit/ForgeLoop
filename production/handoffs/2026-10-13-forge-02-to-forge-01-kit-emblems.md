# Handoff: FORGE-02 → FORGE-01 · colour-vision finding 3 (D-033 / D-039), Kit emblems · 2026-10-13

## What I need / what I'm giving you
The Kit now draws each kingdom's emblem (crown / star / oak leaf / sun) on every banner, flag, pennant, crest,
prop banner and slot sign, plus aerial plaques on the keep. Two things change for gameplay code that changes a
building's kingdom.

## Done (with commits)
- PR [#105](https://github.com/sammysingleton33-bit/ForgeLoop/pull/105), branch `forge/02-blender-aerial-emblems`.
- Additive API: `Kit.EMBLEM_KINDS`, `Kit.emblemKind(color) -> "crown" | "star" | "oak" | "sun" | nil`
  (same hue map as the tower caps; neutral → nil).
- `Kit.setKingdomColor(model, color)` re-forms every emblem to the new colour's kind (neutral removes them). It
  works on one Kit model or on a container holding several.

## Evidence
- `bash roblox/scripts/check.sh` → OVERALL PASS. `KitEmblems.spec` covers the colour → emblem mapping, recolour
  equal to a fresh build for every pair of colours, a moved model and a container of two models.
- FORGE-05 slice run on the merge: a captured watchtower goes from 0 emblem parts (neutral) to crowns after a
  crimson capture.
- Studio: **unverified** (four-kingdom screenshot owed, B-build asks).

## Interfaces touched
Additive: `Kit.EMBLEM_KINDS`, `Kit.emblemKind`, emblem re-forming in `Kit.setKingdomColor` (G10 Kit API).

## Open issues and risks
- `setKingdomColor` does **not** change tower caps, roof style or stone (the kingdom silhouette). A recoloured
  building keeps the old kingdom's shape.
- Emblems cost a different number of parts per kingdom. A recoloured keep can exceed its part budget (emerald keep
  L2 recoloured to gold: 262 parts against 260); `Kit.build` always fits.

## Next actions for the receiver
1. When a building changes kingdom (capture, transfer), rebuild it with `Kit.build(type, level, stage, newColor)`
   rather than calling `setKingdomColor` on it. `WorldView` currently keys models by type, level and stage, so it
   never rebuilds on a kingdom change; add the kingdom (or colour) to that key. `setKingdomColor` stays fine for
   neutral objects that only need their emblem and tint (e.g. the watchtower objective).
2. Use `Kit.emblemKind(color)` when gameplay or UI needs the colour → emblem mapping, instead of a local table.
3. Emblem parts have CanQuery off, so selection raycasts keep hitting the building.

## Files to read
- `games/game-001/src/shared/Kit/Kit.luau` — API header (Recolour section) and `setKingdomColor`.
- `games/game-001/tests/world/KitEmblems.spec.luau` — the recolour contract in specs.
- `games/game-001/art/reviews/kit-architecture.md` round 5 — design, budgets, renders.
