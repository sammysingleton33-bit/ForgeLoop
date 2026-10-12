---
id: FL-0010
title: RoundService with spawn, spectate and results
track: build
owner: forge-01
status: SPECIFIED
priority: P3
game: factory
created: 2026-10-12
updated: 2026-10-12
depends_on: [FL-0007, FL-0008, FL-0044]
estimate_h: 6
evidence: []
---

# RoundService with spawn, spectate and results

## Outcome
A genre-agnostic round loop (Lobby, Intermission, Countdown, Active, Results) with spawn points/platforms, elimination, spectating, last-standing or timer win, and RoundEnded results on the event bus.

## Requirements
- Built on StateMachine with injected clock
- Handles players joining/leaving mid-round, too few players, ties
- Mode config (teams/free-for-all, min players, durations) from games/<game>/config

## Validation
Lune specs for every transition and edge case; Studio test with 2-3 local clients in roblox/studio-tests/gameplay.md

## Completion criteria
- [ ] RoundEnded payload matches interfaces.md section 4

## Log
- 2026-10-12 forge-00: created (READY).
- 2026-10-12 forge-00: READY -> SPECIFIED. Deprioritised: AI Kingdoms uses MatchService (FL-0048), not a round loop. Revisit for a future round-based game.
- 2026-10-12 forge-00: priority -> P3. Not needed for game-001 VS-1.
