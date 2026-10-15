# Analytics event taxonomy (FL-0023)

_Owner: FORGE-04. Status: **in FORGE-00 taxonomy review** (reviews: `production/handoffs/2026-10-13-forge-00-to-forge-04-doc-reviews.md`; FL-0063 handoff `production/handoffs/2026-10-12-forge-04-to-forge-01-00-analytics-fl0063.md`). Last updated 2026-10-15._

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
| Limits reset daily | "Limitations reset daily" | ET (quoted from FORGE-00's 2026-10-13 review; not re-checked here) |
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
- Custom fields never carry personal data. `env.log` analytics lines include the UserId for Studio debugging; they are not forwarded off-platform.
- Only server code calls AnalyticsService. An event caused by a client request (e.g. SettingChanged) is logged only after the server has validated and applied it, under the per-player bucket. No event is logged on a client's report alone that something was shown or done. The one exception is onboarding's client-reported step InspectCitizen (a selection only the client sees; it grants nothing, G11 wording pending FORGE-00). AnswerCitizen follows G9 `CitizenAnswered` from the server (FL-0108).
- **Funnels are frozen once published** (FORGE-00 review L6): step numbers and meanings never change after the first publish, because Roblox keeps a player's saved step and a renumbered step would mix data for good. A new onboarding flow gets a new one-time funnel (`LogFunnelStepEvent` "OnboardingV2") instead of renumbering. A funnel's name is durable too: the VS-1 progress funnel is `FirstMatch` (D-050 (7); called `VS1` before the first publish), with the BRIEF §13 steps; new steps are added only at the end.

## 3. Budget (AI Kingdoms, `games/game-001/config/Analytics.luau`)

| Limit | Roblox cap (quote, source) | House budget | AI Kingdoms uses |
|---|---|---|---|
| Custom event names | 100 — "eventNames \| 100" (ET); "up to 100 custom events" (CE) | 60 | **14** |
| Funnels | 10 — "Number of funnels \| 10" (ET); "Limited to 10 unique funnels per experience." (AS) | 8 | **3** (Onboarding, FirstMatch, Return) |
| Steps per funnel | 100 — "Limited to steps 1-100." (AS) | 30 | **≤ 6** |
| Custom fields per event | 3 — "Number of custom fields \| 3" (ET) | 3 | **≤ 3** |
| Custom field value combinations | 8,000 — "Limited to 8,000 unique combinations of values across the three custom fields per experience." (AS); ET says values past 8,000 are grouped as "Other". The cap is per experience, across **all** events | **total < 2,000** (house rule) | about 440 in all (below) |
| Currency types (economy) | **5** — "Limited to 5 unique currency types per experience." (AS, EE "up to five"); ET says 10. We keep 5. | 3 (guidance, not enforced) | none in VS-1 (no meta currency); kingdom resources are **not** economy events |
| Transaction types | 20 — "Limited to 20 unique types per experience." (AS) | 12 (guidance, not enforced) | the 6 enum names below + ≤ 6 custom |
| Item SKUs | 100 — "Limited to 100 unique SKUs per experience." (AS) | 80 (guidance, not enforced) | FORGE-03 |
| Requests per minute (all AnalyticsService calls) | "120 + (20 * CCU)" (ET), experience-wide (scope **unverified** until a published test place) | 80% of each server's players' share | the adapter's per-server bucket (below) |

Rate cap as built (`AnalyticsService:_admit`):
- One server bucket of `max(20, floor(0.8 × 20 × players))` requests per minute, refilled continuously; the allowance grows at once when players join. It counts only the server's own players' share of the experience-wide cap (FORGE-00 review L8): with the base 120 per server, two 4-player servers or four full ones bursting together could pass `120 + 20 × CCU`; with the share they never can.
- Custom events may only use the bucket down to **25%**, so funnels and economy events keep that reserve.
- Each player has a **30 per minute** bucket, so one player (or a client spamming a remote that leads to analytics) cannot drain the server's budget.
- Dropped calls are counted in `stats.dropped.rate` / `.playerRate`, logged, and warned at most once per minute.

Expected load (estimate, **unverified** until a playtest):
- a VS-1 slice logs about 15 requests per player in 8 minutes;
- a 30-minute match logs about 60 per player: 6 funnel steps, up to 8 onboarding steps, 2 session events, 1 MatchEnded, about 10 conversations, about 30 reputation shifts;
- the allowance is 0.8 × 20 = 16 per player-minute (about 480 per player over 30 minutes).

Custom field value combinations per event (the house rule counts their sum; phase values are CONTRACTS G2 MatchPhase: Lobby, Founding, Expansion, Conflict, Endgame, Results, plus Arena at VS-2, G12.1):

| Event | Fields (values) | Combinations |
|---|---|---|
| SessionStart | visit (3) | 3 |
| SessionEnd | lastActivity (the tracked event names, about 12) | ~12 |
| OnboardingCompleted | flow (1) | 1 |
| OnboardingSkipped | lastStepName (6) × flow (1) | 6 |
| OnboardingHintEscalated | stepName (6) | 6 |
| OnboardingStepPassed | stepName (6) × via (2) | 12 |
| MatchEnded | won (3) × phase (5 playing + unknown) × mode (4) | 72 |
| PhaseLeft | phase (5) | 5 |
| IdleHintShown | phase (4) | 4 |
| CelebrationShown | kind (5: kingdomFounded, keepUpgraded, objectiveCaptured, victory, defeat) | 5 |
| MilestoneReached | milestone (5 FirstMatch steps after Spawn) × mode (4) | 20 |
| SettingChanged | key × value: 5 volumes × 11 (tenths) + 4 booleans × 2 + 1 enum × 2 | 65 |
| ConversationAnswered | occupation (12) × decision (15 content `farm_key`s today) | 180 (grows with the content: 1,200 at 100 `farm_key`s) |
| ReputationShifted | category (6) × source (2) × phase (6) | 72 |
| **Total** | | **about 460** |

A new event, field or content value that would push the total past 2,000 needs a bucket (as SettingChanged's tenths) or FORGE-00's approval.

## 4. Who an event is about (`Experience/Subjects`)
Track rules and onboarding triggers act on **subjects** (`{ player, info }`). Framework events have default resolvers (PlayerReady, Round*, CurrencyChanged, ItemGranted, PurchaseCompleted, RewardRolled, ShopViewed, OnboardingStep). A game passes resolvers for its own events in config (`subjects = { [event] = fn }`). game-001 uses `games/game-001/src/shared/Feedback/Signals.luau`, which implements the CONTRACTS G9 attribution rules:
- "spawn" = `KingdomJoined`;
- "first build placed" credits `Building.placedBy`;
- building completions and captures credit every current member of the kingdom (`KingdomService:getKingdom(id).rulers`);
- gathering: a ruler's gather credits that player, a citizen's deposit credits every current member;
- recruiting credits the player named in `UnitsRecruited`.
- **Funnel order (CONTRACTS G9 v0.4-g6):** a FirstMatch step n > 1 is credited only to a player who already holds step n−1 in this server visit (no persistence in VS-1, D-027). Otherwise it is counted in `stats.dropped.outOfOrder` and not sent. The G9 events, onboarding and the announcer still react kingdom-wide. Return stays unordered: its step 2 is logged on a later day.

game-001 passes these resolvers as config `subjects = Signals.subjects` (FL-0063).

Resolver errors are caught and warned once per minute; analytics never breaks gameplay.

## 5. Custom events and funnels — AI Kingdoms

One file per feature (D-038 (7)), so PRs for different features never edit the same lines. Every event and funnel in `games/game-001/config/Analytics.luau` is in exactly one of them:

| File | Feature | Custom events | Funnels |
|---|---|---|---|
| `analytics/schemas/game-001/sessions.md` | Sessions and return (FL-0023) | SessionStart, SessionEnd | Return |
| `analytics/schemas/game-001/onboarding.md` | Onboarding (FL-0025, FL-0092) | OnboardingCompleted, OnboardingSkipped, OnboardingHintEscalated, OnboardingStepPassed | Onboarding |
| `analytics/schemas/game-001/match.md` | VS-1 progress and matches (FL-0063) | MatchEnded, PhaseLeft | FirstMatch |
| `analytics/schemas/game-001/conversation.md` | Conversations and reputation (FL-0063) | ConversationAnswered, ReputationShifted |  |
| `analytics/schemas/game-001/feedback.md` | Feedback, celebrations and settings (FL-0024, FL-0027, FL-0062) | IdleHintShown, CelebrationShown, SettingChanged |  |

A new feature adds its own file and one row here.

## 6. Economy (`LogEconomyEvent`) — framework mapping (sandbox and later games)

**game-001 logs no economy events** until the user decides BRIEF §16.1 and §16.5 (FORGE-00 review L1). This section maps situations to Roblox's transaction types for games that have a meta currency; it is not a plan for AI Kingdoms. The caller is FORGE-03's EconomyService.

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
| Spend tied to an immediate benefit (extra lives, Roblox's own example (EE)) | sink | `ContextualPurchase` |

EE lists `IAP`, `TimedReward` and `Onboarding` as source-only and `ContextualPurchase` as sink-only. In-match resources (Food, Wood, Stone, Gold) reset every match, so they are **not** economy events: they would burn the 5-currency cap and the rate budget. Match-level resource totals belong in a `MatchEnded`-style custom event if needed.

## 7. What the Creator Dashboard gives us for free (no events needed)
- Retention D1/D7/D30 by cohort ("Users who first played the game on 06/20 and returned to the game the next day", `production/analytics/retention.md`; the docs word D7/D30 inconsistently).
- Average session time ("total time users spend in your game divided by the number of sessions", `engagement.md`), New User First Session Retention ("how many new users are still playing X minutes after joining"), DAU, new users, payer conversion, ARPPU/ARPDAU.
- Full KPIs only after the experience has "more than 10 daily active users (DAU) and 10 play hours for 7 consecutive days" (`analytics-dashboard.md`).
So session duration is covered twice (dashboard + `SessionEnd.value`); our own events add **why** (last activity, stuck tutorial step, match phase at exit).

## 8. Measurement plan (what each question is answered by)

| Question (FORGE-04 mission) | Answered by |
|---|---|
| Tutorial completion | Onboarding funnel (last step `Capture`), `OnboardingCompleted.value` |
| Tutorial skip and where | `OnboardingSkipped` value/field = last completed step |
| Stuck points in the tutorial | `OnboardingHintEscalated` by step |
| Early player actions, resource and construction milestones | FirstMatch funnel steps 2–4 (FL-0063) |
| Milestone timing vs the pacing targets (`config/Pacing.luau`) | `MilestoneReached`: median value by milestone, per mode (FORGE-00 review M7) |
| Match participation / completion, pacing | FirstMatch step 6; `MatchEnded` (won, decided phase, duration, mode, so `match` and `match30` compare); `PhaseLeft` |
| Living kingdom (D-030): which answers rulers give, and how reputation moves | `ConversationAnswered` (decision by occupation, time to answer; no phase, #64); `ReputationShifted` (category, source) |
| Drop-off points | `SessionEnd.lastActivity`; FirstMatch step-to-step conversion; `PhaseLeft` |
| Session duration | Dashboard; `SessionEnd.value` |
| Dead air | `IdleHintShown` per match (PACING.md §6); planned: no server dead-air detector exists yet |
| Reward interactions | `CelebrationShown` (AnnouncerService, at the G9 event); quests and daily rewards are FL-0026 (after VS-1; pending BRIEF §16.1/§16.5) |
| Day-2 return | Return funnel (once persistence exists); dashboard D1 |

## 9. Sandbox (`games/sandbox/config/Analytics.luau`)
Same session events and onboarding events as above, plus `RoundFinished` (value survivedSec; won, placement) and `SettingChanged`, `CelebrationShown`. Funnels: Onboarding, FirstRound (Ready → RoundStarted → RoundFinished), FirstReward (FirstCurrency → FirstItem), Shop, Return. 8 events, 5 funnels.

## 10. How to verify (Studio, gate G6 — run by the user)
1. Play Solo on the integrated build; open the Output window and filter for `analytics`.
2. When the kingdom is joined, expect `analytics event SessionStart`, then `analytics funnel FirstMatch step=1 stepName=Spawn`; the `analytics funnel Onboarding step=1 stepName=Spawn` line may come before or after them. In Studio, either `sent=true` or `sent=false reason=error` is acceptable (unverified which, because Roblox sends nothing from Studio): judge the order and the fields only. After that comes one line per tutorial step as you complete it (full order in `roblox/studio-tests/experience.md` E6), and one `analytics funnel FirstMatch` line the first time each of gather, place, complete, recruit and capture happens.
3. After each later FirstMatch step: `analytics event MilestoneReached value=<seconds since the kingdom was joined> CustomField01=<step name> CustomField02=<mode>`. A celebrating moment (founding, keep upgrade, capture, victory, defeat) logs `analytics event CelebrationShown CustomField01=<kind>` on the server.
4. When the match ends: `analytics event MatchEnded value=<seconds>` with won, the decided phase and the mode. Stop the session mid-match: `analytics event PhaseLeft value=<minute> CustomField01=<phase>`, then `SessionEnd`.
5. Roblox records nothing from Studio; to check real delivery, publish to a private test place and use the View Events tool (near real time) — needs the user's account.

## History
Each feature file keeps its own history. Changes to the shared sections above (rules, budget, measurement plan, verification):
- 2026-10-12 FORGE-04: first version (FL-0023).
- 2026-10-15 FORGE-04 (FORGE-00 review, after #64): M3 server producers (CelebrationShown from AnnouncerService; IdleHintShown planned); M7 `MilestoneReached`; L1 §6 is a framework mapping, no game-001 economy events; L3 house economy budgets are guidance; L6 funnels frozen once published, the VS1 funnel renamed `FirstMatch` (D-050 (7)); L8 per-server bucket = its players' share; boot check that every track rule has a resolver (M8).
- 2026-10-13 FORGE-04 (FL-0063, FORGE-00 doc review): aligned with CONTRACTS v0.4-g8 (G9 order rule v0.4-g6, §4); step meanings for FirstGather and FirstRecruit; Return starts at session start; KingdomEliminated noted; per-event combination budget with a house total under 2,000 (ConversationAnswered drops `phase`; SettingChanged values in tenths); server-only rule (§2); daily limit reset (§1).
- 2026-10-12 FORGE-04 (FL-0063): VS1 track rules built; sessions start on `KingdomJoined` in game-001 (`session.startOn`); `MatchEnded` and `PhaseLeft` built (MatchAnalyticsService, `session.leftInfo`); SessionEnd's drop-off is the last *logged* bus event; `ConversationAnswered` and `ReputationShifted` declared for FORGE-01 (D-030); budget recomputed.
- 2026-10-12 FORGE-04: aligned with CONTRACTS v0.4-g2. Proposed kingdom signals removed (G9 replaces them); `Experience/Subjects` resolver hook; game-001 VS-1 onboarding steps and the declared VS1 funnel (FL-0063); budget recomputed.
- 2026-10-13 FORGE-04: §5 split into one file per feature under `analytics/schemas/game-001/` (D-038 (7)).
- 2026-10-15 FORGE-04 (FL-0108): `ConversationAnswered` is logged from G9 `CitizenAnswered` by a track rule (D-044 (3)); ConversationService never calls AnalyticsService.
