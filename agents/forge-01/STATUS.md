# FORGE-01 status

_Maintained by the worker. Keep it short and current._

| Field | Value |
|---|---|
| Session branch | `forge/01-gameplay`; PR branches `forge/01-gameplay-<topic>` |
| Open PR | #61 FL-0078 population (REVIEW) · #68 FL-0080 reputation (stacked on #61) · #70 FL-0052 army · this PR (#50 M1 destroyed broadcast, refusal codes, STATUS) |
| Merged | #4, #5, #8, #26, #31 FL-0048, #39 FL-0049, #46 living-kingdom groundwork, #50 FL-0051 Build remotes, #51 F1, #54 citizen height, #56 G13.5, #59 F2/F3, #62 placement rectangles |
| Current task | FL-0079 ConversationService (stacked on #68; event transport by a sub-worker), then FL-0081 plots + throne |
| Last verified check | `check.sh` OVERALL PASS on the branches above (game-001 806–864/0); mutations caught per PR |
| Blockers | none. Studio evidence for everything needs user runs (gameplay.md K1–K9) |
| Needs from others | FORGE-00: G8 wording for `SetJobQuota → (boolean, code?)` and Army attack `targetId`; ContentQuery `fireAction` / decayed decision loyalty (using the interim path meanwhile). FORGE-03: refusal codes (handoff 2026-10-13-forge-01-to-forge-03-refusal-codes) |

## Hours to VS-1 (honest estimate)
About 10–14 working hours of FORGE-01 code, plus review/merge time: FL-0079 conversations 4–5 h (in progress), FL-0081 slots/upgrade times/throne seat 3–4 h, #39 replication follow-ups 2 h, then playtest fixes. Studio verification is the user's.

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
1. FL-0079 ConversationService: Converse/Choose, thought bubbles, decision effects and consequences (G13.3).
2. FL-0081: Build.PlaceSlot / Build.Slots on Build/Fit, upgrade times from Costs, ruler seated on the keep Throne.
3. #39 follow-ups: LOD centre = overview camera, encode before commit + spawn cap, lazy codec asserts, clear tracks on clock snap.

## Last report
Done: FL-0078 generated population (#61), FL-0080 ReputationService (#68), FL-0052 army (#70), placement
rectangles and node clearance (#62, merged), F2/F3 (#59, merged), G13.5 (#56, merged), citizen height (#54, merged).
Verified: check.sh PASS on each branch; mutation checks caught (FL-0078 16/16, FL-0080 19/19, FL-0052 14/14).
Unverified: everything in Studio.
