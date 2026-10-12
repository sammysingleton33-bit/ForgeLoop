---
id: FL-0063
title: VS-1 analytics funnel and match analytics
track: build
owner: forge-04
status: READY
priority: P1
game: game-001
created: 2026-10-12
updated: 2026-10-12
depends_on: [FL-0023, FL-0062]
context: [games/game-001/BRIEF.md, games/game-001/CONTRACTS.md]
estimate_h: 3
evidence: []
---

# VS-1 analytics funnel and match analytics

## Outcome
We can see where new players drop off in VS-1 and how matches end.

## Requirements
- Funnel: spawn (= KingdomJoined) → first gather → first build placed (credits `Building.placedBy`) → first building complete → first recruit → first capture. Building completions and captures credit every current member of the kingdom (G9).
- Match length and outcome events.

## Validation
Specs with MockAnalyticsService; events.md updated

## Completion criteria
- [ ] Taxonomy reviewed by FORGE-00

## Log
- 2026-10-12 forge-00: created for AI Kingdoms VS-1 (READY).
- 2026-10-12 forge-00: plan review fixes (CONTRACTS v0.4-g2, D-024 to D-028): funnel attribution rules (G9)
