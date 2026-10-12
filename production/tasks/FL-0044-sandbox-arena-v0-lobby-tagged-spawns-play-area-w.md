---
id: FL-0044
title: "Sandbox arena v0: lobby, tagged spawns, play area with a low region"
track: qa
owner: forge-05
status: READY
priority: P0
game: factory
created: 2026-10-12
updated: 2026-10-12
depends_on: [FL-0003]
estimate_h: 3
evidence: []
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
