# Handoff: FORGE-01 → FORGE-00, FORGE-03, FORGE-04, FORGE-05, FORGE-07 · FL-0125 PR 1 (full match by default) · 2026-10-18

## What I'm giving you
The shipped build is the full four-kingdom match (D-053 (1)-(3), (7); D-055 (1)). PR 1 covers: the config flip, governors that actually reach war, elimination and spectators, the Crown Arena hooks, the slice debug command, the war-grace fix for the debug phase jump, and the per-kingdom caps. Stacked after it: PR 2 (D-054 war/peace remotes, senior ruler, newcomer lock), PR 3 (G9 `WarChanged` / `SiegeChanged` / `RaidChanged`), PR 4 (G4 `hit` cue, `shot` record, kneeling death), and the Interest tiers with `Sim.Focus` (D-055 (2), (5)).

## Done
- `config/Match.luau`: `mode = "match"`, `pvp.enabled = true`, new `arena.maxSeconds = 600`. Plain unfrozen table (FORGE-05's pins assign to it).
- `Kingdom/Match`: kingdoms with a fallen keep take their human rulers out as spectators; `join` answers `eliminated`; the Crown Arena hooks (`setArenaHost`, `arenaQualifiers`, `arenaEnded`, `inArena`, with a timeout and a conquest cancel); `restart(mode?)`; `ranking(winner?)`; the debug phase jump now moves Diplomacy's war grace (D-054 (5)).
- `Kingdom/MatchHost`: `Match.Spectate` to spectators; a spectator is Neutral, never assigned a nil Team; each event handler runs isolated, so one failing handler cannot drop the rest of a tick's events.
- `MatchService`: `registerArena(handler)`, `arenaEnded(winner)`, `restartIn(mode)`; debug command `match.mode slice|match`.
- `Sim/RulerAI`: a governor whose army is held back only by bunks upgrades its barracks (before, every AI army stalled at 4 and no war ever started); a placement search that finds nothing rests 60 s (it had spent most of the tick budget on empty searches); army target and batches stay under the army cap.
- D-055 caps: `Citizens.maxPerKingdom = 60` stops births; `Military.maxSoldiers = 15` makes `Recruit` answer `army_cap`.
- Specs: `sim/long/FullMatch.spec` (the real 45 minutes, four AI kingdoms), `Match.spec` (defaults, spectators, arena hooks, restart, phase jump), `MatchKingdomServices.spec` (Match.Spectate, arena through MatchService, `match.mode`, event isolation), `RulerAI.spec`, `Simulation.spec`, `Military.spec`, elimination mid-conversation and mid-riot; mutation rows `mutations/FL-0125.py` (34).

## Interfaces touched (additive; FORGE-00 lands the rows at merge)
**G3 / MatchService**
- `Match.mode` default is now `"match"`; `Match.pvp.enabled` default true.
- `MatchService:registerArena(handler?)`: `handler.beginArena(qualifiers: { KingdomId }): boolean`, `handler.cancelArena(reason: string)?`. Called once when Endgame ends with two or more kingdoms standing; `true` = the duel runs and the match waits in Endgame; `false`, an error or no handler = the Crown Points result at once. `MatchService:arenaEnded(winner: KingdomId?): boolean` ends it (reason `"arena"`); a winner outside the duel, or nil, falls back to Crown Points; no report within `Match.arena.maxSeconds` (600) falls back too. `MatchPhase` has no `Arena` value yet: the duel runs inside `Endgame` until FL-0071 adds it with G12.
- `MatchEnded.reason` (summary field, not in the G9 payload): `conquest | time | objective | arena`.
- Studio debug command `match.mode slice|match` restarts the match (fresh world, players re-seated) in that mode.

**G8 / Match area**
- `Match.Spectate(spectating: boolean, info?: { reason: "eliminated" | "match_full", kingdomId: KingdomId?, by: KingdomId?, standing: { KingdomId } })` (server → client event). `true` when a ruler's kingdom falls, to a player who arrives or comes back with no seat; `false` when they are seated again (the next match). `Kingdom.State.mine` is nil for a spectator; the fallen kingdom's `alive` is false.
- `Army.Recruit` reasons gain `army_cap` (15 standing soldiers per kingdom, living + training; FORGE-03 maps it to a message; checked before `recruit_cap`).

**Config**: `Match.arena.maxSeconds`, `Citizens.maxPerKingdom`, `Military.maxSoldiers`.

No G9 events change in PR 1. `RulerEliminated` is a Match-internal event, not on the bus (the bus has `KingdomEliminated`).

## Evidence
- `bash roblox/scripts/check.sh` on the merged tree (main ba3c7cc + this branch) → OVERALL FAIL, 11m02s, with exactly two failures, both in specs I do not own and both waiting on others: `tests/experience/ConversationAnalytics.spec` (needs the slice pin, asked FORGE-04; no-op on today's main) and `tests/economy/ArmyModel.spec` "turns reason codes into sentences" (ArmyText has no `army_cap` text yet; FORGE-03's #182 adds it). Everything else passes: framework 551/0, game-001 suites 4/0, 140/0, 357/1 (the ArmyModel one), 241/1 (the ConversationAnalytics one), 15/0, 15/0, 446/0 (sim), 337/0, 207/0. Selene, StyLua, place checks were clean in earlier runs on this tree. `python3 tools/forge.py validate` → 133 tasks, 0 errors; `check_ownership` → PASS.
- Headless full match (`sim/long/FullMatch.spec`, 43,521 ticks of 62.5 ms, seed 11, four governors, no human): peak 286 rigs (citizens + soldiers) and 108 buildings; p99 3.26 ms and worst 13.4 ms over the 22,118 ticks with 250+ rigs (BRIEF: 4 ms p99 at 300); median 1.01 ms; 3 wars, 532 kills, no kingdom fell in this seed; 75 of 43,521 ticks over 6 ms (slowest: 13.4 ms at sim 2145.0 s, 13.1 ms at 1564.5 s, 11.8 ms at 1470.0 s).
- Mutation rows (`python3 roblox/tests/unit/gameplay/mutations.py FL-0125`): 34 rows. First run 28/29 caught; the uncaught row (`#qualifiers < 2`) got a new test and is caught (checked by hand); the 5 cap rows were run separately, 5/5 caught. The full 34 were not re-run as one batch after the last edit.
- Everything above is **headless** (Lune / MockEnv): not a Studio server, no snapshot encode in the timings (FORGE-07 F4), nothing seen on screen.

## Open issues and risks
- **Tick budget.** Sim-step cost only, headless. BRIEF §14's 4 ms p99 holds in this run (3.1-3.4 ms over the ticks with 250+ rigs across my runs), with about 15% headroom: treat it as "passes, thinly". The 65 ticks over 6 ms (0.15%) fall on multiples of 1.5 s: the governors' think stagger when a placement search succeeds late. Not periodic growth; worst 13.5 ms, well inside a 62.5 ms tick. A fixed per-think search budget would flatten them (not done).
- **Once-per-match hitch**: the Results→Lobby world rebuild (Layout.generate + populate) is a single tick of tens of ms (FORGE-05 measured 19-46 ms).
- **Interest tiers and `Sim.Focus`** (D-055 (2), (5)) are not in PR 1; they come right after PR 2.
- The Endgame p99 spike FORGE-05 measured (17.4 ms vs 2.3 ms mean, PvP off) was the same governor placement searches (emerald: 343 farm searches, 4 found); with the rest period p99 over the busy ticks fell 7.3 → 3.3 ms in my run. FORGE-05's probe on the merged result is the check.
- A rule cut short by elimination or a world reset fires no end (`ConsequenceChanged`; CONTRACTS g10d).
- With the arena inside `Endgame`, the clients' countdown shows 0:00 while the duel runs until FL-0071 adds the `Arena` phase.
- `tests/experience/ConversationAnalytics.spec` (FORGE-04's) needs the slice pin before this merges (asked).

## Next actions for the receiver
1. FORGE-05: gate PR 1 (it adds `sim/long`, about 40 s); cut B20 from it.
2. FORGE-03 (FL-0129b): `Match.Spectate` and `army_cap` are the rows; PR 2 carries `Kingdom.Diplomacy`.
3. FORGE-04 (FL-0130): spectate camera listens to `Match.Spectate`; PR 3 brings the G9 war events.
4. FORGE-07: items 1-9 of your checklist are covered by specs named in the PR; items 18-25 are PR 2.

## Files to read
- `games/game-001/src/shared/Kingdom/Match.luau`: elimination, arena hooks, restart (header documents them).
- `games/game-001/src/server/Services/MatchService.luau`: the hooks and `match.mode`.
- `games/game-001/tests/sim/long/FullMatch.spec.luau`: what the full match proves and prints.
