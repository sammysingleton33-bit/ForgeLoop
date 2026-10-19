# Crown Arena fairness harness (FL-0076, FORGE-05)

Nobody has to trust that arena support is fair: these files measure it (design `crown-arena.md` §6, §9;
CONTRACTS G12.3). **Status: gate.** `FairnessGate.spec` runs FORGE-01's `Arena/DuelModel` with the game's
config `Support` (through `Arena/SupportModel`) in every `check.sh` run and fails when an outcome bound breaks.
The other specs prove the harness itself on a local duel double and the design numbers.

| File | What it is |
|---|---|
| `CapsContract.luau` | G12.3 caps and outcome bounds as data; `Caps.spec` keeps it equal to the CONTRACTS.md table |
| `CapsCheck.luau` | `check(modifiers) -> problems`: every mechanical cap (passive, slots, duration, magnitude, stat total, healing, quiet start, floor, no effect on the opponent) |
| `DesignSupport.luau` | design §3 tiers and §4 perks (pledged/empowered) as modifier lists; every perk set per tier |
| `DuelDouble.luau` | stand-in duel model with the G12.2 signatures (`new`, `step`) plus `view`; applies support the G12.3 way |
| `Duellist.luau` | scripted duellists: novice / average / expert, +15 points of hit and parry accuracy per tier |
| `Harness.luau` | Monte Carlo cells, 95 % Wilson intervals, bound checks, Markdown report |
| `ConfigSupport.luau` | the game's support numbers (config `Support` via `SupportModel.modifiers`) behind the DesignSupport interface |
| `FairnessGate.spec.luau` | **the merge gate**: real DuelModel + config Support, supportMatters and skillStillWins at 2000 duels per cell, every noAutoWin cell at 400 (`FORGE_FAIRNESS_FULL=1`: 2000 and every loadout, about 10 min); a negative case proves it fails on the pre-trim numbers; report in `roblox/build/fairness/report.md`, uploaded on main as the CI artifact `forgeloop-fairness-<sha>` |
| `Caps.spec.luau`, `Fairness.spec.luau` | run in `check.sh` (game-001 specs); they prove the caps checks and the harness, each shown able to fail |
| `run.luau` | the full measurement and report |

## Run it

```bash
lune run games/game-001/tests/fairness/run.luau            # average skill, 200 duels per cell (~3 s)
lune run games/game-001/tests/fairness/run.luau --full     # 3 skills x every tier/perk set + 12 loadouts, 2000 per cell (~4-5 min)
lune run games/game-001/tests/fairness/run.luau --duels 500 --skills novice,expert --seed 7 --out /tmp/report.md
```

Exit code 1 when an outcome bound fails. The report goes to `roblox/build/fairness/report.md` (gitignored)
by default. Rates are side A's wins plus half its draws. Side A plays model side "a" in odd duels and "b"
in even ones, so the model's resolution order cancels out (a mirror match measures 50-51 % at 2000 duels).

## Cells and bounds (G12.3, PROVISIONAL)

- `supportMatters/<skill>`: Adoring (default perks reforge + fieldRemedy + heartyRations, empowered) vs
  Hostile at equal skill must win 55-65 %.
- `skillStillWins/<higher>><lower>`: one skill tier better with Hostile vs Adoring must win at least 60 %.
- `noAutoWin/...`: every tier x perk set (and, with `--loadouts`/`--full`, every loadout alone and with
  Adoring support) vs the equal-skill Hostile baseline with sword and shield/medium must win at most 70 %.

A check FAILs when the measured rate breaks its bound. "Marginal" means the 95 % interval crosses the
bound: run more duels before concluding anything.

## Results on the game (headless, scripted duellists)

| Date | Config | supportMatters (novice / average / expert) | skillStillWins | worst noAutoWin |
|---|---|---|---|---|
| 2026-10-19 | design numbers (fieldRemedy 5/8 %, Adoring passive +2 %) | 65.8 / **67.7** / 67.0 % (FAIL) | 78.8 / 72.1 % | 69.8 % |
| 2026-10-19 | trim C (#209: fieldRemedy 3/5 %, Adoring passive +1 %; FORGE-00 ruling) | 60.1 / 60.7 / 61.3 % | 81.8 / 77.2 % | 65.9 % (400 per cell) |

These say the numbers keep support inside the bounds against scripted duellists. They do not say a duel feels fair to a
player: that is the Studio arena script.

## Still open (FL-0076)

- `run.luau` (the standalone CLI) still runs on the duel double; the game numbers come from `FairnessGate.spec`
  (`lune run roblox/tests/harness/run.luau --project games/game-001/default.project.json --specs games/game-001/tests/fairness FairnessGate`).
- The Studio arena script (STUDIO_PLAYTEST) once FORGE-01's DuelService and FORGE-03's arena UI are in a build.
