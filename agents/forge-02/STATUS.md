# FORGE-02 status

_Maintained by the worker. Keep it short and current. Refreshed 2026-10-19 (after #277)._

| Field | Value |
|---|---|
| Session branch | `forge/02-blender-damage-lows` (this PR); other open branches below |
| Open PRs | this one (FORGE-07's L1 / L2 on #277: ceiling numbers, `KitOrder` spec and mutants), #280 (texts after CONTRACTS v0.4-g11m, errata 2: docs and comments only), #279 (`Kit.shield` left-hand Accessory, `Kit.weapon` `opts.shield`) |
| Merged this cycle | #90 pipeline core, #184 outposts, #197 miner pick, #200 four kingdom styles, #207 mesh-citizen Kit runtime, #217 Crown Arena venue + crowd + armour + weapons, #220 citizen mesh kit (style B), #226 170-stud silhouette pass, #240 arena dress placement, #242 status, #247 env-mesh runtime, #260, #263 import checks and CollisionFidelity fix, #264 blender Lune-spec guard, #268 war kit round B, #274 FL-0136 phase 3 (node markers, field fences, cabbage variants), #277 Kit/Damage in the model's own frame |
| Current task | FL-0128 (war kit and damage states) and FL-0136 (environment and architecture from imported meshes) stay BUILDING; FL-0072 shield follow-up (#279) |
| Last verified check | `bash roblox/scripts/check.sh` OVERALL PASS on #274 head `9835ad58` (game-001 specs 2794 / 0) and by FORGE-05's gate 8r on main (2840 / 0). The Kit specs on later branches are targeted runs only. Headless only; **no Studio evidence for any of this art** |
| Blockers | None for me. Mesh art (citizens, environment) waits on the owner's Studio import and Explorer checks (`games/game-001/art/IMPORT_CHARACTERS.md`, `IMPORT_ENVIRONMENT.md`) |
| Needs from others | Owner: re-import `env_kit.fbx` (56 objects) and the citizen kit, the Explorer-first checks, reopen a saved .rbxm to read `CollisionFidelity` (expected, unverified, Default), Render Stats physics memory, Studio screenshots. FORGE-00: yes / no on a lighter-wood chip band for the palisade marks (FORGE-07's L4), CONTRACTS G12.6 row for `Kit.shield` and `opts`. FORGE-01: `ArenaService` switches to `Kit.weapon(..., { shield = false })` plus `Kit.shield(color)` (handoff `2026-10-19-forge-02-to-forge-01-04-shield-accessory.md`). FORGE-04 (#273): re-dress after a server move per errata 2 |

## Open work branches (pushed, not merged)
- `forge/02-blender-damage-lows`, `forge/02-blender-g11m-texts`, `forge/02-blender-shield-accessory`: the three PRs above.
- Parked, not for merge: `forge/02-blender-fl0086-buildings`, `forge/02-blender-b12-visuals`, `forge/02-blender-fl0085-record`, `forge/02-blender-env-wheat` (superseded by the FL-0136 mesh path).

## Last report
FL-0128 lows after #277 (interim art, D-051; headless Lune evidence, no Studio): the ceiling numbers in the texts are the measured 26,402 / 6,945 (farms at level 3: 26,438); `KitOrder` is pinned by a spec (every part of a `Kit.build` model carries a unique integer, the damage walks the numbers, float noise of 1e-4 changes no choice where the numbers decide) with mutants; the palisade-marks read at 170 studs (L4) is held for FORGE-00 (a lighter-wood chip band is the cheap lever).
Still placeholder quality: all mesh art until the Studio import is judged; the orb node markers ("balloons on sticks") and the thin identical field fences; units at 170 studs, tower L2 against L1 and the ram at 170 (not chased per FORGE-00); the shield disc is wider than the torso and lies flat under a hanging left arm (#279).
