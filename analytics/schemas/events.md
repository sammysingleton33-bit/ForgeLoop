# Analytics event taxonomy (FL-0023)

_Owner: FORGE-04. Status: **draft for FORGE-00 taxonomy review** (handoff `production/handoffs/2026-10-12-forge-04-to-forge-00-ai-kingdoms-experience.md`). Last updated 2026-10-12._

Config files are the source of truth: `games/game-001/config/Analytics.luau` (AI Kingdoms) and `games/sandbox/config/Analytics.luau`. The adapter is `roblox/src/server/Services/AnalyticsService.luau` (interfaces §8), validated by `roblox/src/shared/Experience/AnalyticsSchema.luau`. If this page and a config disagree, the config wins and this page is the bug.

Sources: Roblox creator-docs at commit `af5f853` (2026-10-10), paths under `content/en-us/`. **AS** = `reference/engine/classes/AnalyticsService.yaml`; **ET** = `production/analytics/event-types.md`; **CE** = `production/analytics/custom-events.md`; **FE** = `production/analytics/funnel-events.md`; **EE** = `production/analytics/economy-events.md`; **CF** = `production/analytics/custom-fields.md`. Read through `raw.githubusercontent.com` on 2026-10-12.

## 1. Platform facts we design around

| Fact | Quote | Source |
|---|---|---|
| Server and published games only | "Events can only be sent from the server and in published games. Events can't be sent from the client or Studio." | CE, FE, EE |
| Charts lag a day | "charts on the respective pages typically take 24 hours to appear"; the View Events tool shows "A near real-time list of the most recent events" | ET |
| Funnels start at step 1, max 100 | "All funnels start at step 1. Limited to steps 1-100." | AS |
| Skipped steps count as completed | "if any steps are skipped, the intermediate steps will be considered completed." | AS |
| Repeats are ignored but still cost budget | "Repeated steps by the same user in the same funnel session, or when `funnelSessionId` is `nil` will be ignored."; "they're still logged and contribute towards the global rate limit." | AS, FE |
| Session ids only for recurring funnels | "this field is only necessary for **recurring** funnels ... it's recommended to use `HttpService:GenerateGUID()`." | AS |
| Only 10 recent sessions count | "Analytics only tracks the 10 most recent unique `funnelSessionId` values per user for each funnel." | FE |
| Funnel progress expires | "If a user has no events for a funnel for more than 180 days, their saved step expires" | FE |
| Filters/breakdowns use step 1 only | "filters **only apply to the first step** of the funnel" | FE |
| Onboarding funnel is one-time | "A one-time funnel ... A common example is an **onboarding funnel**"; `LogOnboardingFunnelStepEvent(player, step, stepName, customFields)` has no funnel name or session id | FE, AS |
| Custom fields are strings under fixed keys | "Anything other than `CustomField01.Name`, `CustomField02.Name`, and `CustomField03.Name` is ignored."; "values ... must be **strings**" | CF |
| Counter events default to value 1 | "counter events are treated as events with a default value of `1`" | CE |
| Data retention | "automatically rolls off after 90 days from the last data received" | ET |
| Progression events are not charted | "This event does not currently display in any Roblox-provided charts." | AS (we do not use them) |

Consequences for this design:
- Studio walkthroughs verify analytics from the **`env.log` trail** (`analytics <kind> <name> ... sent=true`), never from the dashboard.
- Because skipped steps count as completed, funnels list only steps that every player passes in order; optional milestones are custom events, not funnel steps.
- Recurring funnels always carry a session id (shop open GUID, `matchId`); the adapter refuses recurring steps without one.

## 2. Naming rules
- Event, funnel and step names: **PascalCase**, ASCII letters and digits (`BuildingCompleted`, `FirstUpgrade`). No commas, quotes, spaces or newlines.
- Field names in config: **camelCase** (`buildingType`). They map in list order to `CustomField01..03`.
- One name per meaning, past tense for things that happened (`MatchEnded`, `QuestCompleted`).
- Variants go in custom fields, not in names (`BuildingCompleted` + `buildingType = "Farm"`, never `FarmCompleted`).
- Field values are low-cardinality categories: types, outcomes, phases, roles, small numbers (placement 1–8, streak days). **Never** user ids, names, free text, timestamps or GUIDs (Roblox groups combinations past 8,000 as "Other").
- Every call is written to `env.log`; nothing in a field may be personal data.

## 3. Budget (AI Kingdoms)

