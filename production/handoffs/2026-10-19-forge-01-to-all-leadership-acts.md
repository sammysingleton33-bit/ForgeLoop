# Handoff: FORGE-01 → FORGE-05 (cc FORGE-00, FORGE-03, FORGE-07) · FL-0069 slice 2: acts from simulation state · 2026-10-19

Stacked on #216 (leadership ledger).

## What I'm giving you
`LeadershipService` now records three conduct acts by itself from the simulation, at each 30 s sample, so the support meter moves before any producer service exists.

## Done
- `starvation`: fed ratio below `Support.rules.starvation.below` (0.5) for more than `seconds` (60), once per episode (an episode runs from its first sample under the bar and ends when the fed ratio is back at the bar).
- `fedRatioKept`: the fed ratio never under `fedKept.atLeast` (0.9) through a whole Expansion, Conflict or Endgame, recorded when the phase changes (phase edges are seen at sample resolution, 30 s).
- `overConscription`: soldiers above `conscription.soldierShareAbove` (35 %) of soldiers + citizens for more than 60 s, once per episode.
- Each is recorded for every ruler seated in the kingdom, or for the "no ruler" series when an AI holds it, through the same `record` (so the valour cap, the moment text and the `acted` signal apply).
- Thresholds are PROVISIONAL config `Support.rules`.
- Specs `sim/LeadershipService` (27, on a shortened clock: 5 s samples, 12 s waits; the logic reads only the config); mutation rows `FL-0069.py` (55, all caught; FORGE-07 ran them at bdd57959, I re-ran each re-anchored row).

## Not yet
Producers that need other services: raids defended or abandoned, valour in combat, objectives captured in person, rebuilds, overwork quotas, houses before barracks. Citizen loyalty from memory events, key citizens, petitions.

## Evidence
`bash roblox/scripts/check.sh` OVERALL PASS (selene 0/0/0, game-001 specs 1906 passed, 0 failed); `forge.py validate` 136 tasks 0 errors; `check_ownership.py --base origin/forge/01-arena-leadership --owner forge-01` PASS (4 files). Headless only; no Studio.

## Files to read
- `games/game-001/src/server/Services/LeadershipService.luau` (header), `games/game-001/config/Support.luau` (`rules`)

## Review fixes (FORGE-07, #222)
- **The last phase is credited.** `LeadershipService:closeOut()` takes one more sample and credits `fedRatioKept` for the phase the match is in when its streak qualifies (Endgame never changes while the arena runs, so the phase-change path never fires for it). **ArenaService must call `closeOut()` when the arena begins** (done in the ArenaService PR). Credited once per phase.
- **Acts go to who earned them.** `starvation`, `overConscription` and `fedRatioKept` are recorded only for rulers seated when the streak began (first low sample, first armed sample, first sample of the phase). A ruler who joins later gets nothing from it; a ruler who leaves and returns starts again. The "no ruler" series (AI-held kingdom) takes every act as before.
