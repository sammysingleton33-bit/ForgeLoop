# FORGE-04 status

_Maintained by the worker. Keep it short and current. Updated 2026-10-16._

| Field | Value |
|---|---|
| Session branch | one `forge/04-experience-<topic>` branch per PR, each from `main` (never reused after a merge) |
| Merged since 2026-10-13 | #64 FL-0063 analytics; #82 FL-0027 follow-ups; #98 PACING/EXPERIENCE reviews; #84 + #121 FL-0100 conversation camera and reaction poses (B14); #133 FL-0115 bubbles readable from the air (B15); #134 E9/E10 operator probes; #137 hover and selection outlines; #143 hover-clear spec; #130 back key (gamepad B / Backspace); #142 FL-0121 edit mode and camera (G13.9); #149 FL-0115 B16 off-screen request badges and the cycle key; #123 FL-0103 settings panel; #124 + #146 FL-0108 AnswerCitizen and ConversationAnswered from G9 CitizenAnswered; #144 onboarding hint targets (House only); #157 FL-0121 B17 follow-up (E12 for the Move flow, no camera pan on an edit-mode tap); #147 FL-0063 analytics review items (MilestoneReached, server CelebrationShown, per-server rate share, FirstMatch); #163 FL-0025 completeReward only when a step was server-verified (D-052 (3)); #164 FL-0053 `isTap` and E11 (FORGE-03's back-key wiring, #162); #165 FL-0092 hint targets clear of the no-build areas; #170 FL-0115 `CitizenBubbleIndicatorController:active()` for FORGE-03's Waiting button (#168); #175 FL-0091 consequences read from the air (riot placard, fire on burning buildings, G9 `ConsequenceChanged` notices; B19) |
| Open PRs | #177 FL-0061 PACING slice income targets from `design/economy.md` (FORGE-03's #110) |
| Next | After the operator runs B14–B17 (and B19's E13) in Studio: conversation camera and interaction polish from what they saw (the user's bubble feedback). FL-0026 retention stays SPECIFIED (after VS-1, pending BRIEF §16.1/§16.5) |
| Last verified check | #175: `check.sh` OVERALL PASS (game-001 1707/0), FL-0091 63/63 CAUGHT, ownership PASS; FORGE-05's merge gate on main 5804293 matched. #177: doc only, validate 124/0, pytest 453, ownership PASS, CI green on 591aec7 |
| Blockers | None of mine. Studio evidence (E1, E2, E6, E8 step 13, E9–E13) waits for the local Studio operator; nothing here is claimed as Studio-verified |
| Needs from others | FORGE-00: research N3 note (rate-cap scope unverified, #147). FORGE-03: FL-0123 confirm-on-release with `isTap`. User: the `kingdom.fire` sound with the P1 sounds (handoff `2026-10-16-forge-04-to-user-fire-sound.md`). FORGE-01: nothing open |

## Last report
- Consequences read from the air (FL-0091, #175, merged for B19): rioters show an orange "Rioting" placard, a burning building shows flames and smoke above its roof, and G9 `ConsequenceChanged` gives the kingdom's rulers one toast per start and end. Headless only: the fire and placard visuals have not been seen (E13).
- The user's playtest feedback (citizen chat bubbles hard to see and act on from the air): B15 made bubbles readable and tappable (#133), hover outlines (#137), and B16 added edge badges for off-screen requests and a key to cycle them (#149). All of it is headless-verified (specs, mutation rows, renders), not played in Studio.
- Analytics after #64 are done (#146, #147); the VS-1 funnel is `FirstMatch` (D-050 (7)). Onboarding pays a completion reward only for a flow with a server-verified step (#163, D-052 (3)).
- Base editing (B17): edit mode and camera (#142), E12 for the Move flow (#157); the drag gesture and edge-pan are parked (FL-0123).
