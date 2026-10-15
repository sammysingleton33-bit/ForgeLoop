---
id: FL-0112
title: Starting kingdom cleanup: generated trees and rocks keep out of crop fields and build zones (B15 #1)
track: build
owner: forge-01
status: REVIEW
priority: P0
game: game-001
created: 2026-10-15
updated: 2026-10-15
depends_on: [FL-0051]
evidence: []
---

# Starting kingdom cleanup: generated trees and rocks keep out of crop fields and build zones (B15 #1)

## Outcome
No generated tree, rock or gold vein stands inside a crop field or a plot build zone in any kingdom, for any seed, and every kingdom keeps its whole forest, quarry and gold vein.

## Context
- User feedback record: `production/handoffs/2026-10-13-forge-00-to-all-first-studio-feedback.md`; D-049 (B15/B16 cycle).
- Root cause (FORGE-01, PR #131): the clutter was the sim's generated resource nodes (53 of 114 trees inside the 12 crop fields; 4 rocks in build zones). `Kingdom/Layout.clearSpot` only avoided buildings and slots. WorldPlan decor props already kept out.
- Work exists: PR #131 (`forge/01-gameplay-cleanup`). This task records it; it is not new work.
- **Overlap:** this is a follow-up fix inside FL-0051's node placement (FORGE-01, BUILDING). It is tracked separately only because it's its own B15 PR (#131); FL-0051's remaining scope is unchanged.

## Requirements
- Nodes keep out of every crop field and plot build zone, with slot clearance.
- Spec LayoutZones over seeds 1..20, plus mutations.
- Fairness (#94) is kept: the plots stay rotated copies.

## Validation
Automated: LayoutZones spec, mutations 3/3, check.sh. Studio: B15 checklist (screenshot of every starting farm at the aerial zoom, 0 trees or rocks in the fields).

## Completion criteria
- [ ] #131 merged after review (FORGE-05 gate, FORGE-07 review).
- [ ] Studio evidence recorded (G6, the user).

## Log
- 2026-10-15 FORGE-00: created from the user's first live Studio feedback (record `production/handoffs/2026-10-13-forge-00-to-all-first-studio-feedback.md`; D-049).
