# FORGE-07 baseline audit: the full-match surface (FL-0132)

Date 2026-10-18. Main 4142265 (Operation Crownfall, D-053). **Evidence: a static read of the code on main. Nothing was run (my sandbox does not run repo scripts) and there is no Studio evidence.** Each item cites the lines I read, so anyone can check it. This file is the baseline the FL-0125, FL-0126 and arena PR reviews are measured against; it is updated as those PRs open.

## 1. Owed re-reviews (done 2026-10-18, COMMENT reviews on each PR head)
| PR | Verdict | Next action |
|---|---|---|
| #176 FL-0058 economy.md: ruler caps are enforced | READY TO MERGE (6887821) | FORGE-05; merge #177 before or with it (it cites #177) |
| #177 FL-0061 PACING slice income targets | READY TO MERGE (906dc2f) | FORGE-05 |
| #118 Specs: bad-argument lists really try nil | CHANGES REQUESTED, mechanical (b2c2bbb) | `docs/lessons-learned/gameplay.md` add/add conflict: take main's file and append the PR's last two bullets. The seven nil loops are still on main and every nil case returns `invalid_args` on today's validators |
| #90 FL-0013 Blender pipeline | CHANGES REQUESTED, mechanical (81f129e) | `agents/forge-02/STATUS.md` conflict: take main's #172 version. My M1 (no Blender job in `ci.yml`) and M2 (36 of 38 manifest previews not committed) stay open as tracked follow-ups |

## 2. Client-to-server surface on main (what the Crownfall PRs extend)
| Remote | Validation and limit (as declared) | Authority path |
|---|---|---|
| `Army.Recruit` (function) | barracks id 1..1e6, enum `soldier`, count 1..10; burst 4, 2/s | `host:command` to `Military.recruit`: `isInt(count,1,10)`, kind string, ownership, cap, treasury charge |
| `Army.Command` (event) | up to 50 ids (u16), kind enum, optional `vector3(4000)`, optional string 1..32; burst 6, 3/s | `UnitOrder`: only the caller's living soldiers; `attack` needs `atWar` (`not_at_war`); `out_of_bounds` |
| `Kingdom.SetJobQuota` (function) | job enum, integer 0..50; burst 10, 4/s | the only remote routed through `MatchHost:handleCommandRemote` (`MatchHost.luau:112`) |
| `Build.*`, `Kingdom.Gather/Converse/EndConversation/Choose/Get*` | reviewed in earlier passes | unchanged |
| **Not on any remote today** | `DeclareWar`, `ProposePeace`, `AcceptPeace`, `SetPriority`, `SetAlarm`, `Match.Spectate` | the three Diplomacy commands are called only by `RulerAI` and specs |

Every command passes `Commands.executeFor`, which refuses an inactive sim (`match_not_active`) and a dead kingdom (`kingdom_eliminated`) before the handler runs (`Commands.luau:175-190`). `RulerAI` uses the same path (`RulerAI.luau:235-254`), so the AI has no bypass.

## 3. Findings on main now (before FL-0125)
| ID | Severity | Finding | Owner / action |
|---|---|---|---|
| F1 | **gap, needs an owner** | Humans cannot declare war or propose or accept peace: no `Remotes.luau` row exists for the three Diplomacy commands. FL-0125 lists only `Match.Spectate`; FL-0129 assumes "existing Army/Diplomacy remotes". Without them PvP is AI against AI only | FORGE-00 assigns (FL-0125 or a new task); the new remotes need argument validation, a per-player rate limit, a phase gate and a co-ruler rule, and I review them as an authority surface |
| F2 | low, hurts B20 testing | Diplomacy's war gate is sim time fixed at install: `graceSeconds = phaseEnds.Expansion` (`Match.luau:197`), tested as `s.time < state.graceSeconds` (`Diplomacy.luau:79`). `Match:debugSetPhase` rewrites `phaseEnds` but not sim time or `graceSeconds`. After the Studio `match.phase Conflict` jump, `DeclareWar` (human or `RulerAI`) still answers `grace_period` until sim time 1200 s | FORGE-01: have `debugSetPhase` move `sim.diplomacy.graceSeconds` to `sim.time` when jumping to Conflict or later; FORGE-05: B20 rows must not assume a war after the jump |
| F3 | design, FORGE-00 decides | Co-rulers have equal command rights, and that is documented (`Match.luau:29`, "equal command rights (shared ownership)"). With D-053 (1) a mid-match joiner takes over a governor kingdom with full rights, so once war and peace are reachable any co-ruler can declare war, accept peace for the kingdom, set every job quota to 0 or move walls. Not a code defect | FORGE-00: record "all equal", or tier war, peace and similar irreversible acts. FL-0129's "permission rules follow the server" means "none" until then |
| F4 | note, verification demand | The host clamps `dt` to 1 s (`MatchHost.luau:567`) and `Simulation:advance` then runs up to 16 steps in one Heartbeat (`Simulation.luau:1940`). That recovers when a step costs far less than the 62.5 ms tick and spirals if one step ever exceeds it. `host._simMs` times `match:update` only (`MatchHost.luau:521-526`), while BRIEF §14's 4 ms p99 per Heartbeat includes snapshot encoding | FL-0125's PR must report per-step ms (p99 and worst), the entity count, and whether the figure includes the snapshot encode; a Lune or MockEnv number is headless and not a Studio server number |
| F5 | note | PACING.md still says the AI kingdoms are idle "in slice mode on main"; D-053 makes the full match the default | FORGE-04 revisits it with FL-0125 |

