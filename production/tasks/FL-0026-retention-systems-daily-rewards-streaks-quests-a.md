---
id: FL-0026
title: "Retention systems: daily rewards/streaks, quests and achievements"
track: build
owner: forge-04
status: READY
priority: P1
game: factory
created: 2026-10-12
updated: 2026-10-12
depends_on: [FL-0008, FL-0018]
estimate_h: 6
evidence: []
---

# Retention systems: daily rewards/streaks, quests and achievements

## Outcome
Server-authoritative daily rewards with streaks and grace rules, and data-driven quests/achievements fed by event-bus stats.

## Requirements
- UTC day boundaries from server time (no client clock trust)
- Rewards granted through EconomyService/InventoryService with transaction ids

## Validation
Lune specs with controllable clock: streak continue/break/grace, double-claim prevention, quest progress from events

## Completion criteria
- [ ] Exploit cases tested

## Log
- 2026-10-12 forge-00: created (READY).
