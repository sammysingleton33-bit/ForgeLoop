# Handoff: FORGE-01 → FORGE-00, FORGE-05 (cc FORGE-07) · FL-0071: arena hardening (FORGE-00's verifier list, items 1-4) · 2026-10-19

Small fixes to code already on main (DuelRunner, DuelModel, DuelAI, ArenaFlow header). Nothing changes in the game while `Arena.enabled` is false, but one fix moves the duel's fairness numbers: `heavyWindup.impactAt` is now exact (the telegraph was one tick late). Per FORGE-07's runs (headless), the quick gate's noAutoWin max goes from 67.0 % to 68.3 % and two full-sweep noAutoWin cells (greatsword over medium, novice/adoring and average) read "PASS (marginal)" against the 70 % bound; the full sweep still passes. FORGE-00 rules whether that is acceptable for the provisional bound or the greatsword numbers in `config/Duel.luau` need a look; the `fairness-full` job on the main push will show the two marginal cells.

## What changed
1. **`DuelRunner:act(userId, action, now)`** refuses a nil, NaN or infinite `now` with `(false, "bad_arguments")`. Before, a nil `now` on a champion's first act stored `at = nil` in the rate bucket and every later act by that champion errored.
2. **`heavyWindup.data.impactAt`** is now exactly the time the heavy lands (the windup that starts in a step also spends that step's dt; it was one tick late). `impactIn` in the relay follows.
3. **`DuelAI.new`** treats a seed that is not a finite number as seed 1 (a NaN seed made the generator NaN and the AI only spammed light attacks). The dodge check uses the armour's own `dodgeCost` from config Duel instead of a fixed 25.
4. **Doc drift:** the ArenaFlow header's Champion shape (`{ side, kingdom, userId, isAI, support, weapon, armour, triggers, chosen, gone }`) and its vote-close wording (the stage closes when every kingdom with more than one candidate has had all of them vote).
   The merged `2026-10-19-forge-01-to-all-arena-flow.md` still says the AI champions' ids are `-1` / `-2`; the code (since #223) uses `ArenaFlow.AI_USER_ID`: `a = -1000000001`, `b = -1000000002`. I did not edit that file because it is outside forge-01's paths once merged; please treat this line as the correction.

## Evidence (headless only)
- `sim/DuelRunner` 37, `sim/DuelModel` 30, `sim/DuelAI` 11 specs pass; Selene 0 warnings; StyLua clean.
- `FL-0071H.py` 9 rows, all CAUGHT.
