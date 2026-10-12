# game-001 performance numbers (FL-0049, gate G7)

Studio numbers only, labelled **"Studio, indicative"** (BRIEF §14). Headless Lune timings are not performance
evidence. Procedure: `roblox/studio-tests/gameplay.md` → "Performance capture".

| Date | BuildInfo sha | Setup | Entities | simMsP99 (per 1/16 s tick) | encodeMsP99 | bytes/s per player (`Kingdom perf`) | Network stats KB/s | Who |
|---|---|---|---|---|---|---|---|---|
| _pending the first user run_ | | 2 players, 4 × 12 citizens + `sim.spawn 50` | | | | | | |

Targets: ≤ 4 ms per frame on the server; ≤ 20 KB/s per player (CONTRACTS G4). Every snapshot packet stays
≤ 900 B by construction (SnapshotCodec asserts it; the codec spec proves it at 50 and 300 entities).
