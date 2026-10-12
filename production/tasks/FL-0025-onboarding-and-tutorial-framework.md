---
id: FL-0025
title: Onboarding and tutorial framework
track: build
owner: forge-04
status: READY
priority: P0
game: factory
created: 2026-10-12
updated: 2026-10-12
depends_on: [FL-0008, FL-0023]
estimate_h: 6
evidence: []
---

# Onboarding and tutorial framework

## Outcome
Data-driven onboarding: step graph with triggers from the event bus, highlights/arrows, skip, persisted progress, funnel analytics.

## Requirements
- First meaningful interaction within ~30 s; never blocks play; resumable
- Steps defined per game in games/<game>/config/Onboarding.luau

## Validation
Lune specs for step progression, skip, persistence, triggers; fresh-player Studio walkthrough script

## Completion criteria
- [ ] Funnel steps emitted for every step

## Log
- 2026-10-12 forge-00: created (READY).
