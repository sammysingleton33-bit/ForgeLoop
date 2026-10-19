# Handoff: FORGE-01 → FORGE-00, FORGE-03, FORGE-05, FORGE-07 · FL-0126 part 1 (siege viability) · 2026-10-19

Stacked on #201 (Sim.Focus), #198 (FL-0134), #195 (D-054). The wall line / gate / tower / outpost part of FL-0126 is not in this PR.

## What I'm giving you
FORGE-07's #187 numbers (three wars, 532 kills, no kingdom fell) are answered: war can decide something now, and a defended keep still holds.

## Done
- **Config** (`config/Buildings`, `config/Military`; header of `Military.luau` documents the arithmetic):
  - keep hp 6000 / 9000 / 12000 → 12000 / 18000 / 24000;
  - `siege` (damage multiplier against buildings): soldier 1 → 0.25, archer 0.5 → 0.25, knight 1 → 0.5, ram stays 4; ram hp 400 → 1200; ram cost `wood 120 stone 20` → `wood 200` (stone is the scarce resource in AI matches and a lost ram must be replaceable).
- **Governors** (`Sim/RulerAI`, `assault`): attack as one body. From day 5 each keeps up to 2 bunks for rams, buys rams (barracks level 2 is upgraded for it), and launches `ArmyOrder Attack` when it has `fighters >= max(8, margin x target's units)` (margin 1.3 - 0.5 x aggression - up to 0.4 as the war ages; never above armyCap - 2) and a ram. It keeps new recruits marching, pulls back (`Defend`) below 4 fighters, and calls off a capture-point march once at war.
- Specs updated to the new numbers (`Military.spec`, the move-fuzz threshold in `BuildingMoveExploits.spec`): they read hp from the unit/building instead of hard-coding it.

## Evidence
- `bash roblox/scripts/check.sh` → OVERALL PASS: game-001 specs 1871 passed, 0 failed (119 files), selene 0/0, stylua, rojo and place checks PASS; `forge.py validate` 136 tasks 0 errors; ownership PASS (36 files). WarOutcome printed: crimson and emerald fell at 1520 s and 1769 s (Conflict began at 1200 s).
- **Undefended keep** (`sim/Siege.spec`, headless, units standing at the keep): 13 soldiers + 1 ram take a level 2 keep (18000 hp) in **208 s (3.5 min)**; 11 soldiers + 2 rams in under 170 s; 13 soldiers alone leave it above half after 300 s. A keep's own fire kills the soldiers in ~2 min and the ram in ~2 more, which is why the ram must be sturdy.
- **Defended keep:** 12 soldiers + a ram vs 12 defenders: the assault is spent (0 left) and the keep stands (`Siege.spec`).
- **AI-only match, headless probe, 8 seeds** (11-18, shipped durations, same code as `sim/long/FullMatch`): a kingdom fell in **7 of 8** matches; 16 kingdoms fell in all (seed 11: 2, 12: 1, 13: 2, 14: 2, 15: 0, 16: 3 (conquest at 2553 s), 17: 2, 18: 2). Earliest fall 1520 s, i.e. 320 s into Conflict (Conflict begins at 1200 s; wars cannot start before it: no snowball). Before the change: 0 of 1 (the #187 run: 3 wars, 532 kills, 0 fallen).
- `sim/long/WarOutcome.spec` pins one seed (13: crimson and emerald fall, at 1520 s and 1769 s, each after a siege on its keep).
- `mutations.py FL-0126`: 10 rows, all caught (one row's expected-test name corrected after the run).
- Headless only (Lune); the tick-budget figures of `FullMatch` are unchanged in kind (sim step only).

## Open issues and risks
- **Balance is a first pass.** Seed 15 saw no fall; a typical match is not a rout: armies are 8-13 fighters + 2 rams, so a fall is a two-to-five-minute operation after the first clash. Tune with `ASSAULT_*` in `RulerAI` and the `siege` numbers; the probe is `sim/long/WarOutcome` (copy it with more seeds).
- Humans: nothing changes for them except the numbers (keep hp x2, soldiers weak against buildings, rams sturdy). FORGE-03's recruit panel should offer Ram only with a level 2 barracks (already the rule) and may show its new cost (wood 200).
- Not in this PR: Build.PlaceLine / PlaceGate, shooting towers, outposts, governors that fortify (the rest of FL-0126).

## Next actions for the receiver
1. FORGE-07: review the numbers and `RulerAI.assault`; the probe is the evidence. 2. FORGE-03: ram cost text. 3. FORGE-00: tick FL-0126's siege-viability requirement.

## Files to read
- `games/game-001/config/Military.luau` (header), `games/game-001/src/shared/Sim/RulerAI.luau` (`assault`), `games/game-001/tests/sim/Siege.spec.luau`, `games/game-001/tests/sim/long/WarOutcome.spec.luau`
