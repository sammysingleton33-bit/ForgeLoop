---
id: FL-0044
title: "Sandbox arena v0: lobby, tagged spawns, play area with a low region"
track: qa
owner: forge-05
status: REVIEW
priority: P0
game: factory
created: 2026-10-12
updated: 2026-10-12
depends_on: [FL-0003]
estimate_h: 3
evidence:
  - "check.sh OVERALL PASS on forge/05-integration-fl0044 (7 steps): Lune 183 passed 0 failed 17 files; Selene 0; StyLua 73 files; map gen 9 model files match; Rojo build; place check 19 expected instances, map 4 kingdoms, 52 anchors, 426 parts"
  - "negative map gates (each exit 1, restored green): Position instead of CFrame -> place check 'at 0, 0, 0'; RulerSpawn tag removed -> count FAIL; unanchored part + misspelled tag -> FAIL; hand-edited model file -> map gen FAIL; MapReport spec with broken rule -> 2 failed"
  - top-down plan render of the generated map reviewed by FORGE-05 (layout only; not a Studio visual check)
---

# Sandbox arena v0: lobby, tagged spawns, play area with a low region

## Outcome
FORGE-01 has a real place to run rounds and measure the flood: a small lobby, spawn platforms, and a play area with a marked low region and a documented base water level.

## Requirements
- Map model files + README first (before the skeleton merges); the Rojo mapping into Workspace and the place-check assertions right after the skeleton merges
- Spawn parts tagged ForgeSpawn, lobby spawn tagged ForgeLobbySpawn, play-area bounds part tagged ForgePlayArea, low-region marker parts tagged ForgeFloodProbe (5 points) with their base water Y documented
- Terrain or parts kept small and readable; handoff to FORGE-01 announcing the tags

## Validation
Rojo build contains the tagged instances (place check); Studio screenshot by the user

## Completion criteria
- [ ] Tags documented in games/sandbox/README.md
- [ ] Handoff to FORGE-01 written

## Log
- 2026-10-12 forge-00: created from the prompt review (READY).
- 2026-10-12 forge-05: READY → BUILDING. Retargeted to the AI Kingdoms vertical slice (user direction 2026-10-12): medieval four-kingdom map instead of the flood arena.
- 2026-10-12 forge-05: BUILDING → REVIEW. Map, Rojo Workspace mapping, map contract Config/Map, place-check map assertions, runtime MapReport, S4/M1 Studio steps, handoff to FORGE-01. ForgeFloodProbe dropped (no flood in AI Kingdoms). G5/G6 pending: user Studio S4 + screenshots.
