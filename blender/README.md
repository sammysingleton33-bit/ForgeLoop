# FORGE-02 Blender pipeline

Procedural, reproducible 3D production for FORGELOOP games. Game #1 (AI Kingdoms) art direction:
[`ART_DIRECTION.md`](ART_DIRECTION.md). Writing generators: [`GENERATORS.md`](GENERATORS.md).
Reviews: [`reviews/README.md`](reviews/README.md).

```
blender/
  build.py              CLI: generate -> validate -> export FBX -> render -> contact sheet -> manifest
  lib/                  palette, geometry, shared architecture kit, preview rig, export, validation, manifest
  generators/           one module per asset family (house_cottage.py is the reference)
  scenes/               cohesion vignettes (whole-scene renders)
  budgets.json          LOD0 triangle budgets per class (+ Roblox limits)
  manifest.schema.json  hand-over contract schema; manifest.d/<generator>.json fragments -> manifest.json
  previews/             committed contact sheets (JPEG, <= 250 KB each)
  reviews/              review logs + verdicts (D-019)
  scripts/check.sh      the asset gate
  tests/                pytest (pure-Python subset runs without bpy)
  exports/ renders/     build outputs, git-ignored (reproducible)
```

## Running
Cloud / Linux (bpy wheel, see `tools/setup/cloud-setup.sh --blender-only`):
```bash
~/forge-bpy/bin/python blender/build.py --list
~/forge-bpy/bin/python blender/build.py --generator house_cottage          # 6 variants, previews
~/forge-bpy/bin/python blender/build.py --all --no-render                   # every asset, exports only
~/forge-bpy/bin/python blender/build.py --verify                            # reproducibility check
bash blender/scripts/check.sh                                               # the gate (PASS/FAIL/SKIP)
```
Windows desktop Blender 5.2.x (**unverified until the user runs it** — see `roblox/studio-tests/assets.md` A0):
```bat
"C:\Program Files\Blender Foundation\Blender 5.2\blender.exe" -b -P blender\build.py -- --all --no-render
```
`build.py` adds its own folder to `sys.path` and reads the arguments after `--`, so it works from any
working directory (covered by `tests/test_pipeline.py::test_blender_P_form_*`). Desktop Blender's Python has
no Pillow, so contact sheets are skipped there; exports, validation JSON and individual renders still work.

## Units, axes, pivots
- **1 Blender unit = 1 stud.** Scene unit system None (Roblox `art/blender.md`). Human scale: 5.5-stud character,
  4.4 × 7.6 doors, ~11-stud storeys (ART_DIRECTION §2).
- Blender is Z-up; assets face **−Y**. FBX export with Forward = Z, Up = Y converts (x, y, z) → (−x, z, y), so the
  asset front becomes Roblox **−Z** (the Model's LookVector). Manifest sizes and sockets are already in Roblox X/Y/Z (Y up).
- Pivot at base centre (validated to ≤ 0.01 studs).

## Export settings (Roblox creator-docs `art/blender.md`, `art/modeling/export-requirements.md`, fetched 2026-10-12)
FBX, selected object only, Apply Scalings = **FBX Unit Scale**, scale 1.0, Forward **Z**, Up **Y**, Path Mode
**Copy** + **Embed Textures**, no leaf bones, no animation, face smoothing. One mesh object per file (visual mesh
only), triangulated, one material (`M_forge_palette`) with the palette PNG on Base Color.

## Materials: one palette texture for the whole kit
Every asset samples `exports/textures/forge_palette_v1.png` (512 px, 16 × 16 gradient swatches, `lib/palette.py`).
Each FBX embeds it; in Roblox upload/import it once and reuse the same texture id on every MeshPart (one texture in
memory for the whole world). Palette indices are append-only (never reorder) so existing UVs stay valid.

## Validation (per asset `exports/<id>.validation.json`; build exits 1 on any failure)
LOD0 tris ≤ class budget and ≤ 20,000 (Roblox per-mesh limit), size ≤ 2048 studs, pivot at base centre, no
degenerate faces / loose vertices / open edges (watertight, no zero-thickness surfaces), triangulated, one UV
map in 0–1 sampling only palette swatches, one material, generator structural checks (e.g. window count,
branch depth). Per generator: silhouette difference between variants (1 − IoU of front/side projections) ≥ 0.08.
LOD1 (decimated, 35 %) is a Blender-side budget/preview figure only; Roblox makes its own LODs (`RenderFidelity`).

## Budgets (LOD0 triangles, `budgets.json`)
| Class | Tris | Class | Tris |
|---|---|---|---|
| tree | 4,000 | building_small | 5,000 |
| palm | 3,000 | building_medium | 8,000 |
| bush | 1,500 | building_large | 12,000 |
| rock | 1,000 | castle_wall | 3,000 |
| ruin | 1,500 | castle_tower | 6,000 |
| resource | 1,500 | castle_gate | 9,000 |
| crop | 3,000 | castle_keep | 16,000 |
| prop_small / prop | 800 / 1,800 | bridge | 4,000 |
| banner | 800 | siege | 4,000 |
| character | 2,500 | | |

## Collision
Roblox has no import naming convention for collision meshes (creator-docs; a 2026 feature request is still open),
so each manifest entry carries `collision.fidelity` (set on the MeshPart) and optional `collision.boxes`
(invisible, CanCollide Parts in Roblox coordinates, e.g. tree trunks or gatehouse masses). `"None"` means: visual
MeshPart CanCollide = false, use the boxes only.

## Into Roblox Studio (FORGE-05 with the user)
1. Rebuild exports on the target machine and compare validation JSON tri counts/sizes with `manifest.json`.
2. 3D Importer: File → Import 3D → `exports/<id>.fbx`. File Transform: World Forward **Front**, World Up **Top**;
   Scale Unit **Stud**; Use Imported Pivot on; Import Only As Model on; Merge Meshes off; **Make Double Sided off**
   (all geometry is solid).
3. Per MeshPart: `CollisionFidelity` and `RenderFidelity` from the manifest; add `collision.boxes` Parts if listed;
   set the Model's PrimaryPart; name the Model by asset id; save `roblox/assets/<asset_id>.rbxm`.
4. Checks to run and record: `roblox/studio-tests/assets.md`.
