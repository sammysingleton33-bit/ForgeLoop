# FORGE-02 status

_Maintained by the worker. Keep it short and current._

| Field | Value |
|---|---|
| Session branch | `forge/02-blender` (Blender pipeline + kit, pushes verified); PR branches `forge/02-blender-*` cut from main |
| Open PRs | [#75](https://github.com/sammysingleton33-bit/ForgeLoop/pull/75) FL-0085 #60 follow-ups + #73 spec follow-ups · [#81](https://github.com/sammysingleton33-bit/ForgeLoop/pull/81) G13.2 soldier helmet crest per kingdom (VS-1 acceptance). FL-0098 `Kit.portrait` in progress on `forge/02-blender-fl0098-portrait`, stacked on #81 |
| Merged | #27, #28, #38 (build slots), #43 (world hardening), #60 (FL-0085 part 2: throne, looks, visible levels), #73 (D-033 colours from config) |
| Current tasks | FL-0085 (REVIEW). FL-0098 `Kit.portrait` (BUILDING, stacked on #81). Next: aerial-readable kingdom banners (FORGE-05 CVD finding 3) after #75 merges. Blender: gold sun emblem reads as a "C", fix in progress; then fresh reviews of castle ×4, farm_windmill, farm_barn |
| Last verified check | #73 and #75 after merging main 124af89: `bash roblox/scripts/check.sh` OVERALL PASS (game-001 866 / 869), validate 96/0, ownership PASS. Blender castle round: all four generators BUILD PASS, manifest 0 errors, `blender/tests` 19/19 |
| Blockers | none |
| Needs from others | FORGE-05: review/merge #75, #81; CVD re-run on the crest images. FORGE-01: pass `kingdom` (and `look`, M1) into `Kit.character` in EntityController; L3/L4 (re-seat ruler after keep upgrade, throne CanTouch policy) |

## Blender kit state (D-019 review log in `blender/reviews/`)
- PASS: siege catapult/ballista/ram, prop_banner, goods, cart, bridges, boulder, wood, oak, pine, bush, grass, flowers, fence, haystack.
- UNREVIEWED after geometry changes: castle keep/tower/gatehouse/wall (chunky gold drums, shared emblems), farm_windmill, farm_barn.
- Parked (3 rounds, change of strategy noted in `blender/GENERATORS.md`): farm_field, tree_birch, rock_cliff, resource_stone, resource_ore, prop_well.

## Next
1. FL-0098 `Kit.portrait` (portrait contact sheet reviewed by eye).
2. Sun emblem fix → rebuild sun-bearing generators → fresh reviews.
3. Banner emblems readable from the overview camera (FORGE-05 colour-vision finding 3, VS-1 polish).
4. FL-0086 new building types; FL-0013 pipeline PR; village vignette and import pack.

## Unverified
Nothing has been seen in Roblox Studio (headless gates and Blender renders only).
