---
id: FL-0050
title: "Citizen AI and jobs: farmer, woodcutter, miner, hauler with treasury deposits"
track: build
owner: forge-01
status: READY
priority: P0
game: game-001
created: 2026-10-12
updated: 2026-10-12
depends_on: [FL-0049, FL-0058]
context: [games/game-001/BRIEF.md, games/game-001/CONTRACTS.md]
estimate_h: 8
evidence: []
---

# Citizen AI and jobs: farmer, woodcutter, miner, hauler with treasury deposits

## Outcome
At least 12 citizens visibly work and the kingdom stockpile rises (VS-1 row 4; CONTRACTS G5).

## Requirements
- Utility AI (needs, job, threat) + per-job state machines; deposits via TreasuryService:deposit with txId dep:<entityId>:<tripSeq>
- Bounded memory (<= 8 events) that changes behaviour
- Config Citizens.luau and Jobs.luau (rates, work times)

## Validation
Lune specs: job loops, idempotent deposits, flee on threat, memory effects, 100-citizen tick budget; Studio: 12 citizens working and the stockpile rising

## Completion criteria
- [ ] Studio evidence (user playtest per games/game-001/STUDIO_PLAYTEST.md, BuildInfo sha + screenshots) before ACCEPTED

## Log
- 2026-10-12 forge-00: created for AI Kingdoms VS-1 (READY).
