---
id: FL-0125
title: "Full four-kingdom match by default: match mode, PvP from Conflict, active AI governors, elimination and spectate (D-053 (1)-(3))"
track: build
owner: forge-01
status: BUILDING
priority: P0
game: game-001
created: 2026-10-18
updated: 2026-10-18
depends_on: [FL-0048, FL-0052, FL-0082]
evidence: []
---

# Full four-kingdom match by default: match mode, PvP from Conflict, active AI governors, elimination and spectate (D-053 (1)-(3))

## Outcome
A new server runs the real 30-45 minute match, not the VS-1 slice: timed phases from Pacing, AI governors rule every kingdom without a human from the first second, kingdoms go to war from Conflict on, a kingdom whose keep falls is eliminated and its rulers spectate, and the match always reaches an end: early conquest, or the Crown Arena hand-off (FL-0071), with a Crown Points fallback until the arena lands.

## Context
- Owner directive 2026-10-18 (Operation Crownfall) and D-053. The sim already has timed phases, RulerAI (war, peace, objectives, recruiting), Military (combat, siege x4, walls block armies) and Diplomacy; the build ships `Match.mode = "slice"` with PvP off and AI kingdoms idle, so none of it is playable.
- Interfaces: CONTRACTS G3 (phases), G8 Army/Match remotes, G9 KingdomEliminated / MatchEnded, G11 Pacing. Breaking contract changes need FORGE-00; additive ones are fine.

## Requirements
- `config/Match.luau`: `mode = "match"`, `pvp.enabled = true` (war allowed from Conflict, peace by mutual consent, no betrayal). Keep `slice` reachable through a Studio debug command (`match.mode slice`) so the VS-1 checklists still run (D-053 (7)).
- AI governors (`config/Governor.luau`) rule empty kingdoms from match start in match mode (they stay idle only in slice). Starting citizens exist for all four kingdoms at Founding, not only when a human joins.
- Elimination: a kingdom whose keep is destroyed is eliminated (G9 `KingdomEliminated`); its units and citizens leave the sim cleanly; its human rulers get a `Match.Spectate` state (additive G8 row) and stay in the server. Last kingdom standing ends the match early.
- End of Endgame: until FL-0071 lands, most Crown Points wins (existing PROVISIONAL rule). Expose `MatchService` hooks the ArenaService will use (`beginArena(qualifiers)` / `arenaEnded(winner)`), so the arena slots in without reworking MatchService.
- Mid-match join: auto-assign to the standing kingdom with the fewest human rulers; a human joining a governor kingdom takes over (the AI steps back, already built).
- Headless proof: a full-match spec (`tests/sim/FullMatch.spec.luau`) that runs four AI kingdoms through every phase with the injected clock at the real durations and asserts: wars happen in Conflict, at least one battle, the match ends, no errors, the server tick stays inside the BRIEF §14 budget at peak entities (record the measured ms and entity count in the PR).

## Validation
Automated: the full-match spec, specs for elimination and spectate, mid-match join. Studio: FORGE-05's B20 rows (start a match, watch an AI war in Conflict, see an elimination, reach Results).

## Completion criteria
- [ ] PR merged after review (FORGE-05 gate, FORGE-07 review).
- [ ] Studio evidence (owner's local Studio session).

## Log
- 2026-10-18 FORGE-00: created for Operation Crownfall (owner directive 2026-10-18, D-053).
- 2026-10-18 forge-01: READY → BUILDING. Operation Crownfall mission 1 started on forge/01-gameplay-full-match (main 41422654); reading Match/Pacing/Governor/MatchService first
