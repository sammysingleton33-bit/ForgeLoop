# Handoff: FORGE-02 → FORGE-05 — world v0 Studio checks (W1–W6), build slots, hardening

Date: 2026-10-12 (updated after #27, #28 and #37) · From: FORGE-02 · To: FORGE-05

## What I'm giving you
- **On main:** the Kit v0.2.0 split (#27), WorldService, Layout v0, the Lighting preset, WorldPlan and the terrain adapter (#28). Lighting.Technology = Future comes from your #30.
- **This PR (FL-0055 follow-up) brings to main:**
  - **The build slots from #37.** #37 merged into its stacked base `forge/02-blender-fl0055-world`, not into main, so main has no `buildSlots` yet. This PR is that branch plus current main plus the hardening below.
  - **The hardening from your #28 review:**
    - invisible zone parts and prop footprint plates are not queryable;
    - decoration has CanTouch off and collides only near the ground;
    - forests and lone trees are trimmed: 11,465 → 8,310 world parts, and parts with both CanCollide and CanTouch on go from 10,228 → 0;
    - a parts-per-frame budget (worst frame 1,120 → 418 parts);
    - the voxel budget is checked before each fill;
    - `_build` runs under pcall, so `ready` always fires and a failure logs at error level;
    - start() is idempotent;
    - destroy() stops the build and removes `Workspace.World`;
    - no `SetMaterialColor(Water)`, and the live adapter pcalls `SetMaterialColor` (warns, continues).

## What I need from you
1. Merge this PR. It is the only way the G13.5 slots reach main.
2. Fold W1–W6 into `STUDIO_PLAYTEST.md` row 1. You said you would; the table below replaces the earlier draft.
3. Keep `ReplicatedStorage.Forge.Assets` mapped. `Kit.setAssetSource` reads it, so imported Blender meshes replace the part-built stand-ins of the same asset id (D-021).

## Studio checks (none run yet)
| # | Step | Expected |
|---|---|---|
| W1 | Start the server | Output shows `WorldService ready {ms=…, terrainOps=…, props=…, parts=…}` with parts ≈ 8,300 and no `WorldService build failed` error. Write down the ms. |
| W2 | Fly over the valley | River with water, two bridges, four corner plots, the mountain ring, forests and fields behind each keep. No holes at the world edge. |
| W3 | Lighting | Warm late-morning light, atmosphere haze, clouds, blue water (Terrain.WaterColor). Note anything washed out or too dark. Check Output for a `Terrain:SetMaterialColor failed` warning. |
| W4 | Tags | `GetTagged`: `ResourceNode` 38 models, `BuildZone` 12, `ObjectiveZone` 1, `KingdomPlot` 4, `BuildSlot` 40, each with its id attribute. `BuildSlot` parts have CanQuery on; zone parts have it off. |
| W5 | Walk a plot | Staked slots with signposts along the cross street and avenue. You can walk through slot markers and under tree canopies; trunks, rocks and bridge rails block. |
| W6 | Kit preview calibration | Screenshot the keep and house from the camera in `blender/previews/kit_building_keep.jpg` (3/4 view, about 35° azimuth, 22° elevation). That screenshot decides the final look (D-026). |

## Risks
- The terrain build time in Studio is unknown: headless runs record calls only. If W1 shows more than 5 s, tell me and I'll split further.
- Building part counts change with the FL-0085 part 2 Kit PR (throne, visible levels).
