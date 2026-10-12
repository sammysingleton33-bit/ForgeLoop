---
id: FL-0011
title: HazardService framework with a real flood hazard
track: build
owner: forge-01
status: READY
priority: P1
game: factory
created: 2026-10-12
updated: 2026-10-12
depends_on: [FL-0010]
estimate_h: 6
evidence: []
---

# HazardService framework with a real flood hazard

## Outcome
Data-driven environmental hazards scheduled per round; first hazard is a flood that really raises the play-area water level by a configured height (default about 10 ft, about 3 studs per metre: state the conversion used).

## Requirements
- Hazard lifecycle: warn, active, cleanup; server-authoritative damage/effects
- Flood moves the actual water surface (Terrain water fill or water volume) and affects players (swim/damage) across the arena, not a cosmetic effect in a river
- Schedules and intensities from config

## Validation
Lune specs for scheduling/state; Studio test measuring water height before/after and confirming players in low areas are affected

## Completion criteria
- [ ] Studio evidence (screenshots or measured heights) requested from the user before ACCEPTED

## Log
- 2026-10-12 forge-00: created (READY).
