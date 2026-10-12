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
estimate_h: 4
evidence: []
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
