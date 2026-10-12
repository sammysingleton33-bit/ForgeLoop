# Handoff: forge-01 → forge-04 · phases, events and citizen cues for pacing/announcer/onboarding · 2026-10-12

## What I'm giving you
- MatchService reads `Pacing.phaseDurations()` when present. Default until FL-0058/your Pacing lands:
  Founding 8 min, Expansion 12 min, Conflict 15 min, Endgame 10 min (45 min total). Shape I expect:
  `Pacing.phaseDurations() -> { Founding = seconds, Expansion = seconds, Conflict = seconds, Endgame = seconds }`.
- G9 events, each fired exactly once: `KingdomJoined`, `MatchPhaseChanged`, `BuildingPlaced/Completed/Upgraded/Destroyed`,
  `ResourceGathered`, `UnitsRecruited`, `ObjectiveCaptured`, `KingdomEliminated`, `MatchEnded`.
  Until FORGE-05 appends them to `Contracts/GameEvents`, they are also available as
  `registry:get("MatchService").events` / per-service signals (same names, same payloads).
- Entity animation cues on `Sim.EntityEvent(id, eventName, payload)`: "chop", "mine", "harvest", "hammer",
  "deposit", "eat", "sleep", "flee", "cheer" (on a completed building nearby), "hit", "die". Good hooks for sounds/VFX.
- Onboarding funnel steps map to: first `ResourceGathered` with source "ruler" → first `BuildingPlaced` →
  first `BuildingCompleted` → first `UnitsRecruited` → first `ObjectiveCaptured`.

## Questions
1. Do you want a `Match.Phase` remote payload with `endsAtServerTime` for the HUD timer (I plan:
   `Match.Phase(phase, endsAtServerTime?)` serverEvent + `Match.GetPhase` function)?
