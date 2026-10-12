---
id: FL-0018
title: "Economy core: items, inventory, wallet, reward tables with odds and pity"
track: build
owner: forge-03
status: REVIEW
priority: P0
game: factory
created: 2026-10-12
updated: 2026-10-12
depends_on: [FL-0003]
estimate_h: 6
evidence:
  - check.sh OVERALL PASS at f8d621b (349 Lune specs incl. Wallet 12, Construction 12, ItemRegistry 23, Inventory 19, RewardTables 58)
  - "Proven to fail: Wallet replay mutation fails 'is idempotent per txId'; builder-limit mutation fails 'blocks when every builder is busy'; pity off-by-one fails 4 RewardTables specs; no-largest-remainder fails 7 (expected 9996 to be 10000)"
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
- 2026-10-12 forge-03: READY → BUILDING. Started on forge/03-ui-economy (AI Kingdoms directive).
- 2026-10-12 forge-03: BUILDING → REVIEW. Economy core done: Bundle, Wallet (all-or-nothing, capped, idempotent per txId), Currencies (robuxPurchasable), Construction (AI Kingdoms buildings/units), ItemRegistry, Inventory, RewardTables (odds = sampled distribution incl. pity, largest-remainder display). Config: games/sandbox/config/{Items,Currencies,RewardTables}.luau (AI Kingdoms, provisional numbers). Open: duplicate-cosmetic policy for RewardService (FL-0045).
