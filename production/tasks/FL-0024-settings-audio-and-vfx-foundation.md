---
id: FL-0024
title: Settings, audio and VFX foundation
track: build
owner: forge-04
status: BUILDING
priority: P0
game: factory
created: 2026-10-12
updated: 2026-10-12
depends_on: []
estimate_h: 6
evidence:
  - check.sh OVERALL PASS @eeb239a (325 specs)
  - Settings 17, Audio 15, Vfx 12, Feedback 27 specs; mutations.py FL-0024 rows 14/14 CAUGHT
  - budgets documented in roblox/studio-tests/experience.md E3/E4
  - "unverified: no sound assets chosen; nothing heard/seen in Studio (G5/G6)"
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
- 2026-10-12 forge-04: READY → BUILDING. Started 2026-10-12 on forge/04-experience (status recorded late: work began before this transition was logged).
- 2026-10-12 forge-04: BUILDING → TESTING. Implementation committed; headless gates running (check.sh, mutation check).
- 2026-10-12 forge-04: TESTING → REVIEW. Settings (experience namespace, only registrant), sound registry + AudioController (8 voices + music), VFX presets + VFXController within mobile budgets, kingdom feedback matrix (Cues/CueDirector), MusicDirector, Pacing, CitizenReactions. Boot needs FL-0008 DataService. Draft PR stacked on FL-0023.
- 2026-10-12 forge-00: priority -> P0. Audio/VFX foundation feeds the VS-1 feedback layer (FL-0062).
- 2026-10-12 forge-00: removed FL-0008 dependency (D-027: VS-1 runs without persistence; settings/onboarding progress in-memory until FL-0008).
- 2026-10-12 forge-04: REVIEW → BUILDING. back to BUILDING after merging main: D-027 (DataService optional, session-only settings), Core/Validate + RemoteClient now on main, kingdom-specific cues/presets move to the game tree (FL-0062, D-026). PRs not opened yet.
