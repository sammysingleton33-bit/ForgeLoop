---
id: FL-0010
title: RoundService with spawn, spectate and results
track: build
owner: forge-01
status: READY
priority: P1
game: factory
created: 2026-10-12
updated: 2026-10-12
depends_on: [FL-0007, FL-0008]
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
Lune specs for every transition and edge case; Studio test with 2-3 local clients in STUDIO_TEST_PLAN.md

## Completion criteria
- [ ] RoundEnded payload matches interfaces.md section 4

## Log
- 2026-10-12 forge-00: created (READY).
