# Handoff: forge-04 → forge-00 · taxonomy ready for review; experience spec; pacing doc · FL-0061/0023/0025/0062 · 2026-10-12

## What I need
This is the note you asked for in `2026-10-12-forge-00-answers-to-02-03-04-ai-kingdoms.md` §6: **`analytics/schemas/events.md` is aligned and ready for review.** I'm asking for three reviews:
1. `analytics/schemas/events.md`: FL-0023's completion criterion (the taxonomy review), in the FL-0023 PR.
2. `games/game-001/design/pacing/EXPERIENCE.md`: the first-session experience spec the user asked FORGE-04 for, also in the FL-0023 PR. It covers:
   - pillars and the VS-1 minute-by-minute flow;
   - the feedback matrix on G4.1/G9;
   - audio, VFX and notifications;
   - retention proposals, analytics and open questions.
3. `games/game-001/design/pacing/PACING.md`: FL-0061's completion criterion. The doc merged with PR #15; the review is still open.

## Your answers, applied
| Your point | Where it is now |
|---|---|
| Contract phases (G2) and BRIEF §3 timings | PACING.md and EXPERIENCE.md use Lobby / Founding / Expansion / Conflict / Endgame / Results, with Arena noted for VS-2 (G12). Game pacing lives only in the game tree (FL-0061). |
| Onboarding from G9: gather → build → recruit → capture | `games/game-001/config/Onboarding.luau` has Spawn (`KingdomJoined`), Gather, PlaceBuilding, BuildingComplete, Recruit and Capture. It uses no non-contract events, and the gaps I proposed are withdrawn. |
| The keep, not a Town Hall | The keep everywhere, including the keep level-2 fanfare in the feedback matrix. |
| No currency rewards in VS-1, and no "Crowns" | Removed from config, docs and the FORGE-03 handoff. |
| Spec home `design/pacing/` | `games/game-001/design/pacing/EXPERIENCE.md`. |
| Feedback pipeline in game paths; the framework stays genre-agnostic | Kingdom attribution is in `games/game-001/src/shared/Feedback/Signals.luau`. The kingdom presets and cues come with FL-0062. The framework keeps a generic CueDirector, MusicDirector and VFXController. |
| VS1 funnel = BRIEF §13 with G9 attribution | events.md §5. The track rules are FL-0063. |

## What I'm giving you
- My work is reconciled with CONTRACTS v0.4-g3 (G1–G11 unchanged) and D-024–D-029:
  - DataService is optional; settings and onboarding progress last for the session only without it (D-027).
  - Onboarding starts on `KingdomJoined`.
- **A new framework extension point, `Experience/Subjects`.**
  - A game passes resolvers for its own events through config. A resolver says who an event is about.
  - game-001's G9 attribution rules live in `Feedback/Signals.luau`, and the game configs hand them to the framework services.
  - The framework still never requires game code.

  Please confirm this pattern is fine for future games.

## Assumptions to confirm with the user (EXPERIENCE.md §9)
- Mid-match joiners get the tutorial (a proposal; BRIEF §16.3).

## Evidence
- `bash roblox/scripts/check.sh` OVERALL PASS on `forge/04-experience`: 471 framework specs and 71 game-001 specs, including the boot gate.
- `mutations.py`: 41/41 rows caught.
- Per-PR evidence is in each PR body.

## Next actions for the receiver
1. Review the three documents. Reply in the PRs or by handoff.
2. Confirm or reject the Subjects pattern.
