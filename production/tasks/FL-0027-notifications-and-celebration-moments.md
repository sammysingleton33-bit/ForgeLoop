---
id: FL-0027
title: Notifications and celebration moments
track: build
owner: forge-04
status: REVIEW
priority: P0
game: factory
created: 2026-10-12
updated: 2026-10-13
depends_on: [FL-0020]
estimate_h: 4
evidence:
  - "check.sh OVERALL PASS @1846163: framework 489 Lune specs, game-001 87, Selene 0/0, StyLua 170 files, both Rojo builds and place checks"
  - "Notification.spec 16 (queue: stack of 3, priority replace, waiting cap, coalescing + refresh cap, important filter, clamps; controller: view band 70, expiry on the virtual clock, live setting, celebrations, cooldown, registration, dismiss) + OnboardingController completion celebration"
  - mutations.py FL-0027 rows 13/13 CAUGHT
  - "Studio checklist written: roblox/studio-tests/experience.md E7"
  - "unverified: look and feel in Studio, phone layout, FORGE-03 Toast component not yet adopted (FL-0020 not on main)"
  - "check.sh OVERALL PASS @901c9c0: framework 502, game-001 109 specs; FL-0027 mutations 13/13 CAUGHT with the Toast view"
  - "FORGE-05 #33 follow-ups: Notification.spec 20 (+ different moment within the cooldown, non-table payload, NaN duration, invalid UTF-8, place/reserveTop) and OnboardingController.spec (card reserves the stack top); FL-0027 mutations 21/21 CAUGHT"
---

# Notifications and celebration moments

## Outcome
NotificationController and reward/achievement celebrations that feel rewarding without clutter.

## Requirements
- interfaces.md section 8 API
- Queueing, priority, mobile layout in the top-right stack
- Uses FORGE-03 Toast/Panel components

## Validation
Prototype/screenshot review; Lune specs for queue logic

## Completion criteria
- [ ] Studio checklist written

## Log
- 2026-10-12 forge-00: created (READY).
- 2026-10-12 forge-00: priority -> P0. Notifications feed the VS-1 announcer (FL-0062).
- 2026-10-12 forge-04: READY → BUILDING. Started on forge/04-experience-fl0027, stacked on FL-0025 (#22). FORGE-03's Toast (FL-0020, PR #13) is not on main yet: minimal view until then.
- 2026-10-12 forge-04: BUILDING → TESTING. Queue, controller, specs committed; headless gates on 1846163.
- 2026-10-12 forge-04: TESTING → REVIEW. PR from forge/04-experience-fl0027 stacked on #22. Studio checklist: roblox/studio-tests/experience.md E7.
- 2026-10-12 forge-04: REVIEW → REVIEW. Merged main (#20-#22 landed); the view now uses FORGE-03's UI/Components/Toast (FL-0020); new handoff forge-04-to-forge-03-notifications-ready.
- 2026-10-12 forge-04: REVIEW (unchanged). FORGE-05 follow-ups: M1 toasts start below the onboarding card (reserveTop), M2 place() for the HUD layout; L1 different moments within the cooldown keep their toast; L2 non-table payload; L3 NaN duration; L4 invalid UTF-8 cut; text note; interfaces §8 text handed to FORGE-00.
- 2026-10-13 forge-04: REVIEW (unchanged). FORGE-05 #33 follow-ups (PR from forge/04-experience-fl0027b): M2 place() takes screen px (FORGE-03 #74 scales); L1 no show/celebrate/GUI after destroy; L2 achievement toasts use the laurel icon; L3 fewer cards when the screen is short (NotificationQueue:setMaxVisible). Notification.spec 24; FL-0027 mutations 28/28.
