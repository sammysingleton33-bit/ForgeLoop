---
id: FL-0087
title: Plot picker, slot build menu and upgrade panel (G13.5)
track: build
owner: forge-03
status: READY
priority: P0
game: game-001
created: 2026-10-12
updated: 2026-10-12
depends_on: [FL-0081, FL-0090]
context: [games/game-001/design/living-kingdom.md, games/game-001/CONTRACTS.md, games/game-001/BRIEF.md, games/game-001/content/SPEC.md]
estimate_h: 5
evidence: []
---

# Plot picker, slot build menu and upgrade panel (G13.5)

## Outcome
From the aerial view the player taps a plot, picks a structure with its cost and build time, confirms, and later upgrades it from a clear panel that shows the next level's benefits (VS-1 row 6).

## Requirements
- `PlotPickerController`: on `InputModeController.selected("slot", id)`, show the structures that fit the slot size, with cost and time from `Treasury.GetCosts`, then call `Build.PlaceSlot`.
- `UpgradePanelController`: on building selection, show the level, the next level's cost, time and benefits, and an Upgrade button.
- Extends FL-0059 (PR #19); reuse its build menu. Phone first; touch targets ≥ 44 px.

## Validation
UI specs for affordability state and slot-size filtering. Prototype screenshots. Studio: build on a plot and upgrade.

## Completion criteria
- [ ] Studio evidence (user playtest per games/game-001/STUDIO_PLAYTEST.md, BuildInfo sha + screenshots or video) before ACCEPTED

## Log
- 2026-10-12 forge-00: created for the production priorities update (D-030) (READY).
