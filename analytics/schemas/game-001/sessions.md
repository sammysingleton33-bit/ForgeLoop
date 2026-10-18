# Sessions and return (FL-0023)

_Part of the AI Kingdoms analytics taxonomy: `analytics/schemas/events.md` §5 (rules, budget and naming live there). D-038 (7): one file per feature, so PRs for different features never edit the same lines._

Session start and end for every ruler, and the day-2 return funnel.

## Custom events (`LogCustomEvent(player, name, value, customFields)`)
| Event | Value | CustomField01 | CustomField02 | CustomField03 | Emitted by | Status |
|---|---|---|---|---|---|---|
| SessionStart | daysSinceFirstJoin | visit (`firstDay` \| `return` \| `unknown`) | | | AnalyticsService on `config.session.startOn`: game-001 uses `KingdomJoined`, because VS-1 has no profiles and so no `PlayerReady` (D-027). Once per server visit. `core.createdAt` comes from DataService when present | built (FL-0063) |
| SessionEnd | sessionSec | lastActivity (the last bus event that was actually logged for the player = drop-off point; kingdom-wide repeats such as citizens gathering don't move it) | | | AnalyticsService on `Players.PlayerRemoving` | built |

## Funnels
| Funnel | Roblox method | Kind / session id | Steps | Logged by |
|---|---|---|---|---|
| Return | `LogFunnelStepEvent(player, "Return", nil, ...)` | once | 1 FirstSession (first join today, UTC) · 2 ReturnNextDay | AnalyticsService at session start (`config.session.startOn`; game-001: `KingdomJoined`, D-027). Needs DataService `core.createdAt`, so it is inactive in VS-1 (D-027) |

**Who has no session.** Sessions start on `KingdomJoined`, so a spectator (all kingdoms full) never gets SessionStart, SessionEnd or PhaseLeft. MatchEnded counts rulers only.

Why `Return` stops at step 2: if we logged a day-7 step, a player who skipped day 1 would be counted as a day-1 returner (skipped steps count as completed). D7/D30 come from the Creator Dashboard retention charts.

## History
- 2026-10-12 FORGE-04: first version (FL-0023); aligned with CONTRACTS v0.4-g2.
- 2026-10-13 FORGE-04: moved out of events.md §5 (D-038 (7)).
- 2026-10-13 FORGE-04: sessions start on `config.session.startOn` (game-001: `KingdomJoined`, D-027); lastActivity counts logged events only; spectators have no session (FL-0063, #64).
