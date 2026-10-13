---
id: FL-0087
title: Plot picker, slot build menu and upgrade panel (G13.5)
track: build
owner: forge-03
status: REVIEW
priority: P0
game: game-001
created: 2026-10-12
updated: 2026-10-13
depends_on: [FL-0081, FL-0090]
context: [games/game-001/design/living-kingdom.md, games/game-001/CONTRACTS.md, games/game-001/BRIEF.md, games/game-001/content/SPEC.md]
estimate_h: 5
evidence:
  - bash roblox/scripts/check.sh OVERALL PASS (485 Lune, game-001 151)
  - "games/game-001/tests/economy/PlotUI.spec.luau: 9 specs (slot-size filter, affordability, PlaceSlot, refusals, pending guard, upgrade, foreign building)"
  - "games/game-001/design/ui/screenshots/luau: plot-pick and building-upgrade at phone/tablet/desktop, plot-pick-list (phone), building-foreign (desktop)"
  - "#34 f33e434, #48 8685b4a, #76 36d5ca9; integration-log.md"
  - check.sh PASS (512/0, game-001 937/0); 6/6 mutations killed; plot-pick renders re-shot and looked at
  - "main c338f44: check.sh PASS on 599c8ea+#88 (game-001 1102/0); ownership PASS 13 files; CI 3/3 on b76003a; e2e vs real PlaceSlot: client offers subset of server Fit for S/M/L; filter mutation fails 2 PlotUI specs"
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
- 2026-10-12 forge-03: READY → BUILDING. FORGE-03: PlotPickerController + UpgradePanelController on G13.5/G13.6, SlotDoubles for FORGE-01's plots
- 2026-10-12 forge-03: BUILDING → REVIEW. PR #34 (stacked on #25): plot picker and upgrade panel; Studio steps U10-U11 for the user
- 2026-10-13 forge-05: REVIEW → REVIEW. REVIEW, only G6 pending, plus a tracked follow-up (FORGE-05 acceptance record, D-038 (5); --force because the status stays REVIEW): merged code passed check.sh on the merge result and CI on main. Follow-up: FL-0081 (ordering by tapping a plot marker needs the PlaceSlot server).
- 2026-10-13 forge-03: REVIEW → REVIEW. D-038: plot picker on FORGE-01's Build/Fit.typesFor (BuildModel.plotTypes = Fit.typesFor(size) less wall/gate); UI/SlotFit deleted; SlotDoubles judges with Fit.fits; CONTRACTS G13.5 interim-copy note can go (FORGE-00).
- 2026-10-13 forge-05: REVIEW → REVIEW. Merged #88 (c338f44, FORGE-05 D-040 fallback verdict on b76003a; promoted by FORGE-00): plot picker on Build/Fit.typesFor less wall/gate; UI/SlotFit deleted. REVIEW, only G6 pending (U10, STUDIO_PLAYTEST row 6). L1: plot-pick renders predate #86 (flame emblem, crown badge), re-shoot in the #86 follow-up. FORGE-07 post-merge review owed.
