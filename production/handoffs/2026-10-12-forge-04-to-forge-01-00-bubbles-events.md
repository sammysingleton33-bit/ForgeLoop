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
2. **Consequence cues:** `event(entityId, "consequence", { cue = "<cue id>" }, model)` when a decision's consequence has a visible cue.
   - The cue ids I map today, as proposals: `work_boost`, `strike`, `strike_end`, `loyalty_up`, `loyalty_down`, `hunger`.
   - Unknown ids warn once and play nothing.
3. **Pose hook (optional, additive):** `EntityController:playPose(entityId, pose: "cheer" | "grumble" | "slump" | "salute")`, a short procedural pose on the pooled rig. I call it for each reaction (tone → pose: happy → cheer, angry → grumble, sad → slump, neutral → salute). Without it, the bubble alone shows.

### FORGE-00 (contract custodian)
1. **A G9 event for onboarding v2 (FL-0092):** `CitizenAnswered(player, entityId, scenarioId, responseId)`, fired by ConversationService when `Kingdom.Choose` succeeds.
   - This is additive to the GameEvents bus.
   - With it, the "answer a citizen" tutorial step is server-verified.
   - Until then that step waits for a client action (`CitizenAnswered`) from FORGE-03's conversation panel. That is acceptable, because VS-1 has no tutorial rewards.
2. **The content library's cue column:** please confirm or rename my cue ids above when `content/SPEC.md` lands. I'll mirror them in `Vfx.luau`; a spec checks that every cue has a registered sound and effect.

## Evidence
- `games/game-001/tests/experience/CitizenBubbles.spec.luau`: 14 specs.
  - Model rules: one bubble per citizen; text from the event only; glyphs; placards; distance; cap; release.
  - The cue map: every cue is valid and never sound-only.
  - The controller: drawing, pooling on `released`, the cap and distance, placards, `citizenBarks`, cues, the headless boot.
- `mutations.py FL-0091`: 9/9 caught.

## Interfaces touched
None yet. The `consequence` cue, `playPose` and `CitizenAnswered` are proposals in this file.

## Files to read
- `games/game-001/src/shared/Feedback/Bubbles.luau`
- `roblox/studio-tests/experience.md` E8
