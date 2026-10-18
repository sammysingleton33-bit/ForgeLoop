# Handoff: forge-04 → user · FL-0130 (war notices, two more sounds to pick) · 2026-10-18

## What I need / what I'm giving you
Two P1 sounds join the pick list in `2026-10-12-forge-04-to-user-sounds.md` (plus `2026-10-16-forge-04-to-user-fire-sound.md`). Those handoffs are merged, so this file adds to them. The list now has **44 sounds**: 20 P0, 16 P1 and 8 P2. Pick these two with the other P1 sounds, the same way: Studio → Toolbox → Creator Store → Audio, then send me the ids. No money and no upload are needed.

| Priority | Sound id | Category | Default volume | Search the Creator Store for | What it should sound like |
|---|---|---|---|---|---|
| P1 | `kingdom.alarm` | sfx | 0.7 | 'alarm bell' / 'church bell rapid' (urgent, under 3 s) | Enemies crossed our border (a raid): a short urgent bell, clearly different from the war horn. |
| P1 | `kingdom.fallen` | sfx | 0.7 | 'castle collapse' / 'funeral bell toll' (low, about 2 s) | A kingdom's keep fell: one low toll or rumble. It also plays under "Your keep has fallen". |

## Done (with commits)
- `games/game-001/config/Sounds.luau`: both entries, status `needed`, no asset (branch `forge/04-experience-war-feedback`, FL-0130 part 1).

## Evidence
- `games/game-001/tests/experience/KingdomFeedback.spec.luau` checks that every sound named in `Feedback/Lines` is registered. `games/game-001/tests/experience/Sounds.spec.luau` validates the list.
- Until they have assets, both sounds are skipped (`AudioController` skips `needed` entries); the toasts and celebrations still show.
- **Unverified:** not chosen, heard or level-checked.

## Interfaces touched
None.

## Open issues and risks
- FL-0130 part 2 (hits, arrows and building collapse) will add a few more sounds in its own handoff.

## Next actions for the receiver
1. When you pick the P1 sounds, include `kingdom.alarm` and `kingdom.fallen`.

## Files to read
- `production/handoffs/2026-10-12-forge-04-to-user-sounds.md`: the rest of the list and how to pick.
- `roblox/studio-tests/experience.md` E14: where they are heard.
