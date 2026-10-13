---
id: FL-0051
title: Buildings, construction, territory and ruler gathering
track: build
owner: forge-01
status: BUILDING
priority: P0
game: game-001
created: 2026-10-12
updated: 2026-10-13
depends_on: [FL-0049, FL-0054, FL-0058, FL-0055]
context: [games/game-001/BRIEF.md, games/game-001/CONTRACTS.md]
estimate_h: 9
evidence: []
---

# Buildings, construction, territory and ruler gathering

## Outcome
Players place buildings that builders raise through visible stages; rulers can harvest resource nodes (VS-1 rows 5-6; CONTRACTS G6).

## Requirements
- BuildingService canPlace, place and upgrade:
  - checks territory, build zone, overlap (via `Kit.footprint`) and cost (via `TreasuryService:spend`, costs from `Costs.luau`);
  - sets `placedBy`;
  - links each building's `Door` to the nearest nav node.
- Starting buildings: at Founding start, place `Buildings.luau` `starting` (keep L1, storehouse, farm, lumbercamp, quarry) as `complete` at `Layout.plots[k].anchors`, for all four kingdoms.
- ConstructionService with builder contributions. Each Kit stage replaces the whole previous Model.
- TerritoryService owner and claim over `Layout.regions`. A claim places `Kit.regionMarkers`. Keep level 2 upgrade.
- Ruler gathering:
  - `Kingdom.Gather`: server-validated distance and cooldown; node depletion and regrowth from Layout;
  - client `InteractionController`: a tap or ProximityPrompt on a resource node in explore mode, with the `gathered` signal;
  - fires ResourceGathered.
- Remotes, validated per G8: `Build.Place` / `Build.CanPlace` with `(type, position, rot)`, `Build.Upgrade`, `Build.Buildings` / `Build.GetBuildings`. No CFrame goes on the wire.

## Validation
- Lune specs: placement rules, atomic spend, starting buildings, door links, construction progress, upgrade, claim, and gather exploits (distance, rate, depleted node).
- Studio walkthrough.

## Completion criteria
- [ ] Studio evidence (user playtest per games/game-001/STUDIO_PLAYTEST.md, BuildInfo sha + screenshots) before ACCEPTED

## Log
- 2026-10-12 forge-00: created for AI Kingdoms VS-1 (READY).
- 2026-10-12 forge-00: plan review fixes (CONTRACTS v0.4-g2, D-024 to D-028): starting buildings, door links, footprint, region markers, InteractionController, position+rot placement remotes
- 2026-10-13 forge-00: READY → BUILDING. Status reconciled by the FORGE-00 backlog audit 2026-10-13: partly built in merged PRs #46, #50, #56, #62, #72. Remaining (audit): ruler gather client (InteractionController; onboarding needs it), Door->nav, claim markers, Construction/Territory service facades (G5), #62 M-1. Slot reservation is FL-0081.
