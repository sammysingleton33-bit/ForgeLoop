---
id: FL-0019
title: "PurchaseService: idempotent ProcessReceipt, game passes, PolicyService gating"
track: build
owner: forge-03
status: READY
priority: P0
game: factory
created: 2026-10-12
updated: 2026-10-12
depends_on: [FL-0008, FL-0018, FL-0045]
estimate_h: 6
evidence: []
---

# PurchaseService: idempotent ProcessReceipt, game passes, PolicyService gating

## Outcome
Robux purchases are granted exactly once, durably, and paid random items are only offered where policy allows.

## Requirements
- ProcessReceipt: PurchaseId recorded in economy namespace; NotProcessedYet if profile not loaded, handler fails or saveNow fails; no partial grants
- Product handler registry; game pass ownership cache with pcall + refresh on purchase
- canBuyPaidRandom via PolicyService (false when unknown); numerical odds display for paid random items

## Validation
Lune specs with MockMarketplaceService + DataService mock/real: duplicate receipt, receipt before profile load, handler error, save failure, rejoin replay, pass ownership errors; Studio test-purchase steps

## Completion criteria
- [ ] Every failure path returns NotProcessedYet and leaves no partial grant

## Log
- 2026-10-12 forge-00: created (READY).
