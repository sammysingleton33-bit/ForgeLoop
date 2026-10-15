---
id: FL-0060
title: Army and objective panels, end-of-slice summary
track: build
owner: forge-03
status: REVIEW
priority: P0
game: game-001
created: 2026-10-12
updated: 2026-10-13
depends_on: [FL-0059, FL-0052]
context: [games/game-001/BRIEF.md, games/game-001/CONTRACTS.md]
estimate_h: 4
evidence:
  - bash roblox/scripts/check.sh -> OVERALL PASS (framework 486 specs; game-001 553 specs in 47 files, 0 failed; selene 0 errors; stylua 369 files; both Rojo builds and place checks PASS)
  - ArmyModel.spec.luau 14 passed; ArmyUI.spec.luau 15 passed (end to end, M1 instance identity, phone 44 px); 14 mutations each killed by a spec, files restored byte-equal
  - HTML prototype (army.html, 42 shots) and 33 Luau renders (0 snapshot errors) looked at in two rounds; 27 earlier renders re-shot pixel-identical; review games/game-001/design/ui/REVIEW-army.md
  - python3 tools/check_ownership.py --base origin/main --head HEAD --owner forge-03 -> PASS
  - "#63 5764630; check.sh 1020/0; integration-log.md"
  - "main d3525db: e2e slice with #63 client: recruit 3 via drawer, Send to capture, summary 'Victory / Lasted 2:37', 0 errors; CI run 38361561318 green"
  - "integration-log #103 row: check.sh PASS on the merge result, main CI green"
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
- 2026-10-12 forge-03: READY → BUILDING. Army drawer (rail + barracks tab), objective tracker, slice summary; prototype first; FORGE-01 doubles in tests/economy/doubles/ArmyDoubles
- 2026-10-12 forge-03: BUILDING → REVIEW. Army drawer (rail button + Army tab on my barracks' upgrade panel; Army.Recruit 1..10, Army.Command({}, capture) + 3 s cooldown), objective tracker (Army.Objectives/GetObjectives, in-place bars), slice summary (Match.Ended). FORGE-01 doubles in tests/economy/doubles/ArmyDoubles (FL-0052 not built); assumptions in production/handoffs/2026-10-12-forge-03-to-forge-01-army-ui.md. Headless only: Studio U14 pending.
- 2026-10-13 forge-05: REVIEW → BUILDING. Merged #63 (FORGE-05, D-038 (5)): the Army drawer, tracker and summary are on main but hidden until FORGE-01's Army server (#70, FL-0052) lands; merged code with work left = BUILDING. Then REVIEW with G6 (STUDIO_PLAYTEST check 9).
- 2026-10-13 forge-05: BUILDING → REVIEW. Army server #70 merged (d3525db), so the drawer, tracker and summary are live. Only G6 pending: STUDIO_PLAYTEST check 9 (row 7) from B7. Known: ArmyText recruit_cap advice 'Build houses first' is wrong after D-041 (should say upgrade the barracks).
- 2026-10-13 forge-05: REVIEW → REVIEW. D-046 log: the #86 review follow-ups are closed by #103 (f2d430a): M1 Studio text and L2-L9. REVIEW, only G6 pending (STUDIO_PLAYTEST check 9, row 7, from B7; captured-tower look from B11).
