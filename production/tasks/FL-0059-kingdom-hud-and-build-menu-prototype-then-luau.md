---
id: FL-0059
title: Kingdom HUD and build menu (prototype then Luau)
track: build
owner: forge-03
status: READY
priority: P0
game: game-001
created: 2026-10-12
updated: 2026-10-12
depends_on: [FL-0020, FL-0058, FL-0048, FL-0051]
context: [games/game-001/BRIEF.md, games/game-001/CONTRACTS.md]
estimate_h: 8
evidence: []
---

# Kingdom HUD and build menu (prototype then Luau)

## Outcome
Players always see their kingdom, rulers and resources, and can place buildings with clear costs (VS-1 rows 3, 5, 6).

## Requirements
- HTML/Playwright prototypes at phone, tablet and desktop sizes, reviewed first (games/game-001/design/ui/).
- Boots from the game controllers `src/client/Controllers/{KingdomHud,BuildMenu}Controller.luau` (team.md). Initial state comes from `Kingdom.GetState`, `Match.GetState` and `Treasury.Get`, then from the matching serverEvents.
- HUD: kingdom banner, member list, resource bar with deltas, phase/timer slot, territory count and Crown Points, and a slot for the job panel (FL-0065).
- Build menu and placement ghost:
  - footprint from `Kit.footprint`;
  - valid/invalid tint from `Build.CanPlace` (rate-limited);
  - cost shown; rotation in 90° steps;
  - calls `Build.Place(type, position, rot)`;
  - enters and leaves build mode through `InputModeController`.
- Uses the FORGE-03 UI kit and theme.

## Validation
Prototype screenshots reviewed; Lune specs for formatting and state; Studio screenshots (phone emulator + desktop)

## Completion criteria
- [ ] Studio evidence (user playtest per games/game-001/STUDIO_PLAYTEST.md, BuildInfo sha + screenshots) before ACCEPTED

## Log
- 2026-10-12 forge-00: created for AI Kingdoms VS-1 (READY).
- 2026-10-12 forge-00: plan review fixes (CONTRACTS v0.4-g2, D-024 to D-028): HUD controllers in the game tree, initial state via Get* remotes, ghost via Kit.footprint + Build.CanPlace, territory/Crown Points
