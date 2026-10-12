# FORGE-02 status

_Maintained by the worker. Keep it short and current._

| Field | Value |
|---|---|
| Session branch | `forge/02-blender` (pushes verified); PR branch `forge/02-blender-fl0054-stubs` |
| Open PR | [#16](https://github.com/sammysingleton33-bit/ForgeLoop/pull/16): hour-0 stubs, Kit.luau (G10) and Layout.luau (G10.1) |
| Current tasks | FL-0054 Kit v0 (BUILDING), FL-0055 world v0 (BUILDING), FL-0056 characters (BUILDING), FL-0013 Blender pipeline (BUILDING) |
| Last verified check | `bash roblox/scripts/check.sh` OVERALL PASS on the stub branch (game-001 specs 32/0, framework 309/0, selene 0/0, stylua, place checks); `bash blender/scripts/check.sh` PASS and proven to FAIL/SKIP |
| Blockers | none |
| Needs from others | FORGE-05: merge #16; set `Lighting.Technology = Future` in the project file. FORGE-01: confirm kingdom Color3s and footprints. FORGE-00/user: calibration of the first cottage/oak (Blender) and keep/house (Kit) sheets |

## Done so far
- **Blender pipeline (FL-0013):**
  - palette texture, geometry and architecture kit, Roblox-like Cycles preview rig;
  - FBX export per the Roblox docs, validation JSON, manifest fragments and schema;
  - `build.py --verify`, `check.sh` and tests.
- **Blender medieval kit:** a generator family per asset type, each with a D-019 log in `blender/reviews/`:
  - cottages; market, smithy, storehouse, barracks, tavern, workshop;
  - citizens and soldiers;
  - castle, farm, vegetation, rocks/resources, siege/props/bridges.
- **Kit (Luau):**
  - modules Parts, Pieces, Buildings, Character, Props, WorldPlan, Terrain;
  - preview path: Lune dump → `blender/scripts/render_kit.py`.
- **World:**
  - WorldService, Layout v0, the Lighting preset;
  - world preview: `blender/scripts/render_world.py` → `blender/previews/world_*.jpg`.

## Unverified
Nothing has been seen in Roblox Studio. The desktop-Blender rebuild has not been run.
