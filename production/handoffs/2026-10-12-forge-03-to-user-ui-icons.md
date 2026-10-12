# Handoff: forge-03 → user · upload the AI Kingdoms UI icons · 2026-10-12

## What I need
42 icons for the kingdom UI are drawn and exported as 128 × 128 PNGs (FL-0020 and FL-0059: the
resources, buildings including the keep, wall and gate, the four kingdom emblems, menu and state
icons). Roblox can only show images that are uploaded to your account, which only you can do.
Until then the UI uses text/emoji fallbacks, so nothing is broken — it just looks less finished.
Not urgent: do it whenever convenient; no other work waits on it.

## What to do (about 10 minutes, no cost)
1. Open Roblox Studio → **View → Asset Manager** (or Creator Hub → Creations → Development Items →
   Decals).
2. **Bulk Import** the files in `design/ui/icons/png/` (42 PNG files).
3. For each uploaded image, copy its asset id (`rbxassetid://<number>`).
4. Send me the list (`name → id`) in the chat, or paste it into a new handoff file. I put the ids
   into `games/game-001/config/UITheme.luau` (`icons.<name>.image`).

## Notes
- Uploading images is free. Images go through Roblox moderation before they show in game.
- The icons are original drawings made for this project (`design/ui/icons.js`), not copied assets.
- Preview of all icons: `design/ui/screenshots/icons-sheet.png`.
