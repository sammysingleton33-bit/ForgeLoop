# FORGE-04 status

_Maintained by the worker. Keep it short and current. Updated 2026-10-15._

| Field | Value |
|---|---|
| Session branch | one `forge/04-experience-<topic>` branch per PR, each from `main` (never reused after a merge) |
| Merged since 2026-10-13 | #64 FL-0063 analytics; #82 FL-0027 follow-ups; #98 PACING/EXPERIENCE reviews; #84 + #121 FL-0100 conversation camera and reaction poses (B14); #133 FL-0115 bubbles readable from the air (B15); #134 E9/E10 operator probes; #137 hover and selection outlines; #143 hover-clear spec |
| Open PRs | #123 FL-0103 settings panel (FORGE-07 M1–M3 done) · #124 FL-0108 (1/2) AnswerCitizen on G9 · #130 back key (gamepad B / Backspace, topmost wins) · #142 FL-0121 edit mode and camera (G13.9) · #144 onboarding hint targets (FORGE-00's #140 ask; BuildOnPlot names the House) · #146 FL-0108 (2/2) ConversationAnswered from G9 (stacked on #124) · #147 FL-0063 analytics review items (MilestoneReached, server CelebrationShown, per-server rate share, FirstMatch) · this PR: FL-0115 B16 off-screen request badges and the cycle key |
| Next | After #140 merges: the objective-zone vs `Layout.reservedAreas` check. After the operator runs B14/B16 in Studio: conversation camera and interaction polish from what they saw. FL-0026 retention stays SPECIFIED (after VS-1, pending BRIEF §16.1/§16.5) |
| Last verified check | Each open PR's head: `check.sh` OVERALL PASS and its mutation rows all caught (numbers in each PR body). This PR: RequestIndicators 13/13, FL-0115 46/46, FL-0091 43/43; renders looked at |
| Blockers | None of mine. Studio evidence (E2, E6, E9–E13) waits for the local Studio operator once the features are integrated; nothing here is claimed as Studio-verified |
| Needs from others | FORGE-00: research N3 note (rate-cap scope unverified, #147). FORGE-03: wire `onBack` (#130); optional `cycleRequests()`/`count()` in the "citizens waiting" control; tell me if F or DPad left/right clash in explore mode. FORGE-05: `STUDIO_PLAYTEST.md:264` "House or Farm" (#144). FORGE-01: nothing open |

## Last report
- The user's playtest feedback (citizen chat bubbles hard to see and act on from the air): B15 made bubbles readable and tappable (#133), hover outlines (#137). This PR adds edge badges for requests off screen and a key to go to them. All of it is headless-verified only (specs, mutation rows, renders), not played in Studio.
- Analytics after #64: ConversationAnswered from the G9 event (#146) and FORGE-00's remaining review items (#147). The VS-1 funnel is now `FirstMatch` (D-050 (7)).
