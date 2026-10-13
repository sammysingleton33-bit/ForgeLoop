# VS-1 progress and matches (FL-0063)

_Part of the AI Kingdoms analytics taxonomy: `analytics/schemas/events.md` §5 (rules, budget and naming live there). D-038 (7): one file per feature, so PRs for different features never edit the same lines._

Real progress for every ruler (the VS1 funnel, BRIEF §13), match outcomes and the phase a ruler left in.

## Custom events (`LogCustomEvent(player, name, value, customFields)`)
| Event | Value | CustomField01 | CustomField02 | CustomField03 | Emitted by | Status |
|---|---|---|---|---|---|---|
| MatchEnded | durationSec | won (`true`/`false`) | phase | mode (`slice` \| `match`) | G9 `MatchEnded`, per player still here | planned FL-0063 |
| PhaseLeft | minute | phase | | | player left during a match (disconnect point) | planned FL-0063 |

## Funnels
| Funnel | Roblox method | Kind / session id | Steps | Logged by |
|---|---|---|---|---|
| VS1 | `LogFunnelStepEvent(player, "VS1", nil, step, name, fields)` | once | BRIEF §13: Spawn → FirstGather → FirstBuildPlaced → FirstBuildingComplete → FirstRecruit → FirstCapture (G9 attribution, §4) | declared now; track rules land in FL-0063 |

## History
- 2026-10-12 FORGE-04: declared (FL-0023); VS1 funnel declared for FL-0063 (CONTRACTS v0.4-g2).
- 2026-10-13 FORGE-04: moved out of events.md §5 (D-038 (7)).
