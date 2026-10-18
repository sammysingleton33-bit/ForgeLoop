---
id: FL-0075
title: Duel input mode (PC, touch, gamepad) bound to DuelController
track: build
owner: forge-04
status: BUILDING
priority: P2
game: game-001
created: 2026-10-12
updated: 2026-10-18
depends_on: [FL-0071, FL-0053]
context: [games/game-001/design/crown-arena.md, games/game-001/CONTRACTS.md, games/game-001/BRIEF.md]
estimate_h: 5
evidence: []
---

# Duel input mode (PC, touch, gamepad) bound to DuelController

## Outcome
Rulers can fight the arena duel comfortably on PC, phone and gamepad: light, heavy, block, parry and dodge are bound and readable, and switching into and out of the duel input mode is seamless (design §5).

## Context
D-029; design §5; CONTRACTS G12.6 (`DuelController:act`). FORGE-04 owns InputMode (D-028). After VS-1.

## Requirements
- An `arena` input mode in InputMode: keyboard and mouse, touch buttons (thumb-reachable, ≥ 44 px), gamepad; it binds only to `DuelController:act`.
- Enters on the `duel` stage for the champion; leaves on `crowning`; spectators keep the camera only.

## Validation
Lune specs for mode switching. Studio with the phone emulator and a gamepad (or the emulator): all five actions reachable.

## Completion criteria
- [ ] Studio evidence (user playtest per games/game-001/STUDIO_PLAYTEST.md, BuildInfo sha + screenshots or video) before ACCEPTED

## Log
- 2026-10-12 forge-00: created for the Crown Arena (D-029, VS-2) (READY).
- 2026-10-13 forge-00: READY → SPECIFIED. FORGE-00 reconciliation 2026-10-13 (stale-status sweep): its dependencies are not built yet (FL-0018 economy core, or the Crown Arena FL-0070/FL-0071), so it is SPECIFIED, not READY.
- 2026-10-18 forge-00: SPECIFIED → READY. Operation Crownfall (D-053): arena work starts now; FORGE-01 order FL-0125 → FL-0069 → FL-0070 → FL-0071; defaults from crown-arena.md §11 apply
- 2026-10-18 forge-04: READY → BUILDING. arena mode in InputModeController + InputModeArenaController (keys, gamepad, touch >= 44 px) bound only to DuelController:act (G12.6 DRAFT); walk camera for the duel; Studio-only preview (ForgeDuelPreview) for E16 before FL-0071
