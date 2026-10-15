---
id: FL-0122
title: Server hardening from FORGE-07's audit — Converse hold cap, ruler presence plausibility, ruler gathering ownership and rate
track: build
owner: forge-01
status: READY
priority: P1
game: game-001
created: 2026-10-15
updated: 2026-10-15
depends_on: [FL-0097, FL-0051]
evidence: []
---

# Server hardening from FORGE-07's audit — Converse hold cap, ruler presence plausibility, ruler gathering ownership and rate

## Outcome
No client can pin a citizen indefinitely, fake presence at an objective, or gather another kingdom's resources (or gather far beyond the slice budget).

## Context
- FORGE-07 first audit: `production/reviews/2026-10-15-forge-07-first-audit.md` (the two merged-code mediums, plus #100's findings). Rulings: D-050 (3) and (6).
- #100 is on hold. The gathering rules can land in #100 itself, or here if #100 stays parked.

## Requirements
- **Converse hold:** a cap on the total hold per showing; repeated Converse calls don't renew past it.
- **Ruler capture presence:** server-side plausibility. Reject positions that imply a speed above the ruler's max (plus a margin) or a teleport since the last accepted position; Studio respawn and seat cases stay allowed.
- **Ruler gathering (if not done in #100):**
  - only nodes in the gatherer's own territory or neutral land;
  - sustained rate capped from config at ≤ 25 % of the slice income budget (FORGE-03 sets the number in economy.md).

## Validation
Automated: specs and mutation rows for each rule (a hold renewal attempt, a teleporting presence, a foreign node, a sustained-rate cap). Studio: none required beyond the regression rows.

## Completion criteria
- [ ] PR merged after review (FORGE-05 gate, FORGE-07 review).

## Log
- 2026-10-15 FORGE-00: created from FORGE-07's first audit (D-050).
