---
id: FL-0084
title: Ruler policy hook for headless leadership-strategy simulation
track: build
owner: forge-01
status: SPECIFIED
priority: P2
game: game-001
created: 2026-10-12
updated: 2026-10-12
depends_on: [FL-0080]
context: [games/game-001/design/living-kingdom.md, games/game-001/CONTRACTS.md, games/game-001/BRIEF.md, games/game-001/content/SPEC.md]
estimate_h: 2
evidence: []
---

# Ruler policy hook for headless leadership-strategy simulation

## Outcome
Headless matches can be driven by scripted ruler strategies, so balancing can be measured rather than guessed (design §7).

## Requirements
- A `RulerPolicy` hook in the headless match: a policy decides conversation choices, construction, recruitment and attacks from the same state a player sees.
- Deterministic with a seed.

## Validation
A Lune spec runs one short match with a scripted policy, and the same seed gives the same result.

## Completion criteria
- [ ] `bash roblox/scripts/check.sh` OVERALL PASS with the new specs

## Log
- 2026-10-12 forge-00: created for the production priorities update (D-030) (SPECIFIED).
