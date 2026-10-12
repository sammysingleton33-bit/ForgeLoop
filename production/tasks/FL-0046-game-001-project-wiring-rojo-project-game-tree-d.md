---
id: FL-0046
title: "game-001 project wiring: Rojo project, Game-tree discovery, harness, require policy, CI"
track: infra
owner: forge-05
status: REVIEW
priority: P0
game: game-001
created: 2026-10-12
updated: 2026-10-12
depends_on: [FL-0003]
context: [games/game-001/BRIEF.md, games/game-001/CONTRACTS.md]
estimate_h: 4
evidence:
  - "check.sh OVERALL PASS (9 steps): framework Lune 191 passed/0 failed (17 files); Selene 0; StyLua 81 files; sandbox build + place check (17 instances); game-001 specs 5 passed; game-001 build; game-001 place check (22 instances: Forge + Game trees)"
  - "stamped run (stamp_build.sh + check.sh --require-stamp): both places carry BuildInfo sha 88a997b3e8dd"
  - "positive: a worker-style game service (Game.Services) + game shared module + spec in games/game-001/tests/sim ran in check.sh (game-001 specs 6 passed, 2 files) and booted in Boot.spec"
  - "negative (each exit 1, tree restored clean): framework module requiring @game/ReplicatedStorage/Game -> place check policy FAIL (D-022); missing cross-tree dependency -> Boot.spec FAIL; start() error -> Boot.spec FAIL; Economy Remotes in both trees -> place check areas FAIL + Boot.spec FAIL; same service name in both trees -> Boot.spec FAIL; runner bad option -> exit 2"
  - merged PR #6 as cbe3881; PR CI run 38300402808 green (9/9 steps); CI on main run 38300509272 green with artifacts forgeloop-main-cbe3881 and forgeloop-game001-cbe3881, both places BuildInfo stamped cbe38818d5fe (CI log)
---

# game-001 project wiring: Rojo project, Game-tree discovery, harness, require policy, CI

## Outcome
Game code under games/game-001/src is buildable, testable and runs in Studio next to the framework (CONTRACTS G1).

## Requirements
- games/game-001/default.project.json mapping src/shared -> ReplicatedStorage.Game, src/server -> ServerScriptService.Game, src/client -> StarterPlayerScripts.Game, config -> ReplicatedStorage.Forge.Config (no destructive Workspace sync)
- Main.server/Main.client discover Services/Controllers in both Forge and Game trees; env.sharedModules spans both
- Harness resolves requires over the selected project (sandbox and game-001); specs under games/game-001/tests run in check.sh
- Require policy: @game may also reach ReplicatedStorage/Game/...; framework code may never require Game code (enforced by the place check)
- CI runs gates for both projects; on main uploads forgeloop-game001-<sha>.rbxl
- games/game-001/README.md: how to build, serve and test

## Validation
check.sh green for both projects; negative test: a framework module requiring Game code fails the gate; the user reruns S1-S3 on the game-001 build

## Completion criteria
- [ ] Workers can add a game service + spec and see it run
- [ ] CI green with the game-001 artifact

## Log
- 2026-10-12 forge-00: created for AI Kingdoms VS-1 (READY).
- 2026-10-12 forge-05: READY → BUILDING. game-001 wiring: project file, dual-tree Loader/sharedModules, harness project selection, D-022 require policy, CI artifact.
- 2026-10-12 forge-05: BUILDING → REVIEW. Wiring done and gated headlessly; Studio confirmation (S1 on forgeloop-game001 build) pending. world/ mount waits for FORGE-02's first world file (Rojo fails on a missing path).
- 2026-10-12 forge-05: merged PR #6 (cbe3881). Stays REVIEW until the user's S1 on forgeloop-game001-cbe3881 (G6).
