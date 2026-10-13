# FORGE-02 status

_Maintained by the worker. Keep it short and current._

| Field | Value |
|---|---|
| Session branch | `forge/02-blender` (Blender pipeline + kit, pushes verified); PR branches `forge/02-blender-*` cut from main |
| Open PRs | [#90](https://github.com/sammysingleton33-bit/ForgeLoop/pull/90) FL-0013 Blender pipeline on main (PR-A) · [#85](https://github.com/sammysingleton33-bit/ForgeLoop/pull/85) FL-0098 Kit.portrait · [#105](https://github.com/sammysingleton33-bit/ForgeLoop/pull/105) aerial-readable kingdom emblems (CVD finding 3) |
| Merged | #27, #28, #38, #43, #60, #73, #75, #81 (soldier crest) |
| Current tasks | FL-0013 (REVIEW, #90), FL-0098 (REVIEW, #85), CVD finding 3 (#105), FL-0085/54/55/56 (REVIEW), FL-0057 (BUILDING). Next: image-only preview PRs after #90; FL-0086 new building types |
| Last verified check | #105: roblox check.sh OVERALL PASS (game-001 1114/0) after merging main; 15 mutations caught; aerial renders + cvd.py looked at. #90: blender check.sh PASS. #85: check.sh OVERALL PASS (1049/0) |
| Blockers | none |
| Needs from others | FORGE-07/05: review #90, #85, #105. FORGE-01: FL-0104 (#91) passes `kingdom` to soldier rigs; rebuild captured buildings with Kit.build (caps). FORGE-00/user: D-026 calibration verdicts (sheets in #90). Studio: four-kingdom colour-vision screenshot |

## Blender kit state (D-019 review log in `blender/reviews/`)
- 223 assets: 146 PASS, 70 NEEDS-WORK, 7 UNREVIEWED (house_cottage after the emblem banner).
- Emblems unified (D-039): crown / star / oak leaf / sun from `_kingdom_props_common`; flame removed; no crescent finials.
- Parked (GENERATORS.md): farm_field, tree_birch, rock_cliff, resource_stone, resource_ore, prop_well; kingdom emblem polish (soldier archers, smithy_04 / barracks_04 sun, crown consistency) with the next strategy (one kit-wide emblem plaque).

## Next
1. Image-only preview PRs (~3 MB, referenced sheets) after #90; merge main back into `forge/02-blender`.
2. FL-0086 new building types (mine, blacksmith, market) in the Kit.
3. Kit-wide Blender emblem plaque (parked strategy); village vignette and import pack (FL-0057).

## Unverified
Nothing has been seen in Roblox Studio (headless gates and Blender renders only).
