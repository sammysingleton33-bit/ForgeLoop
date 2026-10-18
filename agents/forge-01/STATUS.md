# FORGE-01 status

_Maintained by the worker. Keep it short and current._

| Field | Value |
|---|---|
| Session branch | PR branches `forge/01-gameplay-<topic>` (one worktree each) |
| Open PRs (mine) | #140 FL-0119 base editing, server (G13.9 v0.4-g9j) · #145 FL-0122 server hardening (D-050) · #125 FL-0082 consequences + D-050 (1) · #127 FL-0109 paged GetEntities + review follow-ups · #129 History text · #118 specs try nil · #94 fair nodes · #100 ruler gather (on hold) |
| Merged 2026-10-15 | #108 (g9f hold) · #131 FL-0112 farm cleanup · #132 FL-0113 PlaceSlot turn · #136 Buildings.wallGap |
| Current task | FL-0119 and FL-0122 in REVIEW (PRs #140, #145); next: FL-0110 (Converse/Choose presentation tags, after #96), `ConsequenceChanged` fire once FORGE-05 declares it, builder repair if FORGE-00 opens a task |
| Last verified check | `check.sh` OVERALL PASS per branch, game-001: #140 1390/0, #145 1356/0, #125 1453/0, #127 1388/0, #129 1414/0; mutation rows caught per PR (FL-0119 44/44, FL-0122 18/18, FL-0082 D-050 16/16). Headless only |
| Blockers | Studio evidence needs user runs (gameplay.md K1-K12, "Base editing", "Server hardening regression rows"). Gates: FORGE-05 / FORGE-07 on the open PRs |
| Needs from others | FORGE-03: UI for base editing (FL-0120), wording for `not_found`, `not_movable`, `alarm`, `under_attack`, `cooldown`, `not_your_node`. FORGE-04: edit input mode (FL-0121), riot placard on the `riot` client event, notices. FORGE-00: CONTRACTS text for the riot marker (a `strike` event with occupation `riot`) and the `ConsequenceChanged` G9 row; confirm the per-kingdom gather allowance. FORGE-05: declare `ConsequenceChanged` |

## Hours to VS-1 (honest estimate)
Code is waiting on gates and Studio, not on more code. Studio verification is the user's.

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
1. Drive #140, #145, #125, #127, #129 through FORGE-05's gate and FORGE-07's review; answer findings with validated pushes.
2. FL-0110 after #96 merges (reactionFor with pre-choice loyalty, traits in citizenState, pinned question variant, tag allowlist).
3. Fire `ConsequenceChanged` once declared; builder repair of fire damage if FORGE-00 opens the task.

## Last report
Done 2026-10-15: user pass "kingdom cleanup and building control": farm clearance (#131), plot rotation server (#132), wall chains (#136),
base editing server (#140, CONTRACTS g9j), FORGE-07 audit hardening (#145), #125/#127/#129 review answers.
Verified: see "Last verified check". Unverified: everything in Studio.
