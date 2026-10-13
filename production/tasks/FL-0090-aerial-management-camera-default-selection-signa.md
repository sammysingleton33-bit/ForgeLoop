---
id: FL-0090
title: Aerial management camera (overview, default), selection signal, walk mode kept (G13.6)
track: build
owner: forge-04
status: REVIEW
priority: P0
game: game-001
created: 2026-10-12
updated: 2026-10-13
depends_on: []
context: [games/game-001/design/living-kingdom.md, games/game-001/CONTRACTS.md, games/game-001/BRIEF.md, games/game-001/content/SPEC.md]
estimate_h: 6
evidence:
  - "check.sh OVERALL PASS @9e4fb27: framework 485, game-001 155 specs (boot gate incl.), Selene 0/0, StyLua 210, both builds and place checks"
  - "specs: RulerCamera 21 (aerial rig math, Layout bounds, WASD/drag/touch pan, zoom 40-220, Q/E outside build mode, streaming throttle, walk mode), InputMode 13 (selection: citizen via pick, BuildingId, BuildSlot, none, tap vs drag, build clears), Ruler 12 (standUp)"
  - "mutation check: FL-0090 rows 15/15 CAUGHT"
  - "unverified: aerial feel on PC and phone emulator, throne visibility, streaming while panning far (Studio, user G6)"
  - "#29 32ef652; integration-log.md"
---

# Aerial management camera (default), selection signal, walk mode kept (G13.6)

## Outcome
The game opens in an aerial management view over the player's kingdom, with the ruler visible on the throne. The player pans, zooms, rotates and selects citizens, buildings and plots with a tap or click. Walk mode stays available for later and for the Crown Arena (VS-1 row 2).

## Requirements
- `RulerCameraController` gets the `overview` mode (the aerial management view, G4.1 name) as the default:
  - zoom ≈ 40–220 studs, bounded to the map;
  - PC: WASD, drag, wheel, Q/E;
  - touch: drag, pinch, two-finger rotate.
- Keep the third-person work as `follow` (walk) mode. Do not discard it.
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
- 2026-10-12 forge-04: READY → BUILDING. On forge/04-experience-fl0053 (PR #29): extends FL-0053, nothing discarded (D-030).
- 2026-10-12 forge-04: BUILDING → TESTING. Aerial overview default, selection, walk mode; headless gates on 9e4fb27.
- 2026-10-12 forge-04: TESTING → REVIEW. In PR #29 with FL-0053. Keys/gestures and Studio checklist in the PR; handoff forge-04-to-forge-01-03-05-ruler-camera-input.
- 2026-10-13 forge-05: REVIEW → REVIEW. REVIEW, only G6 pending (FORGE-05 acceptance record, D-038 (5); --force because the status stays REVIEW): merged code passed check.sh on the merge result and CI on main; the user's Studio run (G6) is the only gate left (STUDIO_PLAYTEST check 3).
