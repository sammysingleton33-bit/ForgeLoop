---
id: FL-0012
title: Server-authoritative combat and damage framework
track: build
owner: forge-01
status: SPECIFIED
priority: P2
game: factory
created: 2026-10-12
updated: 2026-10-12
depends_on: [FL-0009, FL-0035]
estimate_h: 8
evidence: []
---

# Server-authoritative combat and damage framework

## Outcome
Reusable weapons/damage system (melee + ranged) with server hit validation, cooldowns, and kill attribution feeding PlayerEliminated.

## Requirements
- Start only after Game #1 is selected if it needs combat

## Validation
Lune specs for validation (range, rate, line of sight via injected raycast); Studio multi-client test

## Completion criteria
- [ ] Exploit cases (speed, range, rate) rejected

## Log
- 2026-10-12 forge-00: created (SPECIFIED).
