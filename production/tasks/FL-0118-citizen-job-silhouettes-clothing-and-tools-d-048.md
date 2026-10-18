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
- 2026-10-15 forge-02: phase 1b on forge/02-blender-citizen-phase1b (9 parts): woodcutter beanie, smaller darker miner pot, per-individual dyes, idle accessories, governor crown and staff, low soldier crest, red sleeves from above, lower hauler sack; specs and 17 killed mutants; renders `citizen_polish1b_*.jpg`. Status stays REVIEW (D-051); Phase 2 (tools, D-048) is the next stacked branch.
- 2026-10-15 forge-02: phase 1b after 2 author rounds and 2 fresh image-only re-scores: rig set NEEDS-WORK (soldier and governor PASS; variation 2-3, tool readability, hauler front read still below threshold). Stopped per the 2-round rule; tools, hauler strap, builder hard hat and miner lamp go to Phase 2 (D-048, own stacked branch). Status stays REVIEW (D-051).
- 2026-10-15 forge-02: phase 2 on forge/02-blender-citizen-phase2 (stacked on phase 1b): D-048 11-part rigs, each tool a handle plus a head detail, two KitDetail parts per working rig, hauler strap and tie, builder hard hat, miner lamp, spearhead, kingdom-red crown, pompom, pennant, strap and velvet cap; specs and 18 killed mutants; renders `citizen_polish2_*.jpg`. Status stays REVIEW (D-051).
- 2026-10-15 forge-02: phase 2 fresh image-only D-019 re-score (one round): rig set NEEDS-WORK. Soldier and governor PASS; farmer, woodcutter, builder miss only variation (3); miner and hauler 3 on silhouette, variation and readability; idle detail 2. Kingdom red visible from above (461 px, main 420). Remaining items need another art approach (variation beyond hat tone, miner head, front-readable hauler load, idle feature), not more 11-part tool work; left for FORGE-00 under D-051. Table in `art/reviews/kit-characters.md`. Status stays REVIEW.
- 2026-10-15 forge-02: phase 2 clearance fix (FORGE-05/FORGE-01 findings, Pose not relaxed; main 1d336eb merged): pick handle 4.55 with the bar 0.85 higher, mallet lean 15, hoe lean 14. New KitCharacter clearance spec: every Tool-welded part against the Head and every Head-welded part, all 7 Pose actions at speeds 0/6/12, 3 hat rolls, exact shapes at least 0.1 (bounding boxes at least 0.03); 10 mutants killed; PoseClearance passes 8/8. Minima: miner pick against the pot 0.277 exact, builder mallet against the cap 0.150. Renders `citizen_polish2_{jobs,tools,heads,poses}.jpg`. Studio unverified. Status stays REVIEW.

- 2026-10-15 forge-02: B18 shoulder pivots (FORGE-00 via FORGE-01's pose analysis #166), branch forge/02-blender-shoulders: the arm Motor6D pivots sit outside the torso (0.41 citizens/governor = the arm's own centre line, 0.55 soldier); the arm parts hang exactly where they did at rest, Pose.JOINTS/names/wire/part counts unchanged. Arm-vs-head clearance (head surface vs arm boxes, 7 actions, speeds 0/6/12): celebrate -0.10..-0.32 -> +0.45..+0.69 on all 8 rigs, every other action unchanged (>= 0.24). KitCharacter spec +2 tests, 4 mutants killed; check.sh PASS (game-001 1599/0). Renders citizen_shoulders_{rest40,rest170,celebrate,crowd}.jpg: rest pose pixel-identical, the cheer arm rises beside the head. Studio unverified.
