---
id: FL-0092
title: match30 evaluation pacing profile and onboarding v2
track: design
owner: forge-04
status: REVIEW
priority: P1
game: game-001
created: 2026-10-12
updated: 2026-10-15
depends_on: []
context: [games/game-001/design/living-kingdom.md, games/game-001/CONTRACTS.md, games/game-001/BRIEF.md, games/game-001/content/SPEC.md]
estimate_h: 3
evidence:
  - "check.sh OVERALL PASS @bdf9736: framework 485, game-001 112 specs, Selene 0/0, StyLua 203, both builds and place checks"
  - PacingService.spec covers the match30 totals (1,820 s; 25 min kingdom play; Arena 270 s) and validation; Onboarding.spec 11 covers the v2 step triggers
  - mutations.py FL-0092 rows 4/4 CAUGHT
  - "unverified: AnswerCitizen needs FORGE-03 conversation panel report or a G9 CitizenAnswered event; Studio E6 not run"
  - "check.sh OVERALL PASS @3cd506c: framework 486, game-001 518 specs; FL-0092 mutations 5/5 CAUGHT incl. the CitizenInspected hook"
  - "check.sh OVERALL PASS on main d559c9e merged: framework 486, game-001 559 specs (48 files), Selene 0/0, StyLua 337, both builds and place checks; InputMode bare-ground spec + FL-0090 mutations 16/16 CAUGHT"
  - "FORGE-05 hold on #45 (tutorial stalls at AnswerCitizen): step `requires` (passed over while ConversationService is missing) + autoAdvanceSec 120; passed-over or timed-out interactive steps are not funnel steps. Onboarding.spec (framework) 33, game Onboarding.spec 13; FL-0092 mutations 13/13 CAUGHT"
  - "FORGE-05 #45 lows + FORGE-00 ruling: no ConversationService -> AnswerCitizen passed over and the tutorial completes (spec); Arena only in match30 (L1); report() sends only the current step's action (L3); FL-0092 mutations 15/15 CAUGHT"
  - check.sh OVERALL PASS after the FORGE-00 doc-review fixes; game Onboarding.spec 15/0; mutations.py FL-0092 20/20
  - check.sh OVERALL PASS on main d716e51 + #45 (framework 515/0, game-001 962/0); mutations.py FL-0092 21/21
  - "#45 ac97689; check.sh 1029/0; integration-log.md"
  - check.sh OVERALL PASS on main 6c567e5 + FL-0081 follow-ups (game-001 1087/0); mutations.py FL-0092 22/22
  - "main d887beb: check.sh PASS on d6e727f+#99 (game-001 1146/0); CI 3/3 on e240077; onboarding e2e InspectCitizen -> BuildOnPlot -> AnswerCitizen -> Recruit; target mutation caught"
  - "OnboardingTargets.spec 2/2; mutations.py FL-0092 28/28 CAUGHT (new: body Farm, body House or a Farm, 10 start wood in Costs.starting and in Kingdoms.startResources); check.sh OVERALL PASS (lune 528/0, game-001 1432/0). Studio E6 step 4 unverified."
---

# match30 evaluation pacing profile and onboarding v2

## Outcome
A 30-minute match can be evaluated without changing the default, and new players are guided through the new loop.

## Requirements
- Add a `match30` mode to `Pacing.luau` that is not the default (design §6): Lobby 20 s, Founding 5 min, Expansion 7 min, Conflict 8 min, Endgame 5 min, Arena 4.5 min, Results 30 s.
- Onboarding v2 steps: inspect a citizen → build on a plot → answer a citizen → recruit → capture.

## Validation
Pacing spec covers the `match30` totals. Onboarding specs cover the step triggers.

## Completion criteria
- [ ] `bash roblox/scripts/check.sh` OVERALL PASS with the new specs

