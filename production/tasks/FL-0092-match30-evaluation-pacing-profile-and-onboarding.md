---
id: FL-0092
title: match30 evaluation pacing profile and onboarding v2
track: design
owner: forge-04
status: REVIEW
priority: P1
game: game-001
created: 2026-10-12
updated: 2026-10-13
depends_on: []
context: [games/game-001/design/living-kingdom.md, games/game-001/CONTRACTS.md, games/game-001/BRIEF.md, games/game-001/content/SPEC.md]
estimate_h: 3
evidence:
  - "check.sh OVERALL PASS @bdf9736: framework 485, game-001 112 specs, Selene 0/0, StyLua 203, both builds and place checks"
  - PacingService.spec covers the match30 totals (1,820 s; 25 min kingdom play; Arena 270 s) and validation; Onboarding.spec 11 covers the v2 step triggers
  - mutations.py FL-0092 rows 4/4 CAUGHT
  - "unverified: AnswerCitizen needs FORGE-03 conversation panel report or a G9 CitizenAnswered event; Studio E6 not run"
  - "check.sh OVERALL PASS @3cd506c: framework 486, game-001 518 specs; FL-0092 mutations 5/5 CAUGHT incl. the CitizenInspected hook"
  - "check.sh OVERALL PASS on main d559c9e merged: framework 486, game-001 559 specs (48 files), Selene 0/0, StyLua 337, both builds and place checks; InputMode bare-ground spec + FL-0090 mutations 16/16 CAUGHT"
  - "FORGE-05 hold on #45 (tutorial stalls at AnswerCitizen): step `requires` (passed over while ConversationService is missing) + autoAdvanceSec 120; passed-over or timed-out interactive steps are not funnel steps. Onboarding.spec (framework) 33, game Onboarding.spec 13; FL-0092 mutations 13/13 CAUGHT"
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
- 2026-10-12 forge-04: REVIEW (unchanged). Main d559c9e merged. Answered FORGE-03's selection handoff (new handoff forge-04-to-forge-03-selection-rules): both rules already hold; added the bare-ground tap spec and its mutation row.
- 2026-10-13 forge-04: REVIEW (unchanged). FORGE-05 held #45 because the tutorial stalls at AnswerCitizen: steps may `require` a service (passed over without it) and AnswerCitizen auto-advances after 120 s; the funnel counts only what players did. Main (with #33) merged.
