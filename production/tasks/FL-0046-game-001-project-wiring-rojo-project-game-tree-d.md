---
id: FL-0046
title: "game-001 project wiring: Rojo project, Game-tree discovery, harness, require policy, CI"
track: infra
owner: forge-05
status: READY
priority: P0
game: game-001
created: 2026-10-12
updated: 2026-10-12
depends_on: [FL-0003]
context: [games/game-001/BRIEF.md, games/game-001/CONTRACTS.md]
estimate_h: 7
evidence: []
---

# game-001 project wiring: Rojo project, Game-tree discovery, harness, require policy, CI

## Outcome
Game code under games/game-001/src is buildable, testable and runs in Studio next to the framework (CONTRACTS G1).

## Requirements
- `games/game-001/default.project.json` keeps every framework mount of `roblox/default.project.json`, including `roblox/assets` → `ReplicatedStorage.Forge.Assets`. It adds these mounts (CONTRACTS G1):
  - `src/shared` → `ReplicatedStorage.Game`;
  - `world` → `ReplicatedStorage.Game.World`;
  - `src/server` → `ServerScriptService.Game`;
  - `src/client` → `StarterPlayer.StarterPlayerScripts.Game`;
  - `config` → `ReplicatedStorage.Forge.Config`.
- The same file sets these properties; the place check asserts them:
  - a `Players` node with `CharacterAutoLoads = false` (D-026);
  - a `Workspace` node with properties only (no `$path`, so the sync is not destructive): `StreamingEnabled = true`, `ModelStreamingBehavior = Improved`, `StreamOutBehavior = Opportunistic`, `StreamingIntegrityMode = PauseOutsideLoadedArea` (D-025).
- `games/game-001/config/Game.luau` (FORGE-05), so the place check's `Config.Game` exists.
- Main.server and Main.client discover Services and Controllers in both trees, and `env.sharedModules` spans both trees. A duplicate service, controller, remote area or `<Area>.<Action>` fails the boot loudly (D-026).
- GameEvents: append the 11 G9 events to `EVENT_NAMES` and to the interfaces §4 table, as contract v0.3.2 (D-024). Merge within hours 0–4.
- Mock fixes in `roblox/tests/mocks/` (FL-0049's codec specs depend on them):
  - `Wire.estimateBytes` counts `buffer.len` for buffers;
  - `Wire.copyForRemote` copies buffers instead of passing them by reference;
  - a per-remote reorder or delay helper for unreliable events.
- The harness resolves requires over the selected project (sandbox or game-001). Specs under `games/game-001/tests` run in check.sh.
- Require policy: `@game` may also reach `ReplicatedStorage/Game/...` (including `Game/World`). Framework code may never require Game code; the place check enforces this.
- CI runs the gates for both projects. On main it uploads `forgeloop-game001-<sha>.rbxl`.
- Right after this merges, merge the hour-0 contract-stub PRs (CONTRACTS intro).
- `games/game-001/README.md`: how to build, serve and test.

## Validation
- check.sh green for both projects.
- Negative tests, each proven to fail:
  - a framework module requiring Game code;
  - a duplicate remote area across the two trees;
  - a 1,001-byte buffer on an UnreliableRemoteEvent is dropped, while a 1,000-byte one is delivered;
  - a server write to a buffer after FireClient is not visible to the client.
- The place check reads `CharacterAutoLoads` and the streaming properties from the built place.
- The user reruns S1–S3 on the game-001 build and confirms that streaming is on in Studio.

## Completion criteria
- [ ] Workers can add a game service + spec and see it run
- [ ] CI green with the game-001 artifact

## Log
- 2026-10-12 forge-00: created for AI Kingdoms VS-1 (READY).
- 2026-10-12 forge-00: plan review fixes (CONTRACTS v0.4-g2, D-024 to D-028): world/assets mounts, Players/Workspace properties, G9 events, duplicate-name guard, buffer-aware mocks
