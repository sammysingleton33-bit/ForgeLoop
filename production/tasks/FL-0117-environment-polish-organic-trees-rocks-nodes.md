---
id: FL-0117
title: Environment polish: organic trees, rocks, resource nodes and crop rows within the part budget (B15 art where ready)
track: asset
owner: forge-02
status: READY
priority: P1
game: game-001
created: 2026-10-15
updated: 2026-10-15
depends_on: [FL-0116]
evidence: []
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
