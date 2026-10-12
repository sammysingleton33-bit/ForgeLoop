---
id: FL-0023
title: AnalyticsService adapter, event taxonomy and funnels
track: build
owner: forge-04
status: REVIEW
priority: P1
game: factory
created: 2026-10-12
updated: 2026-10-12
depends_on: [FL-0003]
estimate_h: 4
evidence:
  - "check.sh OVERALL PASS @2574877: framework 379 Lune specs, game-001 75 specs (boot gate incl.), Selene 0/0, StyLua 136 files, both Rojo builds and place checks"
  - mutations.py FL-0023 rows 8/8 CAUGHT (+ FL-0061 4/4)
  - "unverified: Roblox records nothing from Studio; real delivery needs a published test place (user approval); taxonomy review by FORGE-00 pending"
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
- 2026-10-12 forge-00: priority -> P1. Analytics adapter needed for FL-0063.
- 2026-10-12 forge-04: READY → BUILDING. Started 2026-10-12 on forge/04-experience (status recorded late: work began before this transition was logged).
- 2026-10-12 forge-04: BUILDING → TESTING. Implementation committed; headless gates running (check.sh, mutation check).
- 2026-10-12 forge-04: TESTING → REVIEW. Adapter, router, schema, sandbox + AI Kingdoms configs and events.md done; draft PR until FL-0003 merges (D-016). Taxonomy review requested from FORGE-00 (handoff 2026-10-12-forge-04-to-forge-00-ai-kingdoms-experience.md).
- 2026-10-12 forge-04: REVIEW → BUILDING. back to BUILDING after merging main (CONTRACTS v0.4-g2, D-024..D-028): game-001 analytics config moves from proposed kingdom signals to G9; G9 funnel attribution is FL-0063. PRs not opened yet.
- 2026-10-12 forge-04: BUILDING → TESTING. Reconciled with CONTRACTS v0.4-g3 and FORGE-00 answers (G9, Subjects hook, no Crowns); headless gates on 2574877.
- 2026-10-12 forge-04: TESTING → REVIEW. PR from forge/04-experience-fl0023; taxonomy review requested from FORGE-00 (handoff forge-04-to-forge-00-ai-kingdoms-experience).
- 2026-10-12 forge-04: evidence added: mutation rows; unverified items listed.
