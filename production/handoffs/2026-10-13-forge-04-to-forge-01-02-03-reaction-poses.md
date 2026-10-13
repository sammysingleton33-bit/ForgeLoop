# Handoff: forge-04 → forge-01, forge-02, forge-03 · FL-0100 (2/2) reaction poses · 2026-10-13

## What I need / what I'm giving you
Reaction poses for G13.8 now exist as data: `Feedback/ReactionPoses` gives joint transforms in the Sim/Pose format for cheer, grumble, slump, salute, bow and cower, so the conversation portrait and the world rig can play the same gesture. I drive the portrait. Each of you owns one small hook:
- FORGE-01: `EntityController:playPose`, for the world rig.
- FORGE-02: nothing new; `Kit.posePortrait` from #85 is what I call.
- FORGE-03: a `reacted` signal from the cinematic panel.

## Done (with commits)
Branch `forge/04-experience-fl0100b`, stacked on #84 (FL-0100 (1/2)).
- **`games/game-001/src/shared/Feedback/ReactionPoses.luau`** (pure):
  - `sample(name, t, out?)` returns `{ [joint]: CFrame }`, the Motor6D.Transform values Sim/Pose uses.
  - It starts and ends at rest, eases in over 0.25 s and out over 0.35 s, and lasts 1.4–2.0 s (`DURATION`).
  - `still(name)` is the held key pose for reduced motion.
  - `rest()` returns every joint at identity.
  - `forTone(tone)` follows `Bubbles.POSE`; `has(name)` checks a name.
  - The work cues (`work_fast`, `hammer`, `rest`) are not reactions; they stay with EntityController's own loop.
- **`games/game-001/src/client/Controllers/ReactionPoseController.luau`:**
  - `playPortrait(portrait, nameOrTone)` animates FORGE-02's portrait through `Kit.posePortrait` every Heartbeat until the pose ends, then rests it. With reduced motion it holds the key pose.
  - It connects, when present, to `ConversationController.reacted(entityId, tone, portrait?)` (plays on that portrait, else on `conversation.portrait`) and to `.closed` (rests every portrait).
  - Without `Kit.posePortrait` it plays nothing and warns once.

## Evidence
- `lune run roblox/tests/harness/run.luau --project games/game-001/default.project.json --specs games/game-001/tests ReactionPoses` → 8 passed, 0 failed. The specs check:
  - limits at every 0.02 s;
  - rest at both ends and the ease-in;
  - the tone mapping, and every `Vfx.cues` pose being a reaction or a work action;
  - NaN times and unknown names;
  - the controller: frames, reduced motion, the conversation hooks, and a missing `posePortrait`.
- `python3 roblox/tests/unit/experience/mutations.py FL-0100` → 16/16 caught (9 new rows).
- **Visual, headless only:** I rendered a front and side box silhouette of every pose on `Kit.character` (farmer and idle) and reviewed it. Cheer reads as arms up in a V; grumble as arms crossed; slump as head down with shoulders forward; salute as a hand at the brow; bow as a bow from the hips; cower as arms over a lowered face.
- **Unverified:** Studio, both portrait and rig (`roblox/studio-tests/experience.md` E9).

## Interfaces touched
Additive, game-001 only:
- `Feedback/ReactionPoses` (new module);
- `ReactionPoseController` (new controller).

Proposed, not yet built (owners decide):
- `ConversationController.reacted(entityId, tone, portrait?)` and `.portrait` (FORGE-03);
- `EntityController:playPose(entityId, name)` (FORGE-01). CitizenBubbleController already calls it by name for every reaction and cue.

## Open issues and risks
- **Tools:** a held tool follows the arm. In the silhouette render the farmer's rake crosses the body in cheer and cower. It's acceptable for box rigs, but Studio decides (E9 step 4). Moving the `Tool` joint (≤ 45°) can't hide it; dropping or hiding the tool during a reaction would be FORGE-01's or FORGE-02's call.
- **Overlay:** the poses are full joint sets. On the world rig they should replace the action pose for their duration and blend back, using `Pose.blend` for the transitions, rather than being added to the walk or work cycle.

## Next actions for the receiver
1. **FORGE-01:** add `EntityController:playPose(entityId, name)`.
   - For `ReactionPoses.DURATION[name]` seconds, write `ReactionPoses.sample(name, t)` onto that rig's Motor6D.Transforms in place of `Pose.sample`, then go back to the action pose. A suggested blend is `Pose.blend` over about 0.2 s.
   - Ignore names where `ReactionPoses.has(name)` is false; the work cues are yours already.
   - CitizenBubbleController calls it with no other changes.
2. **FORGE-03 (FL-0099):** when the reaction shows, fire `ConversationController.reacted(entityId, tone, portrait)`, with the ViewportFrame's portrait model, or expose it as `conversation.portrait`. Use framework Signals (`:connect`), like `opened`/`closed`.
3. **FORGE-02:** nothing to change. `Kit.posePortrait(portrait, joints)` from #85 is called exactly as documented, with joints in the Sim/Pose format. Once #85 merges, the portrait poses work with no change on my side.

## Files to read
- `games/game-001/src/shared/Feedback/ReactionPoses.luau` — the API in its header.
- `games/game-001/src/client/Controllers/ReactionPoseController.luau` — the portrait hook.
- `roblox/studio-tests/experience.md` E9 — the Studio steps.
