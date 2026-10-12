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
estimate_h: 5
evidence: []
---

# Kingdom treasury, costs catalogue and upkeep (Treasury, Costs, Production)

## Outcome
Every kingdom has an exact, shared, exploit-proof stockpile used by the HUD, construction, recruiting and citizens (CONTRACTS G7).

## Requirements
- TreasuryService get/canAfford/spend (atomic)/deposit (idempotent per txId), changed signal, Economy.Treasury serverEvent to kingdom members, Economy.GetCosts function
- Config Resources.luau and Costs.luau (Costs.building(type, level) -> {cost, buildSeconds}; unit costs; starting stockpiles)
- ProductionService upkeep (food per citizen/soldier per minute) with starvation effects agreed with FORGE-01

## Validation
Lune specs: atomic spend, never negative, idempotent deposit replay, two rulers spending at once, upkeep math

## Completion criteria
- [ ] Specs pass; VS-1 balance sheet in games/game-001/design/economy.md

## Log
- 2026-10-12 forge-00: created for AI Kingdoms VS-1 (READY).
