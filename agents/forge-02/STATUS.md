# FORGE-02 status

_Maintained by the worker. Keep it short and current._

| Field | Value |
|---|---|
| Session branch | `forge/02-blender` (pushes verified); PR branches `forge/02-blender-fl00xx*` |
| Open PRs | [#27](https://github.com/sammysingleton33-bit/ForgeLoop/pull/27) Kit v0.2.0 split (green) → [#28](https://github.com/sammysingleton33-bit/ForgeLoop/pull/28) FL-0055 world v0 (green) → [#37](https://github.com/sammysingleton33-bit/ForgeLoop/pull/37) FL-0085 part 1, build slots. Merge in that order |
| Current tasks | FL-0085 (BUILDING, P0: slots in #37; throne, citizen looks, visible levels in the Kit next), FL-0054 / FL-0056 Kit v0 (BUILDING), FL-0055 (in #28), FL-0013 + FL-0057 Blender pipeline and batch (BUILDING) |
| Last verified check | #37 branch: `bash roblox/scripts/check.sh` OVERALL PASS (game-001 91 specs, framework 328, selene 0/0); `blender/tests` 18/19 (the failure is an in-progress props worker asset, not committed) |
| Blockers | none |
| Needs from others | FORGE-05: merge #27 → #28 → #37. FORGE-01: kingdom Color3s (Kit and WorldService use the art-direction values until then). FORGE-00/user: calibration of `blender/previews/house_cottage.jpg`, `tree_oak.jpg`, and the Kit keep/house sheets |

## Hours to VS-1 (FORGE-02 items, honest estimate)
- Build slots (G13.5): done in #37, pending merge.
- Throne seat, visible levels (barracks L1–4, keep L1–3, house and farm L1–2), thatch pennants: ~2 h. Kit worker is mid-way; specs are written.
- Citizen looks (`Kit.character(..., look)`, `Kit.LOOK_RANGES`): ~1–2 h. Kit worker has the API in; review and spec pass pending.
- Kit v0 art pass (FL-0054/56) PR after that: ~1 h of integration.
- **Total: about 4–5 h of FORGE-02 time to the VS-1 Kit PR**, plus FORGE-05 merge latency.

## Done so far
- **Blender pipeline (FL-0013):**
  - palette texture, geometry and architecture kit, Roblox-like Cycles preview rig;
  - FBX export per the Roblox docs, validation JSON, manifest fragments and schema;
  - `build.py --verify`, `check.sh` and tests.
- **Blender medieval kit** (one generator family per asset type, D-019 log in `blender/reviews/`):
  - committed (`a024e40`): cottages v5 (kingdom pennants), farm (field, fence, haystack, windmill, barn), vegetation (oak, pine, birch, bush, flowers, grass);
  - built, not yet committed: castle (wall, tower, gatehouse, keep; fix round for slits and gold), village buildings, citizens and soldiers, rocks and resources, siege, props and bridges.
- **Palette rules:** muted thatch, true-gold kingdom, one emblem per kingdom (crown, star, oak leaf, sun). Recorded in `blender/ART_DIRECTION.md` §3.
- **Kit (Luau):**
  - modules Parts, Pieces, Buildings, Character, Props, WorldPlan, Terrain;
  - preview path: Lune dump → `blender/scripts/render_kit.py`.
- **World:**
  - WorldService, Layout v0 with plot towns and build slots, the Lighting preset;
  - world preview: `blender/scripts/render_world.py` → `blender/previews/world_*.jpg`.

## Unverified
Nothing has been seen in Roblox Studio. The desktop-Blender rebuild (`roblox/studio-tests/assets.md` A0) has not been run.
