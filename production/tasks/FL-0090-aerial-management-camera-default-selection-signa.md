---
id: FL-0090
title: Aerial management camera (default), selection signal, walk mode kept (G13.6)
track: build
owner: forge-04
status: READY
priority: P0
game: game-001
created: 2026-10-12
updated: 2026-10-12
depends_on: []
context: [games/game-001/design/living-kingdom.md, games/game-001/CONTRACTS.md, games/game-001/BRIEF.md, games/game-001/content/SPEC.md]
estimate_h: 6
evidence: []
---

# Aerial management camera (default), selection signal, walk mode kept (G13.6)

## Outcome
The game opens in an aerial management view over the player's kingdom, with the ruler visible on the throne. The player pans, zooms, rotates and selects citizens, buildings and plots with a tap or click. Walk mode stays available for later and for the Crown Arena (VS-1 row 2).

## Requirements
- `RulerCameraController` gets a `management` mode as the default:
  - zoom ≈ 40–220 studs, bounded to the map;
  - PC: WASD, drag, wheel, Q/E;
  - touch: drag, pinch, two-finger rotate.
- Keep the third-person work as `walk` mode. Do not discard it.
- `InputModeController.selected` signal (G13.6). Raycast resolution:
  - citizen: `EntityController:pick`;
  - building: `BuildingId` attribute;
  - slot: `BuildSlot` tag.
- Streaming: the camera's focus point drives what loads.
- Amends FL-0053.

## Validation
Specs for the camera math (bounds, zoom clamp) and selection resolution. Studio: PC and phone emulator, pan, zoom and selection.

## Completion criteria
- [ ] Studio evidence (user playtest per games/game-001/STUDIO_PLAYTEST.md, BuildInfo sha + screenshots or video) before ACCEPTED

## Log
- 2026-10-12 forge-00: created for the production priorities update (D-030) (READY).
