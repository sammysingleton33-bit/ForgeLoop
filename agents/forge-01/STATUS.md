# FORGE-01 status

_Maintained by the worker. Keep it short and current._

| Field | Value |
|---|---|
| Session branch | `forge/01-gameplay` (PR branches `forge/01-gameplay-fl00xx`) |
| Open PR | #31 FL-0048 (REVIEW; main merged, gates PASS) · FL-0049 entity replication + client rigs (REVIEW, stacked on #31). Merged: #26 Types stub |
| Merged | #4 FL-0007, #5 FL-0009, #8 review follow-ups (Validate cframe/record/oneOf) |
| Current task | D-030 VS-1 v2: FL-0078 population (sub-worker on the pure generator) → FL-0080 reputation → FL-0079 conversations → FL-0081 plots + throne |
| Last verified check | `check.sh` OVERALL PASS on the FL-0049 head: framework 485/0, game-001 412/0, Selene 0/0 |
| Blockers | FL-0078/80/79 consume FORGE-00's content library (FL-0083, branch forge/00-content-library, not on main yet): built as pure modules on fixture tables until it lands. Studio evidence for FL-0048/FL-0049 needs a user run |
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
1. FL-0078: wire Sim/Population (sub-worker) into CitizenService (G5 getPopulation / setFedRatio / inspect → CitizenView) and the spawn record (look), on top of the content library once it merges.
2. FL-0080 ReputationService + Society.luau; FL-0079 ConversationService; FL-0081 build slots, upgrade times, throne seat.
3. FL-0050 to FL-0052 rows that VS-1 v2 still needs (fed ratio, Build/Army remotes, Send-to-capture).

## Last report
Done: FL-0049: SnapshotCodec v2, EventCodec, EntityService (diffed spawns/despawns/jobs, cues, reset,
10 Hz snapshots ≤ 900 B), EntityController with pooled Kit rigs and procedural poses (sub-worker),
16 Hz fixed tick with staggered decisions, Layout.nav routing, sim.spawn debug command.
Verified: check.sh PASS; mutations caught (EntityService 6/6, client 23/23, tick/staggering 2/2, Nav 1/1).
Unverified: everything in Studio (K1/K2/K7/K8, PERF.md).
