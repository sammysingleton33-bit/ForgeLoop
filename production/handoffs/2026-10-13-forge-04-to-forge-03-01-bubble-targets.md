# Handoff: forge-04 → forge-03, forge-01 · FL-0091 follow-up: strike/cue targets, conversation hiding · 2026-10-13

## What I need / what I'm giving you
CitizenBubbleController now follows CONTRACTS G13.3 v0.4-g6: it marks only the citizens the server names and never fans out by occupation. It also hides a citizen's bubble while their conversation is open. FORGE-03 owns two pieces: cues with no citizen (the HUD or the keep), and the G13.8 `opened`/`closed` signals.

## Done (with commits)
- Branch `forge/04-experience-fl0091b` (the FL-0091 follow-up PR; #42 is merged).
  - **Targets.** `EntityController.event(id, "strike" | <cue>, …)` marks `id` only. That is #77's shape: one event per id from `entityIds`.
    - A payload that still carries `entityIds` (the raw Sim.Events shape) marks its `entityId` and each listed id, once each.
    - An event with neither an id nor `entityIds` (for example `(nil, "hammer", { occupation })`) shows on no citizen. It is counted in `stats.untargeted`.
    - A strike belongs to the citizen. A job change (a rig swap) keeps the placard, and only the server's "off" or a despawn clears it (FORGE-05 #87 M1).
    - Ids are whole numbers ≥ 1, taken from the list part of `entityIds`. The bubbles refresh once per event.
  - **Cue effects.** A continuous cue effect (`rest` → `ambience.motes`) is kept per citizen. It stops in three cases:
    - after the cue's `seconds` (config `Vfx.cues.rest.seconds = 6`);
    - when that citizen's next cue plays an effect;
    - when the rig is released.

    So a pooled rig never keeps an emitter (FORGE-05 #42 M1).
  - **Conversation.** The citizen's bubble hides between `ConversationController.opened(entityId, position)` and `.closed(entityId)` (G13.8). Until those signals exist, it hides while `ConversationController.state.entityId` names the citizen, which is what main has today.
  - **Lows from FORGE-05's #42 review:**
    - Walk mode measures from the camera, because `getFocus()` would be the stale overview focus. The focus is used only while `mode == "overview"`.
    - Dropped bubbles go back to the pool before new ones are drawn, so there are never more than 8 GUIs.
    - Warnings about unknown cue names are capped at 8 names, plus one "no longer logged" line.
  - **Framework `VFXController.float` / `:bubble`** take `opts.maxDistance`. The default is still 150; 0 means no limit. game-001's FeedbackController (#49) will pass 0, because it culls from the overview's focus.

## Evidence
- `lune run roblox/tests/harness/run.luau --project games/game-001/default.project.json --specs games/game-001/tests CitizenBubbles` → 29 passed, 0 failed.
- `lune run roblox/tests/harness/run.luau Vfx` → passes, including the new text-distance case.
- `python3 roblox/tests/unit/experience/mutations.py FL-0091` → 40/40 caught (15 new rows).
- `bash roblox/scripts/check.sh` → OVERALL PASS (see the PR for numbers).
- **Unverified (Studio, user):** `roblox/studio-tests/experience.md` E8 steps 3, 7 and 8. Nothing renders until FL-0079 (#77) ships the G13.3 events.

## Interfaces touched
- Additive:
  - config `Vfx.cues[*].seconds`;
  - `VFXController:float(text, position?, opts?)` and `:bubble(adornee, text, seconds, opts?)` take `opts.maxDistance`;
  - `CitizenBubbleController.stats.untargeted`.
- No contract change. It follows v0.4-g6 as written.

## Open issues and risks
- `ConversationController` on main has no `opened`/`closed` signals yet, so the hiding relies on `state.entityId`. If `state` ever outlives the panel, the bubble stays hidden until the next conversation; the signals remove that risk.
- #77 sends `kcue` payloads without a `tone`, so an unknown cue's pose falls back to the citizen's current reaction tone, or none. That is fine for VS-1.

## Next actions for the receiver
1. **FORGE-03:** when you add G13.8's `ConversationController.opened` / `.closed`, use framework Signals (`:connect`). CitizenBubbleController and RulerCameraController (#84) both connect to them if they are present, and need nothing else.
2. **FORGE-03 (optional):** an occupation- or kingdom-wide cue with no ids arrives as `EntityController.event(nil, <cue>, { occupation? }, nil)`. CONTRACTS G13.3 puts it on the HUD or the keep. Nothing from FORGE-04 shows it.
3. **FORGE-01:** nothing to change. #77's per-id fan-out of `strike` and `kcue` is what this expects. I checked it against `EntityController.luau` on `forge/01-gameplay-fl0079` (`bf883dc`).

## Files to read
- `games/game-001/src/client/Controllers/CitizenBubbleController.luau` — the header covers targets, cue effects and the conversation rule.
- `games/game-001/config/Vfx.luau` — `cues[*].seconds`.
- `roblox/studio-tests/experience.md` E8 — steps 3, 7 and 8.
