---
id: FL-0106
title: Match.Ended for players who arrive during Results (#70 M2)
track: build
owner: forge-01
status: REVIEW
priority: P1
game: game-001
created: 2026-10-13
updated: 2026-10-13
depends_on: [FL-0052]
context: [games/game-001/CONTRACTS.md]
estimate_h: 1
evidence:
  - PR #97 (f933c27), CI green (per FORGE-01)
  - "main cac9522 + #97: check.sh PASS (framework 517/0, game-001 1221/0); PR CI run 38357527580 3/3; mutations caught: no late send, never cleared"
---

# Match.Ended for players who arrive during Results (#70 M2)

## Outcome
A player who joins while the match is in Results still receives `Match.Ended` and sees the slice summary, instead of an empty screen.

## Context
- FORGE-05's #70 review, M2 (a late joiner during Results never gets `Match.Ended`, MatchHost). Accepted as a follow-up; implemented in PR #97.

## Requirements
- A player arriving during Results gets `Match.Ended` once, with the same payload as everyone else.
- No duplicate for players already present.

## Validation
- Automated: a spec where a player joins during Results and gets exactly one `Match.Ended`.
- Studio (user): join a server in Results (optional; covered by the spec).

## Completion criteria
- [ ] #97 merged with a FORGE-07 verdict

## Log
- 2026-10-13 forge-00: created for FORGE-01's #70 M2 follow-up, which is already implemented in PR #97 (REVIEW).
- 2026-10-13 forge-05: REVIEW → REVIEW. Merged as #97 (681f38c) with a FORGE-05 D-040 fallback verdict (star by FORGE-00, D-046). The spec covers the late joiner (Studio optional per Validation). Left: the FORGE-07 post-merge verdict named in the completion criteria.
