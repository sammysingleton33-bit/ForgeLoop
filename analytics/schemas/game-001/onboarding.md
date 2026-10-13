# Onboarding (FL-0025, FL-0092)

_Part of the AI Kingdoms analytics taxonomy: `analytics/schemas/events.md` §5 (rules, budget and naming live there). D-038 (7): one file per feature, so PRs for different features never edit the same lines._

The tutorial's completion, skips, stuck points and passed steps. Steps come from `games/game-001/config/Onboarding.luau`.

## Custom events (`LogCustomEvent(player, name, value, customFields)`)
| Event | Value | CustomField01 | CustomField02 | CustomField03 | Emitted by | Status |
|---|---|---|---|---|---|---|
| OnboardingCompleted | durationSec | flow | | | OnboardingService | built |
| OnboardingSkipped | lastStep | lastStepName | flow | | OnboardingService on skip; **no funnel step is logged after it** | built |
| OnboardingHintEscalated | step | stepName | | | OnboardingService when a step passes its nudge time (stuck points) | built |
| OnboardingStepPassed | step | stepName | via (`unavailable` \| `timeout`) | | OnboardingService when a step is passed over or an interactive step times out (also logged as its funnel step) | built (FL-0092) |

## Funnels
| Funnel | Roblox method | Kind / session id | Steps | Logged by |
|---|---|---|---|---|
| Onboarding | `LogOnboardingFunnelStepEvent(player, step, stepName, customFields)` | one-time | the 6 steps of `games/game-001/config/Onboarding.luau` (v2, D-030): `Spawn` (KingdomJoined), `InspectCitizen` (client action `CitizenInspected`), `BuildOnPlot` (BuildingPlaced, placedBy), `AnswerCitizen` (client action `CitizenAnswered`; G9 `CitizenAnswered` proposed; `requires = ConversationService`, so the step is passed over while that service is missing, and `autoAdvanceSec = 120`), `Recruit` (UnitsRecruited; `requires = MilitaryService`), `Capture` (ObjectiveCaptured; `requires = ObjectiveService`). InspectCitizen and AnswerCitizen are **client-reported** steps that grant nothing (G11 wording pending FORGE-00). Every step is logged when it completes or is passed: Roblox counts a skipped step as completed anyway, so a step passed over (`unavailable`) or a timed-out interactive step is logged too and **also** as `OnboardingStepPassed`; step n of this funnel therefore means "reached past step n", and real answers = AnswerCitizen − OnboardingStepPassed(stepName AnswerCitizen) | OnboardingService only; nothing after a skip |

Why both Onboarding and VS1: Onboarding counts tutorial completion, and stops at a skip. VS1 counts real progress for everybody, including players who skipped the tutorial or played it on another server. Their difference shows whether the tutorial helps.

## History
- 2026-10-12 FORGE-04: first version (FL-0023, FL-0025); game-001 VS-1 onboarding steps (CONTRACTS v0.4-g2).
- 2026-10-13 FORGE-04 (FL-0092): onboarding v2 steps (D-030); passed-over and timed-out steps are logged and also sent as OnboardingStepPassed.
- 2026-10-13 FORGE-04: moved out of events.md §5 (D-038 (7)).
