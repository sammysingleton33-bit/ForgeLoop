---
id: FL-0054
title: Art direction sheet and Kit builder v0 (part-built medieval architecture with construction stages)
track: asset
owner: forge-02
status: BUILDING
priority: P0
game: game-001
created: 2026-10-12
updated: 2026-10-12
depends_on: [FL-0046]
context: [games/game-001/BRIEF.md, games/game-001/CONTRACTS.md]
estimate_h: 9
evidence: []
---

# Art direction sheet and Kit builder v0 (part-built medieval architecture with construction stages)

## Outcome
Colourful, detailed medieval buildings exist in-engine without any upload step (D-021; CONTRACTS G10).

## Requirements
- Hours 0–2: Kit stub `src/shared/Kit/Kit.luau` with the full G10 API, returning boxes with the named attachments. FORGE-05 merges it right after FL-0046.
- `games/game-001/art/ART_DIRECTION.md`: palette (4 kingdom colours + neutral), materials, shape language, references, a do and do-not list.
- Kit.build for keep L1/L2, house, farm (field + farmhouse), storehouse, lumbercamp, quarry, barracks and watchtower:
  - stages 1–3 + complete;
  - attachments Door, WorkSpot1..n, DropOff and Rally;
  - kingdom colour trims and banners.
- Also `Kit.footprint`, `Kit.NEUTRAL_COLOR`, `Kit.setKingdomColor` and `Kit.regionMarkers`.
- Primitive Parts only (Block, Wedge, CornerWedge, Cylinder, Ball). No PartOperation or UnionOperation, no GeometryService, and no function yields (D-026).
- A part budget per building, documented and enforced in specs. `Kit.prop` stand-ins carry asset ids.
- Kit preview path (required): a Lune script dumps each model's parts (CFrame, size, shape, colour, material) to JSON, and a bpy script renders contact sheets. Preview scores cover silhouette, proportion and palette only.
- Calibration pair:
  1. FORGE-00 or the user judges the first keep/house sheet.
  2. The user takes a Studio screenshot from the same camera CFrame.
  3. The Studio screenshot decides the final look.

## Validation
- Lune specs: every type, level and stage returns a valid model that has the required attachments, stays within the part budget, contains no PartOperation or UnionOperation, and never yields (built inside a coroutine that must finish).
- Contact sheets scored with the D-019 rubric by a fresh reviewer.
- Studio screenshots by the user.

## Completion criteria
- [ ] Calibration screenshot judged by FORGE-00 or the user; Studio evidence (user playtest per games/game-001/STUDIO_PLAYTEST.md, BuildInfo sha + screenshots) before ACCEPTED

## Log
- 2026-10-12 forge-00: created for AI Kingdoms VS-1 (READY).
- 2026-10-12 forge-00: plan review fixes (CONTRACTS v0.4-g2, D-024 to D-028): Kit stub first, primitive Parts only/no yields, footprint/Rally/neutral colour/region markers, preview path required, calibration pair
- 2026-10-12 forge-02: READY → BUILDING. In progress on forge/02-blender (stubs PR #16 open). See agents/forge-02/STATUS.md.
