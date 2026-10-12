---
id: FL-0023
title: AnalyticsService adapter, event taxonomy and funnels
track: build
owner: forge-04
status: READY
priority: P0
game: factory
created: 2026-10-12
updated: 2026-10-12
depends_on: [FL-0003]
estimate_h: 4
evidence: []
---

# AnalyticsService adapter, event taxonomy and funnels

## Outcome
Every game ships with consistent analytics: an adapter over Roblox AnalyticsService (custom, funnel and economy events (progression events optional research only)) and a documented event taxonomy.

## Requirements
- interfaces.md section 8; research current Roblox API names and limits
- analytics/schemas/events.md with onboarding, first-round, shop and retention funnels
- Subscribes to the event bus; no-op safe when Roblox calls fail

## Validation
Lune specs with MockAnalyticsService (event shapes, limits, failure isolation)

## Completion criteria
- [ ] Taxonomy reviewed by FORGE-00

## Log
- 2026-10-12 forge-00: created (READY).
