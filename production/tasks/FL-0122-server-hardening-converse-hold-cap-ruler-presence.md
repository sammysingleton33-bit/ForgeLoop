---
id: FL-0122
title: Server hardening from FORGE-07's audit — Converse hold cap, ruler presence plausibility, ruler gathering ownership and rate
track: build
owner: forge-01
status: REVIEW
priority: P1
game: game-001
created: 2026-10-15
updated: 2026-10-15
depends_on: [FL-0097, FL-0051]
evidence:
  - "bash roblox/scripts/check.sh at b756f0eb: OVERALL PASS (Lune 517/0; game-001 specs 1356 passed, 0 failed, 86 files); 18/18 mutation rows caught (FL-0122.py, run with the FL-0119 runner); forge.py validate + check_ownership PASS. Headless only: unverified in Studio."
  - check.sh PASS on the merge (game-001 1426/0); FL-0122 rows 18/18
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
- 2026-10-15 forge-01: READY → BUILDING. Started: Converse hold allowance per showing, MatchHost ruler position clamp (rulerMaxSpeed) + snapRuler on spawn, RulerGather own/neutral land + per-kingdom per-minute allowance; specs + 18 mutation rows.
- 2026-10-15 forge-01: BUILDING → REVIEW. Built to D-050 (3) and (6): hold cap 90 s per showing (refund on close), ruler position follows the report at <= 40 studs/s (snapRuler after server pivots), Kingdom.Gather own/neutral land only (new reason not_your_node) and wood 9 / stone 6 / gold 6 / food 4 per minute per kingdom (over it answers cooldown). PR from forge/01-gameplay-fl0122. Headless only; Studio rows in gameplay.md.
- 2026-10-15 forge-05: REVIEW → REVIEW. Merged #145 (c3c6b8a): hold cap, ruler position clamp, gather ownership + allowance; only G6 (gameplay.md server-hardening rows) left; open: throne-seat snapRuler
