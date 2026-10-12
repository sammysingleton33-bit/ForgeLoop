# Handoff: FORGE-02 → FORGE-05 — Kit stubs (PR #16), WorldService, lighting, Studio checks

Date: 2026-10-12 · From: FORGE-02 · To: FORGE-05

## What I'm giving you
- **PR #16, hour-0 stubs:** `src/shared/Kit/Kit.luau` (G10) and `world/Layout.luau` (G10.1), with specs. These use your world mount as-is. Please merge when convenient.
- **Next, on `forge/02-blender`, PR coming:**
  - FL-0054 Kit v0: modular Kit and the bpy preview path.
  - FL-0055 world v0:
    - `src/server/Services/WorldService.luau` (G10): no dependencies; builds into `Workspace.World` over frames and fires `ready`;
    - `world/Lighting.luau`;
    - `src/shared/Kit/{WorldPlan,Terrain}.luau`;
    - specs in `tests/world/`.
- WorldService passes the game-001 Boot spec (it boots with everything else under MockEnv). Under Lune it uses a recording terrain adapter, because Lune instances have no `Terrain:Fill*`.

## What I need from you
1. **`Lighting.Technology = Future`** in `games/game-001/default.project.json`. It is not scriptable in Roblox, so WorldService cannot set it. Every other lighting value is applied by WorldService from `world/Lighting.luau`.
2. Keep `ReplicatedStorage.Forge.Assets` mapped. `Kit.setAssetSource` reads it, so imported Blender meshes replace the part-built stand-ins of the same asset id automatically (D-021). FL-0057 sends the first import batch.
3. Add the world checks below to the Studio playtest (`STUDIO_PLAYTEST.md`), or link `roblox/studio-tests/assets.md`.

## Studio checks (none run yet)
| # | Step | Expected |
|---|---|---|
| W1 | Start the server | Output shows `WorldService ready {ms=…, terrainOps=…, props=…, parts=…}`. Write down the ms. |
| W2 | Fly over the valley | River with water, two bridges, four corner plots, the mountain ring, forests and fields. No holes at the world edge. |
| W3 | Lighting | Warm late-morning light, atmosphere haze, clouds. Note anything washed out or too dark. |
| W4 | Tags | `CollectionService:GetTagged("ResourceNode")` returns 38 models, `BuildZone` 12, `ObjectiveZone` 1, `KingdomPlot` 4. Each carries its NodeId/ZoneId/ObjectiveId attribute. |
| W5 | Kit preview calibration | Screenshot the keep and house from the camera in `blender/previews/kit_building_keep.jpg` (3/4 view, about 35° azimuth, 22° elevation). That screenshot decides the final look (D-026). |

## Risks
- The terrain build time in Studio is unknown (headless runs record calls only). There are about 120 Fill calls, the largest a 110-stud ball. If W1 shows more than 5 s, tell me and I'll split further.
- Part counts per building are not final until FL-0054 v0 lands.
