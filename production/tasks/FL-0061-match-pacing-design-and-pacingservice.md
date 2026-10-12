---
id: FL-0061
title: Match pacing design and PacingService
track: design
owner: forge-04
status: READY
priority: P0
game: game-001
created: 2026-10-12
updated: 2026-10-12
depends_on: []
context: [games/game-001/BRIEF.md, games/game-001/CONTRACTS.md]
estimate_h: 4
evidence: []
---

# Match pacing design and PacingService

## Outcome
A 30-45 minute match has a deliberate rhythm: phase lengths, economy growth targets, first-conflict timing (BRIEF section 3; CONTRACTS G11).

## Requirements
- `games/game-001/design/pacing/PACING.md`: minute-by-minute targets for VS-1 and the full match, using FORGE-03's economy numbers.
- Config `Pacing.luau` and `PacingService:phaseDurations(mode: "slice" | "match")` → seconds per MatchPhase (`math.huge` = untimed).
  - Slice mode matches the interim VS-1 rules (G3).
  - Pull only: MatchService finds PacingService, and PacingService never calls MatchService (G11).

## Validation
Review against FORGE-03 numbers; Lune specs for config validation

## Completion criteria
- [ ] FORGE-00 review of the pacing doc

## Log
- 2026-10-12 forge-00: created for AI Kingdoms VS-1 (READY).
- 2026-10-12 forge-00: plan review fixes (CONTRACTS v0.4-g2, D-024 to D-028): phaseDurations(mode) incl. slice mode; pull-only handoff
