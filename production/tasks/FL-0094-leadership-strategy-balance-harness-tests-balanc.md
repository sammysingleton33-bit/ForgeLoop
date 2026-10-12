---
id: FL-0094
title: Leadership-strategy balance harness (tests/balance)
track: qa
owner: forge-05
status: SPECIFIED
priority: P2
game: game-001
created: 2026-10-12
updated: 2026-10-12
depends_on: [FL-0084]
context: [games/game-001/design/living-kingdom.md, games/game-001/CONTRACTS.md, games/game-001/BRIEF.md, games/game-001/content/SPEC.md]
estimate_h: 10
evidence: []
---

# Leadership-strategy balance harness (tests/balance)

## Outcome
Balance between leadership styles is measured. Compassionate, authoritarian/fear, honorable and pragmatic rulers each have a viable path with different risks. Exploits and runaway stats are caught in CI (design §7).

## Requirements
- `games/game-001/tests/balance/` runs headless full matches across seeds and strategies:
  - compassionate
  - authoritarian/fear
  - honorable
  - pragmatic
  - exploitative
  - neglectful
- It reports Crown Points, economy, army, unrest, the loyalty and obedience distribution, and arena support.
- PROVISIONAL bounds from the design: each intended strategy reaches ≥ 85 % of the best one's median, and the exploit probes stay bounded.

## Validation
The harness runs in CI with a fixed seed set. A deliberately broken config fails it (negative test).

## Completion criteria
- [ ] Report attached to the PR

## Log
- 2026-10-12 forge-00: created for the production priorities update (D-030) (SPECIFIED).
