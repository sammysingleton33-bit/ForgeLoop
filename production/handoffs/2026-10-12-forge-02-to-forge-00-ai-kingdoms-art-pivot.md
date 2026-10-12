# Handoff: FORGE-02 → FORGE-00 — AI Kingdoms art status, Blender kit, calibration requests

Date: 2026-10-12 · From: FORGE-02 · To: FORGE-00 (Director)

## Where FORGE-02 stands (aligned with D-020 to D-028 and the §0 queue)
1. **Hour-0 stubs (Kit G10 + Layout G10.1):** PR #16, check.sh OVERALL PASS.
2. **FL-0054 Kit v0** (in progress on `forge/02-blender`): the Kit is split into modules.
   - Preview path working: Lune dump → bpy contact sheets (`blender/scripts/render_kit.py`).
   - Art sheet: `games/game-001/art/ART_DIRECTION.md`.
   - Architecture and characters are being refined in D-019 loops.
3. **FL-0055 world v0** (committed on the branch):
   - WorldService, terrain adapter, deterministic WorldPlan, Lighting preset, prop stand-ins;
   - world preview `blender/scripts/render_world.py`.
4. **FL-0013 Blender pipeline** (on the branch): `check.sh` proven, budgets, manifest and README.
5. **Blender medieval kit:** the user asked in this session for a full Blender environment kit. It doubles as:
   - (a) the FL-0057 organic batch: trees, bushes, flowers, grass, rocks, resource nodes, props, banners, crops;
   - (b) high-fidelity meshes that can replace part-built architecture by asset id later (D-021).

   Generators (6–12 variants each, all in budget, D-019 review logs):
   - **cottages and other buildings:** cottages; market, smithy, storehouse, barracks, tavern, workshop;
   - **castle:** wall, tower, gatehouse, keep;
   - **farm:** field, fence, haystack, windmill, barn;
   - **nature and resources:** trees and plants; rocks and resource nodes;
   - **characters and military:** citizens and soldiers; siege;
   - **bridges and props.**

   Budgets for the medieval classes are in `blender/budgets.json`.

## Requests
1. **Kingdom names.** The Blender art bible uses working names Emberhold/Frostmere/Thornwood/Sunspire for crimson/azure/emerald/gold. Confirm or replace them (BRIEF names?).
2. **Calibration (D-019/D-026).** FORGE-00 or the user judges:
   - `blender/previews/house_cottage.jpg` and `blender/previews/tree_oak.jpg` (Blender calibration);
   - `blender/previews/kit_building_keep.jpg` and `kit_building_house.jpg` (Kit calibration, once v0 lands); the user's Studio screenshot then decides the final look.
3. **Tasks for the extra Blender families.** Should the Blender buildings, castle, characters and siege get their own tasks (VS-2 imports), or fold into FL-0057? Also, should FL-0014/15/16 (REJECTED) point to them?

## Unverified
Nothing has been imported into Roblox Studio (G6). The desktop-Blender rebuild (`roblox/studio-tests/assets.md` A0) has not been run.
