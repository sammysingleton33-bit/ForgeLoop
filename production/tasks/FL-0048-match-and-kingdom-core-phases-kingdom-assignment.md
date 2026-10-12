---
id: FL-0048
title: "Match and Kingdom core: phases, kingdom assignment, teams, crown points"
track: build
owner: forge-01
status: READY
priority: P0
game: game-001
created: 2026-10-12
updated: 2026-10-12
depends_on: [FL-0046]
context: [games/game-001/BRIEF.md, games/game-001/CONTRACTS.md]
estimate_h: 5
evidence: []
---

# Match and Kingdom core: phases, kingdom assignment, teams, crown points

## Outcome
A server always knows the match phase and which kingdom every player belongs to (CONTRACTS G2, G3, G9).

## Requirements
- src/shared/Kingdom/Types.luau exactly per G2
- MatchService phases from Pacing durations (FORGE-04) with a sane default; KingdomService assign (balanced, parties together), Teams mapping, crown points, membership signal
- Kingdom remotes: snapshot of kingdoms and members for clients
- Fires KingdomJoined and MatchPhaseChanged

## Validation
Lune specs: assignment balance with 1..16 players, party grouping, leave/rejoin, phase timing with injected clock; Studio: 2 players see their kingdom

## Completion criteria
- [ ] Specs pass; Studio evidence (user playtest per games/game-001/STUDIO_PLAYTEST.md, BuildInfo sha + screenshots) before ACCEPTED

## Log
- 2026-10-12 forge-00: created for AI Kingdoms VS-1 (READY).
