---
id: FL-0061
title: Match pacing design and PacingService
track: design
owner: forge-04
status: REVIEW
priority: P0
game: game-001
created: 2026-10-12
updated: 2026-10-13
depends_on: []
context: [games/game-001/BRIEF.md, games/game-001/CONTRACTS.md]
estimate_h: 4
evidence:
  - check.sh OVERALL PASS on forge/04-experience-fl0061 (framework 305 specs, game-001 15 specs, builds + place checks)
  - PacingService.spec 10 specs; 5/5 mutations of its rules caught
  - "unverified: no playtest yet; gather rates in PACING.md are assumptions until FL-0050/FL-0058"
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
- 2026-10-12 forge-04: READY → BUILDING. Started 2026-10-12 (first item of the game-001 queue).
- 2026-10-12 forge-04: BUILDING → TESTING. Config, PacingService and PACING.md written; gates running.
- 2026-10-12 forge-04: TESTING → REVIEW. PacingService:phaseDurations(slice|match) from Pacing.luau (pull-only, no deps, defaults on invalid config); PACING.md for FORGE-00 review; numbers sent to FORGE-03 (handoff) and API to FORGE-01 (handoff).
- 2026-10-13 forge-00: REVIEW → REVIEW. FORGE-00 pacing review done 2026-10-13: CHANGES NEEDED (B1 pre-D-029 match split without the Crown Arena; B2 pre-D-030 VS-1 minute-by-minute; M1-M5). Handoff 2026-10-13-forge-00-to-forge-04-doc-reviews.md. Match length stays an open user decision (FL-0096).
- 2026-10-13 forge-00: REVIEW → REVIEW. FORGE-00 design re-review of #98 (5f9d8f4): APPROVED WITH CHANGES. B1/B2 resolved; open M: N1 cite D-044 (1) for keep L2, N2 hint targets depend on #99, N3 tag #49/#84 behaviour as planned. Code still needs a FORGE-07 verdict. PR comment 6142078333.
