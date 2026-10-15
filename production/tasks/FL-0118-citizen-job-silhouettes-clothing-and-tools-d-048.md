---
id: FL-0118
title: Citizen job silhouettes, clothing and tools readable from the air (D-048 11-part rigs)
track: asset
owner: forge-02
status: REVIEW
priority: P1
game: game-001
created: 2026-10-15
updated: 2026-10-15
depends_on: [FL-0085]
evidence:
  - check.sh OVERALL PASS (game-001 1319/0) at fd498fb; KitCharacter.spec 35 tests, 26 Character.luau mutants killed; renders citizen_polish_*.jpg looked at (40 studs and aerial 170 studs, colour and grayscale)
---

# Citizen job silhouettes, clothing and tools readable from the air (D-048 11-part rigs)

## Outcome
From the aerial camera each job reads by silhouette: farmer, woodcutter, miner, builder, hauler, soldier and governor each get signature headwear, an outfit accent and a characterful tool. Citizens look more individual.

## Context
- User feedback record: `production/handoffs/2026-10-13-forge-00-to-all-first-studio-feedback.md`; D-049 (B15/B16 cycle).
- D-048 / CONTRACTS G10 v0.4-g9g: up to 11 parts (2 rigid detail parts, no Motor6D). No new look fields on the wire; the detail derives from occupation and kind the client already has.
- FORGE-02 branch `forge/02-blender-citizen-polish` (no commits yet).
- **Overlap:** FL-0056 (base rigs and job tools, merged; its task status is stale) is the base. This task is the readability pass on top of it, not a re-do.

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
- 2026-10-15 forge-02: READY → BUILDING. Phase 1 (9-part) built on forge/02-blender-citizen-polish; phase 2 (11 parts, D-048) follows in its own PR.
- 2026-10-15 forge-02: BUILDING → REVIEW. Phase 1 PR: per-job headwear, accent and tools within 9 parts; D-019 fresh review and the 11-part phase 2 still to do. Only G6 (Studio) for the visible result.
- 2026-10-15 forge-02: #138 clip fix after FORGE-05's findings (builder head through cap, hauler sack over head; also governor crown top, woodcutter/miner hat seat): hats sit on the head, sack clear of head and arms in every pose, 4 new clearance specs with 10 killed mutants, 9 parts. Renders `citizen_polish_clipfix_*.jpg` looked at; Studio unverified. Task stays REVIEW. Remaining NEEDS-WORK listed in `art/reviews/kit-characters.md` (tools are placeholders -> phase 2; cap/hat reads, variation, idle, governor, soldier helm, kingdom red from above). Celebrate pose sweeps hand tools through the head: `Sim/Pose.celebrate` is FORGE-04's.

