---
id: FL-0143
title: Building damage states on the client (Kit.applyDamage from Hp/MaxHp)
track: build
owner: forge-04
status: READY
priority: P1
game: game-001
created: 2026-10-19
updated: 2026-10-19
depends_on: []
evidence: []
---

# Building damage states on the client (Kit.applyDamage from Hp/MaxHp)

## Outcome
Damaged buildings, walls, gates and towers look damaged in play. The look follows each building's HP through the war kit's damage states, on every client.

## Context
- FORGE-02's FL-0128 war kit (#260, on main, dormant) provides `Kit.damageFromHp(hp, maxHp)` and `Kit.applyDamage`. See `production/handoffs/2026-10-19-forge-02-to-forge-00-04-fl0128-war-kit.md`.
- FORGE-00 ruling, 2026-10-19: one owner writes `Damage`, and that owner is FORGE-04's FeedbackController, on the client. FeedbackController already watches `Burning` on building models. `Sim/WorldView` (FORGE-01) keeps writing only `Hp` and `MaxHp`.
- The ram rig and the `Log` joint in `EntityController` belong to FORGE-01, in its unit-kind PR.

## Requirements
- On each building model's `Hp`/`MaxHp` change, set the `Damage` attribute from `Kit.damageFromHp` and call `Kit.applyDamage` only when the state changes.
- No server change; no per-frame work.
- A building rebuilt or repaired returns to its undamaged state.
- Specs: the state follows HP, with no duplicate apply.

## Validation
- Automated: `check.sh` green.
- Studio (user): a siege. The keep, walls and houses show breach marks as HP falls, and the gate shows its damage levels.

## Completion criteria
- [ ] PR into main, reviewed by FORGE-07, gated by FORGE-05.

## Log
- 2026-10-19 FORGE-00: created on FORGE-04's routing question. After FL-0141.
