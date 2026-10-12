---
id: FL-0067
title: "game-001 wiring follow-ups from the plan review: streaming, character spawn, world mount, buffer-faithful mocks"
track: infra
owner: forge-05
status: READY
priority: P0
game: game-001
created: 2026-10-12
updated: 2026-10-12
depends_on: [FL-0046]
context: [games/game-001/BRIEF.md, games/game-001/CONTRACTS.md]
estimate_h: 3
evidence: []
---

# game-001 wiring follow-ups from the plan review: streaming, character spawn, world mount, buffer-faithful mocks

## Outcome
The game-001 place behaves like production Roblox for the things VS-1 depends on: streaming settings, rulers spawned by the game (not auto-loaded), the world layout mounted, and remote mocks that are faithful to buffer semantics and unreliable-event size limits (D-025, D-026).

## Requirements
- `games/game-001/default.project.json`:
  - a `Players` node with `CharacterAutoLoads = false` (D-026);
  - a `Workspace` node with properties only (no `$path`): `StreamingEnabled = true`, `ModelStreamingBehavior = Improved`, `StreamOutBehavior = Opportunistic`, `StreamingIntegrityMode = PauseOutsideLoadedArea` (D-025);
  - `world` → `ReplicatedStorage.Game.World` mount, so `Layout.luau` reaches FORGE-01 as pure data (CONTRACTS G10.1).
- The place check asserts these properties and the world mount.
- Mock fixes in `roblox/tests/mocks/` (FL-0049's codec specs depend on them):
  - `Wire.estimateBytes` counts `buffer.len` for buffers;
  - `Wire.copyForRemote` copies buffers instead of passing them by reference;
  - a per-remote reorder/delay helper for unreliable events;
  - UnreliableRemoteEvent payloads over the documented size limit are dropped.
- Merge the workers' hour-0 contract-stub PRs as soon as they arrive (CONTRACTS intro).

## Validation
- check.sh green.
- Negative tests, each proven to fail:
  - a 1,001-byte buffer on an unreliable event is dropped while a 1,000-byte one is delivered;
  - a server write to a buffer after FireClient is not visible to the client.
- The user confirms in Studio that streaming is on and the ruler spawns only at the kingdom keep.

## Completion criteria
- [ ] Properties and mounts asserted by the place check
- [ ] Buffer and size-limit mock specs pass and are proven able to fail

## Log
- 2026-10-12 forge-00: created from the plan review; these requirements arrived after FL-0046 had merged (READY).
