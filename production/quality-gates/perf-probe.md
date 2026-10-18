# Match performance probe: headless baselines (FL-0131, FL-0032; release checklist L8, D1, D2)

_Owner: FORGE-05. Probe: `games/game-001/tests/balance/MatchProbe.spec.luau`._

**What this is.** Every real server service of both trees runs in one MockEnv, in Lune, with `Match.mode = "match"` and one idle human in crimson. The probe times three things, each as wall-clock mean, p99 and max per phase:
- `Match:update`, the simulation: **sim**.
- `MatchHost:step`, which is the simulation plus world view plus kingdom state: **host**.
- `EntityService:replicate`, which runs per 10 Hz snapshot (diff, codec encode and send): **replicate**.

It also counts entities (citizens, soldiers and buildings per kingdom, sampled every virtual second) and BaseParts under Workspace (every 30 virtual seconds).

**What this is not.** These are headless numbers, not Studio and not a device:
- Lune runs plain Luau, without Roblox's native code generation.
- MockEnv's Instance tree is not the engine's.
- MockEnv returns the exact 1/16 s tick, so one host tick is one sim step. A live server clamps `dt` to 1 s and can run up to 16 steps in one tick after a hitch.
- `replicate` runs on its own loop. A per-Heartbeat budget (BRIEF §14) therefore compares with host + replicate, not with either one alone.

Use these numbers to compare builds with each other. Only Studio's MicroProfiler and a real device measure the frame budget.

**Run it**
- Default, as in `check.sh`: one seed and the first 60 virtual seconds, about 12 s of wall time. It asserts only that match mode boots, ticks and logs no errors.
- Full: two seeds and the whole match, about 6 minutes of wall time per seed:
  `FORGE_MATCH_PROBE=1 lune run roblox/tests/harness/run.luau --project games/game-001/default.project.json --specs games/game-001/tests/balance MatchProbe`

## Baseline 1: main `5e9e8a10`, before FL-0125 (2026-10-18)
`Match.mode = "match"` as it is on main before FL-0125. PvP is off (`Match.pvp.enabled = false`), the AI kingdoms are populated, and the human does nothing.

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
| Entities (end of Endgame) | 451: azure c101/s4/b40, emerald c101/s4/b40, gold c101/s4/b39, crimson (idle human) c12/s0/b5 | 453 |
| Workspace BaseParts (at 2,670 s) | 24,494 | 24,947 |
| Wall time | 323 s | 356 s |

**Findings** (headless, for the owners to weigh):
1. **Endgame sim p99 rises to about 17.4 ms in both seeds,** from 3.1 ms in Conflict, while the mean only goes from 1.3 to 2.3 ms. That points to a periodic cost in Endgame, not steady growth. FORGE-01 has been told; it is worth a look before FL-0125 adds wars on top.
2. The AI kingdoms grow to about 101 citizens and 40 buildings each, but keep only 4 soldiers each with PvP off. FL-0125's PvP and wars will change the peak, so re-measure at B20.
3. Host step is dominated by the MockEnv world view (Kit building models), which is not representative of the engine. Parts reach about 24.5k at the peak, all of them server-side building and world models.
4. The Results tick has a one-off spike of 19–46 ms (the match end and its summary).

## Next
- B20 (FL-0125): rerun the full probe on the cut and add a row here.
- Studio: FORGE-00's B20 rows ask for MicroProfiler server numbers at Endgame as an indication.
- Device: release checklist D6 (owner).
