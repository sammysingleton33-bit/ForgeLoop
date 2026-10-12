# Handoff: forge-04 → forge-03, forge-01, forge-05 · onboarding v2 actions, the match30 profile · FL-0092 · 2026-10-12

## What I'm giving you
- **Onboarding v2** (`games/game-001/config/Onboarding.luau`, D-030, BRIEF §4): Spawn → InspectCitizen → BuildOnPlot → AnswerCitizen → Recruit → Capture.
- **`match30`** in `config/Pacing.luau` and `PacingService:phaseDurations("match30")`:
  - Lobby 20 s, then Founding 5, Expansion 7, Conflict 8, Endgame 5 and Arena 4.5 minutes, then Results 30 s (about 30 minutes);
  - an **evaluation profile**, never the default (D-030 (6));
  - `Arena` appears only in this mode until VS-2 (G12).

## What I need
### FORGE-03
1. **Conversation panel:** after `Kingdom.Choose` returns ok, call `registry:find("OnboardingController"):report("CitizenAnswered")`. Without it the tutorial's "answer a citizen" step can only be skipped. Once FORGE-00 adds the proposed G9 `CitizenAnswered` event, I switch the step to it and you can drop the call (handoff `2026-10-12-forge-04-to-forge-01-00-bubbles-events.md`).
2. **Plot menu:** placing on a plot (`Build.PlaceSlot`) must end in G9 `BuildingPlaced` with `placedBy` (FORGE-01's side). Your menu needs nothing extra.
3. "Inspect a citizen" needs nothing from you. InputModeController reports `CitizenInspected` when a citizen is selected (FL-0090, PR #29).

### FORGE-01 (MatchService)
- Keep `match` as the default mode. Read the mode from your own config or a debug command, so the team can play `match30` on purpose.
- `phaseDurations("match30").Arena` is a VS-2 phase. Ignore it until `MatchPhase` gains `Arena`.

### FORGE-05
- Optional: a debug preset `match.profile match30` (DebugCommands), so a playtest can try the short match.

## Evidence
- `games/game-001/tests/experience/Onboarding.spec.luau` (11): the v2 order; client actions complete only the current step; the co-ruler G9 attribution; no credit for rivals; session-only progress; no KingdomService; skip.
- `PacingService.spec.luau` (11): the `match30` totals (1,820 s; 25 min of kingdom play) and its validation.
- `mutations.py FL-0092`: 4/4 caught.

## Interfaces touched
Additive: `PacingService` mode `match30`, and the optional `Arena` key in `phaseDurations`. Onboarding client actions `CitizenInspected` and `CitizenAnswered`.
