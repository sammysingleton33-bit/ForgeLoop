# Handoff: forge-04 → user · FL-0074 (Crown Arena crowd sounds, 13 to pick later) · 2026-10-18

## What I need / what I'm giving you
13 crowd sounds join the pick list for the Crown Arena (VS-2). This adds to the earlier lists (`2026-10-12-forge-04-to-user-sounds.md`, `2026-10-16-forge-04-to-user-fire-sound.md`, `2026-10-18-forge-04-to-user-war-sounds.md`, `2026-10-18-forge-04-to-user-war-sounds-2.md`), which are merged, so this is a new file.

The list now has **59 sounds**: 20 P0, 18 P1 and 21 P2. These 13 are all P2: the arena is not built yet, so pick them after the P0 and P1 sounds. Pick them the same way: Studio → Toolbox → Creator Store → Audio, then send me the ids. No money and no upload are needed.

| Priority | Sound id | Category | Default volume | Search the Creator Store for | What it should sound like |
|---|---|---|---|---|---|
| P2 | `crowd.roar` | sfx | 0.6 | 'stadium crowd roar' / 'arena crowd cheer loud' (2-3 s) | An Adoring stand roars at its champion's big hit or parry. |
| P2 | `crowd.cheer` | sfx | 0.55 | 'crowd cheer short' / 'audience applause cheer' (1-2 s) | A Loyal stand cheers its champion. |
| P2 | `crowd.mixed` | sfx | 0.5 | 'crowd mixed reaction' / 'cheer and murmur' (1-2 s) | A Divided stand: half cheering, half muttering. |
| P2 | `crowd.scattered` | sfx | 0.45 | 'scattered applause' / 'few people clapping' (1-2 s) | A Restless stand gives a few claps. Also plays at a thin crowning. |
| P2 | `crowd.gasp` | sfx | 0.55 | 'crowd gasp' / 'audience oh' (under 1.5 s) | The stand gasps when its champion is hurt or near defeat. |
| P2 | `crowd.mutter` | sfx | 0.45 | 'crowd murmur disappointed' / 'audience groan' (1-2 s) | A Divided stand mutters when its champion does badly. |
| P2 | `crowd.boo` | sfx | 0.5 | 'crowd boo' / 'audience booing' (1-2 s, no words) | A Restless or Hostile stand boos. Booing only, never words. |
| P2 | `crowd.murmur` | sfx | 0.4 | 'crowd murmur anticipation' / 'audience buzz' (1-2 s) | Anticipation as a champion winds up a heavy attack. |
| P2 | `crowd.chant` | sfx | 0.55 | 'crowd chant stadium' / 'medieval crowd chanting' (2-4 s, no clear words) | A chanting stand. The chant's words show as subtitles, so the sound itself must not have clear words. |
| P2 | `crowd.perk` | sfx | 0.65 | 'fanfare short brass' / 'heroic sting' (under 2 s) | A key citizen's perk fires: a stinger over the crowd. |
| P2 | `crowd.rally` | sfx | 0.7 | 'huge crowd roar rising' / 'stadium eruption' (2-3 s) | The Crowd Rally: the whole Adoring stand roars for its ruler. |
| P2 | `crowd.flood` | sfx | 0.7 | 'crowd celebration victory' / 'cheering crowd running' (3-5 s) | The winner has high support: the stand floods the arena to crown them. |
| P2 | `crowd.salute` | sfx | 0.55 | 'crowd respectful applause' / 'slow clap warm' (2-3 s) | The loser has high support: the stand still salutes them. |

## Done (with commits)
- `games/game-001/config/Sounds.luau`: all 13 entries, status `needed`, no asset (branch `forge/04-experience-crowd`, FL-0074 part 1).
- `games/game-001/config/Crowd.luau` names which reaction plays which sound.

## Evidence
- `games/game-001/tests/experience/CrowdDirector.spec.luau` checks that every sound the crowd names is registered.
- **Unverified:** none of these sounds has been chosen, heard or level-checked.

## Interfaces touched
None.

## Open issues and risks
- Crowd sounds play over each other in the arena. Levels need a listen in Studio once the arena exists. The crowd ducks under the announcer and perk stingers (`Crowd.duck`).

## Next actions for the receiver
1. None now. Pick the P0 and P1 sounds first; these come with the arena (VS-2).

## Files to read
- `production/handoffs/2026-10-12-forge-04-to-user-sounds.md`: the rest of the list and how to pick.
- `games/game-001/config/Crowd.luau`: when each reaction plays.
