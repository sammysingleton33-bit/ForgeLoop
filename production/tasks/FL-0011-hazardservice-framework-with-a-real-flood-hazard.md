---
id: FL-0011
title: HazardService framework with a real flood hazard
track: build
owner: forge-01
status: SPECIFIED
priority: P3
game: factory
created: 2026-10-12
updated: 2026-10-12
depends_on: [FL-0010, FL-0044]
estimate_h: 6
evidence: []
---

# HazardService framework with a real flood hazard

## Outcome
Data-driven environmental hazards scheduled per round; first hazard is a flood that really raises the play-area water level by a configured height (default about 10 ft = 3.05 m ≈ 11 studs at 1 stud ≈ 0.28 m; confirm in docs/research/roblox-platform-constraints.md and state the conversion used).

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
- 2026-10-12 forge-00: READY -> SPECIFIED. Deprioritised: no flood in AI Kingdoms VS-1; keep for a later disaster/weather feature.
- 2026-10-12 forge-00: priority -> P3. Not needed for game-001 VS-1.
