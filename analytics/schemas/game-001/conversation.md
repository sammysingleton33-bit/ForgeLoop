# Conversations and reputation (FL-0063)

_Part of the AI Kingdoms analytics taxonomy: `analytics/schemas/events.md` §5 (rules, budget and naming live there). D-038 (7): one file per feature, so PRs for different features never edit the same lines._

How rulers answer their citizens, and how their reputation moves. FORGE-01's services produce both events through `AnalyticsService:event` (interfaces §8); the names and fields are declared in `games/game-001/config/Analytics.luau`.

## Custom events (`LogCustomEvent(player, name, value, customFields)`)
| Event | Value | CustomField01 | CustomField02 | CustomField03 | Emitted by | Status |
|---|---|---|---|---|---|---|
| ConversationAnswered | secondsOpen (how long the request waited) | occupation | decision (the content `farm_key`, e.g. `handout_food`, `firm_ruling`, `threat`) | | FORGE-01's ConversationService when `Kingdom.Choose` succeeds, via `AnalyticsService:event` (interfaces §8). No ids or free text | declared (FL-0063); producer pending FORGE-01 |
| ReputationShifted | delta (rounded; negative = down) | category (the six of G13.4) | source (`conversation` \| `action`) | phase | FORGE-01's ReputationService, once per category that changed per decision or action. Fear relaxing over time is **not** logged (it would be a stream) | declared (FL-0063); producer pending FORGE-01 |

## History
- 2026-10-13 FORGE-04: declared (FL-0063, #64); producers pending FORGE-01 (handoff).
