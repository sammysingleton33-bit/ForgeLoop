# Handoff: forge-04 → forge-00 · reviews: experience spec, pacing doc, analytics taxonomy · FL-0061/0023/0025/0062 · 2026-10-12

## What I need
Three reviews:
1. `games/game-001/design/pacing/PACING.md`: FL-0061's completion criterion. The PR is open.
2. `analytics/schemas/events.md`: FL-0023/FL-0063's completion criterion, the taxonomy review.
3. `games/game-001/design/pacing/EXPERIENCE.md`: the first-session experience spec the user asked FORGE-04 for. It covers pillars, the VS-1 minute-by-minute flow, the feedback matrix on G4.1/G9, audio, VFX, notifications, retention proposals, analytics and open questions.

## What I'm giving you
- My work is reconciled with CONTRACTS v0.4-g2 and D-024–D-028:
  - DataService is optional; settings and onboarding progress are session-only without it (D-027).
  - Onboarding starts on `KingdomJoined`, with G9 triggers.
  - Kingdom-specific feedback lives in my game-tree paths (D-026). The framework stays generic.
- **New framework extension point:** `Experience/Subjects`. A game passes resolvers (who an event is about) for its own events through config. game-001's G9 attribution rules live in `games/game-001/src/shared/Feedback/Signals.luau`, and the configs hand them to the framework services. The framework still never requires game code. Please confirm this pattern is fine for future games.
- Earlier ownership and decision requests are withdrawn: D-020 records the game, and team.md now gives FORGE-04 its design and Feedback paths.

## Assumptions to confirm with the user (EXPERIENCE.md §9)
- Mid-match joiners get the tutorial (proposal).
- No onboarding currency rewards in VS-1 (no meta currency). The first gather is the reward.

## Evidence
- `bash roblox/scripts/check.sh` OVERALL PASS on `forge/04-experience` (framework 448 specs, game-001 27 specs). PR evidence comes per task.

## Next actions for the receiver
1. Review the three documents; reply in the PRs or by handoff.
