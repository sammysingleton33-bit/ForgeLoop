# Handoff: forge-03 → user (via FORGE-00) · FL-0105, D-039 · 2026-10-13

## What I need / what I'm giving you
This updates the icon upload list in `2026-10-12-forge-03-to-user-ui-icons.md` after D-039:
- **Add** `gem.png` (the Crown Points icon; Crown Points never use a crown, which is Emberhold's emblem).
- **Add** `emblem_crown.png` (Emberhold's emblem).
- **Skip** `emblem_flame.png`: the flame is retired everywhere and the file is deleted.

Nothing is blocked meanwhile. Until uploaded, the game draws the crest emblems itself, and the Crown Points badge shows the 💎 text glyph.

## Done (with commits)
- PR #86 (branch `forge/03-ui-economy-crest`):
  - `design/ui/icons.js` gains `gem` and `emblem_crown` and drops `emblem_flame`.
  - Exported to `design/ui/icons/png/` (128 px, transparent).

## Evidence
- `node design/ui/export-icons.js` → exported 56 icons. The gem was looked at in `design/ui/screenshots/icons-sheet.png`.
- The in-game look after upload is **unverified** (it needs Studio).

## Interfaces touched
Additive: UITheme icons `gem` and `emblem_crown`. `emblem_flame` is removed (unused since #86).

## Open issues and risks
- An uploaded emblem image replaces the drawn crest emblem, so upload `emblem_crown`, `emblem_star`, `emblem_oak` and `emblem_sun` together, or none of them. That keeps the four crests one family.

## Next actions for the receiver
1. Upload `design/ui/icons/png/gem.png` and `design/ui/icons/png/emblem_crown.png` with the rest of the set, as in the 2026-10-12 handoff.
2. Paste the asset ids into `games/game-001/config/UITheme.luau` under `icons.gem.image` and `icons.emblem_crown.image`, or send them to FORGE-03.

## Files to read
- `production/handoffs/2026-10-12-forge-03-to-user-ui-icons.md`: the upload steps.
- `design/ui/screenshots/icons-sheet.png`: every icon at a glance.