## Log
- 2026-10-12 forge-00: created for the production priorities update (D-030) (READY).
- 2026-10-12 forge-04: READY → BUILDING. On forge/04-experience-fl0092 from main.
- 2026-10-12 forge-04: BUILDING → TESTING. match30 + onboarding v2 committed; headless gates on bdf9736.
- 2026-10-12 forge-04: TESTING → REVIEW. PR from forge/04-experience-fl0092. AnswerCitizen waits for FORGE-03's CitizenAnswered report (or the proposed G9 event).
- 2026-10-12 forge-04: REVIEW → REVIEW. #29 merged before its last commit: the CitizenInspected selection hook is ported into this PR (cherry-picked onto main).
- 2026-10-12 forge-04: REVIEW (unchanged). Main d559c9e merged. Answered FORGE-03's selection handoff (new handoff forge-04-to-forge-03-selection-rules): both rules already hold; added the bare-ground tap spec and its mutation row.
- 2026-10-13 forge-04: REVIEW (unchanged). FORGE-05 held #45 because the tutorial stalls at AnswerCitizen: steps may `require` a service (passed over without it) and AnswerCitizen auto-advances after 120 s; the funnel counts only what players did. Main (with #33) merged.
- 2026-10-13 forge-04: REVIEW (unchanged). FORGE-00's #45 ruling taken as the early-merge option: without ConversationService step 4 is passed over and the tutorial completes (spec). FORGE-05 lows: L1 later phases only in match30, L2 Pacing.luau comment, L3 OnboardingController:report sends only the current step's action, L4 the selection's tutorial report runs inside a pcall. Main 0a7c9f1 merged.
- 2026-10-13 forge-04: REVIEW → REVIEW. REVIEW (unchanged; --force because the status stays REVIEW). FORGE-00 audit asks: main 3bbf2a0 merged; OnboardingService:_begin ignores a player who already left (player.Parent == nil; #22 ghost-state Low-Medium), spec + mutation row. D-038 (1) evidence: game Onboarding.spec 'without ConversationService, AnswerCitizen is passed over and not counted; the tutorial completes'.
- 2026-10-13 forge-04: REVIEW → REVIEW. REVIEW (unchanged; --force). FORGE-00 doc review (handoff 2026-10-13-forge-00-to-forge-04-doc-reviews): #45 B fixed: a passed-over or timed-out step is logged as its funnel step (Roblox counts skipped steps as done) and also as the new OnboardingStepPassed custom event (step; stepName, via), so real answers stay measurable. M: Recruit/Capture require MilitaryService/ObjectiveService (no wait at Recruit on main); Recruit nudgeAfterSec 180 >= expectSec (PACING M5). L: default-mode and match30 selection wording (PACING §2, handoff); EXPERIENCE §2 example, :25 wording, §8 step names.
- 2026-10-13 forge-04: REVIEW → REVIEW. REVIEW (unchanged; --force). FORGE-05 #45 M1 (D-040 fallback review): the BuildOnPlot hint points at HUD.BuildButton ('Open Build and place a House or a Farm') until FL-0081 declares Build.PlaceSlot, then back to the BuildSlot tag; E6 and EXPERIENCE §2 follow; E6 'not logged' wording corrected to OnboardingStepPassed. Main d716e51 merged.
- 2026-10-13 forge-05: REVIEW → REVIEW. REVIEW at merge of #45 (FORGE-05, D-038 (5); --force because the status stays REVIEW): merged under the D-040 fallback verdict. Remaining: AnswerCitizen/Recruit/Capture steps go live with #77/#70; match30 not played (FORGE-01 chooses the mode); then G6 (experience.md E6).
- 2026-10-13 forge-04: REVIEW → REVIEW. REVIEW (unchanged; --force). FL-0081 on main (FORGE-05 B7 follow-ups): BuildOnPlot hint back to the BuildSlot plot markers (Build.PlaceSlot served); Recruit hint targets HUD.ArmyButton (nothing set HUD.Recruit); E6 steps follow. PR from forge/04-experience-fl0081.
- 2026-10-13 forge-05: REVIEW → REVIEW. Merged #99 (d887beb, FORGE-05 D-040 fallback verdict on e240077; star by FORGE-00 for B9): #45 M1 closed: BuildOnPlot hint on the BuildSlot markers, Recruit hint on HUD.ArmyButton. REVIEW, only G6 pending (STUDIO_PLAYTEST row 12).
- 2026-10-15 forge-04: REVIEW → REVIEW. Hint targets (FORGE-00's #140 ask): OnboardingTargets.spec - world hints name a checked tag (BuildSlot, ObjectiveZone), never a position; the marker nearest each kingdom's spawn is its own small slot, which offers a House (Fit.typesFor) and the server takes it at every turn that fits. A Farm does not fit there, so BuildOnPlot now says 'Tap the marked plot, choose a House, then confirm.' (EXPERIENCE §2, E6 step 4). Passes on main and on main + #140 (no-build areas live). FL-0092 mutations 24/24. The no-build-area check of the markers and the objective joins after #140 merges.
- 2026-10-15 forge-04: REVIEW → REVIEW. FORGE-07 #144 review: M1 OnboardingTargets.spec now reads BuildOnPlot's body (names the House, no Farm); L2 the starting stockpile (Costs.starting and the sim seed) pays for a House before any deposit; L1/L3 spec comments (ObjectiveZone check waits on #140; sim:canPlace, not BuildingService:placeSlot); L4 PACING.md:70 + handoff to FORGE-05 for STUDIO_PLAYTEST.md:264; Q (_nearest picks occupied markers, pre-existing) in the handoff. Main 100e340 merged.
