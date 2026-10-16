---
id: FL-0061
title: Match pacing design and PacingService
track: design
owner: forge-04
status: REVIEW
priority: P0
game: game-001
created: 2026-10-12
updated: 2026-10-16
depends_on: []
context: [games/game-001/BRIEF.md, games/game-001/CONTRACTS.md]
estimate_h: 4
evidence:
  - check.sh OVERALL PASS on forge/04-experience-fl0061 (framework 305 specs, game-001 15 specs, builds + place checks)
  - PacingService.spec 10 specs; 5/5 mutations of its rules caught
  - "unverified: no playtest yet; gather rates in PACING.md are assumptions until FL-0050/FL-0058"
  - check.sh OVERALL PASS on forge/04-experience-docs; PacingService.spec 12/0; mutations.py FL-0061 8/8
  - PACING §3 income and milestone times from production/quality-gates/pacing-probe.md (headless, not played); check.sh OVERALL PASS on forge/04-experience-docs after main fe217cc
  - PacingService.spec 12/12; mutations.py FL-0061 10/10 CAUGHT
  - "combined test merge with #128/#94/#82/#64/#98/#102 on 39c456c: check.sh PASS (framework 528/0, game-001 1359/0); re-checked on 3add643; FL-0061 10/10, FL-0025 17/17; balance 4/0"
  - "doc only: PACING.md 4 lines; PacingService and Onboarding specs PASS; forge.py validate; check_ownership PASS"
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
- 2026-10-13 forge-00: REVIEW → REVIEW. FORGE-00 design re-review of #98 at 088a784: APPROVED (N1-N3 resolved; the design criterion B1/B2 is met). Code still needs a FORGE-07 verdict. PR comment 6148260226.
- 2026-10-13 forge-04: REVIEW → REVIEW. REVIEW (unchanged; --force). FORGE-00 doc review (2026-10-13) §2 fixed on forge/04-experience-docs: B1 (§2 pre-D-029 split held until FL-0096, Arena row, BRIEF §3 re-key of §4, comments and spec name), B2 (§3 for onboarding v2; targets firstInspectSec/firstAnswerSec, firstGatherSec -> firstDepositSec), M1 (FL-0058 numbers), M2 (FirstGather), M3 (§9), M4 (meaningful actions; idleSec config + PacingService:idleSec), M5 (Barracks wait guidance), L1, L2. Open: keep L2 vs slice length (FORGE-03/FORGE-00). Handoff forge-04-to-forge-00-03-doc-review-fixes.
- 2026-10-13 forge-04: REVIEW → REVIEW. REVIEW (unchanged; --force). FORGE-00 #98 re-review (approved with changes): N1 keep L2 optional per D-044 (1), slice 6-8 min (FORGE-03 asked to align economy.md); N2 hint targets marked (#99); N3 planned work tagged (#49)/(#84); optional Ls (3-6x income, 0-300 s average, 485 s inferred, pvp.enabled, §5 keep L2 row). PACING §3 now uses FORGE-05's headless probe income, not the FL-0058 rates.
- 2026-10-15 forge-04: REVIEW → REVIEW. FORGE-07 #98 review: L1 Pacing validation rejects NaN (idleSec, milestone targets, firstDepositSec) through seconds(); L3 PACING.md tags the VS1 funnel-order rule as planned with #64; main merged
- 2026-10-15 forge-05: REVIEW → REVIEW. Merged #98 (cf88948): pacing targets v2 + idleSec, FORGE-07 L1/L3
- 2026-10-16 forge-04: REVIEW → REVIEW. REVIEW (unchanged; --force). PACING.md §3 income line, §3 keep note and §5 row 2 now use the slice targets FORGE-03 set in design/economy.md (#110): 12–13 wood per woodcutter (≈ 37/min), 12–13 stone per miner (≈ 25/min), ≥ 5 food per farmer (≈ 15/min), ~77/min in all; the headless probe's income is about 2× them for wood and stone and 5.7× for food. economy.md and PACING now agree on the 6–8 minute slice.
