# Lessons learned — Blender (FORGE-02)

Format: date · lesson · evidence · tag (`observed-once` / `repeated` / `standard`).

- 2026-10-12 · In bpy 5.2.2, `Image.pack()` on a generated image wipes its pixels (renders came out black). Generate the image, save it to a PNG, then load it from disk (the FBX exporter needs a file path to embed anyway). · first cottage renders black; fixed in `lib/asset.py` · `observed-once`
- 2026-10-12 · On this cloud machine (4 CPUs, no GPU) Cycles CPU renders 800×600 at 48 samples + OIDN in ~13.5 s, while Eevee (Mesa llvmpipe) takes ~51 s for the first frame and ~27 s afterwards. Use Cycles for previews. · `scratchpad bench`, both engines timed in one run · `observed-once`
- 2026-10-12 · Design buildings at human scale from the start: a 5.5-stud Roblox character needs ~7.5-stud doors and ~11-stud storeys. The first cottage pass at "realistic-looking" sizes had doors shorter than the character and had to be rebuilt 1.5× larger. · `previews/house_cottage.jpg` v1 vs v2 · `observed-once`
- 2026-10-12 · Bevelling every small box blows triangle budgets (a bevelled box is ~44 tris vs 12). Bevel only parts large enough to catch light (walls, roofs, big stones); keep timbers, frames and battens plain. · cottage 7.1k → 4.8k tris with no visible loss · `observed-once`
- 2026-10-12 · `bpy_extras.io_utils.axis_conversion(to_forward='Z', to_up='Y')` maps Blender (x, y, z) to (−x, z, y), so a −Y-facing Blender front becomes Roblox −Z (LookVector). Pinned by `tests/test_pipeline.py`; Studio confirmation pending (A3). · `observed-once`