| Limit | Roblox cap (quote, source) | House budget | AI Kingdoms uses |
|---|---|---|---|
| Custom event names | 100 — "eventNames \| 100" (ET); "up to 100 custom events" (CE) | 60 | **21** |
| Funnels | 10 — "Number of funnels \| 10" (ET); "Limited to 10 unique funnels per experience." (AS) | 8 | **6** |
| Steps per funnel | 100 — "Limited to steps 1-100." (AS) | 30 | **≤ 9** (Onboarding 9, FirstMatch 7) |
| Custom fields per event | 3 — "Number of custom fields \| 3" (ET) | 3 | **≤ 3** |
| Custom field value combinations | 8,000 — "Limited to 8,000 unique combinations of values across the three custom fields per experience." (AS); ET says values past 8,000 are grouped as "Other" | well under 8,000 | largest: `MatchEnded` won(2) × placement(≤8) × mode(≤3) = 48; `QuestCompleted` questId ≤ 100 |
| Currency types (economy) | **5** — "Limited to 5 unique currency types per experience." (AS, EE "up to five"); ET says 10. We keep 5. | 3 | owned by FORGE-03 (`Currencies.luau`); in-match resources are **not** economy events |
| Transaction types | 20 — "Limited to 20 unique types per experience." (AS) | 12 | the 6 enum names below + ≤ 6 custom |
| Item SKUs | 100 — "Limited to 100 unique SKUs per experience." (AS) | 80 | FORGE-03 |
| Requests per minute (all AnalyticsService calls) | "120 + (20 * CCU)" (ET) | 80% of that | adapter enforces it (below) |

Rate cap as built (`AnalyticsService:_admit`):
- One server bucket of `floor(0.8 × (120 + 20 × players))` requests per minute, refilled continuously; the allowance grows at once when players join.
- Custom events may only use the bucket down to **25%**, so funnels and economy events keep that reserve.
- Each player has a **30 per minute** bucket, so one player (or a client spamming a remote that leads to analytics) cannot drain the server's budget.
- Dropped calls are counted in `stats.dropped.rate` / `.playerRate`, logged, and warned at most once per minute.

Expected load (estimate, **unverified** until a playtest): a 40-minute AI Kingdoms match with ~60 tracked actions per player ≈ 1.5 requests per player-minute (repeats of once-funnel steps are not re-sent), against an allowance of 0.8 × 20 = 16 per player-minute.

## 4. Custom events — AI Kingdoms (`LogCustomEvent(player, name, value, customFields)`)

| Event | Value | CustomField01 | CustomField02 | CustomField03 | Emitted by | Status |
|---|---|---|---|---|---|---|
| SessionStart | daysSinceFirstJoin | visit (`firstDay` \| `return` \| `unknown`) | | | AnalyticsService on `PlayerReady` (core.createdAt from DataService) | built |
| SessionEnd | sessionSec | lastActivity (last tracked bus/custom event name = drop-off point) | | | AnalyticsService on `Players.PlayerRemoving` | built |
| OnboardingCompleted | durationSec | flow | | | OnboardingService (FL-0025) | built in FL-0025 |
| OnboardingSkipped | lastStep | lastStepName | flow | | OnboardingService on skip; **no funnel step is logged after it** | built in FL-0025 |
| OnboardingHintEscalated | step | stepName | | | OnboardingService when a step passes its nudge time (stuck points) | built in FL-0025 |
| MatchEnded | durationSec | won (`true`/`false`) | placement | mode | track rule on `RoundEnded`, per participant still in the server | built |
| PhaseReached | minute | phase (`Opening` … `Resolution`) | | | Experience/Pacing (FL-0024) | planned |
| IdleNudge | idleSec | phase | | | Experience/Pacing dead-air nudge (FL-0024) | planned |
| BuildingCompleted | level | buildingType | | | track rule on `BuildingCompleted` (actor) | built, needs FORGE-01 signal |
| KingdomUpgraded | tier | | | | track rule on `KingdomUpgraded` (actor) | built, needs FORGE-01 signal |
| UnitsRecruited | count | unitType | | | track rule on `UnitsRecruited` (actor) | built, needs FORGE-01 signal |
| BattleEnded | 1 | role (`actor` \| `defender`) | won | | track rule on `BattleEnded` (both sides) | built, needs FORGE-01 signal |
| SiegeEnded | 1 | role | outcome (`Breached` \| `Repelled` \| `Abandoned`) | | track rule on `SiegeEnded` (both sides) | built, needs FORGE-01 signal |
| TerritoryChanged | 1 | role (`actor` gained \| `loser` lost) | | | track rule on `TerritoryChanged` | built, needs FORGE-01 signal |
| KingdomEventStarted | severity (1–3) | eventId | | | track rule on `KingdomEventStarted` (actor) | built, needs FORGE-01 signal |
| RewardClaimed | amount | source (`daily` \| `quest` \| `match` \| `onboarding` \| `achievement`) | rewardKind (`currency` \| `item`) | | Quest/DailyReward/Onboarding services (FL-0026) | planned |
| DailyRewardClaimed | streakDay | graceUsed | | | DailyRewardService (FL-0026) | planned |
| QuestCompleted | tier | questId | | | QuestService (FL-0026) | planned |
| AchievementUnlocked | 1 | achievementId | | | QuestService (FL-0026) | planned |
| CelebrationShown | 1 | kind | | | NotificationController → server report (FL-0027) | planned |
| SettingChanged | 1 | key | value | | SettingsService (FL-0024) | planned |

