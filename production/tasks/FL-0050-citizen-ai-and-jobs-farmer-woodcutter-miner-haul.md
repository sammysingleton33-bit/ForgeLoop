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
depends_on: [FL-0049, FL-0058, FL-0055]
context: [games/game-001/BRIEF.md, games/game-001/CONTRACTS.md]
estimate_h: 9
evidence: []
---

# Citizen AI and jobs: farmer, woodcutter, miner, hauler with treasury deposits

## Outcome
At least 12 citizens visibly work and the kingdom stockpile rises (VS-1 row 4; CONTRACTS G5).

## Requirements
- Utility AI (needs, job, threat) plus per-job state machines, using the `Layout.resourceNodes` work spots and the storehouse `DropOff`.
- Deposits via `TreasuryService:deposit` with txId `dep:<entityId>:<tripSeq>`.
- Starting population from `Citizens.luau` `startingPopulation`, spawned when a kingdom's first ruler joins (G3).
- Hunger follows `CitizenService:setFedRatio`; ProductionService is the only food consumer (G7). Soldiers count in `byJob.soldier`.
- Bounded memory (≤ 8 events) that changes behaviour.
- Row 4b:
  - `CitizenService:inspect` and `Sim.Inspect` (own kingdom only);
  - `Kingdom.SetJobQuota` → `requestWorkers`;
  - reactions: citizens near the keep celebrate when it reaches level 2; a `rulerVisited` memory raises mood, rate-limited per citizen.
- Config `Citizens.luau` and `Jobs.luau`: rates, work times, names. The day/night routine is VS-2.

## Validation
- Lune specs: job loops, idempotent deposits, fed-ratio effects, memory effects, inspect output, quota changes, reactions, and the 100-citizen tick budget.
- Studio: 12 citizens working, the stockpile rising, and the card showing intent and memory.

## Completion criteria
- [ ] Studio evidence (user playtest per games/game-001/STUDIO_PLAYTEST.md, BuildInfo sha + screenshots) before ACCEPTED

## Log
- 2026-10-12 forge-00: created for AI Kingdoms VS-1 (READY).
- 2026-10-12 forge-00: plan review fixes (CONTRACTS v0.4-g2, D-024 to D-028): starting population, fed ratio, inspect/job quota/reactions for row 4b
