# Handoff: forge-04 → user · FL-0130 part 2 (battle sounds, two more to pick) · 2026-10-18

## What I need / what I'm giving you
Two more P1 sounds join the pick list. It adds to `2026-10-12-forge-04-to-user-sounds.md`, `2026-10-16-forge-04-to-user-fire-sound.md` and `2026-10-18-forge-04-to-user-war-sounds.md`, which are merged or in review, so this is a new file. The list now has **46 sounds**: 20 P0, 18 P1 and 8 P2. Pick these with the other P1 sounds, the same way: Studio → Toolbox → Creator Store → Audio, then send me the ids. No money and no upload are needed.

| Priority | Sound id | Category | Default volume | Search the Creator Store for | What it should sound like |
|---|---|---|---|---|---|
| P1 | `war.hit` | sfx | 0.45 | 'sword clash short' / 'shield hit' (metal, under 0.4 s) | A soldier or citizen takes a hit near the view: one short metal clash, no gore. |
| P1 | `war.collapse` | sfx | 0.7 | 'building collapse' / 'wood crash debris' (about 2 s) | A building is destroyed: timber and stone crashing down. |

## Done (with commits)
- `games/game-001/config/Sounds.luau`: both entries, status `needed`, no asset (branch `forge/04-experience-war-client`, FL-0130 part 2).

## Evidence
- `games/game-001/tests/experience/WarFeedback.spec.luau` checks that both sounds are registered, `needed` and without an asset.
- **Unverified:** not chosen, heard or level-checked.

## Interfaces touched
None.

## Open issues and risks
- None.

## Next actions for the receiver
1. When you pick the P1 sounds, include `war.hit` and `war.collapse`.

## Files to read
- `production/handoffs/2026-10-12-forge-04-to-user-sounds.md`: the rest of the list and how to pick.
- `roblox/studio-tests/experience.md` E15: where they are heard.
