# FORGE-04 status

_Maintained by the worker. Keep it short and current. Updated 2026-10-13._

| Field | Value |
|---|---|
| Session branch | `forge/04-experience`, plus one `forge/04-experience-<topic>` branch per PR, each from `main` (#121 is stacked on #84) |
| Merged | #15 FL-0061 pacing; #20–#22 FL-0023 analytics, FL-0024 settings/audio/VFX, FL-0025 onboarding; #29 FL-0053 + FL-0090 aerial camera, selection, walk mode; #33 FL-0027 NotificationController; #42 FL-0091 citizen bubbles, strike placards, cues; #45 FL-0092 match30 + onboarding v2; #87 FL-0091 follow-up; #99 FL-0081 follow-ups; #49 FL-0062 feedback layer; #92 D-038 (7) per-feature files |
| Open PRs | #119 FL-0062 follow-up (★, the slice summary owns the result line) · #64 FL-0063 VS-1 analytics · #82 FL-0027 follow-ups · #84 FL-0100 (1/2) conversation camera · #121 FL-0100 (2/2) reaction poses (stacked on #84) · #98 FORGE-00 doc reviews (design approved; code waits for FORGE-07) · FL-0108 (1/2) AnswerCitizen on G9 `CitizenAnswered` · **this PR** FL-0103 settings panel. Each has main `378a671` or later merged, and its rows are in `mutations/<task>.py` |
| Next | FL-0108 (2/2) after #64: ConversationAnswered from a server subscriber on G9 `CitizenAnswered`; #84: the conversation camera in front of the citizen's face (G13.8 v0.4-g9e); the analytics items of FORGE-00's doc review (events M3, M7, L1/L3/L6/L8; AnalyticsService Subjects check) after #64; the #22 lows |
| Last verified check | `check.sh` OVERALL PASS after the D-046 main merge on #84 (game-001 1226/0), #119 (1222/0), #82 (1220/0), #98 (1223/0), #64 (1229/0) and #121 (1234/0); this PR: framework 526/0, game-001 1220/0. Mutations: FL-0100 16/16, FL-0053 22/22, FL-0062 35/35, FL-0027 31/31, FL-0061 8/8, FL-0025 17/17, FL-0063 23/23, FL-0103 11/11 |
| Blockers | None of mine. Studio evidence (G6, the user's) needs FORGE-01's G13.3 events and producers on `main`, FORGE-02's `Kit.posePortrait` (#85) and FORGE-03's FL-0099 for the portrait poses |
| Needs from others | FORGE-01: `EntityController:playPose(entityId, name)` sampling `Feedback/ReactionPoses` (#121 handoff); the ConversationAnswered and ReputationShifted analytics calls (FL-0063 handoff). FORGE-03: `ConversationController.reacted(entityId, tone, portrait?)` (FL-0099); a `settings` icon in game-001 UITheme (FL-0103 handoff). User: P0 sounds |

## Last report
- D-046 integration: #92 merged. Main is merged into every open PR and each PR's rows are moved into the per-task files; each passed `check.sh` and its mutation run.
- FL-0100 (2/2) is #121: one set of reaction poses (cheer, grumble, slump, salute, bow, cower) for the portrait and the world rig, reviewed in a headless box render.
- FL-0103 is this PR: a settings panel built from FORGE-03's kit, opened from the HUD rail, plus an effects-quality setting. Phone and desktop renders were reviewed headless.
- Nothing has been seen or heard in Studio yet (G6 is the user's).
