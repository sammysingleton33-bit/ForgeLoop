---
id: FL-0100
title: Conversation camera focusOn/restore and reaction poses (G13.8)
track: build
owner: forge-04
status: TESTING
priority: P1
game: game-001
created: 2026-10-13
updated: 2026-10-13
depends_on: [FL-0090, FL-0091]
context: [games/game-001/CONTRACTS.md, games/game-001/design/living-kingdom.md, DECISIONS.md, games/game-001/content/SPEC.md]
estimate_h: 3
evidence:
  - "check.sh OVERALL PASS on main c1ba099 (part 1): framework 512, game-001 940 specs (71 files), Selene 0/0, StyLua 406, both builds and place checks"
  - "RulerCamera.spec 25 (4 new: conversationView, glide + restore equality, reduced-motion cut, opened/closed + pan + walk mode); mutations FL-0100 7/7 CAUGHT"
  - ReactionPoses.spec 8/8; mutations FL-0100 16/16 (9 new rows); headless silhouette render of all six poses reviewed (box render, not Studio)
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
- 2026-10-13 forge-04: SPECIFIED → BUILDING. Started per FORGE-00's handoff 2026-10-13-forge-00-to-all-build-cycle-forge06-cinematic (start after FL-0090 merges; FL-0090 merged in #29). On forge/04-experience-fl0100 from main. Part 1: RulerCameraController focusOn(position, {duration}) + restore(); ConversationController.opened/closed (FORGE-03, G13.8) not on main yet: connected when present.
- 2026-10-13 forge-04: BUILDING → TESTING. Part 1 (focusOn/restore + ConversationController opened/closed) built; headless gates next. Part 2 (reaction poses) follows.
- 2026-10-13 forge-04: TESTING (unchanged). PR (1/2) from forge/04-experience-fl0100: focusOn/restore. Reaction poses (2/2) follow in a second PR. Handoff forge-04-to-forge-03-05-conversation-camera.
- 2026-10-13 forge-04: TESTING → TESTING. Part 2 (reaction poses) on forge/04-experience-fl0100b, stacked on #84: Feedback/ReactionPoses (cheer, grumble, slump, salute, bow, cower; Sim/Pose joint format, within Pose.LIMITS, eased, reduced-motion still pose) and FeedbackPoseController (portrait via Kit.posePortrait, following ConversationController.reacted/closed when present). World rig: FORGE-01's proposed playPose samples ReactionPoses (handoff).
