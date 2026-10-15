---
id: FL-0117
title: "Environment polish: organic trees, rocks, resource nodes and crop rows within the part budget (B15 art where ready)"
track: asset
owner: forge-02
status: REVIEW
priority: P1
game: game-001
created: 2026-10-15
updated: 2026-10-15
depends_on: [FL-0116]
evidence:
  - "bash roblox/scripts/check.sh: OVERALL PASS (game-001 1335 passed)"
  - games/game-001/tests/world/KitProps.spec.luau
  - games/game-001/art/reviews/kit-architecture.md (Environment props polish)
  - check.sh OVERALL PASS (game-001 1354/0) after merging main; KitProps.spec 26 tests, 28 mutations caught; renders env_polish_*.jpg looked at; fresh D-019 review appended to kit-architecture.md (NEEDS-WORK)
  - check.sh PASS on the art merge (game-001 1378/0); world 142/0, sim 583/0 on 9d02bc2
---

# Environment polish: organic trees, rocks, resource nodes and crop rows within the part budget (B15 art where ready)

## Outcome
Trees read as natural oak, pine and birch with layered canopies, tapered trunks and branches. Rocks, ore and log nodes have angular, varied shapes, and the crop rows read as crops, not spikes, from both the aerial and throne cameras.

## Context
- User feedback record: `production/handoffs/2026-10-13-forge-00-to-all-first-studio-feedback.md`; D-049 (B15/B16 cycle).
- The user: "Trees look extremely blocky…", "Rocks and environmental assets feel too primitive".
- FORGE-02 branch `forge/02-blender-env-polish` (started 2026-10-13, no commits yet).
- Mesh trees need the user to import in Studio. That is an optional pilot the user decides on; this task is part-built and doesn't depend on it.
- **Overlap:** FL-0057 (FORGE-02, the Blender mesh import pack for trees and rocks, READY; BUILDING on #90) covers the *mesh* route. This task is the part-built polish that ships without the user's mesh import. When meshes land by id, FL-0057 swaps them in. Don't do the same asset twice.

## Requirements
- Per-prop part counts at or below today's (D-047).
- Ball/Cylinder/Wedge composition, rotated clumps, colour and material variation, ≥ 3 tree species with variants.
- Rocks: clusters, stratified stone, gold-flecked ore.
- The farm crop fix carries FL-0085 attempt 3's findings (tufts read as spikes or flames).

## Validation
Visual: D-019 contact sheets plus in-world renders at the aerial and throne distances, fresh-context reviewer PASS. Automated: Kit specs; the world part spec stays ≤ 27k.

## Completion criteria
- [ ] PR merged after review.
- [ ] D-019 PASS.
- [ ] Studio look (G6).

## Log
- 2026-10-15 FORGE-00: created from the user's first live Studio feedback (record `production/handoffs/2026-10-13-forge-00-to-all-first-studio-feedback.md`; D-049).
- 2026-10-15 forge-02: READY → BUILDING. Started: Props.luau art pass (trees, bushes/flowers, boulders, nodes, crop field/fence/haystack) in worktree env-polish.
- 2026-10-15 forge-02: BUILDING → TESTING. Props polished, uncommitted on forge/02-blender-env-polish. Headless: check.sh OVERALL PASS, KitProps.spec 26 tests, 28/28 mutations caught. Renders in games/game-001/art/reviews/img/env_polish_*.jpg (round logged in kit-architecture.md). Not yet: fresh-reviewer D-019, Studio look (G6), PR.
- 2026-10-15 forge-02: TESTING → REVIEW. Fresh-context D-019 round 1: visible improvement but NOT a pass (trees 4/3/4, rocks/nodes, wheat 2, cabbage OK). Opened as a B15 star PR for the visible improvement; round 2 (oak variety, boulders, ore forms, flowers, wheat stalks) follows.
- 2026-10-15 forge-02: status stays REVIEW, task open until D-019 PASS (D-051: interim art may merge first). Remaining NEEDS-WORK from the fresh-context review, scores sil/var/read/prop/pal/detail/cohes/cost (PASS needs sil, var, read >= 4 and the rest >= 3): **no family passes yet.** Trees 4/3/4/3/4/3/3/4 (var 3: oak variants look cloned, birch crown = balloons on a pole, pine lower boughs read as loose plates, oak base collar). Boulders 2/3/3/3/4/2/3/4 (still parallel-faced boxes, moss ball on the L rocks). Resource nodes 3/3/3/3/4/4/4/4 (the three ores separate by hue only; gold nuggets are cubes). Wheat 2/2/2/3/4/2/3/4 (six identical flat slabs read as planks at both cameras). Cabbage 3/3/4/3/4/3/4/3 (regular dot grid, 65 parts). Bushes and flowers 3/3/3/3/4/3/4/4 (one three-ball recipe; flowers 2 at distance). Round 2 on forge/02-blender-env-polish-r2, after #141 merges: wheat first (<= 17 parts), then boulders (angled wedges/slabs, flat moss), then oak/birch silhouette variety. Visible-defect scan of #141 (every prop id: floating, buried, ground clipping): 72 ids, 1 finding (quarry pick hung 0.13 above the ground, not touching any part), fixed minimally; KitProps.spec now guards it. Neighbouring-prop overlap is placement's (crown radii as before: oak <= 12.2 vs 13-stud scatter, same as main).
- 2026-10-15 forge-05: REVIEW → REVIEW. Merged #141 (d9bb32a) as interim art (D-051): renders opened, no asset worse than main, pines/boulders/nodes/cabbage bed clearly better; stays open until D-019 PASS (oak/birch, wheat NEEDS-WORK)
- 2026-10-15 forge-02: round 2 on forge/02-blender-env-polish-r2 (stacked on #141, no PR yet). Two boulder passes (tipped wedges, then broad chunky blocks plus a wedge) rendered against main and #141 and judged **not clearly better than #141's boulders: reverted to #141's code**. Kept: oaks by archetype (dome, tall, wide, lopsided, twin), birch crown wound into the trunk with a side stub, pine four-bough skirt; all part counts unchanged. Wheat: D-047 amendment allows up to 44 parts (6x7 tufts) when FL-0116 measures >= 600 parts under 27k; implemented in its own commit. Details and renders in art/reviews/kit-architecture.md (round 2).
- 2026-10-15 forge-02: fresh-context image-only D-019 re-score of round 2 (separate session, images only; recorded in kit-architecture.md): trees 4/4/4/3/4/4/4/3 PASS (borderline; weakest species birch), boulders (#141's, reverted after two primitive passes were not clearly better) 2/3/3/3/4/3/3/4 NEEDS-WORK, wheat at 44 parts (6x7 tilted wedge tufts, D-047 amendment) 2/3/3/3/3/3/3/3 NEEDS-WORK (no longer planks; reads as tiles or bales, not stalks). Round-2 branch head: check.sh OVERALL PASS (game-001 1413/0). Still open: boulders (needs mesh or new primitive vocabulary), wheat stalks (needs more parts than 44 or a mesh row), birch trunk and crown, oak variants 1 and 6, flowers/bushes/ore forms from round 1.
