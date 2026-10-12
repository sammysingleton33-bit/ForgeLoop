---
id: FL-0024
title: Settings, audio and VFX foundation
track: build
owner: forge-04
status: READY
priority: P1
game: factory
created: 2026-10-12
updated: 2026-10-12
depends_on: [FL-0008]
estimate_h: 6
evidence: []
---

# Settings, audio and VFX foundation

## Outcome
Player settings persisted in the experience namespace; SoundRegistry + AudioController (categories, volume, pooling); VFX preset library (hits, rewards, ambience) within mobile budgets.

## Requirements
- Sound ids + licence notes in shared/Experience/Sounds.luau
- Settings UI uses FORGE-03 components when available

## Validation
Lune specs for settings persistence/migration and registry validation; Studio listening/visual checklist

## Completion criteria
- [ ] Budgets documented (concurrent sounds, particle counts)

## Log
- 2026-10-12 forge-00: created (READY).
