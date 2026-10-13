# FORGE-04 status

_Maintained by the worker. Keep it short and current. Updated 2026-10-13._

| Field | Value |
|---|---|
| Session branch | `forge/04-experience`, plus one `forge/04-experience-<topic>` branch per PR, each from `main` |
| Merged | #15 FL-0061 pacing; #20–#22 FL-0023 analytics, FL-0024 settings/audio/VFX, FL-0025 onboarding; #29 FL-0053 + FL-0090 aerial camera, selection, walk mode; #33 FL-0027 NotificationController; #42 FL-0091 citizen bubbles, strike placards, cues; #45 FL-0092 match30 + onboarding v2 |
| Open PRs (all from `main`, independent of each other) | **this PR** D-038 (7): per-feature files for mutation rows, Studio-test history and the analytics taxonomy (merge first; the rest then move their rows) · #64 FL-0063 VS-1 analytics · #49 FL-0062 feedback layer · #87 FL-0091 follow-up (v0.4-g6 `entityIds`, `rest` effect, #42 lows) · #82 FL-0027 follow-ups · #84 FL-0100 (1/2) conversation camera (FORGE-07 reviews it last) |
| Next | After this PR lands: merge `main` into each open PR and move its rows into `mutations/<task>.py`. Then: the doc PR for FORGE-00's 2026-10-13 doc reviews (PACING B1/B2, EXPERIENCE, Subjects M8/M9); FL-0100 (2/2) reaction poses on the portrait (`Kit.posePortrait`, FORGE-02 #85) and the world rig (FORGE-01 `playPose`); FL-0103 settings panel (P2, D-038 (4)); the #22 lows |
| Last verified check | `check.sh` OVERALL PASS on this PR after merging main `b1a4f81` (with #45). Mutations through the per-task files: FL-0092 21/21, FL-0090 16/16; on the open PRs FL-0063 23/23, FL-0062 28/28, FL-0091 40/40, FL-0027 30/30 |
| Blockers | None of mine. Studio evidence (G6, the user's) for FL-0090, FL-0091, FL-0062 and FL-0063 needs FORGE-01's G13.3 events and ConversationService (#77) and the G9 producers on `main` |
| Needs from others | FORGE-01: `EntityController:playPose`; the ConversationAnswered and ReputationShifted analytics calls (FL-0063 handoff). FORGE-03: G13.8 `ConversationController.opened`/`closed`; `report("CitizenAnswered")`. FORGE-00: an ownership row if `roblox/studio-tests/experience.md` should become one file per section (it is per-section history for now). User: P0 sounds |

## Last report
- D-030 work is in review. #45 is merged (FORGE-05, D-040 fallback). FORGE-00's audit and doc-review asks are done on #64; #49 has main merged. The rest of the doc review (PACING, EXPERIENCE, Subjects) is the next doc PR.
- D-038 (7) is this PR. Each task's mutation rows go in its own file, each Studio-test section keeps its own history, and §5 of the analytics taxonomy is split into one file per feature.
- Nothing has been seen or heard in Studio yet (G6 is the user's).
