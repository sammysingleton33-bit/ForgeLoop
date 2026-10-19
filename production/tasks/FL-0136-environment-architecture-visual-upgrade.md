---
id: FL-0136
title: "Environment and architecture visual upgrade with licensed assets: farms and crops, trees, rocks, markets, walls, castles, props, kingdom identity (D-057)"
track: asset
owner: forge-02
status: BUILDING
priority: P1
game: game-001
created: 2026-10-18
updated: 2026-10-19
depends_on: [FL-0135]
evidence:
  - tooling committed 9f4422c7; no third-party files committed (sha256 pins in blender/lib/envkit_sources.json)
  - bash blender/scripts/check.sh PASS; blender/tests 64 passed; forge validate 136 tasks 0 errors; ownership PASS; nothing third-party committed (sha256 pins + CC0 licence text only); Blender renders not Studio
---

# Environment and architecture visual upgrade with licensed assets: farms and crops, trees, rocks, markets, walls, castles, props, kingdom identity (D-057)

## Outcome
The kingdoms and the valley look finished from the aerial camera:
- real crops in the fields;
- organic trees and rocks;
- castles, keeps, walls, markets and houses with the four kingdoms' architecture and banners;
- props that make a town feel lived in.

Construction stages and building levels stay readable.

## Context
- D-057 (same sources, style and import path as FL-0135). This task absorbs FL-0117 (wheat and boulders were parked waiting on the mesh pilot) and the look half of FL-0127 part 2 (the four kingdom identities; FL-0127's layout and fairness work stays there).
- Budgets: D-047's part ceiling becomes a triangle and draw budget for imported pieces (D-057 (5)). Record measured figures.

## Requirements
- Build kit pieces from the chosen pack, Blender-customised to the one style:
  - crops by growth stage;
  - tree and rock sets;
  - keep, house, farm, storehouse, barracks, market, wall, gate and tower;
  - props.
- Per-kingdom variants (roof, trim, banner and emblem, stone and wood tones) through the FL-0127 style table.
- `Kit.build` keeps its signature, stages and levels, and every footprint stays exactly as it is (`Kit.footprint` is the placement contract). Imported pieces must fit the existing footprints.
- The fallback to part-built models stays until the import.
- Same import-ready batch format as FL-0135. One owner import may carry both.
- Before/after renders of a starting kingdom and of all four kingdoms at the aerial distance.

## Validation
Automated: footprint parity specs (imported bounds within `Kit.footprint`), the fallback path, NodeKeepOut still green. Visual: D-019. Studio: B2x rows after the import.

## Completion criteria
- [ ] PR merged after review (FORGE-05 gate, FORGE-07 asset-safety and code review).
- [ ] Studio screenshot evidence in a delivered playable build.

## Log
- 2026-10-18 FORGE-00: created from the owner's visual-quality directive (D-057). It absorbs FL-0117 and FL-0127 part 2's look.
- 2026-10-19 forge-02: READY → BUILDING. Phase 1 only (coordinator): one comparison round S1 (FL-0013 generators) vs S2 (KayKit Medieval Hexagon Pack 1.0 CC0, pinned 84fa4e91, baked to vertex colours) vs S3 (part-built Kit) for keep L1/L3, house, barracks, watchtower, trees/boulder, wheat; branch forge/02-blender-fl0136-compare; tooling pushed (blender/lib/envkit.py, scripts/envkit_*.py, lune/EnvDump.spec.luau). Renders running; then ONE fresh D-019 reviewer, then STOP and report.
- 2026-10-19 forge-02: BUILDING → BUILDING. Phase 1 DONE (one comparison round, one fresh D-019 reviewer, stopped): reviewer SPLIT: buildings best D (current part-built Kit), trees C (FL-0013 generators), wheat B (own style-B); KayKit (S2) fails D-033 as a recolour-only set; only own wheat ships. Recommendation: hybrid on style B (own wheat, own trees and rocks, keep the Kit for identity buildings, KayKit only for common buildings after palette alignment). Record: games/game-001/art/reviews/env-mesh.md; sheets img/d057-env-review-r1/; branch forge/02-blender-fl0136-compare (no PR). Phase 2 awaits FORGE-00.
