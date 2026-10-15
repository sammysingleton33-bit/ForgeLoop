---
id: FL-0116
title: World dressing trim to the D-047 part ceiling (density knob, D-019 renders)
track: asset
owner: forge-02
status: REVIEW
priority: P1
game: game-001
created: 2026-10-15
updated: 2026-10-15
depends_on: [FL-0055]
evidence:
  - "check.sh OVERALL PASS at d008916 (game-001 1462/0, lune 528, selene 0, stylua 494); validate 124/0; ownership PASS; 5+12+14 mutants killed; before/after renders world_trim_*.jpg; fresh image-only D-019: rounds 2-3 NEEDS-WORK (banners, now untouched), round 4 not re-reviewed"
---

# World dressing trim to the D-047 part ceiling (density knob, D-019 renders)

## Outcome
The all-built-at-max world stays at or below 27k parts (about 26.5k), the valley does not read as sparse, and the density can be turned back up after a phone test.

## Context
- User feedback record: `production/handoffs/2026-10-13-forge-00-to-all-first-studio-feedback.md`; D-049 (B15/B16 cycle).
- D-047 (amended): measured 28,138 parts. FL-0086 lands its 27k ceiling spec after this.
- Farm clutter was resource nodes (FL-0112, #131), so FORGE-02's dressing clearance only guards WorldPlan dressing (a margin around fields, footprints, roads and slots). It does not move or filter nodes; those belong to FORGE-01.

## Requirements
- Forest and prop density as config knobs.
- Trim what the throne and aerial cameras see least first: map edges, under canopy, between kingdoms.
- Buildings, kingdom silhouettes and type budgets unchanged.

## Validation
Automated: the part-count spec ≤ 27k; the dressing clearance spec. Visual: D-019 before/after renders at the gameplay camera distance, judged by a fresh-context reviewer.

## Completion criteria
- [ ] PR merged after review.
- [ ] D-019 PASS recorded.

## Log
- 2026-10-15 FORGE-00: created from the user's first live Studio feedback (record `production/handoffs/2026-10-13-forge-00-to-all-first-studio-feedback.md`; D-049).
- 2026-10-15 forge-02: BUILDING → REVIEW. PR opened: density knob (features.density), plot clearance guard (decor off fields/roads/buildings/slots by drawn extent, moved not deleted, gate banners untouched), protected plot/farm showcase, radial thinning with forest discs sized to the kept trees; WorldService at ready 8,328 -> 6,569 parts; D-047 ceiling rebuilt in a scratch merge with FL-0086: 25,861 / 27,000 (headroom 1,139).
