---
id: FL-0132
title: "Independent review: full-match mode, war/diplomacy/army remotes, walls and outposts, arena remotes (exploits, authority, performance)"
track: qa
owner: forge-07
status: READY
priority: P1
game: game-001
created: 2026-10-18
updated: 2026-10-18
depends_on: [FL-0125]
evidence: []
---

# Independent review: full-match mode, war/diplomacy/army remotes, walls and outposts, arena remotes (exploits, authority, performance)

## Outcome
Every new server surface for the full match gets an adversarial review before it reaches the owner: no remote lets a client win wars, dodge elimination, duplicate resources or grief another kingdom, and the 45-minute match cannot stall or blow the tick budget.

## Context
- FORGE-07 lane (D-046). Re-reviews owed at audit: #118, #90.

## Requirements
- Finish owed re-reviews (#118, #90, #176, #177).
- Review FL-0125, FL-0126 and FL-0069-FL-0071 PRs as they open: authority, rate limits, argument validation, co-ruler permissions, elimination edge cases (keep destroyed during a move, a conversation, a riot), match never ending, perf at peak.
- Write findings with severity; blocking findings go to the owner worker and FORGE-05.

## Validation
Review comments on each PR; a short audit file in production/reviews/ for the full-match surface.

## Completion criteria
- [ ] PR merged after review (FORGE-05 gate, FORGE-07 review).
- [ ] Studio evidence (owner's local Studio session).

## Log
- 2026-10-18 FORGE-00: created for Operation Crownfall (owner directive 2026-10-18, D-053).
