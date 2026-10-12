# Crown Arena fairness harness (FL-0076, FORGE-05)

Nobody has to trust that arena support is fair: these files measure it (design `crown-arena.md` §6, §9;
CONTRACTS G12.3). **Status: scaffold.** It runs on a local duel double and the design numbers until
FORGE-01's `Arena/DuelModel.luau` (FL-0070) and config `Support.luau` (FL-0071) land, so its numbers say
how the harness behaves, not whether the game is fair.

| File | What it is |
|---|---|
| `CapsContract.luau` | G12.3 caps and outcome bounds as data; `Caps.spec` keeps it equal to the CONTRACTS.md table |
| `CapsCheck.luau` | `check(modifiers) -> problems`: every mechanical cap (passive, slots, duration, magnitude, stat total, healing, quiet start, floor, no effect on the opponent) |
| `DesignSupport.luau` | design §3 tiers and §4 perks (pledged/empowered) as modifier lists; every perk set per tier |
| `DuelDouble.luau` | stand-in duel model with the G12.2 signatures (`new`, `step`) plus `view`; applies support the G12.3 way |
| `Duellist.luau` | scripted duellists: novice / average / expert, +15 points of hit and parry accuracy per tier |
| `Harness.luau` | Monte Carlo cells, 95 % Wilson intervals, bound checks, Markdown report |
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

## When FL-0070/FL-0071 land

1. Point `Harness.run({ model = DuelModel })` at `@game/ReplicatedStorage/Game/Arena/DuelModel`. The CLI then
   runs through the Lune harness (game requires), and the duellists get a small `view` adapter if the real
   `DuelState` differs.
2. Read support numbers from config `Support.luau` instead of `DesignSupport` (`options.support`).
3. `Caps.spec` already checks `Arena/Caps.luau` against the same sets as soon as the file exists.
4. Add a `game-001 fairness` step to `roblox/scripts/check.sh` (the merge gate, 2000 duels per cell) and
   attach the report to the CI artifact.
