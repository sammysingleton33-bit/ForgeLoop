---
id: FL-0076
title: Crown Arena fairness harness, caps spec and arena integration
track: qa
owner: forge-05
status: BUILDING
priority: P2
game: game-001
created: 2026-10-12
updated: 2026-10-19
depends_on: [FL-0070, FL-0071]
context: [games/game-001/design/crown-arena.md, games/game-001/CONTRACTS.md, games/game-001/BRIEF.md]
estimate_h: 12
evidence:
  - "Scaffold in games/game-001/tests/fairness/ (CapsContract, CapsCheck, DesignSupport, DuelDouble, Duellist, Harness, run.luau): Caps.spec 5 + Fairness.spec 10 pass; mutations caught: cap raised in CapsContract, quiet start removed, stacking triggers, Fine Wares without a slot, heal above max HP"
  - "Mirror match (hostile vs hostile, equal skill, 2000 duels): novice 51.2 % [49.0, 53.4], average 51.2 % [49.0, 53.4], expert 50.4 % [48.2, 52.6]; ~1,200 duels/s (quick run 28 cells x 100 duels in 2.4 s)"
  - "Merged PR #18 as 6f3ce4b; CI on main run 38306276658 gates PASS"
---

# Crown Arena fairness harness, caps spec and arena integration

## Outcome
Nobody has to trust that support is fair: CI proves the caps hold and that support shifts duels only within the agreed bounds, and the arena runs in the integrated game-001 build with a Studio test script (design §6, §9).

## Context
D-029; design §6, §9; CONTRACTS G12.3. Build the harness scaffold now in slack time against a local DuelModel double in `games/game-001/tests/fairness/`; switch to the real `DuelModel` and `SupportModel` when FL-0070 and FL-0071 land.

## Requirements
- Caps spec: every value in `Caps.luau` and `Support.luau` is within G12.3; it fails on any increase not backed by a DECISIONS entry.
- Fairness harness: scripted duellists at three skill tiers × every support tier × trigger sets × loadouts; ≥ 2,000 seeded duels per cell for the merge gate; win rates with 95 % confidence intervals; fails when an outcome bound is broken. Report written to the CI artifact.
- Arena integration in `games/game-001` build and place check; G12.5 events appended to GameEvents when VS-2 starts (as D-024).
- Studio arena script in `STUDIO_PLAYTEST.md` with `DebugCommands` presets (Adoring vs Hostile, force each trigger, AI champion).

## Validation
`bash roblox/scripts/check.sh` with fairness and caps steps; a deliberately over-cap config makes the gate fail (negative test). Studio run per the new script.

## Completion criteria
- [ ] Fairness report attached to the PR with the numbers for every outcome bound

## Log
- 2026-10-12 forge-00: created for the Crown Arena (D-029, VS-2) (READY).
- 2026-10-12 forge-05: READY → BUILDING. Scaffold against a local DuelModel double and the design numbers (DuelDouble, DesignSupport); caps spec checks CapsContract against CONTRACTS G12.3 row by row and FORGE-01's Arena/Caps.luau once it exists. Merge-gate step in check.sh and the report artifact wait for FL-0070/FL-0071 (the double's own numbers are not the game's). Handoff to FORGE-01: arena-harness-needs.
- 2026-10-19 forge-05: first run on the real DuelModel (main ebdd564, #208) with the design §3/§4 support fixture (config Support, #209, not on main yet), 2000 duels per cell: supportMatters novice 65.8 % [63.6, 67.8], average 67.7 % [65.6, 69.7], expert 67.0 % [64.9, 69.0] vs 55-65 % (average FAIL, the others marginal FAIL); skillStillWins 78.8 % and 72.1 % PASS (>= 60 %); worst noAutoWin 69.8 % [67.7, 71.7] marginal PASS (<= 70 %); mirror 49.2-50.6 %. Sent to FORGE-01 and FORGE-00. Next: run on config Support (#209), add the check.sh fairness step. Headless, scripted duellists.
- 2026-10-19 forge-05: FORGE-01's three support trims on the real DuelModel (DesignSupport fixture + trim; supportMatters and skillStillWins 2000 duels, every noAutoWin cell 1000): all pass G12.3. A (fieldRemedy 0.03/0.05): supportMatters 62.0/63.4/62.9 %, worst noAutoWin 68.2 %; B (A + reforge 0.05/0.08): 61.6/62.9/62.4 %, 68.0 %; C (A + Adoring passive 0.01): 60.1/60.7/61.3 %, 64.5 %, skillStillWins 81.8/77.2 %. Recommended C, the only one inside FORGE-00's targets (supportMatters about 60-63 %, noAutoWin worst <= 68 %). Headless, scripted duellists.
- 2026-10-19 forge-05: fairness gate merged (#219, d03f61c): FairnessGate.spec on the real DuelModel + config Support runs in every check.sh (94 bounds: supportMatters/skillStillWins at 2000, every noAutoWin perk set plus the worst loadout cells at 400, a borderline cell re-run at 2000; repeated pick refused or counted once); CI job fairness-full runs the 2000-duel sweep of every cell and loadout on main pushes touching the arena. Results on trim C: supportMatters 60.1/60.7/61.3 %, skillStillWins min 77.2 %, noAutoWin max 67.0 % (novice Adoring greatsword/medium). Proven to fail on the pre-trim config, a repeated pick (before #218) and a 20 % greatsword buff (FORGE-07). Remaining: the Studio arena script once DuelService and the venue land. Headless, scripted duellists.
