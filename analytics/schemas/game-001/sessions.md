# Sessions and return (FL-0023)

_Part of the AI Kingdoms analytics taxonomy: `analytics/schemas/events.md` §5 (rules, budget and naming live there). D-038 (7): one file per feature, so PRs for different features never edit the same lines._

Session start and end for every ruler, and the day-2 return funnel.

## Custom events (`LogCustomEvent(player, name, value, customFields)`)
| Event | Value | CustomField01 | CustomField02 | CustomField03 | Emitted by | Status |
|---|---|---|---|---|---|---|
| SessionStart | daysSinceFirstJoin | visit (`firstDay` \| `return` \| `unknown`) | | | AnalyticsService on `PlayerReady` (core.createdAt from DataService when present) | built |
| SessionEnd | sessionSec | lastActivity (last tracked bus/custom event = drop-off point) | | | AnalyticsService on `Players.PlayerRemoving` | built |

## Funnels
| Funnel | Roblox method | Kind / session id | Steps | Logged by |
|---|---|---|---|---|
| Return | `LogFunnelStepEvent(player, "Return", nil, ...)` | once | 1 FirstSession (first join today, UTC) · 2 ReturnNextDay | AnalyticsService on `PlayerReady` (needs DataService `core.createdAt`; inactive in VS-1, D-027) |

Why `Return` stops at step 2: if we logged a day-7 step, a player who skipped day 1 would be counted as a day-1 returner (skipped steps count as completed). D7/D30 come from the Creator Dashboard retention charts.

## History
- 2026-10-12 FORGE-04: first version (FL-0023); aligned with CONTRACTS v0.4-g2.
- 2026-10-13 FORGE-04: moved out of events.md §5 (D-038 (7)).
