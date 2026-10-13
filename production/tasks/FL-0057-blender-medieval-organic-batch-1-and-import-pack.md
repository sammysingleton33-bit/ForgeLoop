---
id: FL-0057
title: Blender medieval organic batch 1 and import pack
track: asset
owner: forge-02
status: BUILDING
priority: P1
game: game-001
created: 2026-10-12
updated: 2026-10-13
depends_on: [FL-0013]
context: [games/game-001/BRIEF.md, games/game-001/CONTRACTS.md]
estimate_h: 10
evidence: []
---

# Blender medieval organic batch 1 and import pack

## Outcome
Forests, rocks, crops and props look hand-crafted and cohesive (replaces jungle-specific FL-0014/15/16).

## Requirements
- Generators: oak, pine, birch, bushes, rocks S/M/L, wheat crop stages, log and stone piles, crates, barrels, banners (4 colours)
- D-019 rubric with a fresh-context reviewer; budgets per FL-0013; the D-019 calibration for this batch is the first oak contact sheet (D-026)
- Import pack + guide; asset ids match Kit.prop stand-ins so imported meshes swap in automatically

## Validation
blender/scripts/check.sh; contact sheets reviewed; user import in Studio

## Completion criteria
- [ ] Assets import and swap in by id (G6)

## Log
- 2026-10-12 forge-00: created for AI Kingdoms VS-1 (READY).
- 2026-10-12 forge-00: plan review fixes (CONTRACTS v0.4-g2, D-024 to D-028): calibration on the first oak sheet (D-026)
- 2026-10-13 forge-02: READY → BUILDING. Organic batch generators built and reviewed (oak, pine, bush, grass, flowers, boulder, wood, haystack, fence, banners PASS; birch, cliff, stone, ore, wheat field parked after 3 rounds); import pack + guide not done.
- 2026-10-13 forge-02: BUILDING → BUILDING. Calibration verdict (D-026, FORGE-00 on #90, 2026-10-13, renders only): first oak sheet tree_oak PASS (silhouette 4, variation 4, readability 4, cohesion/budget 4); note: autumn variants 06/08 sit close to Sunspire gold at distance -> keep them out of Sunspire's plot and below ~25% of any one forest. Import pack + guide still to do.
