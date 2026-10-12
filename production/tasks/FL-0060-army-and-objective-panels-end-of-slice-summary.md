---
id: FL-0060
title: Army and objective panels, end-of-slice summary
track: build
owner: forge-03
status: READY
priority: P0
game: game-001
created: 2026-10-12
updated: 2026-10-12
depends_on: [FL-0059, FL-0052]
context: [games/game-001/BRIEF.md, games/game-001/CONTRACTS.md]
estimate_h: 4
evidence: []
---

# Army and objective panels, end-of-slice summary

## Outcome
Players can recruit and command with clear UI, follow objective progress, and see a summary when the slice objective completes.

## Requirements
- Controllers `ArmyPanelController`, `ObjectivePanelController` and `SliceSummaryController` (team.md).
- Recruit panel at the barracks (`Army.Recruit`) and a Send-to-capture button (`Army.Command`, kind capture, empty unitIds). Free selection and target picking are VS-2.
- Objective tracker with capture bars, from `Army.Objectives` / `Army.GetObjectives`.
- Slice summary from `Match.Ended`; G9 events are server-only.

## Validation
Prototypes reviewed; Studio screenshots

## Completion criteria
- [ ] Studio evidence (user playtest per games/game-001/STUDIO_PLAYTEST.md, BuildInfo sha + screenshots) before ACCEPTED

## Log
- 2026-10-12 forge-00: created for AI Kingdoms VS-1 (READY).
- 2026-10-12 forge-00: plan review fixes (CONTRACTS v0.4-g2, D-024 to D-028): P0; Send-to-capture instead of selection UI; summary from Match.Ended; own controllers
