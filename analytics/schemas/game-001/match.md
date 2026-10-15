# VS-1 progress and matches (FL-0063)

_Part of the AI Kingdoms analytics taxonomy: `analytics/schemas/events.md` §5 (rules, budget and naming live there). D-038 (7): one file per feature, so PRs for different features never edit the same lines._

Real progress for every ruler (the VS1 funnel, BRIEF §13), match outcomes and the phase a ruler left in.

## Custom events (`LogCustomEvent(player, name, value, customFields)`)
| Event | Value | CustomField01 | CustomField02 | CustomField03 | Emitted by | Status |
|---|---|---|---|---|---|---|
| MatchEnded | durationSec | won (`true`/`false`/`draw` when there is no single winner: a draw or a shared win is never logged as a loss) | phase (the last playing phase before Results = where it was decided: Founding..Endgame, Arena from VS-2) | mode (`MatchService.mode`: `slice` \| `match` \| `match30` \| `unknown`; comparison labels, not a match-length decision, BRIEF §16.10) | MatchAnalyticsService on G9 `MatchEnded`, per ruler still here (spectators not counted). KingdomEliminated is not logged in VS-1 (the slice has no elimination); VS-2 adds it as a custom event | built (FL-0063) |
| MilestoneReached | sinceStartSec (whole seconds since this visit's session started, i.e. KingdomJoined) | milestone (the VS1 step: FirstGather, FirstBuildPlaced, FirstBuildingComplete, FirstRecruit, FirstCapture) | mode (`MatchService.mode`, `unknown` without it) | | AnalyticsService right after it sends a VS1 step ≥ 2 (`config.milestones`): at most 5 per player per visit. The pacing targets count from Founding, which in the slice starts on the first join, so a later joiner's times run shorter | built (FORGE-00 review M7) |
| PhaseLeft | minute | phase | | | AnalyticsService at session end through `config.session.leftInfo` → MatchAnalyticsService, for a ruler leaving in Founding..Arena. Logged before SessionEnd, so the order never depends on PlayerRemoving handler order | built (FL-0063) |

## Funnels
| Funnel | Roblox method | Kind / session id | Steps | Logged by |
|---|---|---|---|---|
| VS1 | `LogFunnelStepEvent(player, "VS1", nil, step, name, fields)` | once | BRIEF §13: Spawn → FirstGather → FirstBuildPlaced → FirstBuildingComplete → FirstRecruit → FirstCapture (G9 attribution, §4) | AnalyticsService track rules on `KingdomJoined`, `ResourceGathered`, `BuildingPlaced` (placedBy), `BuildingCompleted`, `UnitsRecruited`, `ObjectiveCaptured` (built, FL-0063). `inOrder`: a step is credited only to a player who already has the previous step (FORGE-00's #64 ruling). Roblox counts skipped steps as completed, so a co-ruler credited for the kingdom's completion or capture would otherwise inflate FirstBuildPlaced and FirstRecruit. Repeats are counted (`stats.dropped.duplicate`), never logged |

**VS1 step meanings.** FirstGather: the first ResourceGathered credited to the player by Feedback/Signals (their own gather, or any citizen deposit into their kingdom, credited to every member). FirstRecruit: the player named in UnitsRecruited. The others follow G9 (§4).

**FirstGather under D-030.** Ruler gathering is optional and citizens gather for the kingdom. By G9, citizens' gathering credits every member, so this step completes within seconds of the first citizen deposit: it measures "the economy started", not a ruler's action. With the order rule, a ruler who places a building before their first deposit credit loses that FirstBuildPlaced (it is dropped, not deferred) and is credited at their next placement. The funnel follows BRIEF §13 as written. For FORGE-00's review: a v2 funnel could replace FirstGather with FirstCitizenInspected or FirstConversation once a server-side conversation event exists.

## History
- 2026-10-12 FORGE-04: declared (FL-0023); VS1 funnel declared for FL-0063 (CONTRACTS v0.4-g2).
- 2026-10-13 FORGE-04: moved out of events.md §5 (D-038 (7)).
- 2026-10-13 FORGE-04: built (FL-0063, #64): MatchAnalyticsService for MatchEnded and PhaseLeft, the VS1 track rules with `inOrder` (FORGE-00's #64 ruling), step meanings and FirstGather under D-030.
- 2026-10-15 FORGE-04: MilestoneReached (FORGE-00 review M7): live milestone times against `config/Pacing.luau`.
