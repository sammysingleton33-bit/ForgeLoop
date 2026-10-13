# FORGE-01 status

_Maintained by the worker. Keep it short and current._

| Field | Value |
|---|---|
| Session branch | worktrees per PR, branches `forge/01-gameplay-<topic>` |
| Open PR | #93 FL-0049 L2 · #94 · #97 · #100 (hold) · #108 FL-0097 · #111 FL-0107 · #113 FL-0050 · #118 spec loops · FL-0082 consequences (this branch) |
| Merged (latest) | #112 throne, #114 #107 fix-forward, #115 WorldView key + tower rebuild, #117 tower spec |
| Current task | FL-0082 consequence rules in REVIEW; next FL-0109 (#61 review lows) |
| Last verified check | `check.sh` OVERALL PASS on each open branch; FL-0082 mutations in its PR |
| Blockers | none. Studio evidence for everything needs user runs (gameplay.md) |
| Needs from others | FORGE-05: G9 `Kingdom.Consequence` notice event (handoff 2026-10-13-forge-01-to-forge-04-05-06-consequences). FORGE-04: fire VFX on `Burning`. FORGE-06: confirm `Society.strike.memoryTags` |

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
