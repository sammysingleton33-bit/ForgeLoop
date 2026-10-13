---
id: FL-0091
title: Citizen thought and speech bubbles, reactions, strike placards, consequence cues (G13.3)
track: build
owner: forge-04
status: REVIEW
priority: P0
game: game-001
created: 2026-10-12
updated: 2026-10-13
depends_on: [FL-0079]
context: [games/game-001/design/living-kingdom.md, games/game-001/CONTRACTS.md, games/game-001/BRIEF.md, games/game-001/content/SPEC.md]
estimate_h: 5
evidence:
  - "check.sh OVERALL PASS @5741a20: framework 485, game-001 123 specs, Selene 0/0, StyLua 207, both builds and place checks"
  - "CitizenBubbles.spec 22: pool (one per citizen, release for pooled rigs, BillboardGui reuse) and distance culling (maxDistance from the camera focus, maxOnScreen, priority, LOD-hidden rigs skipped), text from the event only, glyphs/words not colour, citizenBarks, cue map pinned to the G13.3 cue vocabulary and covering every Content/Consequences cue_id (direct and \'cue\' form, unknown-cue tone fallback), no cue effect without a rendered rig, headless boot"
  - mutations.py FL-0091 rows 25/25 CAUGHT (incl. FORGE-05 review R42-1/2/3/6, N1, N2)
  - "Vfx.spec: a Model parent gets an owned Attachment under its PrimaryPart (FORGE-05 N1 / #49 M2); check.sh OVERALL PASS on main 5db78fd: framework 489, game-001 817 specs (63 files), Selene 0/0, StyLua 391"
  - "check.sh OVERALL PASS on main 4d880a4 + G13.3 cues + review fixes: framework 486, game-001 703 specs (54 files), Selene 0/0, StyLua 371, both builds and place checks"
  - "unverified: needs FORGE-01 EntityController thought/reaction/strike events (FL-0079) and Studio video (E8); poses wait for EntityController:playPose (proposed)"
  - "#42 c28576a; integration-log.md"
---

# Citizen thought and speech bubbles, reactions, strike placards, consequence cues (G13.3)

## Outcome
Citizens visibly think and react. Thought bubbles mark requests and concerns, reactions show their mood after an answer, strikers hold placards, and every consequence has a readable cue (VS-1 rows 4 and 9).

## Requirements
- `CitizenBubbleController` turns the `thought`, `reaction` and `strike` events from `Sim.Events` (G13.3) into BillboardGui bubbles:
  - pooled, with a distance limit and at most N on screen;
  - text from the event only.
- Reaction tones get a short procedural pose (cheer, slump, salute, grumble).
- Consequence cue ids from the content library map to VFX and sound in `Sounds.luau` and `Vfx.luau`.
- Subtitled; no colour-only meaning.

## Validation
Specs for the pool and the distance culling. Studio video of a request bubble, an answer, a reaction and a strike.

## Completion criteria
- [ ] Studio evidence (user playtest per games/game-001/STUDIO_PLAYTEST.md, BuildInfo sha + screenshots or video) before ACCEPTED

## Log
- 2026-10-12 forge-00: created for the production priorities update (D-030) (READY).
- 2026-10-12 forge-04: READY → BUILDING. On forge/04-experience-fl0091 from main; FL-0079 (FORGE-01) not landed: built on the G4.1/G13.3 shapes with doubles.
- 2026-10-12 forge-04: BUILDING → TESTING. Bubbles model, controller, Vfx config, specs; headless gates on 5741a20.
- 2026-10-12 forge-04: TESTING → REVIEW. PR from forge/04-experience-fl0091. Studio: roblox/studio-tests/experience.md E8 (needs FL-0079 + EntityController events). Handoff forge-04-to-forge-01-00-bubbles-events.
- 2026-10-12 forge-04: REVIEW (unchanged). Main d559c9e merged; cues follow CONTRACTS G13.3 `cue` (v0.4-g4): Vfx.cues keyed by its vocabulary, unknown cues fall back to the reaction tone; handoff and E8 updated.
- 2026-10-12 forge-04: REVIEW (unchanged). Main 4d880a4 (FL-0083 content library) merged: every content cue_id is mapped (spec); `cueId` read as well as `cue`.
- 2026-10-12 forge-04: REVIEW (unchanged). FORGE-05 review: R42-1 distance from the camera focus, no BillboardGui MaxDistance; R42-6 LOD-hidden rigs skipped; R42-3 thoughts survive a job-change rig swap (placard drops: new occupation); R42-2 NaN ids ignored; R42-4 positions only for citizens with a bubble.
- 2026-10-13 forge-04: REVIEW (unchanged). FORGE-05 re-review: N1 effects on a Model now get an owned Attachment under its PrimaryPart (fixed once in VFXController, also #49 M2); N2 cues for unrendered citizens play nothing. Main 5db78fd merged.
- 2026-10-13 forge-05: REVIEW → REVIEW. REVIEW, only G6 pending, plus a tracked follow-up (FORGE-05 acceptance record, D-038 (5); --force because the status stays REVIEW): merged code passed check.sh on the merge result and CI on main. Follow-ups from FORGE-05's #42 review: M1 'rest' cue effect never stops on pooled rigs; strike/cue entityIds (CONTRACTS v0.4-g6) handled in FORGE-04's small follow-up PR; walk-mode focus (Low). Bubbles stay empty until FL-0079 (#77).
