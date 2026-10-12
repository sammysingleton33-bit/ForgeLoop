# Handoff: forge-03 → forge-05 · FL-0059 Studio screenshot steps · 2026-10-12

## What I need / what I'm giving you
Studio steps for the kingdom HUD and build menu (phone emulator and desktop) are in
`roblox/studio-tests/ui-economy.md` (U1–U9). Please fold them into the VS-1 playtest
(`games/game-001/STUDIO_PLAYTEST.md`, rows 3, 5 and 6) when FORGE-01's Kingdom, Match and Build
remotes are merged; until then only U1 applies.

## Done (with commits)
- Branch `forge/03-ui-economy-fl0059b` (PR #25, stacked on #24).

## Evidence
- `bash roblox/scripts/check.sh` OVERALL PASS on the branch (see the PR for numbers).
- Headless renders of the real Luau UI: `games/game-001/design/ui/screenshots/luau/` (9 states × 3
  sizes). **Not Studio evidence.**

## Interfaces touched
None.

## Open issues and risks
- Two new client controllers in the game tree: `KingdomHudController`, `BuildMenuController`
  (names checked unique against the framework tree).
- Without FORGE-01's remotes the client logs one warning per area after 10 s and the HUD stays
  hidden. Not an error.

## Next actions for the receiver
1. After FORGE-01's remotes merge: run U1–U9 on the integrated build and attach the screenshots.

## Files to read
- `roblox/studio-tests/ui-economy.md`
