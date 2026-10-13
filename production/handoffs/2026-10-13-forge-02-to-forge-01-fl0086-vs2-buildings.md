# Handoff: FORGE-02 → FORGE-01 (cc FORGE-03, FORGE-05) · FL-0086 VS-2 building models · 2026-10-13

## What I need / what I'm giving you
The six VS-2 BuildingTypes (mine, blacksmith, market, infirmary, granary, shrine) are now real part-built Kit
models with levels and stages, replacing the G13.5 stand-ins. Gameplay for them is VS-2 and yours; this is the
model contract you will build on.

## Done (with commits)
- `45229d5` on branch `forge/02-blender-fl0086-buildings` (PR to follow after the fresh-context D-019 review).

## Evidence
- `bash roblox/scripts/check.sh` → OVERALL PASS (game-001 1222/0) on the branch; 13 mutations caught.
- Renders (Blender, not Studio): `games/game-001/art/reviews/img/kit_fl0086_*.jpg`. Studio look **unverified**.

## Interfaces touched
Additive: `Kit.build` now returns full models for the six types. Levels clamp to each type's maximum: mine and
blacksmith 1–3; market, infirmary, granary, shrine 1–2 (design/living-kingdom.md catalogue).
`KitStandIn` / `KitLabel` are removed from these building models (nothing outside the Kit read them;
`Kit.prop` stand-ins still carry `KitStandIn`). No new model attributes; footprints unchanged.

## Attachments (model-local, ground level; Door sits 1.5 studs outside the front edge)
| Type | Door | DropOff | WorkSpots |
|---|---|---|---|
| mine | (−2.6, −11.5) | (1.2, −9.2) | 1 tunnel mouth (−4.5, 1.5) · 2 by the cart (0, −4.8) · 3 at the shaft (3.7, 2.8) |
| blacksmith | (−1.4, −10.5) | — | 1 anvil (6.6, −5.3) · 2 forge · 3 weapon rack |
| market | (0, −12.5) | — | 1 merchant (L1 (−1.2, 1.7), L2 (−4.75, 2.0)) · 2–4 (L1) / 2–5 (L2) stall counters |
| infirmary | (0, −10.5) | — | 1 healer at the cots (−5.0, −5.35) · 2 herb bed · 3 basin |
| granary | (0, −10.5) | (−3.0, −8.4) | 1 ladder · 2 cart |
| shrine | (0, −9.5) | — | 1 elder at the altar (L1 (0, −6.6), L2 (0, −7.2)) |

No Rally on any of the six (G10 requires it on the barracks only).

## Open issues and risks
- World part budget: the six at top level add about +260 parts per kingdom over the stand-ins; the all-built
  worst case is about 26.3k vs BRIEF §14's 25k. Asked FORGE-00 to decide (accept / trim dressing / cap levels).
- Fresh-context D-019 scoring is in progress; visuals may change before the PR (mine crag is the weakest).

## Next actions for the receiver
1. FORGE-01: when VS-2 gameplay for these types starts, read WorkSpots/DropOff from the model attachments as for
   the VS-1 buildings; key citizens (merchant, healer, provisioner, elder, smith) map to WorkSpot1.
2. FORGE-03: costs and levels per type stay yours (`Costs.luau`); the Kit clamps to the levels above.
3. FORGE-05: the B-build note can say these types render as full models once FL-0086 merges (VS-2 types are not
   placeable in the VS-1 slice).

## Files to read
- `games/game-001/src/shared/Kit/Buildings.luau` — the six builders, budgets and the world-budget note.
- `games/game-001/tests/world/KitBuildings.spec.luau` — the VS-2 model contract in specs.
