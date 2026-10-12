---
id: FL-0049
title: Entity simulation core, snapshot codec, replication and client rendering
track: build
owner: forge-01
status: READY
priority: P0
game: game-001
created: 2026-10-12
updated: 2026-10-12
depends_on: [FL-0046]
context: [games/game-001/BRIEF.md, games/game-001/CONTRACTS.md]
estimate_h: 8
evidence: []
---

# Entity simulation core, snapshot codec, replication and client rendering

## Outcome
Server-simulated entities appear and move smoothly on every client at scale (D-023, CONTRACTS G4).

## Requirements
- EntityService spawn/get/despawn; fixed-tick scheduler (decisions ~10 Hz, movement ~20 Hz); navigation over a graph from WorldService tags with simple steering
- SnapshotCodec (buffer) round-trip; interest management per player; reliable spawn/despawn/event remotes
- Client EntityController: pooled rigs from Kit.character, ~100 ms interpolation, animation by action, rendered signal
- Performance instrumentation: sim ms/frame and bytes/s logged

## Validation
Lune specs: codec round-trip and bounds, tick determinism, interest filtering, navigation; Studio: 50 test entities walking smoothly with sim ms/frame and bytes/s recorded

## Completion criteria
- [ ] Studio perf numbers in games/game-001/tests/sim/PERF.md; Studio evidence (user playtest per games/game-001/STUDIO_PLAYTEST.md, BuildInfo sha + screenshots) before ACCEPTED

## Log
- 2026-10-12 forge-00: created for AI Kingdoms VS-1 (READY).
