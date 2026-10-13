---
id: FL-0045
title: "Economy server services: EconomyService, InventoryService, RewardService, ShopService"
track: build
owner: forge-03
status: SPECIFIED
priority: P2
game: factory
created: 2026-10-12
updated: 2026-10-13
depends_on: [FL-0018]
estimate_h: 6
evidence: []
---

# Economy server services: EconomyService, InventoryService, RewardService, ShopService

## Outcome
The server-side economy other systems call: grants, spends, inventory, reward rolls and shop purchases with soft currency, exactly per interfaces.md section 7, firing the section 4 events exactly once.

## Requirements
- EconomyService registers the `economy` namespace (section 5) in `new`; `getBalance`, `grant`, `spend` idempotent per txId; reports sources/sinks via AnalyticsService:economy (only caller; registry:find in start())
- InventoryService `grant`/`count`; RewardService `roll` sampling exactly `RewardTables.odds(tableId, pityState)`; ShopService soft-currency purchases with confirmation flow support and `ShopViewed` events
- Paid-random gate: any roll paid with Robux or a robuxPurchasable currency checks canBuyPaidRandom first
- Fires CurrencyChanged / ItemGranted / RewardRolled exactly once per successful action; never on idempotent replay, failed or partial grants

## Validation
Lune specs with DataService test double / real module: idempotent replay fires nothing, failed grant fires nothing, restricted player blocked from a soft-currency crate, unknown policy blocked, displayed odds equal sampled distribution for every reachable pity state; check.sh green

## Completion criteria
- [ ] Specs above pass and are proven able to fail
- [ ] FORGE-04 and FORGE-01 can call the services per section 7

## Log
- 2026-10-12 forge-00: created from the second prompt review (READY).
- 2026-10-12 forge-00: priority -> P2. Player meta-economy/monetization comes after VS-1; the kingdom economy is FL-0058.
- 2026-10-13 forge-00: READY → SPECIFIED. FORGE-00 reconciliation 2026-10-13 (stale-status sweep): its dependencies are not built yet (FL-0018 economy core, or the Crown Arena FL-0070/FL-0071), so it is SPECIFIED, not READY.
