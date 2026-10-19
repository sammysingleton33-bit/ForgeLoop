# Handoff: FORGE-02 → FORGE-01 (cc FORGE-00, FORGE-05) · FL-0127 part 1: three neutral outposts in the world layout · 2026-10-18

## What I need / what I'm giving you
`world/Layout.luau` now places three neutral outposts besides the central watchtower, as `Layout.objectives` entries. They are
positions only: the sim still sees one objective until you add config rows (`config/Objectives.luau`, matched by id; the
sim copies `x, z, radius, regionId` from the world entry, `Kingdom/Layout.objectives()`), so FL-0125/FL-0126 are not
touched by this PR. FL-0126 consumes them.

## Done (with commits)
- Branch `forge/02-blender-fl0127-outposts`: `world/Layout.luau`, `Kit/WorldPlan.luau` (trim protection numbers only),
  `tests/world/Outposts.spec.luau`, WorldService/WorldDump specs.

| id | position (x, z) | radius | regionId | nav node | road |
|---|---|---|---|---|---|
| `outpost_n` | (40, −330), faces the valley centre | 20 | `outpost_n` (140 × 140, neutral) | linked to the azure road (230, −220) | spur from the azure road |
| `outpost_s` | (30, 315) | 20 | `outpost_s` | linked to the gold road (240, 230) | spur from the gold road |
| `outpost_w` | (−430, 10), west bank | 20 | `outpost_w` | linked to both west-bank roads (−190, −230) and (−190, 245) | two spurs |

The watchtower stays the first entry (`Layout.objectives[1]`, id `watchtower`, region `heartland`). `Layout.objectives[i].cframe`
faces the valley centre, so a neutral tower built there (Kit `watchtower`, `Kit.NEUTRAL_COLOR`) faces the right way.

## Evidence
- Headless Lune: `Outposts.spec` 7 tests (capture points with radius, a neutral region that contains the point, a nav node; objectives
  300+ studs apart; clear of forest stands, hills, the river, plots and the map edge; every kingdom's nearest neutral objective is
  330–365 studs away and a second one within 520; every objective reachable on the nav graph from every kingdom's gate; a spur
  ends at each outpost; decor stays out of radius + 14); 4 mutants killed (west outpost into a forest, a missing nav link, no spur
  flag, an outpost pushed out of range). `WorldService.spec` updated (zones by id, density-1.0 pins, per-objective protection radii).
- Trimmed world at ready (seed 1): 6,570 parts (was 6,569): the spurs' road pieces and the outposts' zones are paid for by tighter
  trim protection near them (`TRIM.outpostRadius` 70, `TRIM.spurBand` 20; protecting all three like the heartland, 170 studs, cost
  +631 parts and would have eaten the D-047 headroom).
- D-047: the ceiling spec on `forge/02-blender-fl0086-buildings` assumes 3 neutral towers (3 × 115 = 345); with the watchtower plus
  three outposts that is 4 towers: +115 parts (an estimate, not measured here); the last measured total was 25,861 / 27,000.
- Renders (Blender, not Studio): `games/game-001/art/reviews/img/fl0127_*` (top view and each outpost).

## Interfaces touched
Additive: three entries in `Layout.objectives` (G10.1 `objectives` list; ids `outpost_n`, `outpost_s`, `outpost_w`), three regions,
nav nodes and edges, four road features marked `spur = true`. No contract field changes.

## Open issues and risks
- Fairness is a band, not symmetry: four kingdoms, three outposts. West kingdoms get the west-bank outpost; east kingdoms the north/south ones.
- Studio unverified: where the outposts sit against the real terrain (hills are far; forests are 14+ studs clear).
- `Layout.OBJECTIVES` (sim) is unchanged until you add rows; `ObjectiveZone` parts exist for all four objectives already (WorldService).

## Next actions for the receiver
1. FORGE-01 (FL-0126): add `Objectives.luau` rows for the three ids (territoryRadius, crownPoints, captureSeconds, holdPointsPerMinute),
   build the neutral tower per objective in ObjectiveService, and let governors march on them.
2. FORGE-05: the world part count is the thing to watch when FL-0127 part 2 (four dressed kingdoms) lands.

## Files to read
- `games/game-001/world/Layout.luau` — OUTPOST_* block after the kingdom-to-hub chains, `objectives`, the `spur` roads
- `games/game-001/tests/world/Outposts.spec.luau` — the rules
