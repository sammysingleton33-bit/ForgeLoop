---
id: FL-0095
title: Review and edit the DRAFT dialogue library; supply the 16-archetype files
track: design
owner: user
status: READY
priority: P1
game: game-001
created: 2026-10-12
updated: 2026-10-12
depends_on: [FL-0083]
context: [games/game-001/design/living-kingdom.md, games/game-001/CONTRACTS.md, games/game-001/BRIEF.md]
estimate_h: 1
evidence: []
---

# Review and edit the DRAFT dialogue library; supply the 16-archetype files

## Outcome
The user has reviewed, rewritten or approved the DRAFT dialogue, and supplied the earlier 16-archetype / 48-response files if they want them imported.

## Requirements
- Edit `AI_Kingdoms_Content.xlsx` (yellow columns are text) and hand it back. FORGE-00 imports it with `content.py import-xlsx`, validates and commits it.

## Validation
`content.py validate` reports 0 errors after the import.

## Completion criteria
- [ ] Edited workbook imported

## Log
- 2026-10-12 forge-00: created for the production priorities update (D-030) (READY).
