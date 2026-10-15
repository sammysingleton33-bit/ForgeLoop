---
id: FL-0025
title: Onboarding and tutorial framework
track: build
owner: forge-04
status: REVIEW
priority: P0
game: factory
created: 2026-10-12
updated: 2026-10-15
depends_on: [FL-0023]
estimate_h: 6
evidence:
  - "check.sh OVERALL PASS @4054eab: framework 471 Lune specs, game-001 86 specs (boot gate + VS-1 flow), Selene 0/0, StyLua 167 files, both Rojo builds and place checks"
  - mutations.py FL-0025 rows 11/11 CAUGHT; whole file 39/39 at 4054eab
  - "funnel step per completed step and no step after skip: games/game-001/tests/experience/Onboarding.spec.luau (8) and roblox/tests/unit/experience/Onboarding.spec.luau"
  - "unverified: Studio walkthrough E6 not run; needs FORGE-01 KingdomJoined/G9 producers, WorldService tags and FORGE-03 HUD targets on the build"
  - "check.sh OVERALL PASS @7ee0f3c: framework 472, game-001 87 specs; mutations FL-0025 14/14 CAUGHT"
  - Onboarding.spec, AnalyticsSchema.spec, game AnalyticsConfig.spec pass; mutations.py FL-0025 17/17
  - "Onboarding.spec 31/31 (new: completeReward only when earned, across a persisted rejoin and never when skipped; service: every server step passed over pays no Complete grant); mutations.py FL-0025 22/22 CAUGHT (5 new rows)"
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
- 2026-10-12 forge-00: priority -> P0. Onboarding framework feeds VS-1 onboarding (FL-0062).
- 2026-10-12 forge-00: removed FL-0008 dependency (D-027: VS-1 runs without persistence; settings/onboarding progress in-memory until FL-0008).
- 2026-10-12 forge-04: READY → BUILDING. Started 2026-10-12 on forge/04-experience (status recorded late: work began before this transition was logged).
- 2026-10-12 forge-04: BUILDING → TESTING. Implementation committed; headless gates running (check.sh, mutation check).
- 2026-10-12 forge-04: TESTING → REVIEW. Step graph, OnboardingService, OnboardingController, AI Kingdoms first_session flow (9 steps) and sandbox flow; funnel step per completed step, OnboardingSkipped + no later funnel step, persisted/resumable, never blocks play. Draft PR stacked on FL-0024.
- 2026-10-12 forge-04: REVIEW → BUILDING. back to BUILDING after merging main: D-027 (session-only progress), first step on KingdomJoined, G9 triggers via a subject-resolver hook. PRs not opened yet.
- 2026-10-12 forge-04: BUILDING → TESTING. Reconciled: startOn KingdomJoined, G9 triggers via Subjects + game-001 Signals, session-only progress (D-027); headless gates on 4054eab.
- 2026-10-12 forge-04: TESTING → REVIEW. PR from forge/04-experience-fl0025, stacked on FL-0024. Studio walkthrough: roblox/studio-tests/experience.md E6.
- 2026-10-12 forge-04: REVIEW → REVIEW. Follow-up in PR #22: idle hints from config (framework holds no game text, D-026), generic ReachedTarget detector, neutral fixtures.
- 2026-10-13 forge-04: REVIEW → REVIEW. REVIEW (unchanged; --force). FORGE-00 doc review M8: Subjects.missing + Onboarding.events; OnboardingService refuses a config listening to an event no resolver covers (logged as an error) instead of a step that never completes; game-001 spec covers Onboarding.luau and Analytics.luau. M9: interfaces §8 text proposed in handoff forge-04-to-forge-00-03-doc-review-fixes. AnalyticsService's boot check follows after #64.
- 2026-10-15 forge-04: REVIEW → REVIEW. D-052 (3) (FORGE-07 #124 L3): a flow pays its completeReward only if at least one step was done by its real action (bus or satisfied, the PAID_VIA rule). The engine records state.earned at that completion, persists and restores it (a rejoin keeps it), and Onboarding.completionReward(flow, state) returns the reward only for a finished, earned flow; OnboardingService grants that and logs 'completion reward withheld' otherwise. VS-1 sets no completeReward, so nothing changes in game-001.
