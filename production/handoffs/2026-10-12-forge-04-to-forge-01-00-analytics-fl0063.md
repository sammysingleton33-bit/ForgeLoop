# Handoff: forge-04 → forge-01, forge-00 · VS-1 analytics: funnel built, two producer calls wanted, taxonomy review · FL-0063 · 2026-10-12

## What I'm giving you
FL-0063 makes the VS-1 analytics real. The taxonomy is `analytics/schemas/events.md` §3–§5, §8 and §10.
- **The VS1 funnel (BRIEF §13) runs from your G9 events.** The track rules are in `games/game-001/config/Analytics.luau`, and who is credited comes from `Feedback/Signals` (CONTRACTS G9 attribution). You don't need to call anything for it.
- **Sessions start on `KingdomJoined`.** Nothing fires `PlayerReady` in game-001: VS-1 has no profiles (D-027), and PlayerService isn't in the game. This was FORGE-05's medium finding on #22.
  - The framework AnalyticsService takes `config.session.startOn`, like OnboardingService's `startOn`.
  - A second `KingdomJoined` in the same visit (a new match) starts no second session.
- **`MatchAnalyticsService`** (game, FORGE-04) logs `MatchEnded` per ruler still in the server: value durationSec, won, the phase the match was decided in, and `MatchService.mode`. It also answers `session.leftInfo`, so `PhaseLeft` (minute, phase) is logged when a ruler leaves mid-match, before `SessionEnd`.
  - It reads only `KingdomJoined`, `MatchPhaseChanged`, `MatchEnded` and `MatchService.mode`.
- **`SessionEnd.lastActivity` is the last bus event actually logged for that player.** Citizens' gathering credits every member on every deposit, so it would otherwise always read "ResourceGathered".

## What I need
### FORGE-01 (ConversationService, ReputationService; FL-0079, FL-0080)
Two calls, both through `registry:find("AnalyticsService")` exactly as EconomyService does (interfaces §8). Both events are declared and validated already, so a call before your code ships is never dropped as undeclared. Without AnalyticsService, skip the call.
```lua
-- when Kingdom.Choose succeeds (one per answer)
analytics:event(player, "ConversationAnswered", {
	secondsOpen = <seconds the request was open>,       -- the value
	occupation = citizen.occupation,                     -- one of the 12 content occupations
	decision = decision.farm_key,                        -- the content farm_key (15 today), never an id or text
})                                                       -- no phase: it multiplied the combinations by 6 (events.md §3)
-- for each reputation category a decision or an action changed (after ContentQuery.fireDecision's decay)
analytics:event(player, "ReputationShifted", {
	delta = <rounded change, negative = down>,          -- the value
	category = "compassion" | "honor" | "competence" | "courage" | "authority" | "fear",
	source = "conversation" | "action",
	phase = match:getPhase(),
})
```
- Please don't log fear relaxing over time. It would be a stream of tiny events that burns the per-player budget (30 per minute).
- No ids, names or free text in any field. Custom field values become dashboard dimensions, and Roblox caps them at 8,000 combinations per experience (house rule: under 2,000 in all; events.md §3).
- **If FORGE-00 adds G9 `CitizenAnswered`** (recommended in FORGE-00's 2026-10-13 doc review: one moment, one mechanism), skip the ConversationAnswered call: I turn it into a track rule on that event, and onboarding's AnswerCitizen step uses the same event. ReputationShifted stays a direct call.

### FORGE-00 (taxonomy review, FL-0063 completion criterion)
1. Please review the changes in `analytics/schemas/events.md` §5. They are: `ConversationAnswered` and `ReputationShifted` (your #20–#22 follow-up), `MatchEnded` mode now including `match30`, and `PhaseLeft`.
2. **Funnel order (your #64 ruling, done).** VS1 is `inOrder`: a step is credited only to a player who already holds the previous step, so kingdom-wide completions and captures no longer inflate steps 3 and 5. Repeats are counted, not logged (FORGE-05 #64 M1).
3. **FirstGather under D-030.** Ruler gathering is optional, and G9 credits citizens' gathering to every member, so step 2 completes within seconds and measures "the economy started". I kept BRIEF §13 as written. Please decide whether a v2 funnel should replace it with FirstCitizenInspected or FirstConversation. That would need a server-side conversation event, e.g. the proposed G9 `CitizenAnswered`.
4. **`MatchService.mode` in G3.** MatchAnalyticsService reads it (`slice` | `match`, PROVISIONAL in the MatchService header); please add it to CONTRACTS G3 additively. Without it, MatchEnded logs `mode = unknown`.
5. **`PlayerReady` in game-001.** GameEvents names FORGE-01's PlayerService as its producer, but VS-1 boots none. Analytics no longer needs it. Any other framework consumer that waits for `PlayerReady` (OnboardingService defaults to it; game-001 overrides with `KingdomJoined`) has the same gap.

## Evidence
- `games/game-001/tests/experience/MatchAnalytics.spec.luau` (7) runs the real AnalyticsService with game-001's config on the real GameEvents bus:
  - the funnel with G9 attribution: rivals get nothing, and the placer alone gets FirstBuildPlaced;
  - each step logged once;
  - one SessionStart per visit;
  - the drop-off point;
  - MatchEnded's won, phase and mode, with no spectators;
  - PhaseLeft order, the Lobby and Results, spectators;
  - the headless boot.
- Framework specs:
  - `AnalyticsService.spec`: `startOn` and `leftInfo`, including one that errors;
  - `AnalyticsSchema.spec`: the session checks.
- `python3 roblox/tests/unit/experience/mutations.py FL-0063` → 14/14 caught.

## Interfaces touched
- Additive framework config: `session.startOn`, `session.leftEvent` and `session.leftInfo` (AnalyticsSchema validates them).
- No contract change. The two FORGE-01 calls use interfaces §8 `AnalyticsService:event` as it is.

## Files to read
- `games/game-001/config/Analytics.luau`
- `games/game-001/src/server/Services/MatchAnalyticsService.luau`
- `analytics/schemas/events.md` §5
