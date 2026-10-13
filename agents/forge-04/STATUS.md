# FORGE-04 status

_Maintained by the worker. Keep it short and current. Updated 2026-10-13._

| Field | Value |
|---|---|
| Session branch | `forge/04-experience`, plus one `forge/04-experience-<topic>` branch per PR, each from `main` |
| Merged | #15 FL-0061 pacing; #20–#22 FL-0023 analytics, FL-0024 settings/audio/VFX, FL-0025 onboarding; #29 FL-0053 + FL-0090 aerial camera, selection, walk mode; #33 FL-0027 NotificationController; #42 FL-0091 citizen bubbles, strike placards, cues; #45 FL-0092 match30 + onboarding v2; #87 FL-0091 follow-up (v0.4-g6 targets, rest effect); #99 FL-0081 follow-ups (plot-marker and Army-button hints, walk mode unseats) |
| Open PRs (all from `main`, independent of each other) | **this PR** D-038 (7): per-feature files for mutation rows, Studio-test history and the analytics taxonomy (merge first; the rest then move their rows) · #49 FL-0062 feedback layer (★ under D-040, ready for FORGE-05's review) · #64 FL-0063 VS-1 analytics · #82 FL-0027 follow-ups (now also drops `KIND_ICON`) · #84 FL-0100 (1/2) conversation camera (FORGE-07 reviews it last) · #98 FORGE-00 doc reviews (PACING, EXPERIENCE, Subjects M8; FORGE-00 design approved, code waits for FORGE-07) |
| Next | After this PR lands: merge `main` into each open PR and move its rows into `mutations/<task>.py`. Then: the analytics items of FORGE-00's doc review (events M3, M7, L1/L3/L6/L8; AnalyticsService Subjects check) after #64; FL-0100 (2/2) reaction poses on the portrait (`Kit.posePortrait`, FORGE-02 #85) and the world rig (FORGE-01 `playPose`); FL-0103 settings panel (P2, D-038 (4)); the #22 lows |
| Last verified check | #49 `04a78cd` and #82 `623ecb9`, each with main `3d3cb82` merged: `check.sh` OVERALL PASS (game-001 1212/0 and 1181/0); mutations FL-0062 30/30, FL-0027 30/30; CI green on #49. This PR: `check.sh` OVERALL PASS after merging main `4502935` (with #87). Mutations through the per-task files: FL-0091 43/43, FL-0092 21/21, FL-0090 16/16; on the open PRs FL-0063 23/23, FL-0062 28/28, FL-0027 30/30, FL-0061 8/8 (#98), FL-0092 22/22 (#99) |
| Blockers | None of mine. Studio evidence (G6, the user's) for FL-0090, FL-0091, FL-0062 and FL-0063 needs FORGE-01's G13.3 events and ConversationService (#77) and the G9 producers on `main` |
| Needs from others | FORGE-01: `EntityController:playPose`; the ConversationAnswered and ReputationShifted analytics calls (FL-0063 handoff). FORGE-03: G13.8 `ConversationController.opened`/`closed`; `report("CitizenAnswered")`. FORGE-00: an ownership row if `roblox/studio-tests/experience.md` should become one file per section (it is per-section history for now). User: P0 sounds |

## Last report
- D-030 work is in review. #45, #87 and #99 are merged (FORGE-05, D-040 fallback). #49 is ready for its ★ review: music stays silent with placeholder sound ids (spec), and the announcer no longer repeats FORGE-03's recruit toast to the recruiter. FORGE-00's audit and doc-review asks are done on #64 and #98 (design approved; D-044 rulings applied).
- D-038 (7) is this PR. Each task's mutation rows go in its own file, each Studio-test section keeps its own history, and §5 of the analytics taxonomy is split into one file per feature.
- Nothing has been seen or heard in Studio yet (G6 is the user's).