## 4. Checked on main and found sound (read, not run)
- **Combat is gated on war.** `atWar` guards `Army.Command` attack and every target selection in `Military.luau` (lines 261, 400, 423, 679-818, 920, 1006).
- **Elimination removes everything in one place.** `eliminate` (`Military.luau:544-607`) flips `alive`, pays the conqueror, plunders the treasury, removes citizens, units and buildings, resets every relation of the fallen kingdom to Peace, and emits one `KingdomEliminated`. `EntityService` despawns the removed ids by diffing its known set against the sim (`EntityService.luau:440-447`), after a short wait for the die cue, so clients do not keep ghost rigs.
- **The match always has an end path.** Conquest ends it when one or no kingdom stands (`Match.luau:569`); phases advance on sim time (`:582`); `_finish` yields no winner when none stands, so a double elimination is a draw (`:510`); Results returns to Lobby with the same players after `resultsSec` (`:615-626`).
- **Joining.** `_room` returns 0 for a dead kingdom (`Match.luau:265-271`), so no joiner is seated in an eliminated kingdom; with no room anywhere `join` answers `match_full`.
- **Argument validation** of the Diplomacy handlers: a non-string or over-long kingdom id answers `invalid_args` (`Diplomacy.luau:36`).

## 5. Review checklist for the Crownfall PRs
**FL-0125 (full match by default)**
1. `Match.mode = "match"`, `pvp.enabled = true`: confirm slice stays reachable through the debug command and that `match.phase` works (F2).
2. Elimination while a conversation is open: `ConversationService` holds an entity id whose citizen `eliminate` has removed. The next `Kingdom.Choose` or `EndConversation` must answer a refusal, leave no stuck state and never throw.
3. Elimination during a riot: `ConsequenceService` skips dead kingdoms (`ConsequenceService.luau:447`), so no riot-end `ConsequenceChanged` fires. Check that nothing holds a reference to the destroyed building and that clients clear the placards and fire.
4. Elimination in the same tick as another keep falling: ranking, winners, `Match.Ended` payload and the arena hand-off with zero or one survivor.
5. A move or a build command that arrives in the tick the keep falls: `_checkMove` and `executeFor` refuse on `alive`; confirm no half-applied state.
6. `Match.Spectate`: an eliminated ruler keeps no command rights, cannot be reseated, and spectating survives the Results to Lobby reset. A late joiner when every living kingdom is full or dead becomes a spectator, not a stuck player.
7. Governors from match start: the staggered decision loop stays inside the tick budget at four kingdoms; a human joining takes over cleanly; `assistHumans = false` still holds.
8. The full-match spec: it must assert that the match ends, record the per-step ms and entity count (F4), and say it is headless.
9. `beginArena(qualifiers)` / `arenaEnded(winner)`: no path leaves the match in Endgame forever (a missing `arenaEnded` must time out), and a failed arena falls back to Crown Points.

**FL-0126 (walls, gates, outposts)**
10. `Build.PlaceLine` / `PlaceGate`: bounded segment count and length per call, total cost charged atomically (all or nothing), rate limit, ownership of the territory, no-build areas and objective zones honoured (D-052 (2)).
11. Outposts grant territory: an outpost placed in neutral land must not let a kingdom wall in a rival's plot or an objective; a fallen outpost must give the territory back cleanly.
12. Towers that shoot: target selection uses `atWar` only, never hits peace-time kingdoms or own units, and the per-tick cost is bounded at peak entities.
13. Walls and the navigation graph: a closed wall must not leave citizens or armies with no path and spin the pathfinder every tick.

**Arena PRs (FL-0069 to FL-0071)**
14. `DuelModel` is pure and deterministic; a duel has a hard time cap and a defined result for a draw; a disconnect or an eliminated champion resolves the duel instead of stalling it.
15. Champion vote: co-ruler votes are counted once per user, a leaver's vote is dropped, the leadership fallback is deterministic.
16. Support offers and the caps: server-computed, the client sends only a choice; no remote lets a client pick its own number.
17. Every new remote: declared argument validation, a rate limit, a server-side authority check, and `kingdom_eliminated` / spectator refusal.

## 6. What is not covered
No Studio run and no local test run exist for any item above. FORGE-05's test merge and the owner's Studio session remain the only runs. This audit will be re-issued with verdicts per PR as the Crownfall PRs open.
