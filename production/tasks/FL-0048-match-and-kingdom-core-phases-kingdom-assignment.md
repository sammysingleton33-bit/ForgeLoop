---
id: FL-0048
title: "Match and Kingdom core: phases, kingdom assignment, teams, crown points"
track: build
owner: forge-01
status: REVIEW
priority: P0
game: game-001
created: 2026-10-12
updated: 2026-10-12
depends_on: [FL-0046, FL-0055, FL-0056]
context: [games/game-001/BRIEF.md, games/game-001/CONTRACTS.md]
estimate_h: 6
evidence:
  - "check.sh OVERALL PASS: framework 328/0, game-001 305/0 (23 files), Selene 0/0, StyLua 170, builds + place checks PASS"
  - 18 mutations of the FL-0048 rules each caught by a named spec (MatchKingdomServices, Match, FirstPlayable)
---

# Match and Kingdom core: phases, kingdom assignment, teams, crown points

## Outcome
A server always knows the match phase and which kingdom every player belongs to (CONTRACTS G2, G3, G9).

## Requirements
- Hour 0: `src/shared/Kingdom/Types.luau`, exactly per G2, as a stub PR. FORGE-05 merges it right after FL-0046.
- MatchService (G3, G11):
  - takes phase durations from `PacingService:phaseDurations(mode)` via `registry:find` in `start()`, with built-in defaults when PacingService is absent;
  - VS-1 slice mode: Lobby 0 s, Founding on the first join and untimed, and the first `ObjectiveCaptured` → `MatchEnded { winner }` → Results. These rules are interim, pending the user's §16.3 and §16.4.
- KingdomService:
  - creates four Teams with `AutoAssignable = false` and fixed, distinct named TeamColors from `Kingdoms.luau`;
  - `assign` groups players by `Player.PartyId`, then balances, and sets `Player.Team`;
  - crown points and the membership signal.
- Spawn (`CharacterAutoLoads` is false, D-026): after `WorldService.ready` and `assign`, call `LoadCharacterAsync`, pivot to `Layout.plots[k].spawn`, and attach `Kit.regalia(color)`. Do the same on every respawn.
- Remotes `Kingdom.State` / `Kingdom.GetState` and `Match.State` / `Match.GetState` / `Match.Ended` (G8).
- Fires KingdomJoined, MatchPhaseChanged and MatchEnded.

## Validation
- Lune specs:
  - assignment balance with 1..16 players, party grouping by PartyId, leave and rejoin;
  - Teams are created with AutoAssignable false and distinct TeamColors;
  - spawn waits for `WorldService.ready`;
  - phase timing and slice end with an injected clock;
  - defaults without PacingService.
- Studio: 2 players in one simulated party share a kingdom and spawn at its keep wearing regalia.

## Completion criteria
- [ ] Specs pass; Studio evidence (user playtest per games/game-001/STUDIO_PLAYTEST.md, BuildInfo sha + screenshots) before ACCEPTED

## Log
- 2026-10-12 forge-00: created for AI Kingdoms VS-1 (READY).
- 2026-10-12 forge-00: plan review fixes (CONTRACTS v0.4-g2, D-024 to D-028): Teams AutoAssignable=false, PartyId grouping, spawn after WorldService.ready, regalia, Pacing pull, slice mode, Kingdom/Match remotes
- 2026-10-12 forge-01: READY → BUILDING. sim moved to games/game-001; re-scoped to CONTRACTS v0.4-g3
- 2026-10-12 forge-01: BUILDING → REVIEW. Match + Kingdom core per CONTRACTS v0.4-g3 in PR [FORGE-01] FL-0048; hour-0 Types stub in PR #26. Studio evidence (K1/K2/K7 in roblox/studio-tests/gameplay.md) pending a user run.
