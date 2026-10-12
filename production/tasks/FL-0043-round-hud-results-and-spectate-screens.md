---
id: FL-0043
title: Round HUD, results and spectate screens
track: build
owner: forge-03
status: READY
priority: P1
game: factory
created: 2026-10-12
updated: 2026-10-12
depends_on: [FL-0020]
estimate_h: 6
evidence: []
---

# Round HUD, results and spectate screens

## Outcome
Players always see the round state, a countdown/timer, who is left, a clear results screen and a usable spectate overlay.

## Requirements
- Fed by Gameplay.RoundState / Gameplay.Eliminated / Gameplay.RoundResult serverEvents (interfaces.md section 4); deadlines from serverTimeNow
- Top-centre round zone per section 9; results modal; spectate overlay with next/previous target and leave-spectate
- Built on the FORGE-03 component kit; mobile layout

## Validation
HTML/Playwright prototypes reviewed; Lune specs for formatting/state helpers; Studio steps in roblox/studio-tests/ui-economy.md

## Completion criteria
- [ ] Works with 2-3 local clients in Studio (G6, user)

## Log
- 2026-10-12 forge-00: created from the prompt review (READY).
