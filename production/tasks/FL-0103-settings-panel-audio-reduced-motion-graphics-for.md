---
id: FL-0103
title: "Settings panel: audio, reduced motion, graphics (FORGE-03 components; D-038 (4))"
track: build
owner: forge-04
status: TESTING
priority: P2
game: game-001
created: 2026-10-13
updated: 2026-10-13
depends_on: [FL-0024]
context: [games/game-001/CONTRACTS.md, DECISIONS.md, games/game-001/STUDIO_PLAYTEST.md]
estimate_h: 4
evidence:
  - SettingsPanel.spec 8/8; Vfx.spec 17/17; mutations FL-0103 11/11; headless render (design/ui/render, scene roblox/tests/unit/experience/scenes/settings.luau) phone 844x390 and desktop reviewed
---

# Settings panel: audio, reduced motion, graphics (FORGE-03 components; D-038 (4))

## Outcome
Players can open a settings panel and change music and effects volume, turn on reduced motion (camera cuts instead of glides, fewer shakes) and lower graphics effects. Settings persist for the session.

## Context
- D-038 (4); FL-0024 (SettingsService and SettingsController exist; no UI). G13.8 reduced motion is delivered with FL-0100 and reused here.
- FORGE-03 UI components (`roblox/src/shared/UI`).

## Requirements
- Panel built from FORGE-03 components, opened from the HUD (coordinate the rail button with FORGE-03).
- Volume sliders per audio group, reduced-motion toggle, effects-quality toggle; values go through SettingsService.
- Phone layout at 844x390.

## Validation
- Automated: specs for the panel model and SettingsService round trip.
- Render: phone and PC screenshots reviewed.
- Studio (user): experience.md E2.

## Completion criteria
- [ ] Panel merged with specs
- [ ] E2 no longer blocked

## Log
- 2026-10-13 forge-00: created from the backlog audit (D-038) (READY).
- 2026-10-13 forge-04: READY → BUILDING. Started per FORGE-00's D-046 order (after FL-0100 (2/2); FL-0108 waits on #111). On forge/04-experience-fl0103 from main: framework SettingsPanelController + Experience/SettingsModel and SettingsPanel from FORGE-03 components, a rail button through KingdomHudController:addRailItem, and an effectsQuality setting.
- 2026-10-13 forge-04: BUILDING → TESTING. Built: framework SettingsPanelController (rail button through KingdomHudController:addRailItem, drawer as menu 'settings'; own ScreenGui without a host), Experience/SettingsModel and SettingsPanel from FORGE-03's kit, and the effectsQuality setting (VFXController halves particles). Headless render reviewed at phone and desktop; gates next.
