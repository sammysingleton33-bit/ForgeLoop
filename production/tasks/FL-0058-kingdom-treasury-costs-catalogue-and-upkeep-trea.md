---
id: FL-0058
title: Kingdom treasury, costs catalogue and upkeep (Treasury, Costs, Production)
track: build
owner: forge-03
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

# Kingdom treasury, costs catalogue and upkeep (Treasury, Costs, Production)

## Outcome
Every kingdom has an exact, shared, exploit-proof stockpile used by the HUD, construction, recruiting and citizens (CONTRACTS G7).

## Requirements
- Hour 0: stub config `Resources.luau` and `Costs.luau` (G6/G7 signatures, placeholder numbers). FORGE-05 merges them right after FL-0046.
- TreasuryService: get, canAfford, spend (atomic), spendUpTo, deposit (idempotent per txId), and the changed signal.
- Remotes in the area `Treasury` (not `Economy`, D-026): `Treasury.Changed` to kingdom members, `Treasury.Get` and `Treasury.GetCosts`.
- Config `Costs.luau`:
  - `Costs.building(type, level) -> {cost, buildSeconds}`;
  - `Costs.unit(unitType) -> {cost, trainSeconds, upkeepFood}`;
  - starting stockpiles.
- ProductionService is the only food consumer. Each minute it takes `spendUpTo` food for citizens and soldiers, then calls `CitizenService:setFedRatio` (G7).
- VS-1: any kingdom member may spend. Co-ruler permissions are VS-2.

## Validation
- Lune specs: atomic spend; never negative; a partial spendUpTo; idempotent deposit replay; two rulers spending at once; upkeep maths and fed ratio.

## Completion criteria
- [ ] Specs pass; VS-1 balance sheet in games/game-001/design/economy.md

## Log
- 2026-10-12 forge-00: created for AI Kingdoms VS-1 (READY).
- 2026-10-12 forge-00: plan review fixes (CONTRACTS v0.4-g2, D-024 to D-028): stubs first, spendUpTo, single food consumer + setFedRatio, Costs.unit, Treasury remote area
