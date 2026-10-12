---
id: FL-0091
title: Citizen thought and speech bubbles, reactions, strike placards, consequence cues (G13.3)
track: build
owner: forge-04
status: READY
priority: P0
game: game-001
created: 2026-10-12
updated: 2026-10-12
depends_on: [FL-0079]
context: [games/game-001/design/living-kingdom.md, games/game-001/CONTRACTS.md, games/game-001/BRIEF.md, games/game-001/content/SPEC.md]
estimate_h: 5
evidence: []
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
