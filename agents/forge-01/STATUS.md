# FORGE-01 status

_Maintained by the worker. Keep it short and current._

| Field | Value |
|---|---|
| Session branch | PR branches `forge/01-gameplay-<topic>` (one worktree each) |
| Open PR | #108 FL-0097 cinematic conversation server (G13.8) · #107 #77 lows (N3 request kept until answered, N2, N4, N5) · #104 FL-0080 follow-ups (upgrade credited to its upgrader) · #93 FL-0049 replication hygiene · #94 FL-0051 fair nodes · #97 Match.Ended for late joiners (FL-0106) · #100 ruler gather (on hold until VS-1 accepted) |
| Merged (2026-10-13) | #68 FL-0080 · #70 FL-0052 + D-041 bunks · #77 FL-0079 conversations · #89 FL-0081 slots + throne · #91 / #101 FL-0104 · #106 FL-0081 follow-ups |
| Current task | FL-0107 CitizenAnswered (built; waits for FORGE-05 to declare the event in Contracts/GameEvents) |
| Last verified check | `check.sh` OVERALL PASS on every open branch (game-001 1148–1152/0); mutation sets fully caught per PR |
| Blockers | FL-0107: the GameEvents row is FORGE-05's (custodian). Studio evidence needs user runs (gameplay.md K1–K12, STUDIO_PLAYTEST) |
| Needs from others | FORGE-05: GameEvents `CitizenAnswered` row + contract-spec line. FORGE-03: call `Kingdom.EndConversation` on panel close; `recruit_cap` text ("no free bunk"). FORGE-04: camera focus on Converse `position` |

## Hours to VS-1 (honest estimate)
About 3–5 working hours of FORGE-01 code, plus review/merge time: #39 replication follow-ups 2 h, review fixes on #68/#70/#77/FL-0081, then playtest fixes. Studio verification is the user's.

## What exists (headless-verified only; nothing run in Studio)
- `games/game-001/src/shared/{Kingdom,Sim,Match}` and `src/server/Services/{Match,Kingdom}Service.luau`:
  deterministic kingdom simulation (utility-AI citizens with per-activity state machines, compact memory,
  jobs/quotas, construction, military, objectives, optional diplomacy, AI governors), on the world Layout
  plots (G10.1).
- FL-0048: G2 types (v0.4-g3), MatchService with PacingService durations and the VS-1 slice mode,
  KingdomService (Teams, PartyId grouping, spawn after WorldService.ready with regalia and respawn,
  membership signal, Crown Points), remotes `Kingdom.State/GetState/Gather/SetJobQuota` and
  `Match.State/GetState/Ended`, G9 events exactly once.
- Snapshot codec v1 (G4 v1 layout) — to be replaced by v2 (D-025) in FL-0049.

## Next
1. Drive #68, #70, #77 and FL-0081 to merge (review fixes).
2. #39 follow-ups: LOD centre = overview camera, encode before commit + spawn cap, lazy codec asserts, clear tracks on clock snap.
3. #62 M-1: forest/quarry/gold vein in the keep-local frame (fairness spec).

## Last report
Done: #61 review fixes (merged); #68 on ContentQuery.fireAction (#67); #77 on fireDecision listeners and
CONTRACTS v0.4-g6 strike/cue entityIds; FL-0081 build slots, throne seating and three builder fixes in the sim.
Verified: check.sh PASS on each branch; mutations caught (#61 10/10, #68 9/9, #77 17/17, FL-0081 12/13 with
the miss on code now removed).
Unverified: everything in Studio (K1–K11).
