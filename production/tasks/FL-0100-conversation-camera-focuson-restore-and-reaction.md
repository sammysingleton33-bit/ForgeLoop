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
  - RulerCamera.spec 29/29 (2 new); mutations FL-0100 12/12 on #84
  - RulerCamera.spec 30/30; mutations FL-0100 14/14 on #84
  - RulerCamera.spec 33/33; mutations FL-0100 21/21 and FL-0053 22/22 on #84
  - RulerCamera.spec 33/33; mutations FL-0100 21/21 on #84
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
- 2026-10-13 forge-04: TESTING → TESTING. G13.8 v0.4-g9e (FORGE-00 ruling on #108): the conversation camera stands in front of the citizen's face. focusOn takes { facing }; on opened the yaw comes from the citizen's rig (EntityController:getModel), and the camera follows the server's turn toward the ruler while the panel is open; a pan, a go-to or a turn by the player stops the following.
- 2026-10-13 forge-04: TESTING → TESTING. FORGE-03's FL-0099 (#126) phone check: the conversation focus moves 10 studs on a phone (FORGE-03's UI/Layout breakpoint), so the citizen sits at 33-38 % from the top, above the stage that starts about 47 % down; 6 studs elsewhere. A spec projects the citizen through the camera at 750x311.
- 2026-10-13 forge-04: TESTING → TESTING. FORGE-05 B14 review on #84. M1: the facing is the line from the citizen to the ruler's character, as the server turns them, so nothing follows a released citizen; the rig fallback (no ruler character) follows one turn within 1.5 s and 2 studs. L1: returning to the overview drops a glide left from a conversation that ended in walk mode. L2: during a conversation the zoom floor is the conversation's. L3: glide durations clamped. Studio rows in experience.md E10.
- 2026-10-13 forge-04: TESTING → TESTING. FORGE-03's measured FL-0099 stage tops on phones (47 % short answers, 29-30 % costed or long; HUD stack ends at 26 %): phoneOffset is 12 studs, so the head sits at 28-30 % just under the HUD; a long conversation hides at most the body.
