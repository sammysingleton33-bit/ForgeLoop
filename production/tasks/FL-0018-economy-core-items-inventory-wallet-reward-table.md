---
id: FL-0018
title: "Economy core: items, inventory, wallet, reward tables with odds and pity"
track: build
owner: forge-03
status: READY
priority: P0
game: factory
created: 2026-10-12
updated: 2026-10-12
depends_on: [FL-0003]
estimate_h: 6
evidence: []
---

# Economy core: items, inventory, wallet, reward tables with odds and pity

## Outcome
Data-driven economy primitives: ItemRegistry, Inventory (stacks, caps, equip slots), Wallet (non-negative, idempotent transaction ids), RewardTable (weighted tiers, exact odds for disclosure, optional pity, seeded RNG), config validation at startup.

## Requirements
- Implements interfaces.md section 7 shared parts
- Config files in games/sandbox/config: Items, Currencies, RewardTables
- Odds shown to players come from the same function the server uses

## Validation
Lune specs: odds sum to 1, seeded determinism, distribution within tolerance over many rolls, pity triggers exactly as configured, invalid configs rejected, wallet idempotency/overflow, inventory caps

## Completion criteria
- [ ] Specs pass in check.sh

## Log
- 2026-10-12 forge-00: created (READY).
