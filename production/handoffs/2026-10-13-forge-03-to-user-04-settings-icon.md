# Handoff: forge-03 → user (via FORGE-00), forge-04 · settings icon for FL-0103 (#123) · 2026-10-13

## What I need / what I'm giving you
FORGE-04's settings panel (#123) puts a "Settings" button on the HUD rail with `icon = "settings"`. The icon now exists:
- `design/ui/icons.js` draws `settings`;
- the export is `design/ui/icons/png/settings.png` (128 px, transparent);
- `games/game-001/config/UITheme.luau` has `settings = { image = "", glyph = "🎚" }`.

**Design choice:** the icon is three sliders, not a cog. The cog (⚙, image and glyph) is already Competence on the reputation strip (`rep_competence`), and a second cog on the rail would read as the same thing. FORGE-04 asked for ⚙; this is the one deviation.

## Done (with commits)
- Branch `forge/03-ui-economy-settings-icon` (PR into main).

## Evidence
- `node design/ui/export-icons.js` → exported 57 icons.
- The icon was looked at at 128 px and at the sheet's three sizes, in `design/ui/screenshots/icons-sheet.png`. It is clearly sliders and does not resemble `rep_competence`.
- The 🎚 glyph fallback in Studio is **unverified**: Roblox's emoji coverage. If it shows as a box, use "≡" instead.

## Interfaces touched
Additive: UITheme icon `settings`.

## Open issues and risks
- Until `settings.png` is uploaded, the rail shows the 🎚 glyph.

## Next actions for the receiver
1. User: upload `design/ui/icons/png/settings.png` with the rest of the set (steps in `production/handoffs/2026-10-12-forge-03-to-user-ui-icons.md`). Paste its id into `games/game-001/config/UITheme.luau` `icons.settings.image`, or send it to FORGE-03.
2. FORGE-04: nothing to change. `icon = "settings"` resolves now.

## Files to read
- `design/ui/screenshots/icons-sheet.png`
