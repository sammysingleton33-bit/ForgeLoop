# FORGE-02 status

_Maintained by the worker. Keep it short and current._

| Field | Value |
|---|---|
| Session branch | `forge/02-blender-status` (this refresh); work branches below |
| Open PR | #90 (FL-0013 Blender pipeline core, waiting for FORGE-07/05 review). Everything else of this cycle is merged: #138 #153 #155 #169 (citizens, B18), #141 #151 (environment), #159 (world trim), #160 (farm nodes), #85 (portrait) |
| Current task | none active. Next candidates (FORGE-00 to order): FL-0086 round 2, the parked B12 visuals, the FL-0085 record, a wheat and boulder fix that needs meshes |
| Last verified check | `bash roblox/scripts/check.sh` OVERALL PASS on #169 at merge (FORGE-05: game-001 1692/0, main f3298dd = B18). Headless only; **no Studio evidence for any of this art** |
| Blockers | Wheat and boulders: wedge and block layouts read as built objects, not crops or rocks (3 attempts each, D-019 NEEDS-WORK). The fix is one-mesh props from the Blender pipeline, which needs the user's Studio import (the optional mesh pilot, `import_pilot` in the session scratch; nothing uploaded by FORGE-02) |
| Needs from others | FORGE-07/05: review of #90. FORGE-05 / the user: Studio look at the starting farms (B17 checklist G1) and at the cheer (arms beside the head) and the 8 citizen rigs at 40-80 studs and from the aerial camera. FORGE-01: drop the 20 world-node ids from the `KNOWN` ratchet in `tests/sim/LayoutZones.spec.luau`, flip the cheer ratchet to ≥ 0.1, and `Layout.keepOutAreas()` when it is on main (my `NodeKeepOut.spec` has a one-line TODO to read it) |

## Work branches (pushed, not merged; each needs a main merge and a fresh gate before any PR)
- `forge/02-blender-fl0086-buildings` (266f375): six VS-2 building types, carries the D-047 27k ceiling spec (it now passes with #159: measured 25,861 / 27,000 on a scratch merge). Fresh D-019 was NEEDS-WORK, round-2 fix list in the handoff `production/handoffs/2026-10-13-forge-02-to-forge-01-fl0086-vs2-buildings.md`.
- `forge/02-blender-b12-visuals` (f95ee2b): throne seen from behind, oak emblem, house pennants.
- `forge/02-blender-fl0085-record` (c83032a): farm crop attempt 3 and the FL-0085 record.
- `forge/02-blender-env-wheat` (758c185): ridged-row wheat at 44 parts, D-019 NEEDS-WORK, not for merge (FORGE-00 ruling: keep #141's slabs until a mesh row exists).

## Last report
B18 cut (main f3298dd) carries FORGE-02's playtest art pass as **interim art (D-051), nothing passes D-019 yet, all Blender and headless evidence**:
- Environment (#141, #151): fuller oak/pine/birch, angular boulders, readable stone/ore/wood nodes, flat crop rows. Pine clearly better, oak and birch modest.
- World (#159, #160): decor trimmed to the 27k part ceiling (measured 25,861) with farm and plot views protected; the 20 world resource nodes moved out of the starting farms by drawn extent, same offsets in all four plots.
- Citizens (#138, #153, #155, #169): per-job hats, colours and handle-and-head tools in the 11-part rig (D-048), kingdom red from above, arms-up cheer clears the head. Soldier and governor pass D-019; the set is NEEDS-WORK on variation, miner and hauler front read and idle detail.
Still placeholder quality: wheat crop, boulders, per-individual variation, the miner's pick read from the front, the hauler's load from the front, idle silhouette.
