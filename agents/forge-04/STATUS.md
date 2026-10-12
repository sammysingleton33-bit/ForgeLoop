# FORGE-04 status

_Maintained by the worker. Keep it short and current._

| Field | Value |
|---|---|
| Session branch | `forge/04-experience` (cloud session; pushes to the worker branch and the `forge/04-experience-fl00xx` PR branches work) |
| Merged | #15 FL-0061 pacing; #20–#22 FL-0023 analytics, FL-0024 settings/audio/VFX, FL-0025 onboarding |
| Open PRs (independent of each other, all from `main`) | #29 FL-0053 + FL-0090 aerial camera, selection, walk mode · #33 FL-0027 NotificationController on FORGE-03's Toast · #42 FL-0091 citizen bubbles · #45 FL-0092 match30 + onboarding v2 · #49 FL-0062 announcer, kingdom effects, work feedback, music |
| Next | FL-0063 VS-1 funnel track rules (G9 attribution, Signals); FL-0074 crowd director design (VS-2, slack time) |
| Last verified check | `check.sh` OVERALL PASS on every open PR head (evidence in each task file); `mutations.py` on the combined worker: 102/102 caught before FL-0062, 10/10 FL-0062 rows on #49 |
| Blockers | none of mine. Studio evidence for FL-0053/0090/0091/0062 needs FORGE-01's spawn/seat, EntityController and G9 producers on `main` |
| Needs from others | FORGE-01: `swing`/`consequence` cues, entity-scoped `strike`, `playPose`, `Kingdom.name` (handoffs). FORGE-00: G9 `CitizenAnswered`, content cue ids; reviews of events.md, EXPERIENCE.md, PACING.md. FORGE-03: `CitizenAnswered` report, `OnboardingTarget` attributes, listen to `selected`. FORGE-05: `EnableMouseLockOption = false`, playtest rows. User: P0 sounds |

## Last report
- D-030 work is in review: the aerial camera is the default with tap selection (G13.6); citizen bubbles (G13.3); `match30` and onboarding v2.
- The VS-1 feedback layer (FL-0062) is in review.
- Nothing has been seen or heard in Studio yet (G6 is the user's).
