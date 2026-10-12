---
id: FL-0092
title: match30 evaluation pacing profile and onboarding v2
track: design
owner: forge-04
status: REVIEW
priority: P1
game: game-001
created: 2026-10-12
updated: 2026-10-12
depends_on: []
context: [games/game-001/design/living-kingdom.md, games/game-001/CONTRACTS.md, games/game-001/BRIEF.md]
estimate_h: 3
evidence:
  - "check.sh OVERALL PASS @bdf9736: framework 485, game-001 112 specs, Selene 0/0, StyLua 203, both builds and place checks"
  - PacingService.spec covers the match30 totals (1,820 s; 25 min kingdom play; Arena 270 s) and validation; Onboarding.spec 11 covers the v2 step triggers
  - mutations.py FL-0092 rows 4/4 CAUGHT
  - "unverified: AnswerCitizen needs FORGE-03 conversation panel report or a G9 CitizenAnswered event; Studio E6 not run"
  - "check.sh OVERALL PASS @3cd506c: framework 486, game-001 518 specs; FL-0092 mutations 5/5 CAUGHT incl. the CitizenInspected hook"
---

# match30 evaluation pacing profile and onboarding v2

## Outcome
A 30-minute match can be evaluated without changing the default, and new players are guided through the new loop.

## Requirements
- Add a `match30` mode to `Pacing.luau` that is not the default (design §6): Lobby 20 s, Founding 5 min, Expansion 7 min, Conflict 8 min, Endgame 5 min, Arena 4.5 min, Results 30 s.
- Onboarding v2 steps: inspect a citizen → build on a plot → answer a citizen → recruit → capture.

## Validation
Pacing spec covers the `match30` totals. Onboarding specs cover the step triggers.

## Completion criteria
- [ ] `bash roblox/scripts/check.sh` OVERALL PASS with the new specs

## Log
- 2026-10-12 forge-00: created for the production priorities update (D-030) (READY).
- 2026-10-12 forge-04: READY → BUILDING. On forge/04-experience-fl0092 from main.
- 2026-10-12 forge-04: BUILDING → TESTING. match30 + onboarding v2 committed; headless gates on bdf9736.
- 2026-10-12 forge-04: TESTING → REVIEW. PR from forge/04-experience-fl0092. AnswerCitizen waits for FORGE-03's CitizenAnswered report (or the proposed G9 event).
- 2026-10-12 forge-04: REVIEW → REVIEW. #29 merged before its last commit: the CitizenInspected selection hook is ported into this PR (cherry-picked onto main).
