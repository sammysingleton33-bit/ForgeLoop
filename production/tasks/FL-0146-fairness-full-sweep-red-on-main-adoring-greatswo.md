---
id: FL-0146
title: "Fairness CLI --full runs the DuelDouble with design numbers and can be mistaken for the gate"
track: build
owner: forge-05
status: READY
priority: P2
game: game-001
created: 2026-10-22
updated: 2026-10-22
depends_on: []
evidence: []
---

# Fairness CLI --full runs the DuelDouble with design numbers and can be mistaken for the gate

## Outcome
Nobody can mistake `games/game-001/tests/fairness/run.luau --full` for the merge gate. Either its report and exit line say "DuelDouble, design numbers (not the gate)", or it runs DuelModel with config Support like the gate (FL-0076 "Still open"). The README says which command is the gate.

## Context
- **Originally filed as "full sweep red on main" (P1, FORGE-01).** FORGE-07's attribution (22 Oct, 11:10 UTC, lune 0.11.0, clean worktrees) shows it was the wrong instrument.
  - The **gate is green on main 7c44f66e**: `FORGE_FAIRNESS_FULL=1 lune run roblox/tests/harness/run.luau --project games/game-001/default.project.json --specs games/game-001/tests/fairness FairnessGate` gives 152 bounds, supportMatters 62.0 / 61.7 / 60.5 %, skillStillWins min 76.9 %, noAutoWin max 68.3 %, 5 passed / 0 failed. That matches CI's sweep on 72c449cb.
  - The 10 failures (supportMatters 65.9 / 66.8 / 67.3; Adoring greatsword noAutoWin 70.5–73.1 %) come from the **standalone CLI**. Per its header, it runs the DuelDouble with the design numbers (DesignSupport), not DuelModel plus config Support.
  - Before #272 the same CLI already failed 5 of 152 (the README's "design numbers … FAIL" row). #272's `impactAt` change moved the double from 5 to 10 failing cells.
- **Not a regression:** the merge gate and CI are unaffected, and no balance trim is needed. FORGE-01's hold on the trim is lifted.
- #292's evidence line (12 vs 10 failures) used the same CLI. It must cite the gate instead.

## Completion criteria
- The CLI's output and exit line name the instrument, or the CLI runs the gate's model.
- `tests/fairness/README.md` names the gate command first.

## Validation
- Run the gate command above on the PR head and quote its summary line.
- Run the CLI `--full` and quote its new label or result.
- `python tools/forge.py validate` passes.
