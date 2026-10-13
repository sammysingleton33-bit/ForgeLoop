# Handoff: forge-04 → forge-01, forge-05 · the VS-1 feedback layer: what it hooks, one proposed cue · FL-0062 · 2026-10-12

## What I'm giving you
FL-0062 adds the game-001 feedback layer:
- server: `AnnouncerService`, which sends G9 → moments over the new remote area `Feedback` (`Feedback.Moment`);
- client: `AnnouncerController`, `FeedbackController` and `MusicController`;
- shared data in `src/shared/Feedback/`: `Moments`, `Lines`, `Presets`, `Remotes`.

It hooks only G9 events (server) and the G4.1 client signals. It never touches `Sim.*`.

Studio debug commands (F8): `fx.announce <kind>` and `fx.burst`.

## What I need
### FORGE-01
1. **G9 producers** as in CONTRACTS G9. Two details matter:
   - `BuildingPlaced` carries `placedBy`. The co-rulers' toast names the placer; the placer gets no announcer toast, because FORGE-03's build notice already covers it;
   - `Building.cframe` is set (the effect plays at the building).
2. **`KingdomService:getKingdom(id).name`** (G2 `Kingdom.name`): the announcer uses it ("Frostmere took a watchtower"). Until it exists, it falls back to the id, title-cased.
3. **`InteractionController.gathered(nodeId, resource, amount)`** (G4.1): the ruler's gather gets a sound, chips at `Layout.resourceNodes[nodeId]` and "+N Wood".
4. **`EntityController.event` cues:**
   - `deposit` and `celebrate` (G4) already have feedback;
   - **proposed, client-only:** `event(id, "swing", { job }, model)` once per work-animation cycle of a woodcutter, miner, farmer or builder. G4 has no per-swing network events, so the animator would raise this locally, with no remote traffic. With it, citizens' work becomes audible near the camera (at most one sound per citizen per 1.5 s, within 150 studs). Without it, citizens' work stays silent.
5. **`EntityController.released`** fires before a rig returns to the pool (G4.1). FeedbackController stops every effect it attached to that rig.
6. **`Match.State`** (G8) carries the phase. MusicController follows it, and AnnouncerService's phase moments as well. At start it also calls `Match.GetState` once (through `RemoteLink.request`), because the Match.State sent to an arriving player can come before the controller listens.
7. **`MatchEnded`.** Each player's moment carries `outcome`: `won`, `lost`, `draw` (no winner) or `watched` (a spectator). Only won and lost get Victory or Defeat.

### FORGE-05
- `STUDIO_PLAYTEST.md` rows 4 and 7 can point at `roblox/studio-tests/experience.md` E5 for the feedback checks. The `fx.*` commands follow your debug panel's naming.

## Evidence
- `games/game-001/tests/experience/KingdomFeedback.spec.luau` (26 specs):
  - moment audiences and payloads (primitives and Vector3 only);
  - Lines resolve to registered sounds and effects;
  - the presets fit the budget;
  - AnnouncerService over Feedback.Moment, with and without KingdomService, and the debug commands;
  - the controllers: celebrations and toasts, the gather, deposits and swings, release clean-up, music.
  - FORGE-05's #49 follow-ups: one toast per placement, match outcomes, no fallback toast for a declined celebration, kingdom colours, distance from the camera focus, a bounded attached-effects list, `Match.GetState` for late joiners.
- `mutations.py FL-0062`: 21/21 caught.

## Interfaces touched
Additive: the remote area `Feedback` (FORGE-04's, CONTRACTS v0.4-g2) with `Feedback.Moment`. The `swing` cue is a proposal.
