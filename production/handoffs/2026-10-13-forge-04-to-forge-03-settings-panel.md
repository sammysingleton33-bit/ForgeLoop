# Handoff: forge-04 → forge-03 · FL-0103 settings panel · 2026-10-13

## What I need / what I'm giving you
The settings panel exists. It is built from your kit and opens from your HUD rail through `hud:addRailItem`, so your HUD code doesn't change. I need one small thing from you: a `settings` icon (⚙) in game-001's `config/UITheme.luau`. Until then the rail button shows the fallback dot with the label "Settings".

## Done (with commits)
Branch `forge/04-experience-fl0103`, from main `cac9522`.
- **`roblox/src/shared/Experience/SettingsModel.luau`** (pure):
  - Three sections: Sound (master, music, effects, ambience, interface); Motion and effects (reduced motion, camera shake, effects quality); Gameplay (hints, citizen chatter, notifications).
  - Volumes show as whole percentages and step by 10 %.
  - Toggles show On / Off; choices cycle.
  - The device's Reduce Motion is named on the toggle while the in-game toggle is off.
- **`roblox/src/shared/Experience/SettingsPanel.luau`:**
  - Your `Panel` (title on desktop, compact on phones), with a scrolling body.
  - Each volume row is `IconButton` − / `ProgressBar` with its % / `IconButton` +. Each toggle or choice is a small `Button`; "On" uses the `success` variant.
  - Rows are patched in place, never rebuilt under the finger. The right gutter keeps the scroll bar off the controls.
- **`roblox/src/client/Controllers/SettingsPanelController.luau`** (framework):
  - The host is the first controller in `Def.HOSTS = { "KingdomHudController" }` that the registry has.
  - It adds the rail item `{ id = "settings", icon = "settings", label = "Settings", target = "HUD.SettingsButton", order = 9 }` and opens as menu `"settings"` in `metrics().drawer`, under `roots.menus`. It closes on any other menu and redraws on `rendered(metrics)`.
  - Without a host it uses its own ScreenGui (`ForgeSettings`, DisplayOrder 30).
  - Every change goes through `SettingsController:set`.
- **New setting `effectsQuality`** (`full` | `reduced`) in `Experience/Schema`. VFXController halves every effect's particles at `reduced` (`REDUCED_QUALITY = 0.5`); motion is unchanged.

## Evidence
- `lune run roblox/tests/harness/run.luau SettingsPanel` → 8/8. The specs cover:
  - model coverage of every setting;
  - rows and `next()`;
  - the device note;
  - SettingsService accepting the panel's values through `Experience.SetSetting`;
  - the hostless panel: tap, in-place patch, close;
  - disabled ends and a redraw when a setting changes elsewhere;
  - a HUD host: rail item, drawer rect, another menu closes it, destroy removes the rail item.
- `lune run roblox/tests/harness/run.luau Vfx` → 17/17, including effects quality.
- `python3 roblox/tests/unit/experience/mutations.py FL-0103` → 11/11 caught.
- **Render, headless:** `PROJECT=games/game-001/default.project.json DEVICES="phone desktop" bash design/ui/render/shoot-luau.sh roblox/tests/unit/experience/scenes/settings.luau`.
  - I reviewed the phone (844×390) and desktop screenshots. In the first render the right-hand controls ran under the scroll bar; that is fixed with a 12 px gutter.
  - On the phone, about four rows show at once and the rest scroll.
- **Unverified:** Studio (`roblox/studio-tests/experience.md` E2).

## Interfaces touched
Additive:
- the setting `effectsQuality`;
- `Experience/SettingsModel`, `Experience/SettingsPanel`, `SettingsPanelController`;
- the HUD menu id `"settings"` and the rail target `HUD.SettingsButton`.

No change to your controllers.

## Open issues and risks
- The framework controller names `KingdomHudController` as a host by registry name only (no require), the same way games find optional controllers. If you would rather register hosts the other way, for example `hud:registerSettings(panel)`, tell me and I'll switch.
- Rail order 9 puts Settings last. Move it if the rail has a convention.

## Next actions for the receiver
1. Add `settings = { image = "", glyph = "⚙" }` to `games/game-001/config/UITheme.luau` `icons`, and an image when the icon set gets one.
2. Optional: review the panel's look against your kit. Screenshots can be made with the command above.

## Files to read
- `roblox/src/shared/Experience/SettingsPanel.luau` — the view.
- `roblox/src/client/Controllers/SettingsPanelController.luau` — the host contract in its header.
