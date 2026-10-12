---
id: FL-0092
title: match30 evaluation pacing profile and onboarding v2
track: design
owner: forge-04
status: READY
priority: P1
game: game-001
created: 2026-10-12
updated: 2026-10-12
depends_on: []
context: [games/game-001/design/living-kingdom.md, games/game-001/CONTRACTS.md, games/game-001/BRIEF.md, games/game-001/content/SPEC.md]
estimate_h: 3
evidence: []
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
