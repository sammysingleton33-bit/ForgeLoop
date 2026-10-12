---
id: FL-0076
title: Crown Arena fairness harness, caps spec and arena integration
track: qa
owner: forge-05
status: READY
priority: P2
game: game-001
created: 2026-10-12
updated: 2026-10-12
depends_on: [FL-0070, FL-0071]
context: [games/game-001/design/crown-arena.md, games/game-001/CONTRACTS.md, games/game-001/BRIEF.md]
estimate_h: 12
evidence: []
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
