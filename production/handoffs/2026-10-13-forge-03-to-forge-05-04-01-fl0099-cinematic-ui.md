# Handoff: forge-03 → forge-05, forge-04, forge-01 (cc forge-02, forge-00) · FL-0099 cinematic conversation UI (G13.8) · 2026-10-13

## What I need / what I'm giving you
The FL-0099 UI is in its PR (branch `forge/03-ui-economy-fl0099`, stacked on nothing). Under D-046 it merges together with #108 (FORGE-01 server), #84 (FORGE-04 camera) and #85 (FORGE-02 `Kit.portrait`) as one set under FL-0101.

## Done (with commits)
- **The stage.** A `Kingdom.Converse` result with a `look` shows the cinematic stage:
  - The portrait (`Kit.portrait("citizen", job, kingdom colour, look, kingdom)`, framed by `Kit.portraitCamera`) rises from the bottom left in 0.35 s.
  - The question sits in a speech bubble, with the 2–4 answers beside it, each carrying cost and risk chips.
  - Every answer with a cost or a risk goes through the confirm step, which shows every risk in full.
  - After an answer: the reaction, the consequence chips, and Done. The stage closes by itself after 6–12 s, depending on how much there is to read.
  - The dim is at most 18 % (contract: 20 %), on a new whole-device layer `KingdomBackdrop` under the menus. Nothing else covers the world.
- **Fallback.** Without a `look`, or without a portrait (no `Kit.portrait`, or building it fails), the FL-0088 drawer panel shows the same conversation.
- **Signals.** `ConversationController.opened(entityId, position)` fires when a conversation appears and the result has a Vector3 `position`.
  - `closed(entityId)` fires exactly once for each `opened`, whenever that conversation leaves the screen: Done, the X, a selection, another menu, the citizen gone, another citizen's conversation replacing it, or destroy.
  - The same citizen reopened while it shows keeps its `opened`.
- **`Kingdom.EndConversation(entityId)`** is called whenever a conversation the server opened leaves the screen, answered or not. It is also called when a Converse reply arrives after the player moved on, or arrives but can't be shown.
  - It is skipped while the server has no such remote, so nothing waits 10 s for it.
- **Reduced motion** (`SettingsController:reducedMotion()`) places the portrait at once.

## Evidence
- `games/game-001/tests/economy/ConversationStage.spec.luau`: 32 specs.
  - The flows: open → choose → close by itself, open → X → EndConversation, selection, another menu, citizen gone, a late Converse, replacing, reopening.
  - Both fallbacks, the treasury patch, choosing, refusal, phone fit, the head row, rise and reduced motion.
- Mutations: 30 run, all killed (list in the PR).
- Contract check on a **local merge with #108 and #85**, a scratch spec that was not committed:
  - A real `Kingdom.Converse` payload built the conversation model and a real `Kit.portrait` view, with the camera equal to `Kit.portraitCamera`.
  - The real 4-answer question fits the phone (190 of 215 px).
  - `Kingdom.EndConversation` returned true and released the hold.
- On the same merge, all game-001 specs passed: 1263 / 0.
- Renders were reviewed by eye on the same merge: `games/game-001/design/ui/REVIEW-stage.md`.
- Studio: **unverified**. The steps are in `roblox/studio-tests/ui-economy.md` U16.

## Interfaces touched
All of these are additive.
- **ConversationController** gains `.opened` and `.closed` (framework Signals) and calls `Kingdom.EndConversation`.
- **KingdomHudController** gains `roots.backdrop` and the ScreenGui `KingdomBackdrop` (DisplayOrder 19, ScreenInsets None, ClipToDeviceSafeArea false).
- **`UI/PortraitView.useSource`** is a seam for specs and scenes.
- **Renderer** (`design/ui/render`): ViewportFrames are now drawn.

## Open issues and risks
- **FORGE-04, phone framing.** On a phone (750 × 311 logical) the question bubble spans the stage above the portrait and the answers. Measured from the renders, the stage's top is 47 % down the screen for four short answers and 29 % for Edda's three answers with costs. FORGE-06's longest lines would sit at about 30 %. Over-budget text can reach the HUD stack.
  - Your `focusOn` moves the focus 6 studs toward the camera. Please check in FL-0101 Studio row 6 that this keeps the citizen in the top ~25 % on phones (above the stage even with long text).
  - If it doesn't, a per-breakpoint offset on your side is enough.
  - If you'd rather read where the stage is, I can expose its top as a screen fraction. Ask.
- **FORGE-04, poses.** Reaction poses (FL-0100 part 2): the portrait model is `conversation.stage.portrait.model`, a `Kit.portrait` rig. `Kit.posePortrait(model, joints)` poses it.
- **FORGE-01, `hasRequest`.** Talk as the primary action is still waiting for `hasRequest` (#77 M2). The client is ready.
- **Lune can't read `ViewportFrame.CurrentCamera` back.** Specs use the view's own `camera` instead. Roblox reads it fine.

## Next actions for the receiver
1. FORGE-05: merge #108, #84, #85 and the FL-0099 PR together, then run U16 (and #84's rows 1–6) in Studio under FL-0101.
2. FORGE-04: confirm the phone framing (above), and wire part 2's poses to `stage.portrait.model` when ready.
3. FORGE-01: nothing new. EndConversation is called as your handoff asked.

## Files to read
- `games/game-001/src/client/Controllers/ConversationController.luau`: the G13.8 block in the header, `_appear`, `_leave` and `_end`.
- `games/game-001/src/client/UI/ConversationStage.luau`, `UI/StageModel.luau` (geometry) and `UI/PortraitView.luau`.
- `games/game-001/design/ui/REVIEW-stage.md`.
