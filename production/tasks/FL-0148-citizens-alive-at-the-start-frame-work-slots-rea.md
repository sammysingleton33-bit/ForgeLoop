---
id: FL-0148
title: "Citizens alive at the start frame: work slots, readable swings, facing, carried goods"
track: build
owner: forge-04
status: REVIEW
priority: P0
game: game-001
created: 2026-10-22
updated: 2026-10-22
depends_on: []
evidence:
  - "rig 1.5 (FORGE-00 17:04), slots 5 studs: check.sh OVERALL PASS on ca7a4cc6 (main e8a82c51 merged in): game-001 3052/0, framework 588/0, selene 0, stylua 736 files, both builds and place checks PASS; sim specs 1158/0 at 5 studs (5.25 trips Simulation.spec's two-builders timing test: 4.6/5.0 pass, 4.8/5.25/5.5 fail); FL-0148 rows 66/66 CAUGHT on da2ff4f6 (0 stale over 1005 rows); production 32 seeds main e8a82c51 vs head: food +0.1 %, wood -0.8 %, all resources -0.3 %, every measure under 0.5 sd; workers within 1.5 studs 56 % -> 0.1 %, median nearest neighbour 0.97 -> 4.98 studs; KitCharacter 59/59 on main, main + #317 (92f0b664) and #317's tool pass; sheets games/game-001/design/pacing/citizens/fl0148-start-citizens.jpg and fl0148-phone-scale.jpg opened (headless Blender, not Studio)"
  - "check.sh OVERALL PASS on a156247f (main 06230ecd merged in): game-001 2957/0, framework 588/0, selene 0, stylua 729 files, both builds and place checks PASS; FL-0148 rows 42/42 CAUGHT; production 32 seeds main vs head: all resources +0.0 % (sd 1.1 %), food +0.6 %, wood -0.8 %, stone -1.0 %, gold +0.6 %; workers within 1.5 studs 56 % -> 0.1 %; sheet games/game-001/design/pacing/citizens/fl0148-start-citizens.jpg (headless Blender, not Studio)"
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
- 2026-10-22 forge-04: BUILDING → REVIEW. PR open: work slots (3.5 studs, production unchanged on 32 seeds), facing, blows that read at zoom 70 (hoe to 105 deg), carried goods, blow start at phase 0; before/after sheet opened and judged
- 2026-10-22 forge-04: REVIEW (new head). Rig drawn 1.5x (FORGE-00 17:04), slots 5 studs apart (5.25 trips FORGE-01's two-builders timing test), the pick and hammer tip forward (clear of #317), FORGE-01's L1-L3 and FORGE-07's L1-L4 fixed; sheets re-rendered at 1.5 and opened
