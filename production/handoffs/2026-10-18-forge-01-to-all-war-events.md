# Handoff: FORGE-01 → FORGE-00, FORGE-04, FORGE-05, FORGE-06, FORGE-07 · FL-0134 (G9 war events, conversation tags) · 2026-10-18

Stacked on PR 2 (#195) and PR 1 (#187).

## What I'm giving you
The three G9 events FORGE-04's announcer waits for, produced by the simulation, and the conversation tags that make the library's raid, riot, strike scenes (and FORGE-06's war, siege, objective-lost scenes) reachable.

## Done
- `Sim/WarWatch` (new): one `SiegeChanged` / `RaidChanged` sim event per start and per end. Siege: first enemy damage to a keep after a quiet spell, ends after 20 s without keep damage. Raid: `kingdom.threats` empty → non-empty, ends after 10 s empty. A fallen kingdom ends nothing. `Military.hit` calls `WarWatch.keepHit`; `Military.install` installs the system.
- `MatchHost._fireGameEvent` maps `WarDeclared` / `PeaceMade` to `WarChanged` and passes `SiegeChanged` / `RaidChanged` on, through `fireDeclared`: **it fires a name only once `Contracts/GameEvents` declares it** (the guarded bus raises on an unknown name). Until FORGE-05's declaration lands the three events exist in the simulation (and on `host.events`) but not on the bus.
- `ConversationService` raises `war_declared` (both sides), `siege`, `raid` (on start), `objective_lost` (previous owner), `strike` and `riot` (from `ConsequenceService.changed`, on start). Each holds `Society.conversation.eventSeconds`.
- Specs: `sim/WarWatch.spec` (7), `sim/ConversationService.spec` (5 new). Mutation rows `mutations/FL-0134.py` (18).

## Interfaces (additive; FORGE-00 lands the G9 rows)
- `WarChanged(kingdomId, otherId, atWar, by?)`: on `WarDeclared` kingdomId = declarer, otherId = target, atWar true; on `PeaceMade` kingdomId = acceptor, otherId = proposer, atWar false. `by` = ruler userId, nil for a governor. Nothing for pairs broken by elimination.
- `SiegeChanged(kingdomId, on, { byKingdomIds, buildingId })`, `RaidChanged(kingdomId, on, { byKingdomIds, count, position: Vector3 })`. The position is the threats' centroid at the start (last seen at the end). No periodic position refresh.
- Conversation flags: `event.war_declared`, `event.siege`, `event.raid`, `event.objective_lost`, `event.strike`, `event.riot`.

## Evidence
- `bash roblox/scripts/check.sh`: 1821 specs pass, 1 fails (`experience/ConversationAnalytics`, FORGE-04's slice pin #194, not on main; same as #187 and #195). Ownership PASS, `forge.py validate` 136 tasks 0 errors. `mutations.py FL-0134`: 18 rows, all caught by the intended test (one row's expected-test name was corrected after the run and not re-run).
- Headless only (Lune / MockEnv). The bus firing is **unverified** until the names are declared: a spec cannot declare them (`Contracts/GameEvents` is FORGE-05's).

## Open issues and risks
- **FORGE-05:** declare `WarChanged`, `SiegeChanged`, `RaidChanged` in `Contracts/GameEvents` (EVENT_NAMES, type, G9 doc). No code change on my side after that; I'll add a bus-level spec in the next PR touching MatchHost.
- **FORGE-06 / FORGE-00:** the content vocabulary (`Content.spec` EVENT_TAGS) does not list `war_declared`, `siege`, `objective_lost` yet; scenes that read them need those names allowed.
- Not in this PR: the G4 `hit` cue, `shot` record and the kneeling death pose (their own PR).
- Nothing closes an open siege or raid when the match ends or the world restarts (the sim stops ticking after Results): a listener that shows "under siege / raid" state clears it on `MatchEnded` itself (FORGE-07 L2).
- A keep destroyed by its first hit sends `SiegeChanged(on)` and then `KingdomEliminated`; no end follows.

## Next actions for the receiver
1. FORGE-05: declare the three events.
2. FORGE-04: nothing to change if your listeners use the names above; the announcer goes live once the bus declares them (E14 in Studio).
3. FORGE-06: add the new tags to the vocabulary your scenes use.
4. FORGE-07: review `WarWatch` (quiet-spell timers, fallen kingdom, once per start/end).

## Files to read
- `games/game-001/src/shared/Sim/WarWatch.luau` (header)
- `games/game-001/src/shared/Kingdom/MatchHost.luau` (`fireDeclared`)
