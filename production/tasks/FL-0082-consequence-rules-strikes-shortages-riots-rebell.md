---
id: FL-0082
title: "Consequence rules: strikes, shortages, riots, rebellion gating, army morale effects"
track: build
owner: forge-01
status: SPECIFIED
priority: P1
game: game-001
created: 2026-10-12
updated: 2026-10-12
depends_on: [FL-0079, FL-0080]
context: [games/game-001/design/living-kingdom.md, games/game-001/CONTRACTS.md, games/game-001/BRIEF.md, games/game-001/content/SPEC.md]
estimate_h: 10
evidence: []
---

# "Consequence rules: strikes, shortages, riots, rebellion gating, army morale effects"

## Outcome
Leadership has real, causal consequences. Exploited workers strike, hunger causes unrest, long instability causes riots and fires, and rebellion needs sustained conditions plus an instigator. Low army morale makes troops retreat, surrender or defect (design §5).

## Requirements
- Data-driven rules in config `Society.luau`: condition, minimum duration, instigator, effect and cue. No single decision can trigger a kingdom-wide rebellion.
- Strike (VS-1 if cheap, else VS-2), shortage unrest, riot and fire, rebellion (VS-2/3), desertion risk after betraying a trusted captain (shown as a risk), morale thresholds in battle.
- Every consequence is visible: a cue for FORGE-04 and a notice.

## Validation
Lune specs per rule: the trigger needs the sustained condition, it clears when fixed, and a single decision is never enough. The FL-0094 harness confirms no runaway.

## Completion criteria
- [ ] `bash roblox/scripts/check.sh` OVERALL PASS with the new specs

## Log
- 2026-10-12 forge-00: created for the production priorities update (D-030) (SPECIFIED).
