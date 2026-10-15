---
id: FL-0118
title: Citizen job silhouettes, clothing and tools readable from the air (D-048 11-part rigs)
track: asset
owner: forge-02
status: READY
priority: P1
game: game-001
created: 2026-10-15
updated: 2026-10-15
depends_on: [FL-0085]
evidence: []
---

# Citizen job silhouettes, clothing and tools readable from the air (D-048 11-part rigs)

## Outcome
From the aerial camera each job reads by silhouette: farmer, woodcutter, miner, builder, hauler, soldier and governor each get signature headwear, an outfit accent and a characterful tool. Citizens look more individual.

## Context
- User feedback record: `production/handoffs/2026-10-13-forge-00-to-all-first-studio-feedback.md`; D-049 (B15/B16 cycle).
- D-048 / CONTRACTS G10 v0.4-g9g: up to 11 parts (2 rigid detail parts, no Motor6D). No new look fields on the wire; the detail derives from occupation and kind the client already has.
- FORGE-02 branch `forge/02-blender-citizen-polish` (no commits yet).

## Requirements
- 9-part improvements first, then the 11-part variant in its own PR.
- The client may drop the detail parts beyond the rig LOD distance.
- The Kit spec enforces ≤ 11.
- Poses and `Sim/Pose.JOINTS` unchanged.

## Validation
Visual: D-019 aerial and close-up renders, fresh-context reviewer PASS. Automated: KitCharacter specs, part cap.

## Completion criteria
- [ ] PR(s) merged after review.
- [ ] D-019 PASS.
- [ ] Studio look (G6).

## Log
- 2026-10-15 FORGE-00: created from the user's first live Studio feedback (record `production/handoffs/2026-10-13-forge-00-to-all-first-studio-feedback.md`; D-049).
