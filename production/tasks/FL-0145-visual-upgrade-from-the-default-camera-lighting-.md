---
id: FL-0145
title: "Visual upgrade from the default camera: lighting, terrain, village, nature, citizens"
track: asset
owner: forge-02
status: BUILDING
priority: P0
game: game-001
created: 2026-10-19
updated: 2026-10-19
depends_on: []
evidence: []
---

# Visual upgrade from the default camera: lighting, terrain, village, nature, citizens

## Outcome
From the default gameplay camera, each kingdom reads as a lived-in medieval village in a varied landscape: warm light and atmosphere, ground broken up by roads, plazas and fields, clustered and varied nature, and citizens you can recognise from the air.

## Context
- The owner's Studio run of B22 found the world empty (too much grass), citizens barely recognisable from the aerial camera, buildings disconnected, nature repetitive, and lighting weak. D-059 (2)–(3).
- FORGE-02 owns world/ (Layout, Lighting), the Kit, WorldService and blender/. Coordinate with FORGE-01 on G13.5 slots and the EntityController far LOD, and with FORGE-04 on the camera values and framing.
- D-057 budgets hold. KayKit (CC0) buildings are allowed under D-057 (20).

## Requirements
- **Pass 1, for the next playable build:**
  - lighting and atmosphere;
  - ground and terrain variation, with dirt roads and plazas;
  - forest clustering and variation;
  - citizen readability at the default camera.
- **Pass 2:**
  - village composition (paths, fences, clustered props, building orientation);
  - building silhouettes and roofs, with KayKit or Blender meshes where they are the strongest lever.
- No decorative assets that barely show in normal play.

## Validation
- Automated: `check.sh` green, within the D-047 ceiling.
- **Renders:** full-kingdom before/after renders at the real default camera height, pitch and FOV, desktop and phone, plus one fresh review per pass.
- **Studio (user):** screenshots from the default camera, compared with the owner's B22 screenshots.

## Completion criteria
- [ ] Pass 1 in the next playable build.
- [ ] Pass 2 in the build after.

## Log
- 2026-10-19 FORGE-00: created from the owner's playtest feedback.
