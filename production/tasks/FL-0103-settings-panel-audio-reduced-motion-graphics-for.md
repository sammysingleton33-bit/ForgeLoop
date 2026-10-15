---
id: FL-0103
title: "Settings panel: audio, reduced motion, graphics (FORGE-03 components; D-038 (4))"
track: build
owner: forge-04
status: REVIEW
priority: P2
game: game-001
created: 2026-10-13
updated: 2026-10-15
depends_on: [FL-0024]
context: [games/game-001/CONTRACTS.md, DECISIONS.md, games/game-001/STUDIO_PLAYTEST.md]
estimate_h: 4
evidence:
  - SettingsPanel.spec 8/8; Vfx.spec 17/17; mutations FL-0103 11/11; headless render (design/ui/render, scene roblox/tests/unit/experience/scenes/settings.luau) phone 844x390 and desktop reviewed
  - SettingsController.spec 3/3, SettingsPanel.spec 10/10, Settings.spec 22/22; mutations.py FL-0103 17/17 CAUGHT; headless renders at 3 sizes looked at; Studio E2 unverified
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
- 2026-10-15 forge-04: TESTING → REVIEW. FORGE-07 #123 review: M1 steppers 44 px and regular (44 px) buttons, rows 52 px; M2 phones stack the label over its control (a 260 px drawer never cuts a label), renders committed at 844x390, 667x375 and 1920x1080 (scenes/shots) and looked at; M3 SettingsController coalesces taps (one SetSetting per key after 0.3 s still, under the rate limit) and ignores older echoes while its own change is unanswered (2 s), then the server wins; main merged
