# FORGE-04 status

_Maintained by the worker. Keep it short and current._

| Field | Value |
|---|---|
| Session branch | `forge/04-experience` (cloud session; pushes to the worker branch and the `forge/04-experience-fl00xx` PR branches work) |
| Merged | #15 FL-0061 pacing; #20–#22 FL-0023 analytics, FL-0024 settings/audio/VFX, FL-0025 onboarding; #29 FL-0053 + FL-0090 aerial camera, selection, walk mode; #33 FL-0027 NotificationController |
| Open PRs (independent of each other, all from `main`; FORGE-05's order #42 → #45 → #49, then #64) | #42 FL-0091 citizen bubbles + the VFXController Model fix · #45 FL-0092 match30 + onboarding v2 (no stall at AnswerCitizen) · #49 FL-0062 announcer, kingdom effects, work feedback, music · #64 FL-0063 VS-1 analytics funnel, sessions, match analytics |
| Next | FORGE-05's re-reviews; FL-0074 crowd director design (VS-2, slack time); low follow-ups on merged #22/#29 (ambience voice, music fade, shake NaN) |
| Last verified check | `check.sh` OVERALL PASS on every open PR head after merging `main` with #33 (evidence in each task file); `mutations.py` per task: FL-0091 25/25, FL-0092 13/13, FL-0062 21/21, FL-0063 14/14, FL-0027 22/22 |
| Blockers | none of mine. Studio evidence for FL-0090/0091/0062/0063 needs FORGE-01's EntityController G13.3 events, ConversationService and G9 producers on `main` |
| Needs from others | FORGE-01: G13.3 events through EntityController (per citizen), `playPose`, LOD centre = camera focus in overview, the `swing` local cue, ConversationAnswered/ReputationShifted analytics calls (handoffs). FORGE-00: G9 `CitizenAnswered`, SPEC §5.4 `cue`/`cueId`, taxonomy review (FL-0063), FirstGather under D-030, interfaces §8 text. FORGE-03: `report("CitizenAnswered")`, `NotificationController:place(...)` from the HUD. User: P0 sounds |

## Last report
- D-030 work is in review: aerial camera default with tap selection (merged); citizen bubbles and consequence cues aligned to G13.3 and the content library; `match30` and onboarding v2.
- The VS-1 feedback layer (FL-0062) and the VS-1 analytics (FL-0063) are in review; FORGE-05's review findings are fixed and answered on each PR.
- Nothing has been seen or heard in Studio yet (G6 is the user's).
