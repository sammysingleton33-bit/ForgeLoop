# Handoff: forge-04 → forge-03 · FL-0108 AnswerCitizen on G9 CitizenAnswered · 2026-10-13

## What I need / what I'm giving you
The onboarding AnswerCitizen step now follows FORGE-01's G9 `CitizenAnswered` (#111, FL-0107), credited to the answering ruler. `CitizenAnswered` is no longer a client action (G11, D-044 (4)). Your `onboarding:report("CitizenAnswered")` in ConversationController is therefore ignored by the server and can go.

## Done (with commits)
Branch `forge/04-experience-fl0108`, from main `55ba707`.
- `games/game-001/config/Onboarding.luau`:
  - AnswerCitizen uses `trigger = { bus = "CitizenAnswered" }`.
  - `clientActions` is `{ "GoalAcknowledged", "CitizenInspected" }`.
  - `requires = "ConversationService"` and `autoAdvanceSec = 120` stay, so the tutorial never waits on a request that doesn't come.
- `games/game-001/src/shared/Feedback/Signals.luau`: a `CitizenAnswered` resolver. The subject is the answering player; `info` carries kingdom, decision and secondsOpen, and no ids.
- `roblox/src/shared/Experience/Onboarding.luau`: the framework rule now refuses `autoAdvanceSec` only on **rewarded** bus steps, because a reward needs the real action. An unrewarded bus step may move on, like a client step.

## Evidence
- `lune run roblox/tests/harness/run.luau --project games/game-001/default.project.json --specs games/game-001/tests Onboarding` → 16/16. The new spec checks:
  - a client report no longer counts;
  - a co-ruler's answer doesn't complete my step;
  - my answer does, and is not logged as passed.
- `lune run roblox/tests/harness/run.luau Onboarding` → framework 26/26 and OnboardingController 10/10. A rewarded bus step still can't auto-advance; an unrewarded one can.
- `python3 roblox/tests/unit/experience/mutations.py FL-0108` → 9/9 caught (after FORGE-07's #124 review: the early-action reward, the CitizenAnswered resolver fields and the client whitelist).
- **Unverified:** Studio, `roblox/studio-tests/experience.md` E6 step 4 (the card moves on after a real answer).

## Interfaces touched
- Additive: the `CitizenAnswered` resolver in `Feedback/Signals`.
- Narrowed: the onboarding validation rule. A config valid before is still valid.
- Removed: the client action `CitizenAnswered` (G11 already said it moves to the G9 event).

## Open issues and risks
- Until your call is removed, the client still sends `Experience.OnboardingAction("CitizenAnswered")` after every answer. The server ignores it because it isn't in `clientActions`. It's harmless, but it is a wasted remote call per answer.

## Next actions for the receiver
1. **FORGE-03:** remove `onboarding:report("CitizenAnswered")` from `games/game-001/src/client/Controllers/ConversationController.luau` (around line 318) and its header note (line 37). Then update or drop `CitizenUI.spec` "reports CitizenAnswered once per accepted Choose…" (around line 828).
2. **FORGE-04 (me):** the `ConversationAnswered` analytics half of FL-0108 follows once #64 (FL-0063, which declares that event) is on main. A server subscriber will log it from the same G9 event, so ConversationService never calls AnalyticsService.

## Files to read
- `games/game-001/config/Onboarding.luau` — the AnswerCitizen step.
- `games/game-001/src/shared/Feedback/Signals.luau` — the `CitizenAnswered` row.
