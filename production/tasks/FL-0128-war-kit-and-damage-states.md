---
id: FL-0128
title: "War kit: wall, gate and tower levels, siege ram, kingdom soldier variants and weapons, damaged and burning building states"
track: asset
owner: forge-02
status: READY
priority: P1
game: game-001
created: 2026-10-18
updated: 2026-10-18
depends_on: [FL-0127]
evidence: []
---

# War kit: wall, gate and tower levels, siege ram, kingdom soldier variants and weapons, damaged and burning building states

## Outcome
Warfare looks like warfare from the air: walls, gates and towers with a clear silhouette, a siege ram model, soldiers that read as a kingdom's army (kingdom-coloured tabard and shield, spear/sword/bow by unit kind), and buildings that visibly show damage before they fall.

## Context
- BRIEF §4 VS-2 rows 3-5; Military units in `config/Military.luau` (FORGE-01). D-048 rig cap (≤ 11 parts). Kit is primitives only (D-021).

## Requirements
- Kit pieces for wall segment, gate (open/closed state), tower (levels 1-2), siege ram, all kingdom-tinted via the FL-0127 style table.
- Soldier looks per unit kind in `Kit.character` within 11 parts; the kingdom crest stays (D-033).
- Damage states: a `Damage` attribute (0-1) on building models drives cracked/missing parts and smoke at thresholds; the riot `Burning` look (FORGE-04's VFX) stays compatible. Write the additive attribute contract in your handoff.
- D-019 renders at aerial and close range.

## Validation
Automated Kit specs and part counts. Visual D-019. Studio rows with FORGE-05.

## Completion criteria
- [ ] PR merged after review (FORGE-05 gate, FORGE-07 review).
- [ ] Studio evidence (owner's local Studio session).

## Log
- 2026-10-18 FORGE-00: created for Operation Crownfall (owner directive 2026-10-18, D-053).
