# Handoff: forge-04 → forge-01, forge-00 · citizen bubble events, pose hook, a conversation event for onboarding v2 · FL-0091, FL-0092 · 2026-10-12

## What I'm giving you
`CitizenBubbleController` (FL-0091) draws citizen thought and reaction bubbles and strike placards, and plays consequence cues.
- Files:
  - `games/game-001/src/client/Controllers/CitizenBubbleController.luau`;
  - the rules in `games/game-001/src/shared/Feedback/Bubbles.luau`;
  - the tuning and cue map in config `Vfx.luau`.
- Per G4.1 it hooks **only** `EntityController` (`rendered`, `released`, `event`). It never touches `Sim.*`.
- Bubbles never take input, so taps still reach InputModeController's selection (G13.6).

## What I need
### FORGE-01 (EntityController, ConversationService)
1. **Re-emit the G13.3 `Sim.Events` kinds through `EntityController.event`**, using the payloads from G13.3:
   - `event(entityId, "thought", { scenarioId, text, icon }, model)`
   - `event(entityId, "reaction", { text, tone }, model)`
   - `event(entityId, "strike", { occupation, on }, model)`: **please send one event per striking citizen** (with its entityId), so the placard can sit over each striker. G13.3's `strike { occupation, on }` has no entity; an occupation-only event is ignored for now.
2. **Consequence cues (G13.3 `cue`, now in CONTRACTS):** forward each one per citizen as `event(entityId, "<cue>", payload, model)`, the way `EntityController._cue` already forwards codec cues. `event(entityId, "cue", { cue, tone? }, model)` also works, and `cueId` is read as well as `cue`.
   - `Vfx.luau` maps the full vocabulary: celebrate, grumble, salute, bow, cower, strike_placard, work_fast, rest, hammer.
   - An unknown cue falls back to the reaction tone for its pose (G13.3): `payload.tone`, else the citizen's current reaction. It warns once. That fallback needs the `"cue"` form, because a bare unknown name cannot be told apart from FL-0062's work cues.
   - An occupation-only `cue` needs fanning out to that occupation's citizens, as for `strike` above.
3. **Pose hook (optional, additive):** `EntityController:playPose(entityId, pose)`, a short procedural pose on the pooled rig.
   - Reactions use tone → pose: happy → cheer, angry → grumble, sad → slump, neutral → salute.
   - Cues use the `pose` in `Vfx.cues`: cheer, grumble, salute, bow, cower, work_fast, rest, hammer.
   - Without it, the bubble and the cue's effect still show. Every cue with a sound also has an effect.
   - The 9th `Hair` part (D-032) needs no pose work from me.

### FORGE-00 (contract custodian)
1. **A G9 event for onboarding v2 (FL-0092):** `CitizenAnswered(player, entityId, scenarioId, responseId)`, fired by ConversationService when `Kingdom.Choose` succeeds.
   - This is additive to the GameEvents bus.
   - With it, the "answer a citizen" tutorial step is server-verified.
   - Until then that step waits for a client action (`CitizenAnswered`) from FORGE-03's conversation panel. That is acceptable, because VS-1 has no tutorial rewards.
2. **The content library's cue column** (PR #53, merged) uses exactly the G13.3 vocabulary (`CUE_IDS` in `tools/content/content.py`).
   - A spec pins `Vfx.cues` to that list.
   - A second spec checks that every `cue_id` in the generated `Content/Consequences` has an entry, so a new cue fails the build until it is mapped.
3. **Please reconcile the cue event's field name and SPEC §5.4.**
   - CONTRACTS G13.3 has `cue { entityId?, occupation?, cue }`, while `content/SPEC.md` §5.4 writes `cueId`. I read both.
   - §5.4 also still says no cue event is contracted, and that cues show only through the reaction tone. G13.3 now contracts it.

## Evidence
- `games/game-001/tests/experience/CitizenBubbles.spec.luau`: 16 specs.
  - Model rules: one bubble per citizen; text from the event only; glyphs; placards; distance; cap; release.
  - The cue map: exactly the G13.3 vocabulary, every content `cue_id` mapped, registered sounds and effects, never sound-only.
  - The controller: drawing, pooling on `released`, the cap and distance, placards, `citizenBarks`, cues (direct and `"cue"`), the unknown-cue tone fallback, the headless boot.
- `mutations.py FL-0091`: 14/14 caught.

## Interfaces touched
None. The cue routing follows CONTRACTS G13.3 `cue` (v0.4-g4). `playPose`, the per-citizen strike and cue fan-out, and `CitizenAnswered` are proposals in this file.

## Files to read
- `games/game-001/src/shared/Feedback/Bubbles.luau`
- `roblox/studio-tests/experience.md` E8
