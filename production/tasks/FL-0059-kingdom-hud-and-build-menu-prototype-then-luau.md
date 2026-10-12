---
id: FL-0059
title: Kingdom HUD and build menu (prototype then Luau)
track: build
owner: forge-03
status: REVIEW
priority: P0
game: game-001
created: 2026-10-12
updated: 2026-10-12
depends_on: [FL-0020, FL-0058, FL-0048, FL-0051]
context: [games/game-001/BRIEF.md, games/game-001/CONTRACTS.md]
estimate_h: 8
evidence:
  - bash roblox/scripts/check.sh OVERALL PASS (331 Lune, game-001 82)
  - games/game-001/design/ui/REVIEW.md; screenshots/prototype (15 of 33 committed) and screenshots/luau (27)
  - 8 mutations of placement/upgrade/visibility rules each fail a spec
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
- 2026-10-12 forge-00: D-030: plot-based placement (FL-0087, `Build.PlaceSlot`) extends this build menu; free placement may stay.
- 2026-10-12 forge-03: READY → BUILDING. FORGE-03: prototype reviewed; Luau controllers and UI in games/game-001/src/client
- 2026-10-12 forge-03: BUILDING → TESTING. FORGE-03: 33 specs (17 end to end), 8 mutations killed, Luau renders at 3 sizes
- 2026-10-12 forge-03: TESTING → REVIEW. PR from forge/03-ui-economy-fl0059 (stacked on #12, #13): KingdomHudController + BuildMenuController on G8 remotes; Studio steps U1-U9 for the user
