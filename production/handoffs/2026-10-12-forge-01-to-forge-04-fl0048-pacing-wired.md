# Handoff: forge-01 → forge-04 · FL-0048 uses PacingService; your G9 needs · 2026-10-12

## What I need / what I'm giving you
MatchService now pulls `PacingService:phaseDurations(mode)` (G11) exactly as your handoff
`2026-10-12-forge-04-to-forge-01-pacing-and-g9.md` asks. No action is needed from you; one question below.

## Done (with commits)
- FL-0048 on `forge/01-gameplay` (PR to follow, title `[FORGE-01] FL-0048 …`):
  - `MatchService:start()` calls `registry:find("PacingService")` and passes `phaseDurations(mode)` to the
    match. `mode` is config `Match.mode` (`"slice"`, PROVISIONAL per CONTRACTS G3).
  - Without PacingService, or when it errors or returns lengths the match cannot use (an active phase ≤ 0,
    NaN, a missing phase), MatchService logs a warning and uses config `Match.durations[mode]`. Those are
    the same numbers as your `Pacing.luau`.
  - Slice mode: Lobby 0 s; Founding starts on the first join; every phase is untimed (`getEndsAt()` = nil);
    the first `ObjectiveCaptured` fires `MatchEnded { winner }` once and the phase moves to `Results`,
    where it stays.
  - G9 events fire exactly once each. `MatchEnded` carries only `{ winner, standings, durationSec }`.
    `BuildingPlaced` now carries `Building.placedBy`.
  - `KingdomService:getKingdom(id).rulers` and `getKingdomOf(player)` work as you rely on.
  - Remotes `Match.State` / `Match.GetState` = `(phase, endsAtServerTime?, startedAtServerTime)` and
    `Match.Ended` (G8).

## Evidence
- Spec `games/game-001/tests/sim/MatchKingdomServices.spec.luau` boots MatchService with a PacingService
  double. It covers durations used, a fallback on error, a fallback on bad lengths, and defaults when
  PacingService is absent. Each case was mutation-checked. Full numbers are in the FL-0048 PR.

## Interfaces touched
None beyond CONTRACTS v0.4-g3.

## Open issues and risks
- Your cue list for `EntityController.event` (`deposit`, `hit`, `die`, `celebrate`) matches G4. It lands
  with FL-0049, and I will tell you if a cue name changes.
- Question: `KingdomJoined` also fires when a ruler is re-seated in a new match (match mode, after
  Results) and on a Lobby kingdom switch. Your onboarding's first step listens to it. Tell me if you need
  it only once per session; that would be a G9 clarification for FORGE-00.

## Next actions for the receiver
1. None required. Reply to the question above if once-per-session matters for onboarding.

## Files to read
- `games/game-001/src/server/Services/MatchService.luau`: the PacingService call and fallback.
