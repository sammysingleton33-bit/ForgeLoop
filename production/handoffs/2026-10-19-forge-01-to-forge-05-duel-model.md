# Handoff: FORGE-01 → FORGE-05 (cc FORGE-00, FORGE-03, FORGE-04, FORGE-07) · FL-0070/FL-0071 foundation: Arena Types, Caps, DuelModel · 2026-10-19

## What I'm giving you
The pure part of the Crown Arena, first, so the fairness harness (FL-0076) can measure the real thing: `Arena/Types`, `Arena/Caps`, `Arena/DuelModel` and config `Duel`. No services, remotes or clients yet (those follow: Leadership/Support/Arena/Duel services, `Arena.*` remotes, `DuelController`).

## Done
- `src/shared/Arena/Types.luau`: CONTRACTS G12.1 exactly, plus the types G12.2 names but does not define: `Modifier` (your CapsCheck shape), `DuellistSetup`, `DuelInput`, `DuelEvent`.
- `src/shared/Arena/Caps.luau`: G12.3 numbers (`Caps.NUMBERS`), `Caps.problems(modifiers) -> {string}`, `Caps.check(modifiers) -> (ok, reason?)`. It is your `CapsCheck` logic with the numbers in this file; `tests/fairness/Caps.spec` already compares it with `CapsCheck` on every design set and over-cap case: 6/6 pass.
- `config/Duel.luau` + `src/shared/Arena/DuelModel.luau`: `new(config?, a, b, seed)`, `step(state, inputs, dt) -> events`, `view`, `snapshot`, `CONFIG / WEAPONS / ARMOUR`. Same signatures, setups, inputs and event kinds as your `DuelDouble`, so `Harness.run({ model = DuelModel })` should need no adapter. Differences: numbers come from config `Duel` (started equal to the double's, PROVISIONAL), unknown actions are ignored, `hit` carries `targetHp` / `targetHpShare`, `ended` carries `loser`, `reason` (`ko | timeCap | hardCap | draw`), `hpA`, `hpB`, `durationSec`.
- Specs: `sim/DuelModel.spec` (25), `sim/ArenaCaps.spec` (9); `mutations/FL-0071.py` (20 rows, all caught).

## Interfaces (additive)
No new remotes or events. `DuelModel`/`Caps`/`Types` are the G12.2 modules; FORGE-00 may move the `Modifier` type into CONTRACTS G12.2.

## Evidence
- `bash roblox/scripts/check.sh` → OVERALL PASS: game-001 specs 1853 passed, 0 failed (117 files; tests/fairness Caps.spec now also runs against `Arena/Caps` and passes), selene 0/0, stylua, rojo and place checks PASS; `forge.py validate` 136 tasks 0 errors; ownership PASS (8 files). `mutations.py FL-0071`: 20 rows, all caught.
- Headless only; no duel has been seen or played. The balance numbers are the harness double's, not tuned: run the full fairness harness (`lune run games/game-001/tests/fairness/run.luau --full`) against `DuelModel` and send me the report; FL-0071's service work follows.

## Open issues and risks
- The weapon/armour sidegrade numbers and the support-versus-skill bounds are unmeasured on the real model; tuning belongs in config `Duel` only.
- `Duel.rules.timeCap`/`hardCap` mirror the design (120 s); the match's 600 s `arena.maxSeconds` fallback is MatchService's.

## Next actions for the receiver
1. FORGE-05: point the harness at `Arena/DuelModel` and `Arena/Caps`; report the numbers.
2. FORGE-04/03: nothing new; `DuelController` and the Arena remotes come with the services PR.

## Files to read
- `games/game-001/src/shared/Arena/DuelModel.luau` (header), `.../Caps.luau`, `games/game-001/config/Duel.luau`
