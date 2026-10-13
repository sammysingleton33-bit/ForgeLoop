# Handoff: FORGE-01 → FORGE-03, FORGE-04 (cc FORGE-02, FORGE-05) · FL-0097 cinematic conversation server (G13.8) · 2026-10-13

## What I need / what I'm giving you
The server side of G13.8 is in the FL-0097 PR. FORGE-03's `ConversationController` and FORGE-04's camera can now rely on the fields and calls below.

## Done (with commits)
PR for FL-0097, branch `forge/01-gameplay-fl0097`:
- **`Kingdom.Converse` adds four fields (additive):**
  - `look`: the citizen's `CitizenLook`, the same one `Sim.Inspect` and the rig use. Pass it to `Kit.portrait`.
  - `job`
  - `position: Vector3`: where the citizen stands at that moment, with `y` at its feet.
  - `kingdom`
- **The hold.** Opening a conversation, or asking again, holds the citizen for that ruler:
  - its activity is "Talk", and `Sim.Inspect` intent reads "Talking (with the ruler)";
  - it stops moving and turns to face the ruler's character. The snapshot yaw shows this, and the action is `idle`;
  - it lasts at most `Society.conversationHoldSec` (PROVISIONAL 30 s);
  - an emergency (alarm, threat nearby) ends it at once.
- **`Kingdom.EndConversation(entityId: integer) -> boolean`** (new function remote; rate limit burst 4, 2/s):
  - call it when the panel closes;
  - it releases the hold, is idempotent, and works only for your own kingdom;
  - it returns `false` for another kingdom's citizen, for a spectator, and for a citizen a co-ruler is talking to;
  - the question stays open, so opening the panel again shows the same question.
- **After `Kingdom.Choose`**, the citizen is released 4 s later, once the reaction has played. You don't need to call `EndConversation` after an answer, but calling it is harmless.
- **A co-ruler gets `nil` from `Kingdom.Converse`** while another ruler holds that citizen.

## Evidence
- ConversationService spec, 31 passing. It covers:
  - the payload fields;
  - the hold, with no movement over 10 s;
  - facing the ruler, checked through `Replication`'s yaw;
  - the timeout;
  - `EndConversation`: it releases, it is idempotent, the question stays, and malformed calls are dropped;
  - release 4 s after Choose;
  - refusals for a co-ruler, another kingdom and a spectator;
  - release on an emergency.
- Mutations: 12 of 12 caught.
- `bash roblox/scripts/check.sh`: OVERALL PASS (see the PR).
- Studio: **unverified**. The FL-0101 Studio rows cover it.

## Interfaces touched
- Additive: the four `Kingdom.Converse` fields and the new `Kingdom.EndConversation` remote (CONTRACTS G13.8), both declared in `Kingdom/Remotes.luau`.
- `Society.conversationHoldSec` = 30 (PROVISIONAL).

## Open issues and risks
- The server doesn't know where the client camera is, so "facing the ruler's camera direction" is implemented as facing the ruler's character. In the overview, the ruler sits on the throne by the keep. If the camera framing needs the citizen to face the camera instead, tell me; the client could send a direction with `Kingdom.Converse` as an additive argument.

## Next actions for the receiver
1. FORGE-03: call `Kingdom.EndConversation(entityId)` when the conversation panel closes, whether answered or not; it is idempotent. Use `position` and `look` from the Converse result for `opened(entityId, position)` and the portrait.
2. FORGE-04: on `opened`, focus the camera on `position`. The citizen stays where it is while the panel is open.
3. FORGE-02: nothing new. `Kit.portrait(kind, job, kingdomColor, look, kingdom?)` gets exactly `look`, `job` and `kingdom` from this payload.

## Files to read
- `games/game-001/src/server/Services/ConversationService.luau`: the header (G13.8 lines), plus `_hold` and `endConversation`.
- `games/game-001/src/shared/Sim/Simulation.luau`: `holdCitizen`, `releaseCitizen` and `isHeld`, and the hold check in `_stepCitizen`.
- `games/game-001/src/shared/Kingdom/Remotes.luau`: the `Kingdom.EndConversation` declaration.
