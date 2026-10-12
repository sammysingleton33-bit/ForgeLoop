---
id: FL-0055
title: "World layout v0 and WorldService: valley, river, forests, quarries, roads, 4 kingdom plots, nodes, objective"
track: asset
owner: forge-02
status: READY
priority: P0
game: game-001
created: 2026-10-12
updated: 2026-10-12
depends_on: [FL-0046]
context: [games/game-001/BRIEF.md, games/game-001/CONTRACTS.md]
estimate_h: 8
evidence: []
---

# World layout v0 and WorldService: valley, river, forests, quarries, roads, 4 kingdom plots, nodes, objective

## Outcome
A colourful medieval valley exists at server start with tagged resource nodes, build zones and a neutral Watchtower objective (VS-1 row 1; CONTRACTS G10).

## Requirements
- Hours 0–2: a stub `world/Layout.luau` with the G10.1 schema: one plot filled, a few nav nodes, one resource node per resource, and the Watchtower objective.
- Layout.luau v0:
  - 4 plots (spawn, regionId, anchors, build zones);
  - a nav graph over roads, paths and work spots;
  - resource nodes with work spots and nav nodes;
  - the neutral Watchtower objective with its regionId;
  - regions;
  - every position within ±4,000 studs.
- WorldService:
  - terrain from `Fill*` primitives per Layout feature, through a thin terrain adapter whose calls Lune specs record;
  - work spread across frames; `WriteVoxels`, if used, at most 64×64×16 voxels per frame;
  - props and forests placed deterministically across frames;
  - plots dressed with props only; it never calls Kit.build for buildings;
  - tags with `NodeId`, `ZoneId` and `ObjectiveId` attributes;
  - `WorldService.ready` and `isReady()`; build time logged in ms.
- `world/Lighting.luau` preset: Lighting.Technology, Atmosphere, Sky, ColorCorrection, Bloom, terrain material colours. Fixed time of day for VS-1.
- World preview: export Layout (heightfield samples, river spline, material regions, prop and Kit placements) to JSON. Render a top-down view and 3 oblique views with the Kit preview bpy renderer, and score them with D-019 before asking the user.
- Kingdom 1 dressed, kingdoms 2–4 blocked out. Part and terrain budgets documented.

## Validation
- Lune specs for layout validity: no overlaps; every resource node, objective, anchor and spawn reachable on the nav graph; bounds; unique ids. Also the recorded terrain calls.
- Preview renders scored.
- Studio fly-through screenshots, with the logged build time.

## Completion criteria
- [ ] Studio evidence (user playtest per games/game-001/STUDIO_PLAYTEST.md, BuildInfo sha + screenshots) before ACCEPTED

## Log
- 2026-10-12 forge-00: created for AI Kingdoms VS-1 (READY).
- 2026-10-12 forge-00: plan review fixes (CONTRACTS v0.4-g2, D-024 to D-028): Layout stub + G10.1 schema, Fill* terrain via adapter, ready signal, Lighting.luau, world preview renders
