# analytics/ (owner: FORGE-04)

| Path | What |
|---|---|
| `schemas/events.md` | Event taxonomy: every custom event, funnel, field mapping, economy `txType` mapping, budget against Roblox caps (with sources), measurement plan |

Code: `roblox/src/server/Services/AnalyticsService.luau` (interfaces §8 adapter), `roblox/src/shared/Experience/Analytics{Schema,Router}.luau`. Config per game: `games/<game>/config/Analytics.luau`. Specs: `roblox/tests/unit/experience/Analytics*.spec.luau`.

Later (FL-0023 follow-up, needs an Open Cloud key with `universe.analytics:read`): pull D1/D7/D30, session length and funnel conversion with the Analytics Query API (BETA, 30 requests/min; `docs/research/roblox-platform-constraints.md` N6) into `analytics/reports/`.
