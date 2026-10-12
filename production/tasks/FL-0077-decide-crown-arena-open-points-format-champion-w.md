---
id: FL-0077
title: Decide Crown Arena open points (format, champion, what the duel decides, support strength)
track: design
owner: user
status: READY
priority: P1
game: game-001
created: 2026-10-12
updated: 2026-10-12
depends_on: []
context: [games/game-001/design/crown-arena.md, games/game-001/CONTRACTS.md, games/game-001/BRIEF.md]
estimate_h: 0.5
evidence: []
---

# Decide Crown Arena open points (format, champion, what the duel decides, support strength)

## Outcome
The user has decided the four open Crown Arena points, and FORGE-00 has recorded them in DECISIONS and config defaults (BRIEF §16.9, design §11).

## Context
D-029; design `games/game-001/design/crown-arena.md` §11. Defaults are PROVISIONAL until then.

## Requirements
- (a) Format: top-2 kingdoms in one final duel (default) / bracket / other.
- (b) Champion in multi-ruler kingdoms: vote with leadership fallback (default) / automatic / co-rulers in sequence.
- (c) What the duel decides: the match winner (default) / a large Crown Points bonus.
- (d) Support strength: the G12.3 outcome bounds (default), and whether weak support may debuff (default: no).

## Validation
The decision is recorded in DECISIONS.md and CONTRACTS G12 by FORGE-00.

## Completion criteria
- [ ] DECISIONS entry written

## Log
- 2026-10-12 forge-00: created for the Crown Arena (D-029, VS-2) (READY).
