---
id: FL-0051
title: Buildings, construction, territory and ruler gathering
track: build
owner: forge-01
status: READY
priority: P0
game: game-001
created: 2026-10-12
updated: 2026-10-12
depends_on: [FL-0049, FL-0054, FL-0058]
context: [games/game-001/BRIEF.md, games/game-001/CONTRACTS.md]
estimate_h: 8
evidence: []
---

# Buildings, construction, territory and ruler gathering

## Outcome
Players place buildings that builders raise through visible stages; rulers can harvest resource nodes (VS-1 rows 5-6; CONTRACTS G6).

## Requirements
- BuildingService canPlace/place/upgrade (territory, overlap, terrain, cost via TreasuryService:spend, costs from Costs.luau); ConstructionService with builder contributions and Kit stages
- TerritoryService owner/claim; keep level 2 upgrade
- Kingdom.Gather: server-validated distance and cooldown, node depletion/regrowth; fires ResourceGathered
- Build.Place and Build.Upgrade remotes validated

## Validation
Lune specs: placement rules, atomic spend, construction progress, upgrade, gather exploits (distance, rate); Studio walkthrough

## Completion criteria
- [ ] Studio evidence (user playtest per games/game-001/STUDIO_PLAYTEST.md, BuildInfo sha + screenshots) before ACCEPTED

## Log
- 2026-10-12 forge-00: created for AI Kingdoms VS-1 (READY).
