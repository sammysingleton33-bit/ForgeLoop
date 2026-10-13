---
id: FL-0062
title: "VS-1 onboarding and feedback layer: hints, sounds, VFX, announcer"
track: build
owner: forge-04
status: REVIEW
priority: P0
game: game-001
created: 2026-10-12
updated: 2026-10-13
depends_on: [FL-0025, FL-0027, FL-0046]
context: [games/game-001/BRIEF.md, games/game-001/CONTRACTS.md]
estimate_h: 8
evidence:
  - "check.sh OVERALL PASS @3ae1917: framework 486, game-001 462 specs (boot gate incl.), Selene 0/0, StyLua 298, both builds and place checks"
  - "KingdomFeedback.spec 20: announcer mapping (G9 audiences, payload primitives), step flow without DataService covered by Onboarding.spec (FL-0025/FL-0092), VFX clean-up on EntityController.released, deposits/swings rate and distance, music by phase"
  - "mutations.py FL-0062 rows 21/21 CAUGHT (incl. FORGE-05 #49 review: M1, L1-L4, L6, L8)"
  - "KingdomFeedback.spec 26 after the #49 review: one toast per placement, won/lost/draw/watched, no fallback toast for a declined celebration, kingdom tint, distance from the camera focus, bounded attached-effects list, Match.GetState for late joiners"
  - "unverified: nothing heard or seen in Studio; needs FORGE-01 G9 producers and EntityController cues; sounds not chosen yet (user)"
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
- 2026-10-12 forge-04: READY → BUILDING. On forge/04-experience-fl0062 from main. Onboarding parts shipped with FL-0025 (#22) and FL-0092 (#45); this PR is the feedback layer and announcer.
- 2026-10-12 forge-04: BUILDING → TESTING. Announcer, feedback, music, presets; headless gates on 3ae1917.
- 2026-10-12 forge-04: TESTING → REVIEW. PR from forge/04-experience-fl0062. Studio: roblox/studio-tests/experience.md E5 (fx.announce / fx.burst). Handoff forge-04-to-forge-01-05-feedback-layer.
- 2026-10-13 forge-04: REVIEW (unchanged). FORGE-05 #49 review: M1 placer excluded from buildingPlaced; M2 fixed once in VFXController (#42, merges first); L1 focus distance; L2 attached list pruned; L3 no fallback toast for a declined celebration; L4 match outcome won/lost/draw/watched; L6 Match.GetState at start (RemoteLink.request); L8 kingdom tint; nits. Main 5db78fd merged.
