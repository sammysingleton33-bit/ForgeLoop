---
id: FL-0063
title: VS-1 analytics funnel and match analytics
track: build
owner: forge-04
status: REVIEW
priority: P1
game: game-001
created: 2026-10-12
updated: 2026-10-15
depends_on: [FL-0023, FL-0062]
context: [games/game-001/BRIEF.md, games/game-001/CONTRACTS.md]
estimate_h: 3
evidence:
  - "check.sh OVERALL PASS on main 92512a5: framework 489, game-001 787 specs (63 files), Selene 0/0, StyLua 389, both builds and place checks"
  - "MatchAnalytics.spec 7 (real AnalyticsService + game config + real GameEvents bus: G9 attribution, once per step, one session per visit, drop-off point, MatchEnded won/phase/mode, PhaseLeft order/Lobby/Results/spectators, headless) + AnalyticsService.spec startOn/leftInfo + AnalyticsSchema.spec session checks"
  - mutations.py FL-0063 rows 14/14 CAUGHT
  - "unverified: Studio trail (roblox/studio-tests/experience.md E1, events.md §10); real delivery needs a published test place (user)"
  - check.sh OVERALL PASS after the doc-review fixes (game-001 945/0); mutations.py FL-0063 23/23
  - AnalyticsService.spec +5 (milestones x2, boot check, bucket sizing; rate specs re-derived), AnalyticsSchema.spec +1, MatchAnalytics +1, KingdomFeedback +2; mutations FL-0063 39/39
---

# VS-1 analytics funnel and match analytics

## Outcome
We can see where new players drop off in VS-1 and how matches end.

## Requirements
- Funnel: spawn (= KingdomJoined) → first gather → first build placed (credits `Building.placedBy`) → first building complete → first recruit → first capture. Building completions and captures credit every current member of the kingdom (G9).
- Match length and outcome events.

## Validation
Specs with MockAnalyticsService; events.md updated

## Completion criteria
- [ ] Taxonomy reviewed by FORGE-00

## Log
- 2026-10-12 forge-00: created for AI Kingdoms VS-1 (READY).
- 2026-10-12 forge-00: plan review fixes (CONTRACTS v0.4-g2, D-024 to D-028): funnel attribution rules (G9)
- 2026-10-13 forge-04: READY → BUILDING. On forge/04-experience-fl0063 from main 92512a5. FL-0079/FL-0080 (FORGE-01) not landed: conversation and reputation events declared, producers handed off.
- 2026-10-13 forge-04: BUILDING → TESTING. VS1 track rules + Signals subjects; session.startOn KingdomJoined; MatchAnalyticsService (MatchEnded, PhaseLeft via session.leftInfo); headless gates.
- 2026-10-13 forge-04: TESTING → REVIEW. PR from forge/04-experience-fl0063. Taxonomy review by FORGE-00 (completion criterion); FORGE-01 producer calls in handoff forge-04-to-forge-01-00-analytics-fl0063.
- 2026-10-13 forge-04: REVIEW (unchanged). FORGE-05 #64 review + FORGE-00 ruling: M1 repeated funnel steps counted, never logged; M2 VS1 is inOrder (a step only after the previous one). Lows: a draw / shared win is won = draw; a ruler who rejoins as a spectator is not counted; spec gaps (spectator and joinedAt guards, departed rulers forgotten, match clock reset); stale config text. MatchAnalytics.spec 9; FL-0063 mutations 22/22. Main a75de0f merged.
- 2026-10-13 forge-04: REVIEW → REVIEW. Status unchanged (--force). FORGE-00 doc review (2026-10-13-forge-00-to-forge-04-doc-reviews) residue on #64: §4 funnel-order bullet (B1), Return row at session start (M1), FirstGather/FirstRecruit meanings + the inOrder race (M2), KingdomEliminated note (M4), per-event combination budget with a house total < 2,000; ConversationAnswered drops phase, SettingChanged values in tenths (M5, new M); server-only rule (M3 wording); L2/L4/L5/L7 wording; MatchService.mode G3 ask and the G9 CitizenAnswered option in the handoff. Still open for the doc PR: M3 producers for IdleHintShown/CelebrationShown, M7 milestone timing, L1/L3/L6/L8.
- 2026-10-15 forge-04: REVIEW → REVIEW. FORGE-00's 2026-10-13 review items open after #64: M3 CelebrationShown from AnnouncerService on the server (IdleHintShown's producer named; no server dead-air detector yet); M7 MilestoneReached (framework config.milestones, game-001 VS1 + mode); M8 boot check that every track rule has a resolver; L1 §6 is a framework mapping (no game-001 economy events); L3 house economy budgets marked guidance; L6 funnels frozen once published, durable VS1 name pending FORGE-00; L8 per-server bucket = max(20, 0.8 x 20 x players). PACING.md §7 milestone times now from MilestoneReached; #64 'planned' tags removed.
