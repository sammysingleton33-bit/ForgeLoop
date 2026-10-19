---
id: FL-0127
title: "Four distinct, fully dressed kingdoms: architecture, emblems and surroundings per kingdom (VS-2 row 1)"
track: asset
owner: forge-02
status: BUILDING
priority: P1
game: game-001
created: 2026-10-18
updated: 2026-10-18
depends_on: [FL-0116, FL-0124]
evidence: []
---

# Four distinct, fully dressed kingdoms: architecture, emblems and surroundings per kingdom (VS-2 row 1)

## Outcome
From the aerial camera, each kingdom reads as its own place: Emberhold, Frostmere, Thornwood and Sunspire differ in roof shape, trim, banner emblem, ground palette and surrounding props, and all four plots are fully dressed (VS-1 only dressed the player's own). Three neutral outposts stand on the map.

## Context
- BRIEF §6 (four banners and working names), §4 VS-2 row 1; owner directive 2026-10-18: "four competing, visually distinctive medieval kingdoms".
- Budget: D-047 part ceiling (27k hard, all-built-at-max), D-048 rigs. D-019 visual gate and D-051 interim-art rule apply.

## Requirements
- A per-kingdom style table in the Kit (roof profile, trim and wall colours, banner emblem, keep silhouette detail, ground decal palette) applied by `Kit.build(type, level, stage, kingdomColor)` through the kingdom id, without new contract fields if possible (else write the additive G10 row in your handoff).
- Dress all four plots in `world/Layout.luau` and `WorldPlan`: each kingdom gets surroundings that match its identity (e.g. Frostmere: pines and pale stone; Sunspire: dry grass, sandstone; Thornwood: dense oaks; Emberhold: dark stone and red banners). Keep the plots fair: same node counts and distances per kingdom (#94).
- Place three neutral outposts (`Layout.objectives`, ids `outpost_n/e/s` or similar) for FL-0126, each with a neutral tower model.
- Keep every farm field and build zone clear (the FL-0124 specs must stay green for all four kingdoms).
- Renders at the aerial camera distance of all four kingdoms side by side for D-019, plus the part count.

## Validation
Automated: Kit/World specs, part-count spec under the ceiling, NodeKeepOut for all four. Visual: D-019 review of the four-kingdom renders. Studio: B20/B21 rows.

## Completion criteria
- [ ] PR merged after review (FORGE-05 gate, FORGE-07 review).
- [ ] Studio evidence (owner's local Studio session).

## Log
- 2026-10-18 FORGE-00: created for Operation Crownfall (owner directive 2026-10-18, D-053).
- 2026-10-18 forge-02: READY → BUILDING. Started (Operation Crownfall, D-053; FORGE-00's mission 1). Part 1: three neutral outposts in world/Layout.luau (ids outpost_n/s/w, kind capture, regions, nav nodes, road spurs, ObjectiveZone), consumed by FL-0126 once FORGE-01 adds the config rows; then the four distinct kingdoms.
- 2026-10-18 forge-02: part 2A (per-kingdom architecture styles) on forge/02-blender-fl0127-styles: Kit/KingdomStyle.luau (stone, timber, plaster, thatch and crop palettes; roof pitch, snow and moss courses; merlons; banner tails) consulted by Pieces and applied once at the end of Kit.build; same part counts as main in 154 models x 5 colours, footprints unchanged; KitStyles.spec (differences, counts, cues, determinism, palette, 11 mutants) + the Kit specs green; aerial and gameplay renders of the four kingdoms in games/game-001/art/reviews/img (kit_fl0127_*), fresh-context D-019 image review NOT yet run. Part 2B (plot ground and decor) dropped by the coordinator: D-057 makes imported meshes the main art route and FL-0136 absorbs it; WIP patch kept out of the repo. Status unchanged (BUILDING).
