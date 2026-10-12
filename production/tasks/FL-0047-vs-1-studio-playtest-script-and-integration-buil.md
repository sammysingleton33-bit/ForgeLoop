---
id: FL-0047
title: VS-1 Studio playtest script and integration builds
track: qa
owner: forge-05
status: READY
priority: P0
game: game-001
created: 2026-10-12
updated: 2026-10-12
depends_on: [FL-0046]
context: [games/game-001/BRIEF.md, games/game-001/CONTRACTS.md]
estimate_h: 3
evidence: []
---

# VS-1 Studio playtest script and integration builds

## Outcome
The user can verify VS-1 in Studio in under 20 minutes with a scripted checklist, and the results land as evidence.

## Requirements
- games/game-001/STUDIO_PLAYTEST.md: setup (rojo serve or CI .rbxl), one section per VS-1 row (BRIEF section 4) with exact steps, expected result, screenshot to take and Output log to paste
- 2-player local server test for a shared kingdom
- Results recorded in production/quality-gates/studio-runs.md

## Validation
Dry-run against the built place structure; user run

## Completion criteria
- [ ] User completes the checklist on an integrated build

## Log
- 2026-10-12 forge-00: created for AI Kingdoms VS-1 (READY).
