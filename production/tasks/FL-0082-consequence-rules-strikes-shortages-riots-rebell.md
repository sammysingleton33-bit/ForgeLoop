---
id: FL-0082
title: "Consequence rules: strikes, shortages, riots, rebellion gating, army morale effects"
track: build
owner: forge-01
status: REVIEW
priority: P1
game: game-001
created: 2026-10-12
updated: 2026-10-15
depends_on: [FL-0079, FL-0080]
context: [games/game-001/design/living-kingdom.md, games/game-001/CONTRACTS.md, games/game-001/BRIEF.md, games/game-001/content/SPEC.md]
estimate_h: 10
evidence:
  - check.sh OVERALL PASS (game-001 1257/0, framework 517/0) on main 55ba7074 + branch; Consequences.spec 10/0, ConsequenceService.spec 23/0, WorldView.spec 6/0; mutations 22/24 caught (1 equivalent, code removed; 1 caught after the no-conditions spec)
  - "bash roblox/scripts/check.sh on the #125 head after the D-050 follow-up: OVERALL PASS (Lune 528/0; game-001 specs 1453 passed, 0 failed, 91 files); roblox/tests/unit/gameplay/mutations/FL-0082.py 16/16 caught (one equivalent mutant dropped). Headless only: unverified in Studio (K12)."
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
- 2026-10-13 forge-00: SPECIFIED → READY. FORGE-00 reconciliation 2026-10-13 (stale-status sweep): dependencies are met (FL-0079/FL-0080/FL-0085 merged, only G6 left), so the task is READY.
- 2026-10-13 forge-01: READY → BUILDING. Consequence rules: sustained strikes (existing Society.strike), food shortage unrest, riot with an instigator (fire on a building, rioters stop work), rebellion gated off in the slice, army morale states for VS-2 combat. Server-authoritative ConsequenceService over a pure Sim/Consequences; thresholds PROVISIONAL in Society.luau.
- 2026-10-13 forge-01: BUILDING → REVIEW. ConsequenceService + pure Sim/Consequences: sustained strikes (grievance memories, strikers' mean loyalty ends it), food-shortage unrest (conditions every 10 s, unrest pressure), riot with an instigator (fire on the nearest non-keep building, floor 25 %, rioters off work, cooldown), rebellion gated off in config, morale states for VS-2 combat; Burning attribute in WorldView; Studio command consequence.unrest + preset vs1.riot. Thresholds PROVISIONAL in Society.luau. Not built: desertion risk after a betrayed captain and morale applied in battle (VS-2, MilitaryService). Handoff 2026-10-13-forge-01-to-forge-04-05-06-consequences (G9 notice event, fire VFX, memory tags).
- 2026-10-15 forge-01: REVIEW → REVIEW. Forced same-status note: D-050 (1) follow-up on #125: rioters are their own state (strike event marked riot, own client event), a burning building halts and heals back (0.2 %/s, interim for builder repair), consequence notice row written out in the handoff. Gate green; PR #125 updated.
