# Onboarding (FL-0025, FL-0092)

_Part of the AI Kingdoms analytics taxonomy: `analytics/schemas/events.md` §5 (rules, budget and naming live there). D-038 (7): one file per feature, so PRs for different features never edit the same lines._

The tutorial's completion, skips and stuck points. Steps come from `games/game-001/config/Onboarding.luau`.

## Custom events (`LogCustomEvent(player, name, value, customFields)`)
| Event | Value | CustomField01 | CustomField02 | CustomField03 | Emitted by | Status |
|---|---|---|---|---|---|---|
| OnboardingCompleted | durationSec | flow | | | OnboardingService | built |
| OnboardingSkipped | lastStep | lastStepName | flow | | OnboardingService on skip; **no funnel step is logged after it** | built |
| OnboardingHintEscalated | step | stepName | | | OnboardingService when a step passes its nudge time (stuck points) | built |

## Funnels
| Funnel | Roblox method | Kind / session id | Steps | Logged by |
|---|---|---|---|---|
| Onboarding | `LogOnboardingFunnelStepEvent(player, step, stepName, customFields)` | one-time | the 6 steps of `games/game-001/config/Onboarding.luau`: `Spawn` (KingdomJoined), `Gather` (ruler's ResourceGathered), `PlaceBuilding` (BuildingPlaced, placedBy), `BuildingComplete`, `Recruit` (UnitsRecruited), `Capture` (ObjectiveCaptured) | OnboardingService only; nothing after a skip |

Why both Onboarding and VS1: Onboarding counts tutorial completion, and stops at a skip. VS1 counts real progress for everybody, including players who skipped the tutorial or played it on another server. Their difference shows whether the tutorial helps.

## History
- 2026-10-12 FORGE-04: first version (FL-0023, FL-0025); game-001 VS-1 onboarding steps (CONTRACTS v0.4-g2).
- 2026-10-13 FORGE-04: moved out of events.md §5 (D-038 (7)).
