---
id: FL-0055
title: "World layout v0 and WorldService: valley, river, forests, quarries, roads, 4 kingdom plots, nodes, objective"
track: asset
owner: forge-02
status: READY
priority: P0
game: game-001
created: 2026-10-12
updated: 2026-10-12
depends_on: [FL-0046]
context: [games/game-001/BRIEF.md, games/game-001/CONTRACTS.md]
estimate_h: 6
evidence: []
---

# World layout v0 and WorldService: valley, river, forests, quarries, roads, 4 kingdom plots, nodes, objective

## Outcome
A colourful medieval valley exists at server start with tagged resource nodes, build zones and a neutral Watchtower objective (VS-1 row 1; CONTRACTS G10).

## Requirements
- world/Layout.luau data; WorldService builds terrain (grass, paths, river water, hills) and places props and forests deterministically
- Tags ResourceNode, BuildZone, ObjectiveZone, KingdomPlot:<id>; navigation graph waypoints for FORGE-01
- Kingdom 1 dressed, kingdoms 2-4 blocked out; part and terrain budgets documented

## Validation
Lune specs for layout validity (no overlaps, nodes reachable on the nav graph, tags present); Studio fly-through screenshots

## Completion criteria
- [ ] Studio evidence (user playtest per games/game-001/STUDIO_PLAYTEST.md, BuildInfo sha + screenshots) before ACCEPTED

## Log
- 2026-10-12 forge-00: created for AI Kingdoms VS-1 (READY).
