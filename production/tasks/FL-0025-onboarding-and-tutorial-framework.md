---
id: FL-0025
title: Onboarding and tutorial framework
track: build
owner: forge-04
status: REVIEW
priority: P0
game: factory
created: 2026-10-12
updated: 2026-10-12
depends_on: [FL-0008, FL-0023]
estimate_h: 6
evidence:
  - check.sh OVERALL PASS @eeb239a (325 specs)
  - Onboarding 21 + OnboardingController 7 specs; mutations.py FL-0025 rows 8/8 CAUGHT
  - "fresh-player walkthrough with env.log funnel order: roblox/studio-tests/experience.md E6"
  - "unverified: needs DataService/RemoteService/kingdom signals; Studio walkthrough not run"
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
- 2026-10-12 forge-04: READY → BUILDING. Started 2026-10-12 on forge/04-experience (status recorded late: work began before this transition was logged).
- 2026-10-12 forge-04: BUILDING → TESTING. Implementation committed; headless gates running (check.sh, mutation check).
- 2026-10-12 forge-04: TESTING → REVIEW. Step graph, OnboardingService, OnboardingController, AI Kingdoms first_session flow (9 steps) and sandbox flow; funnel step per completed step, OnboardingSkipped + no later funnel step, persisted/resumable, never blocks play. Draft PR stacked on FL-0024.
