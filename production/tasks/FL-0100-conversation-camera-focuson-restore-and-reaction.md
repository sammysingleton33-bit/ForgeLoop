---
id: FL-0100
title: Conversation camera focusOn/restore and reaction poses (G13.8)
track: build
owner: forge-04
status: SPECIFIED
priority: P1
game: game-001
created: 2026-10-13
updated: 2026-10-13
depends_on: [FL-0090, FL-0091]
context: [games/game-001/CONTRACTS.md, games/game-001/design/living-kingdom.md, DECISIONS.md, games/game-001/content/SPEC.md]
estimate_h: 3
evidence: []
---

# Conversation camera focusOn/restore and reaction poses (G13.8)

## Outcome
When a conversation opens, the camera glides from the aerial view toward the citizen's real place in the kingdom, frames them beside the portrait, and glides back afterwards. Reactions show on both the portrait and the citizen in the world.

## Context
- D-036, CONTRACTS G13.8 (Camera and presentation), G13.6 (RulerCameraController), FL-0091 reactions.

## Requirements
- `RulerCameraController:focusOn(position, { duration = 0.6 })`: ease to about 25–35 studs, citizen off-centre so the portrait does not cover them; stays inside map bounds.
- `:restore()` returns to the saved overview (position, zoom, rotation).
- Reduced-motion setting cuts instantly.
- Reaction poses or emotes by tone (happy, angry, sad, neutral), and later by FORGE-06 emotion metadata, on portrait and world rig.
- Listen to `ConversationController.opened/closed`; never raycast for selection yourself.

## Validation
- Automated: specs for focus target, restore equality, reduced-motion path, bounds clamp.
- Studio (user, via FL-0101): smooth glide in and out on PC and phone emulator.

## Completion criteria
- [ ] focusOn/restore merged with specs
- [ ] Reaction poses merged

## Log
- 2026-10-13 forge-00: created for cinematic conversations (D-036, CONTRACTS G13.8). After FL-0090 merges; start with focusOn/restore, then reactions.
