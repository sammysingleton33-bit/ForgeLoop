---
id: FL-0047
title: VS-1 Studio playtest script and integration builds
track: qa
owner: forge-05
status: READY
priority: P0
game: game-001
created: 2026-10-12
updated: 2026-10-12
depends_on: [FL-0046]
context: [games/game-001/BRIEF.md, games/game-001/CONTRACTS.md]
estimate_h: 5
evidence: []
---

# VS-1 Studio playtest script and integration builds

## Outcome
The user can verify VS-1 in Studio in under 20 minutes with a scripted checklist, and the results land as evidence.

## Requirements
- `games/game-001/STUDIO_PLAYTEST.md`: setup (`rojo serve` or the CI `.rbxl`), then one section per VS-1 row (BRIEF §4, including 4b) with exact steps, the expected result, the screenshot to take and the Output log to paste.
- Row 1 checks that the ruler spawns at their own keep and never falls or respawns elsewhere.
- Row 3 runs Server & Clients twice: 2 clients in one Party Simulator party (same kingdom), and 2 clients with no party.
- The entity rows run once with Network Simulator latency and packet loss, and record bytes/s.
- A Studio-only debug panel and `Debug.*` remotes in `roblox/src/shared/Debug/`, handled only when `RunService:IsStudio()` is true on the server.
  - Commands: grant resources, finish construction, place a completed Barracks, spawn N soldiers or test entities, set phase, show BuildInfo.
  - Owners register their own commands through a `DebugCommands` registry, so nobody edits another worker's file.
- Each row starts from a debug preset, so rows can be tested independently. Playtest A (rows 1–4b) runs before the full run.
- Results are recorded in `production/quality-gates/studio-runs.md`.

## Validation
- Dry-run against the built place structure.
- Lune specs: debug remotes are neither created nor handled when IsStudio is false.
- User run.

## Completion criteria
- [ ] The user completes Playtest A and then the full checklist on integrated builds.

## Log
- 2026-10-12 forge-00: created for AI Kingdoms VS-1 (READY).
- 2026-10-12 forge-00: plan review fixes (CONTRACTS v0.4-g2, D-024 to D-028): Party Simulator, spawn check, Network Simulator, Studio-only debug presets, Playtest A
