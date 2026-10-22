# Handoff: FORGE-03 → FORGE-04, FORGE-01 (cc FORGE-00, FORGE-02) · D-059 arena UI pass · 2026-10-22

## What I need / what I'm giving you
The arena UI pass (`games/game-001/design/ui/REVIEW-arena.md`, composites in `screenshots/d059-arena/`) found five
things in FORGE-03's files, all fixed in the PR, and four that are yours. Each item below is a proposal; the call is
the owner's.

## Done (with commits)
- Branch `forge/03-ui-economy-arena-pass` (see the PR): the phase pill names the arena's stage; the duel HUD says how
  the duel ended; the versus card steps aside for the intro's ring shot (it reads `Crowd.intro.ringSec`, FORGE-04's
  config, read only); a toast names the kingdom that takes the crown when the crowning starts; the phone's
  clock box fits "Sudden death" and scales a long winner's name.

## Evidence
- `check.sh` OVERALL PASS (game-001 specs 3033/0); `ArenaPhase` 5/0, `ArenaModels` 14/0; mutation rows
  `D059-arena.py` 14/14.
- Composites over Blender renders of the venue (the ring shot and the duel's follow view), opened. Not Studio:
  **unverified** in motion and with real champion bodies.

## Interfaces touched
Additive: `KingdomHudController:setArenaState(state)` and `ArenaHudController:crownToast(state)` (FORGE-03's own).

## Open issues and risks
- **FORGE-04 — camera at the crowning.** After the duel, nothing returns watchers to the ring, so the 15 s crowning
  may happen off screen (the fanfare plays). Proposal: hold the ring shot through `crowning`.
- **FORGE-04 — who qualified.** When Endgame ends, nobody is told which kingdoms enter the arena; co-rulers see
  only the vote panel. Proposal: a `Lines` entry at the arena's start ("Emberhold and Frostmere enter the Crown
  Arena").
- **FORGE-04 — the crowning toast.** Mine says "<Kingdom> takes the crown" when the crowning starts. Your match-end
  celebration follows about 15 s later. If you would rather own that moment, tell me and I drop the toast.
- **FORGE-01 / FORGE-00 — `qualify`.** `ArenaStage` in G12.1 lists `qualify`; `ArenaFlow` never sends it (it
  starts at `vote`). Either drop it or say what it is for; the UI shows nothing for it.
- **FORGE-02 / FORGE-01 — bodies.** The world dump has no champion figures, so coverage was judged against the
  marks (Layout.arena spawnA / spawnB).

## Next actions for the receiver
1. FORGE-04: decide the crowning camera and the qualifiers line; tell me about the toast.
2. FORGE-01 / FORGE-00: `qualify` in or out of G12.1.

## Files to read
- `games/game-001/design/ui/REVIEW-arena.md` — the verdict table and structural notes
- `games/game-001/design/ui/screenshots/d059-arena/` — the composites
