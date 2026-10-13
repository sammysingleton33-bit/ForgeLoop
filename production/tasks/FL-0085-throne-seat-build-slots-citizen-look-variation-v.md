---
id: FL-0085
title: Throne seat, build slots, citizen look variation, visible building levels (G13)
track: asset
owner: forge-02
status: REVIEW
priority: P0
game: game-001
created: 2026-10-12
updated: 2026-10-13
depends_on: []
context: [games/game-001/design/living-kingdom.md, games/game-001/CONTRACTS.md, games/game-001/BRIEF.md, games/game-001/content/SPEC.md]
estimate_h: 6
evidence:
  - "PR #38 merged dc0b09f: BuildSlots.spec 8/8"
  - "PR #43 merged 986c773: check.sh OVERALL PASS, game-001 442/0"
  - "PR #60 merged 25b11cb: check.sh OVERALL PASS, game-001 799/0; FORGE-05 review 831/0 on the merge result"
---

# Throne seat, build slots, citizen look variation, visible building levels (G13)

## Outcome
The keep has a visible throne where the ruler sits. Each kingdom has clear build plots. Citizens look like individuals. Building levels are visibly different (VS-1 rows 2, 4 and 6).

## Requirements
- `Kit.build("keep", …)` contains a `Seat` named `Throne` on a raised dais, visible from the aerial camera.
- `Layout.plots[k].buildSlots` (≥ 8 per kingdom, sizes S/M/L). WorldService tags each slot marker `BuildSlot` with a `SlotId` attribute.
- `Kit.character(kind, job, color, look?)` takes the optional `CitizenLook` (skin, hair, hair colour, outfit), stays ≤ 8 parts, and exports the palette ranges.
- Visible level differences:
  - barracks levels 1–4;
  - keep levels 1–3;
  - house and farm levels 1–2.
- Kingdom pennants on thatch variants (calibration follow-up).

## Validation
Kit and Layout specs:
- the throne seat exists;
- slot count, sizes and no overlap with nav or roads;
- look ranges;
- part budgets.

A preview sheet per level is reviewed under D-019.

## Completion criteria
- [ ] Visual review per D-019 (preview images committed small)

## Log
- 2026-10-12 forge-00: created for the production priorities update (D-030) (READY).
- 2026-10-13 forge-02: READY → BUILDING. Started 2026-10-12: slots in #37/#38, throne/levels/looks in the Kit.
- 2026-10-13 forge-02: BUILDING → REVIEW. Part 1 build slots merged (#38, dc0b09f) + world hardening (#43, 986c773); part 2 throne seat, visible levels (barracks L1-4, keep L1-3, house/farm L1-2), citizen looks on the D-032 rig merged (#60, 25b11cb). FORGE-05 integration review verified 12,110 rigs and every keep level/colour; follow-ups L1/L2/L5/L6 in the next FORGE-02 PR, M1 (look -> EntityController pool key) with FORGE-01.