"needs FORGE-01 signal": the rule is live in config but the bus event is a **proposal** (`roblox/src/shared/Experience/KingdomSignals.luau`, handoff to FORGE-01). Until `Contracts/GameEvents` declares it, the adapter logs `analytics: waiting for bus events not declared yet events=...` once at start and the rule is inert.

## 5. Funnels — AI Kingdoms

| Funnel | Roblox method | Kind / session id | Steps | Logged by |
|---|---|---|---|---|
| Onboarding | `LogOnboardingFunnelStepEvent(player, step, stepName, customFields)` | one-time (Roblox's own onboarding funnel) | the 9 steps of `games/game-001/config/Onboarding.luau` (FL-0025): `Arrive`, `MoveRuler`, `FindKingdom`, `CheckResources`, `AssignCitizen`, `PlaceFarm`, `FirstHarvest`, `UpgradeHall`, `NextGoal` | OnboardingService only; after a skip nothing more is logged |
| FirstMatch | `LogFunnelStepEvent(player, "FirstMatch", nil, step, name, fields)` | once | 1 MatchJoined (`RoundStateChanged` Active) · 2 FirstConstruction · 3 FirstBuilding · 4 FirstUpgrade · 5 FirstArmy · 6 FirstCombat (battle or siege, either side) · 7 MatchFinished (`RoundEnded`) | track rules |
| MatchProgress | `LogFunnelStepEvent(player, "MatchProgress", matchId, step, name, fields)` | recurring, **session = matchId** | 1 Joined · 2 FirstBuilding · 3 FirstUpgrade · 4 FirstArmy · 5 FirstCombat · 6 Finished | track rules — shows where players drop out of every match, not only the first |
| FirstReward | `LogFunnelStepEvent(player, "FirstReward", nil, ...)` | once | 1 FirstHarvest (`ResourceProduced` actor) · 2 FirstCurrency (`CurrencyChanged` delta > 0) · 3 FirstItem (`ItemGranted`) | track rules |
| Shop | `LogFunnelStepEvent(player, "Shop", <GUID per open>, ...)` | recurring, **new GUID on every `ShopViewed`**, continued by `PurchaseCompleted` within 900 s | 1 Opened · 2 Purchased | track rules; a purchase with no open shop session is dropped (`noSession`), never counted as a conversion |
| Return | `LogFunnelStepEvent(player, "Return", nil, ...)` | once | 1 FirstSession (first join today, UTC) · 2 ReturnNextDay (joined on the next UTC day) | AnalyticsService on `PlayerReady` (needs DataService `core.createdAt`) |

Why `Return` stops at step 2: if we logged a day-7 step, a player who skipped day 1 would be counted as a day-1 returner (skipped steps count as completed). D7/D30 come from the Creator Dashboard retention charts, and `SessionStart.value` (days since first join) gives the raw distribution.

Why both `FirstMatch` and `MatchProgress`: Roblox filters and breakdowns apply to step 1 and funnels show cohorts (FE), so the once funnel measures new-player conversion while the recurring one measures every match, including returning players.

## 6. Economy (`LogEconomyEvent`) — owned by FORGE-03's EconomyService

`EconomyService` is the only caller of `AnalyticsService:economy(player, flow, currency, amount, balance, txType, item?)` (interfaces §7/§8); nothing derives economy events from `CurrencyChanged`. The adapter sends `Enum.AnalyticsEconomyFlowType.Source/Sink`, requires `amount > 0` and `balance >= 0` (AS: amount "should always be positive", endingBalance "should always be greater than or equal to 0"), and warns once for each custom transaction type.

`txType` mapping for FORGE-03 (names of `Enum.AnalyticsEconomyTransactionType`, AS: "pass the `Name` value of the enum"):

| Situation | flow | txType |
|---|---|---|
| Currency bought with Robux (developer product) | source | `IAP` |
| Item bought in a shop with currency | sink | `Shop` |
| Item sold to a shop for currency | source | `Shop` |
| Match reward, quest reward, achievement reward | source | `Gameplay` |
| Currency spent inside gameplay (e.g. entry fee) | sink | `Gameplay` |
| Daily reward / streak | source | `TimedReward` |
| Tutorial completion reward | source | `Onboarding` |
| Spend tied to an immediate benefit (speed up construction, revive, reroll a quest) | sink | `ContextualPurchase` |

EE lists `IAP`, `TimedReward` and `Onboarding` as source-only and `ContextualPurchase` as sink-only. In-match resources (Food, Wood, Stone, Gold) reset every match, so they are **not** economy events: they would burn the 5-currency cap and the rate budget. Match-level resource totals belong in a `MatchEnded`-style custom event if needed.

## 7. What the Creator Dashboard gives us for free (no events needed)
- Retention D1/D7/D30 by cohort ("Users who first played the game on 06/20 and returned to the game the next day", `production/analytics/retention.md`; the docs word D7/D30 inconsistently).
- Average session time ("total time users spend in your game divided by the number of sessions", `engagement.md`), New User First Session Retention ("how many new users are still playing X minutes after joining"), DAU, new users, payer conversion, ARPPU/ARPDAU.
- Full KPIs only after the experience has "more than 10 daily active users (DAU) and 10 play hours for 7 consecutive days" (`analytics-dashboard.md`).
So session duration is covered twice (dashboard + `SessionEnd.value`); our own events add **why** (last activity, stuck tutorial step, match phase at exit).

## 8. Measurement plan (what each question is answered by)

| Question (FORGE-04 mission) | Answered by |
|---|---|
| Tutorial completion | Onboarding funnel (last step `NextGoal`), `OnboardingCompleted.value` (seconds) |
| Tutorial skip and where | `OnboardingSkipped` value/field = last completed step |
| Stuck points in the tutorial | `OnboardingHintEscalated` by step |
| Early player actions | FirstMatch funnel steps 1–5, FirstReward funnel |
| Resource and construction milestones | FirstReward step 1, FirstMatch steps 2–4, `BuildingCompleted`, `KingdomUpgraded` |
| Match participation / completion | MatchProgress step 1 vs step 6; `MatchEnded` (won, placement, duration) |
| Drop-off points | `SessionEnd.lastActivity`; MatchProgress step-to-step conversion; `PhaseReached` |
| Session duration | Dashboard; `SessionEnd.value` |
| Progression | `KingdomUpgraded`, `QuestCompleted`, `AchievementUnlocked` (FL-0026) |
| Reward interactions | `RewardClaimed`, `DailyRewardClaimed`, `CelebrationShown`; FirstReward funnel |
| Pacing (30–45 min target, no dead air) | `MatchEnded.value` distribution; `PhaseReached` minute per phase; `IdleNudge` count |
| Day-2 return | Return funnel; dashboard D1 |
| Shop conversion | Shop funnel (session per open) |

## 9. Sandbox (`games/sandbox/config/Analytics.luau`)
Same session events and onboarding events as above, plus `RoundFinished` (value survivedSec; won, placement) and `SettingChanged`, `CelebrationShown`. Funnels: Onboarding, FirstRound (Ready → RoundStarted → RoundFinished), FirstReward (FirstCurrency → FirstItem), Shop, Return. 8 events, 5 funnels.

## 10. How to verify (Studio, gate G6 — run by the user)
1. Play Solo on the integrated build; open the Output window and filter for `analytics`.
2. Expect, in order: `analytics event SessionStart ... sent=true`, then one `analytics funnel Onboarding step=1 stepName=Arrive` per tutorial step as you complete it (full order in `roblox/studio-tests/experience.md`).
3. Roblox records nothing from Studio; to check real delivery, publish to a private test place and use the View Events tool (near real time) — needs the user's account.

## Changelog
- 2026-10-12 FORGE-04: first version (FL-0023).
