# FORGE-01 status

_Maintained by the worker. Keep it short and current._

| Field | Value |
|---|---|
| Session branch | `forge/01-gameplay` (PR branches `forge/01-gameplay-fl00xx`) |
| Open PR | #26 FL-0048 hour-0 Types stub (CI green) · FL-0048 Match + Kingdom core (REVIEW, branch `forge/01-gameplay-fl0048`) |
| Merged | #4 FL-0007, #5 FL-0009, #8 review follow-ups (Validate cframe/record/oneOf) |
| Current task | FL-0048 in review → next FL-0049 entity sim, codec v2, replication, client rendering |
| Last verified check | `check.sh` OVERALL PASS on the FL-0048 head: framework 328/0, game-001 305/0, Selene 0/0; 18/18 mutations caught |
| Blockers | None for FL-0049. Studio evidence for FL-0048 needs a user run (K1/K2/K7 in `roblox/studio-tests/gameplay.md`) |
| Needs from others | FORGE-02: WorldService `ready` shape + regalia attachments (handoff 2026-10-12-forge-01-to-forge-02-05-fl0048-spawn). FORGE-04: KingdomJoined once-per-session? (handoff …-fl0048-pacing-wired) |

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
1. FL-0049: codec v2 (8 B header, 10 B records, ≤ 80 per event, ≤ 900 B), `Sim.Snapshot/Events/GetEntities`,
   EntityService, EntityController (Kit.character rigs, procedural Motor6D poses, BulkMoveTo), perf log line.
2. FL-0050 → FL-0052 per PROMPT §0 (citizens on Layout nodes and fed ratio, Build/Army remotes, Send-to-capture).
3. Crown Arena (FL-0069+) only after FL-0052.

## Last report
Done: FL-0048 (re-scoped to CONTRACTS v0.4-g3) incl. debug commands match.phase / kingdom.respawn /
preset vs1.row3 and a spec on FORGE-03's real TreasuryService; #26 Types stub; handoffs to FORGE-04, FORGE-02/05.
Verified: check.sh PASS, 18/18 mutations caught. Unverified: everything in Studio.
Interim: citizens still pay their own meals from the treasury until FL-0050 adds CitizenService + fed ratio
(ProductionService charges nothing while CitizenService is absent, so nothing is charged twice).
