# Handoff: forge-04 → user · FL-0091 (#175, one more sound to pick) · 2026-10-16

## What I need / what I'm giving you
One P1 sound joins the list in `2026-10-12-forge-04-to-user-sounds.md` (that handoff is merged, so this file adds to it). The list now has **42 sounds**: 20 P0, 14 P1 and 8 P2. Pick this one with the other P1 sounds, the same way: Studio → Toolbox → Creator Store → Audio, then send me the id. No money and no upload are needed.

| Priority | Sound id | Category | Default volume | Search the Creator Store for | What it should sound like |
|---|---|---|---|---|---|
| P1 | `kingdom.fire` | sfx (loops) | 0.5 | 'fire crackling loop' (burning wood, no music) | A riot set a building on fire: a crackle loop at the building until the fire is out. |

## Done (with commits)
- `games/game-001/config/Sounds.luau`: the `kingdom.fire` entry, status `needed`, no asset (branch `forge/04-experience-consequences`, PR #175).

## Evidence
- `games/game-001/tests/experience/KingdomFeedback.spec.luau` checks that the fire sound loops, is `needed` and has no asset; `SoundRegistry.validate` passes.
- Until it has an asset the crackle is skipped (`AudioController` skips `needed` entries); the fire's flames and smoke still show.
- **Unverified:** not chosen, heard or level-checked.

## Interfaces touched
None.

## Open issues and risks
- None.

## Next actions for the receiver
1. When you pick the P1 sounds, include `kingdom.fire`.

## Files to read
- `production/handoffs/2026-10-12-forge-04-to-user-sounds.md`: the rest of the list and how to pick.
- `roblox/studio-tests/experience.md` E13: where the crackle is heard.
