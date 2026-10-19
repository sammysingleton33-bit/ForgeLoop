# Handoff: forge-04 → user · FL-0074 part 2b (Crown Arena music and stingers, 3 to pick later) · 2026-10-19

## What I need / what I'm giving you
Three more sounds join the pick list for the Crown Arena (VS-2): the arena's music and two short stingers. The earlier lists are merged, so this is a new file (`2026-10-12-forge-04-to-user-sounds.md`, `2026-10-16-forge-04-to-user-fire-sound.md`, `2026-10-18-forge-04-to-user-war-sounds.md`, `2026-10-18-forge-04-to-user-war-sounds-2.md`, `2026-10-18-forge-04-to-user-crowd-sounds.md`).

The list now has **62 sounds**: 20 P0, 18 P1 and 24 P2. These 3 are P2: pick them after the P0 and P1 sounds, the same way as before (Studio → Toolbox → Creator Store → Audio), then send me the ids. No money and no upload are needed.

| Priority | Sound id | Category | Default volume | Search the Creator Store for | What it should sound like |
|---|---|---|---|---|---|
| P2 | `music.arena` | music (loop) | 0.55 | 'epic tournament' / 'medieval arena drums brass' | The arena from the intro to the crowning: a festive, tense tournament loop. It plays over the battle music; the victory or defeat music still replaces it at the end. |
| P2 | `arena.horn` | sfx | 0.7 | 'medieval herald horn' / 'tournament horn call' (2-3 s) | The intro begins and the gates open: one herald's horn call. |
| P2 | `arena.fanfare` | sfx | 0.7 | 'royal fanfare trumpets' / 'coronation fanfare' (3-5 s) | A champion is crowned. It never plays when the duel is called off. |

## Done (with commits)
- `games/game-001/config/Sounds.luau`: all 3 entries, status `needed`, no asset (branch `forge/04-experience-arena-stage`, FL-0074 part 2b).
- `games/game-001/src/client/Controllers/CrowdStageController.luau` plays them; `MusicController:setScene("arena")` plays `music.arena`.

## Evidence
- `games/game-001/tests/experience/Sounds.spec.luau` checks every entry is a valid registry entry and still `needed`; `CrowdStage.spec` checks when each one plays (headless).
- **Unverified:** none of these sounds has been chosen, heard or level-checked.

## Interfaces touched
None.

## Open issues and risks
- `music.arena` and the crowd sounds play together. Their levels need one listen in Studio once the arena runs (E18 step 5, then E17 step 5).
- Until `music.arena` is picked, the arena keeps the match music (battle or phase music) rather than going silent, so it is safe to pick it after the P0 and P1 music.

## Next actions for the receiver
1. None now. Pick the P0 and P1 sounds first; these come with the arena (VS-2).
