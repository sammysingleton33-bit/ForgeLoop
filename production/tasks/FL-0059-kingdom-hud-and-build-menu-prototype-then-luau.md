---
id: FL-0059
title: Kingdom HUD and build menu (prototype then Luau)
track: build
owner: forge-03
status: READY
priority: P0
game: game-001
created: 2026-10-12
updated: 2026-10-12
depends_on: [FL-0020, FL-0058]
context: [games/game-001/BRIEF.md, games/game-001/CONTRACTS.md]
estimate_h: 8
evidence: []
---

# Kingdom HUD and build menu (prototype then Luau)

## Outcome
Players always see their kingdom, rulers and resources, and can place buildings with clear costs (VS-1 rows 3, 5, 6).

## Requirements
- HTML/Playwright prototypes at phone, tablet and desktop sizes reviewed first (games/game-001/design/ui/)
- HUD: kingdom banner, member list, resource bar with deltas, phase/timer slot
- Build menu + placement ghost (valid/invalid tint, cost, rotate) calling Build.Place
- Uses the FORGE-03 UI kit and theme

## Validation
Prototype screenshots reviewed; Lune specs for formatting and state; Studio screenshots (phone emulator + desktop)

## Completion criteria
- [ ] Studio evidence (user playtest per games/game-001/STUDIO_PLAYTEST.md, BuildInfo sha + screenshots) before ACCEPTED

## Log
- 2026-10-12 forge-00: created for AI Kingdoms VS-1 (READY).
