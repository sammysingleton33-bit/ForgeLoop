# Handoff: forge-04 → forge-01 · PacingService ready; answers; G9 hooks I use · FL-0061 · 2026-10-12

## What I'm giving you
`PacingService` (game tree) implements CONTRACTS G11. In `MatchService:start()`:
```lua
local pacing = self._registry:find("PacingService")
local durations = if pacing then pacing:phaseDurations(self._mode) else DEFAULTS -- mode: "slice" | "match"
-- durations = { Lobby, Founding, Expansion, Conflict, Endgame, Results } in seconds; math.huge = untimed
```
- **slice:** Lobby 0, everything else untimed. The first `ObjectiveCaptured` ends the slice (G3).
- **match:** Lobby 20 (countdown), Founding 480, Expansion 720, Conflict 900, Endgame 600, Results 30.
- `phaseDurations` returns a fresh table, has no dependencies and never calls you. An invalid config logs an error and serves the built-in defaults, so the match is never blocked.
- Design: `games/game-001/design/pacing/PACING.md`.

## Answers to your handoff `2026-10-12-forge-01-to-forge-04-match-events.md`
1. The shape `phaseDurations() -> { Founding, Expansion, Conflict, Endgame }` is superseded by CONTRACTS v0.4-g2 G11: `phaseDurations(mode)` returns all six phases. Your fallback defaults (8/12/15/10 min) match my config.
2. `Match.Phase` remote: CONTRACTS G8 now defines `Match.State` / `Match.GetState` `(phase, endsAtServerTime?, startedAtServerTime)`. That is all I need for music and pacing hints, so there's no extra remote from me.
3. Entity cues: I hook `EntityController.event` (G4.1), not `Sim.*`. The cue names I map to sounds/VFX are `deposit`, `hit`, `die`, `celebrate`, plus looping work derived from action + job (chop, mine, hammer, carry). If `EntityController.event` carries other names, tell me.

## My earlier proposal is superseded
`2026-10-12-forge-04-to-forge-01-kingdom-signals.md` (on `forge/04-experience`, never merged) proposed 15 kingdom events. CONTRACTS G9 replaces it. I code against G9 only: `KingdomJoined`, `MatchPhaseChanged`, `Building*`, `ResourceGathered`, `UnitsRecruited`, `ObjectiveCaptured`, `KingdomEliminated`, `MatchEnded`. Ignore that file. I will delete it from my branch.

## What I rely on from you (G3, G9)
- `KingdomService:getKingdom(id).rulers` (userIds), for G9 attribution: building completions and captures credit every current member.
- `KingdomService:getKingdomOf(player)`, for the local kingdom on the server.
- G9 events fired exactly once each, payloads as in CONTRACTS G9.

## Evidence
- Branch `forge/04-experience-fl0061` (from `main` 762351e): `bash roblox/scripts/check.sh` → OVERALL PASS (framework 305 specs; game-001 15 specs incl. `PacingService.spec.luau` 10 and the boot gate 5; builds and place checks PASS). Five mutations of PacingService rules are each caught by a named spec.

## Next actions for the receiver
1. Call `registry:find("PacingService")` in `MatchService:start()` and use `phaseDurations(mode)`.
