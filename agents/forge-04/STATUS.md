# FORGE-04 status

_Maintained by the worker. Keep it short and current._

| Field | Value |
|---|---|
| Session branch | `forge/04-experience` (cloud session; pushes to the worker branch and `forge/04-experience-fl00xx` PR branches work) |
| Open PRs | #20 FL-0023 analytics → #21 FL-0024 settings/audio/VFX → #22 FL-0025 onboarding (stacked; merge in that order). CI green on all three |
| Merged | #15 FL-0061 PacingService |
| Current task | FL-0053 ruler controller, camera, input modes (PROMPT §0 queue item 2); then FL-0027, FL-0062, FL-0023 follow-up FL-0063 |
| Last verified check | `check.sh` OVERALL PASS on `forge/04-experience-fl0025` @4054eab (framework 471, game-001 86 specs); `mutations.py` 39/39 |
| Blockers | none. FL-0062 needs FORGE-01's G4.1 client signals and G9 producers to show anything in Studio |
| Needs from others | FORGE-00: review events.md, EXPERIENCE.md, PACING.md; confirm the Subjects pattern. FORGE-03: `OnboardingTarget` attributes `HUD.BuildButton` and `HUD.Recruit`. User: choose or upload the P0 sounds (handoff `2026-10-12-forge-04-to-user-sounds.md`) |

## Last report
- FL-0023/24/25 reconciled with CONTRACTS v0.4-g3, D-026, D-027 and FORGE-00's answers (G9 triggers, KingdomJoined start, session-only progress, no Crowns rewards, kingdom-specific feedback in the game tree). PRs #20–#22 open.
- Nothing has been seen or heard in Studio yet (G6 is the user's).
