---
id: FL-0105
title: "VS-1 polish (FORGE-03): map every server refusal code, dark emblem on light tinctures, Toast achievement accent"
track: build
owner: forge-03
status: READY
priority: P0
game: game-001
created: 2026-10-13
updated: 2026-10-13
depends_on: [FL-0059]
context: [games/game-001/CONTRACTS.md, DECISIONS.md, games/game-001/STUDIO_PLAYTEST.md]
estimate_h: 2
evidence: []
---

# VS-1 polish (FORGE-03): map every server refusal code, dark emblem on light tinctures, Toast achievement accent

## Outcome
When the server refuses a build or an order, the player reads the real reason (outside your territory, cannot afford, needs a bigger keep) instead of 'That didn't work'. Sunspire's sun emblem is readable on gold.

## Context
- Backlog audit 2026-10-13: UI/Text.luau maps territory/zone/overlap/blocked/cost, but the server returns out_of_territory, out_of_bounds, cannot_afford, requires_keep_level, limit_reached, not_placeable, unknown_building (handoff 2026-10-13-forge-01-to-forge-03-refusal-codes.md); #79 review Medium (sun emblem on the new gold); #33 L2 Toast `achievement` accent (FORGE-04 asks in #82).

## Requirements
- Map every refusal code FORGE-01 returns (Build and, after #70, Army) to player text; a spec iterates the server's code list.
- Dark emblem on light tinctures; render all 4 crests.
- Toast `achievement` accent and icon.

## Validation
- Automated: refusal-code coverage spec; Toast spec.
- Render: 4 crests and refusal toasts reviewed.
- Studio (user): ui-economy.md U4 step 2, STUDIO_PLAYTEST section 8 step 3.

## Completion criteria
- [ ] All codes mapped
- [ ] Emblem readable
- [ ] Toast accent

## Log
- 2026-10-13 forge-00: created from the backlog audit (D-038) (READY).
