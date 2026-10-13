# FORGE-02 status

_Maintained by the worker. Keep it short and current._

| Field | Value |
|---|---|
| Session branch | `forge/02-blender` (Blender pipeline + kit, pushes verified); PR branches `forge/02-blender-*` cut from main |
| Open PRs | [#90](https://github.com/sammysingleton33-bit/ForgeLoop/pull/90) FL-0013 Blender pipeline on main (PR-A: pipeline, 38 generators, manifest, reviews, calibration previews; task statuses) · [#81](https://github.com/sammysingleton33-bit/ForgeLoop/pull/81) G13.2 soldier crest (CVD runs 2-3 pass) · [#85](https://github.com/sammysingleton33-bit/ForgeLoop/pull/85) FL-0098 Kit.portrait (stacked on #81) |
| Merged | #27, #28, #38, #43, #60, #73 (D-033 colours), #75 (FL-0085 follow-ups + #73 spec follow-ups) |
| Current tasks | Aerial-readable kingdom emblems in the Luau Kit (FORGE-05 CVD finding 3, VS-1 polish) on `forge/02-blender-aerial-emblems`. FL-0013 (REVIEW, #90), FL-0098 (REVIEW, #85), FL-0085/54/55/56 (REVIEW), FL-0057 (BUILDING). Next: image-only preview PRs (~3 MB, referenced sheets only) after #90 |
| Last verified check | #90: `bash blender/scripts/check.sh` PASS (VERIFY PASS, pytest 19), validate 105/0, ownership PASS (203 files). #81/#85: roblox check.sh OVERALL PASS (game-001 941 / 946) |
| Blockers | none |
| Needs from others | FORGE-07/05: review #90, #81, #85. FORGE-01: pass `kingdom` to soldier rigs (FL-0104) after #81. FORGE-00/user: D-026 calibration verdicts on kit keep/house, cottage and oak sheets (in #90) |

## Blender kit state (D-019 review log in `blender/reviews/`)
- 223 assets: 146 PASS, 70 NEEDS-WORK, 7 UNREVIEWED (house_cottage after the emblem banner).
- Emblems unified (D-039): crown / star / oak leaf / sun from `_kingdom_props_common`; flame removed; no crescent finials.
- Parked (GENERATORS.md): farm_field, tree_birch, rock_cliff, resource_stone, resource_ore, prop_well; kingdom emblem polish (soldier archers, smithy_04 / barracks_04 sun, crown consistency) with the next strategy (one kit-wide emblem plaque).

## Next
1. Aerial emblems in the Luau Kit (render check incl. CVD simulation at ~170 studs).
2. Image-only preview PRs after #90; sync main back into `forge/02-blender`.
3. FL-0086 new building types; kit-wide emblem plaque; village vignette and import pack (FL-0057).

## Unverified
Nothing has been seen in Roblox Studio (headless gates and Blender renders only).
