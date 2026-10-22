---
id: FL-0148
title: "Citizens alive at the start frame: work slots, readable swings, facing, carried goods"
track: build
owner: forge-04
status: BUILDING
priority: P0
game: game-001
created: 2026-10-22
updated: 2026-10-22
depends_on: []
evidence: []
---

# Citizens alive at the start frame: work slots, readable swings, facing, carried goods

## Outcome
At the default start view (FL-0147), the ruler sees their citizens as separate, readable workers. Each stands at their own spot at a workplace, faces the work, swings visibly, and carries goods home. Production is unchanged.

## Context
- **D-059**, the owner's B22 playtest: citizens are "barely recognisable" at the default camera.
- **FORGE-04's audit (22 Oct, 14:20 UTC, headless, real Match):**
  - 56 % of working samples had a neighbour within 1.5 studs. All workers on a target stopped at the same arrive point.
  - Swings of 20–60° at 0.6 Hz don't read at zoom 70.
  - The `carrying` state was not drawn.
- **Ownership:** a one-PR exception `forge04-citizens-alive` covers `Sim/Pose`, `Sim/CitizenActions`, `Sim/Replication` (facing lines), the `EntityController` carry attach and their specs. FORGE-01 agreed and reviews as owner. FORGE-05 removes the exception at merge.
- **Carried props:** `Kit.carried` is FORGE-02's #312.

## Requirements
- (a) Work slots: each worker on the same target gets its own slot about 2.5 studs apart. Slots are deterministic.
- (b) Swings that read at zoom 70, kept clear of heads and bodies by PoseClearance.
- (c) Carried goods from `Kit.carried`, welded while carrying and removed before pooling.
- (d) Face the target, and start each blow at phase 0.
- Production must not change: same seeds, real Match, quote resources per minute before and after.
- The 100-citizen budget spec stays green.

## Validation
- Automated: the sim, economy and fairness specs; `CitizenActions`, `Pose`, `PoseClearance`, `Replication` and `EntityController` specs; full `check.sh`; the FL-0148 mutation rows.
- Renders: before and after at the FL-0147 camera at 30 s, crimson and azure, plus crops, opened by FORGE-04.
- Studio (owner): citizens readable and separate at the start view. Unverified until then.

## Completion criteria
- [ ] Merged with FORGE-01 (owner) and FORGE-07 reviews.
- [ ] Neighbour-within-1.5-studs share near 0 %. Production within seed noise.
- [ ] Before and after sheet on the PR.

## Log
- 2026-10-22 FORGE-00: filed for FORGE-04's D-059 citizens-alive PR (branch forge/04-experience-citizen-motion).
- 2026-10-22 forge-00: SPECIFIED → READY. Filed for FORGE-04's D-059 PR
- 2026-10-22 forge-00: READY → BUILDING. FORGE-04 building on forge/04-experience-citizen-motion
