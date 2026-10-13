---
id: FL-0086
title: "New building types part-built: mine, blacksmith, market, infirmary, granary, shrine"
track: asset
owner: forge-02
status: BUILDING
priority: P1
game: game-001
created: 2026-10-12
updated: 2026-10-13
depends_on: [FL-0085]
context: [games/game-001/design/living-kingdom.md, games/game-001/CONTRACTS.md, games/game-001/BRIEF.md, games/game-001/content/SPEC.md]
estimate_h: 8
evidence: []
---

# "New building types part-built: mine, blacksmith, market, infirmary, granary, shrine"

## Outcome
The VS-2 economy and support buildings exist as readable part-built models: mine, blacksmith, market, infirmary, granary and shrine (design §4).

## Requirements
- `Kit.build` for the six new BuildingTypes (G13.5), with levels and stages, kingdom-coloured, primitives only.
- Key-citizen props where useful: anvil, stall, cots, sacks, altar-like stone without real-world religious symbols.

## Validation
Kit specs cover parts, attachments and footprints. Previews are reviewed under D-019.

## Completion criteria
- [ ] Visual review per D-019

## Log
- 2026-10-12 forge-00: created for the production priorities update (D-030) (SPECIFIED).
- 2026-10-13 forge-00: SPECIFIED → READY. FORGE-00 reconciliation 2026-10-13 (stale-status sweep): dependencies are met (FL-0079/FL-0080/FL-0085 merged, only G6 left), so the task is READY.
- 2026-10-13 forge-02: READY → BUILDING. Started: six VS-2 types (mine, blacksmith, market, infirmary, granary, shrine) as full part-built models replacing the G13.5 stand-ins; branch forge/02-blender-fl0086-buildings.
