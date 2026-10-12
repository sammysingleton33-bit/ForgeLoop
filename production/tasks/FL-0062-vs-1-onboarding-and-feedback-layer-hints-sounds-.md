---
id: FL-0062
title: "VS-1 onboarding and feedback layer: hints, sounds, VFX, announcer"
track: build
owner: forge-04
status: READY
priority: P0
game: game-001
created: 2026-10-12
updated: 2026-10-12
depends_on: [FL-0025, FL-0027, FL-0046]
context: [games/game-001/BRIEF.md, games/game-001/CONTRACTS.md]
estimate_h: 8
evidence: []
---

# VS-1 onboarding and feedback layer: hints, sounds, VFX, announcer

## Outcome
A new player is guided gather -> build -> recruit -> capture in the first minutes, and every action feels responsive (VS-1 guided row).

## Requirements
- Onboarding.luau steps triggered by G9 events; skip; hints anchored to world objects
- Feedback: chop/mine/hammer/deposit/complete/recruit/capture sounds + VFX hooked on EntityController.rendered and G9 events; licence notes
- AnnouncerService kingdom-scoped messages via NotificationController

## Validation
Lune specs for step flow and announcer mapping; Studio walkthrough script

## Completion criteria
- [ ] Studio evidence (user playtest per games/game-001/STUDIO_PLAYTEST.md, BuildInfo sha + screenshots) before ACCEPTED

## Log
- 2026-10-12 forge-00: created for AI Kingdoms VS-1 (READY).
