# Match performance probe: headless baselines (FL-0131, FL-0032; release checklist L8, D1, D2)

_Owner: FORGE-05. Probe: `games/game-001/tests/balance/MatchProbe.spec.luau`._

**What this is.** Every real server service of both trees runs in one MockEnv, in Lune, with `Match.mode = "match"` and one idle human in crimson. The probe times three things, each as wall-clock mean, p99 and max per phase:
- `Match:update`, the simulation: **sim**.
- `MatchHost:step`, which is the simulation plus world view plus kingdom state: **host**.
- `EntityService:replicate`, which runs per 10 Hz snapshot (diff, codec encode and send): **replicate**.

It also counts:
- **Rigs**: citizens plus soldiers per kingdom, sampled every virtual second. These are the replicated entities that clients render as rigs. BRIEF §14 (and line 78) budgets **300 per server**, about 75 per kingdom, and at most **150 rendered on screen**. Buildings are counted beside rigs, not as part of them.
- **Bandwidth**: the bytes of EntityService's `Sim.Snapshot` and `Sim.Events` buffers that reach the one human, per phase, in KB/s. BRIEF §14 sets ≈ 5 KB/s per player at 50 entities for the VS-1 broadcast, and ≤ 20 KB/s with the VS-2 interest tiers. There is no interest management yet, so every snapshot goes to every player.
- **The ten slowest sim ticks per phase**, each with its sim time, to tell a periodic cost from a one-off.
- **BaseParts under Workspace**, every 30 virtual seconds.

**What this is not.** These are headless numbers, not Studio and not a device:
- Lune runs plain Luau, without Roblox's native code generation.
- MockEnv's Instance tree is not the engine's.
- MockEnv returns the exact 1/16 s tick, so one host tick is one sim step. A live server clamps `dt` to 1 s and can run up to 16 steps in one tick after a hitch.
- `replicate` runs on its own loop. A per-Heartbeat budget (BRIEF §14) therefore compares with host + replicate, not with either one alone. In the engine, a host tick and a snapshot can fall in the same Heartbeat, so their worst cases can add up. The one-off Results spike (finding 4) can therefore share a frame with the final snapshot.

Use these numbers to compare builds with each other. Only Studio's MicroProfiler and a real device measure the frame budget.

**Run it**
- Default, as in `check.sh`: one seed and the first 60 virtual seconds, about 12 s of wall time. It asserts only that match mode boots, ticks and logs no errors.
- Full: two seeds and the whole match, about 6 minutes of wall time per seed:
  `FORGE_MATCH_PROBE=1 lune run roblox/tests/harness/run.luau --project games/game-001/default.project.json --specs games/game-001/tests/balance MatchProbe`

## Baseline 1: main `5e9e8a10`, before FL-0125 (2026-10-18)
Main's default on this commit is still `Match.mode = "slice"`. The probe forces `"match"` for the run and restores it afterwards. PvP is off (main's `Match.pvp.enabled = false`), match mode populates the AI kingdoms, and the human does nothing. This baseline predates the rig, bandwidth and slowest-tick lines, so those columns come from baseline 2.

Both seeds reached Results at 2,700 virtual s, the default Pacing phase lengths, with **no error logs**. The two seeds agree within about 10 %; the ms below are seed 1, with seed 2 in brackets where it differs more.

| Phase | Ticks | Sim ms mean / p99 / max | Host ms mean / p99 / max | Replicate ms mean / p99 / max (snapshots) |
|---|---|---|---|---|
| Lobby | 320 | 0.003 / 0.008 / 0.03 | 3.5 / 7.6 / 12.7 | 0.66 / 2.3 / 5.1 (200) |
| Founding | 7,680 | 0.41 / 1.14 / 10.7 | 4.1 / 9.5 / 22.0 (max 115.0) | 0.97 / 2.6 / 5.3 (4,800) |
| Expansion | 11,520 | 0.83 / 1.78 / 20.4 | 4.9 / 9.9 / 28.5 | 1.67 / 4.3 / 8.9 (7,200) |
| Conflict | 14,400 | 1.33 / 3.09 / 30.3 | 5.8 / 11.8 / 44.9 | 2.56 / 6.5 / 21.7 (9,000) |
| **Endgame** | 9,600 | **2.30 / 17.39 / 35.1** | 7.4 / 22.8 / 46.9 (max 71.1) | 3.55 / 8.4 / 14.0 (6,000) |
| Results | 48 | 0.97 / 46.4 / 46.4 | 6.0 / 52.7 / 52.7 | 3.07 / 4.7 / 4.7 (30) |

| Peak | Seed 1 | Seed 2 |
|---|---|---|
| **Rigs** (citizens + soldiers; end of Endgame) | **327**: azure 101+4, emerald 101+4, gold 101+4, crimson (idle human) 12+0. **Over the 300 budget** | 327 |
| Buildings | 124: azure 40, emerald 40, gold 39, crimson 5 | 126 |
| Workspace BaseParts (at 2,670 s) | 24,494 | 24,947 |
| Wall time | 323 s | 356 s |

**Findings** (headless, for the owners to weigh):
1. **Rigs exceed the 300-per-server budget** (BRIEF §14, line 78) with PvP off and an idle human. Each AI kingdom grows to about 105 rigs, against the ~75 per kingdom the budget allows. Three AI kingdoms plus the idle human already reach 327. If a human kingdom grew like the AI ones, it would reach about 420. Four kingdoms of 105 rigs each are also about 2.8× the 150-on-screen limit if one view can see them all; that depends on the camera and LOD and is unmeasured here. **This is for FORGE-00 and FORGE-01:** cap the population at about 75 per kingdom, or change the budget.
2. **Endgame sim p99 rises to about 17.4 ms in both seeds,** from 3.1 ms in Conflict, while the mean only goes from 1.3 to 2.3 ms. The cause is not established here. FORGE-01 reports, from his branch, that repeated RulerAI placement searches for farm spots that don't exist are most of the cost, and he is throttling failed searches. From baseline 2 the probe prints the ten slowest ticks per phase with their sim time, to show whether the spikes are periodic.
3. With PvP off, the AI kingdoms keep only 4 soldiers each. FL-0125's PvP and wars will change the peak, so it must be re-measured at B20.
4. Host step is dominated by the MockEnv world view (Kit building models), which is not representative of the engine. Parts reach about 24.5k at the peak, all of them server-side building and world models.
5. The Results tick has a one-off spike of 19–46 ms (the match end and its summary). See the note on a shared Heartbeat above.
6. **Bandwidth was not measured in baseline 1.** It comes from baseline 2.

## Next
- B20 (FL-0125): rerun the full probe on the cut and add a row here.
- Studio: FORGE-00's B20 rows ask for MicroProfiler server numbers at Endgame as an indication.
- Device: release checklist D6 (owner).
