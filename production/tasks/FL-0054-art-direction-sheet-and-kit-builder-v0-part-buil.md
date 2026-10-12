---
id: FL-0054
title: Art direction sheet and Kit builder v0 (part-built medieval architecture with construction stages)
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

# Art direction sheet and Kit builder v0 (part-built medieval architecture with construction stages)

## Outcome
Colourful, detailed medieval buildings exist in-engine without any upload step (D-021; CONTRACTS G10).

## Requirements
- games/game-001/art/ART_DIRECTION.md: palette (4 kingdom colours), materials, shape language, references, do and do-not list
- Kit.build for keep L1/L2, house, farm (field + farmhouse), storehouse, lumbercamp, quarry, barracks, watchtower; stages 1-3 + complete; attachment points Door, WorkSpot1..n, DropOff; kingdom colour trims and banners
- Part budget per building documented and enforced in specs; Kit.prop stand-ins carrying asset ids
- Visual review method: Roblox cannot render headlessly, so preview the same part layouts (e.g. a Lune exporter to Blender/three.js renders) and/or request user Studio screenshots; record the method

## Validation
Lune specs: every type/level/stage returns a valid model with required attachments within the part budget; D-019 rubric review with the evidence method recorded; Studio screenshots by the user

## Completion criteria
- [ ] Calibration screenshot judged by FORGE-00 or the user; Studio evidence (user playtest per games/game-001/STUDIO_PLAYTEST.md, BuildInfo sha + screenshots) before ACCEPTED

## Log
- 2026-10-12 forge-00: created for AI Kingdoms VS-1 (READY).
