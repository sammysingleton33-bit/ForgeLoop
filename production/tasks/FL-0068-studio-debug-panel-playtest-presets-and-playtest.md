---
id: FL-0068
title: Studio debug panel, playtest presets and Playtest A
track: qa
owner: forge-05
status: BUILDING
priority: P0
game: game-001
created: 2026-10-12
updated: 2026-10-12
depends_on: [FL-0047]
context: [games/game-001/BRIEF.md, games/game-001/CONTRACTS.md, games/game-001/STUDIO_PLAYTEST.md]
estimate_h: 4
evidence:
  - "Debug.spec 7 cases (registry validation, fail-closed args, presets, Studio-only remotes, rate limit, panel end-to-end under MockEnv); negative: IsStudio guard removed -> 'outside Studio creates no remotes' FAIL; truthy arg check -> fail-closed spec FAIL"
  - "Merged PR #14 as 5eb33ae (after worker PRs #16, #15, #12). Merge result with main d1910dd: check.sh 9/9 PASS (Lune 328/0; game-001 specs 56/0); ownership PASS (10 files)."
---

# Studio debug panel, playtest presets and Playtest A

## Outcome
The user can test each VS-1 row independently in minutes, starting from a known state, and the first partial playtest (Playtest A, rows 1–4b) can run before the whole slice exists (D-028).

## Requirements
- A Studio-only debug panel with `Debug.*` remotes in `roblox/src/shared/Debug/`. The server handles them only when `RunService:IsStudio()` is true.
  - Commands: grant resources, finish construction, place a completed Barracks, spawn N soldiers or test entities, set the phase, show BuildInfo.
  - Owners register their own commands through a `DebugCommands` registry, so nobody edits another worker's file.
- `STUDIO_PLAYTEST.md` additions:
  - every row starts from a debug preset;
  - row 1 checks that the ruler spawns at their own keep and never falls or respawns elsewhere;
  - row 3 runs Server & Clients twice: 2 clients in one Party Simulator party (same kingdom), and 2 clients with no party;
  - the entity rows run once with Network Simulator latency and packet loss and record bytes/s.
- Playtest A (rows 1–4b) is requested from the user as soon as those rows are on `main`.

## Validation
- Lune specs: debug remotes are neither created nor handled when IsStudio is false.
- Dry run against the built place; the user runs Playtest A.

## Completion criteria
- [ ] Debug panel and presets merged
- [ ] Playtest A requested with an exact artifact link, and its results recorded in studio-runs.md

## Log
- 2026-10-12 forge-00: created from the plan review; these requirements arrived after FL-0047 had merged (READY).
- 2026-10-12 forge-05: READY → BUILDING. Debug panel + registry + Studio-only server merged in this PR; presets come from row owners (handoff); Playtest A requested once rows 1-4b are on main.
- 2026-10-12 forge-05: panel, registry and Studio-only server on main (PR #14, 5eb33ae); stays BUILDING until the row owners' presets (vs1.row1/3/4/5/6/7) land and Playtest A runs.
