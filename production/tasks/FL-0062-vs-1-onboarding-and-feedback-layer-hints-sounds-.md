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
- Onboarding:
  - `Onboarding.luau` steps for the framework OnboardingService (FL-0025);
  - the first step on `KingdomJoined`, then gather → build → recruit → capture from G9 events;
  - skippable; hints anchored to world objects;
  - progress is session-only when DataService is absent (D-027).
- Feedback:
  - chop, mine, hammer, deposit, complete, recruit and capture sounds and VFX;
  - hooked on `EntityController.rendered`, `.event` and `.released` (clean-up for pooled rigs), on `InteractionController.gathered` (G4.1), and on G9 events — never on `Sim.*` remotes;
  - licence notes.
- AnnouncerService sends kingdom-scoped messages through the framework NotificationController. Game remotes go in the area `Feedback`.
- No game-tree Onboarding, Audio, VFX or Notification services or controllers (D-026).

## Validation
- Lune specs: step flow (including without DataService), announcer mapping, and VFX clean-up on release.
- Studio walkthrough script.

## Completion criteria
- [ ] Studio evidence (user playtest per games/game-001/STUDIO_PLAYTEST.md, BuildInfo sha + screenshots) before ACCEPTED

## Log
- 2026-10-12 forge-00: created for AI Kingdoms VS-1 (READY).
- 2026-10-12 forge-00: plan review fixes (CONTRACTS v0.4-g2, D-024 to D-028): session-only progress, KingdomJoined start, G4.1 hooks, framework services only, Feedback area
