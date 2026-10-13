---
id: FL-0049
title: Entity simulation core, snapshot codec, replication and client rendering
track: build
owner: forge-01
status: REVIEW
priority: P0
game: game-001
created: 2026-10-12
updated: 2026-10-12
depends_on: [FL-0046, FL-0055, FL-0056]
context: [games/game-001/BRIEF.md, games/game-001/CONTRACTS.md]
estimate_h: 9
evidence:
  - "check.sh OVERALL PASS: framework 485/0, game-001 412/0 (38 files), Selene 0/0, builds + place checks PASS"
  - "mutations caught: EntityService 6/6, client 23/23, tick + staggering 2/2, Nav for units 1/1"
  - "codec spec: every packet <= 900 B at 50 and 300 entities; EntityService spec: <= 900 B with 300 live entities"
---

# Entity simulation core, snapshot codec, replication and client rendering

## Outcome
Server-simulated entities appear and move smoothly on every client at scale (D-023, CONTRACTS G4).

## Requirements
- EntityService spawn, get and despawn.
- A fixed-tick scheduler: decisions at ~10 Hz, staggered round-robin across frames; movement at ~20 Hz.
- Navigation over the `Layout.nav` graph (pure data, G10.1; no tags, no PathfindingService) with simple steering.
- SnapshotCodec v2 (G4):
  - 8 B header (serverTime, seq, chunk, n) and 10 B records;
  - at most 80 records per event; the codec asserts raw size ≤ 900 B;
  - 10 Hz with ≈200 ms interpolation; idle and working entities refreshed round-robin about every 1 s;
  - VS-1 broadcasts every entity. Interest tiers are VS-2.
- Reliable traffic:
  - `Sim.Events`, batched per player per tick: spawn, despawn, jobChanged and the cues `deposit`, `hit`, `die`, `celebrate`. No per-swing events.
  - `Sim.GetEntities` for initial state.
- Client EntityController:
  - drops stale seq, ignores unknown ids, keeps a despawned-id set;
  - pooled rigs from `Kit.character` under a client-created Workspace folder, moved with `BulkMoveTo`;
  - procedural animation through `Motor6D.Transform` by action and job, with a pure pose module;
  - custom LOD beyond 150 studs;
  - the G4.1 API: `rendered`, `released`, `event`, `pick`, `getModel`.
- Instrumentation: sim ms per Heartbeat (p99), including encoding, and bytes/s per player.

## Validation
- Lune specs:
  - codec round-trip and quantisation bounds; every packet ≤ 900 B with 50 and with 300 entities;
  - seq wrap and stale-packet drop; a late snapshot after despawn; an unknown id. Out-of-order snapshots use the MockRemotes reorder helper (FL-0046);
  - tick determinism and staggering; navigation; pose maths.
- Studio: 50 test entities (spawned with the debug command) walk smoothly. Run once with Network Simulator latency and loss. Record sim ms and bytes/s.

## Completion criteria
- [ ] Studio numbers in `games/game-001/tests/sim/PERF.md`, labelled "Studio, indicative" (BRIEF §14); Studio evidence (user playtest per games/game-001/STUDIO_PLAYTEST.md, BuildInfo sha + screenshots) before ACCEPTED

## Log
- 2026-10-12 forge-00: created for AI Kingdoms VS-1 (READY).
- 2026-10-12 forge-00: plan review fixes (CONTRACTS v0.4-g2, D-024 to D-028): snapshot v2 (≤900 B chunks, seq/time), batched events, GetEntities, procedural animation, G4.1 API; interest tiers moved to VS-2
- 2026-10-12 forge-01: READY → BUILDING. codec v2, EventCodec, EntityService, EntityController (sub-worker), 16 Hz tick, staggered decisions, Layout.nav routing
- 2026-10-12 forge-01: BUILDING → REVIEW. In PR [FORGE-01] FL-0049 (stacked on #31). Studio K8 and the perf capture (PERF.md) are pending a user run.
