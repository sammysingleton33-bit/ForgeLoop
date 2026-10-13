# Lessons learned — Blender (FORGE-02)

Format: date · lesson · evidence · tag (`observed-once` / `repeated` / `standard`).

- 2026-10-12 · In bpy 5.2.2, `Image.pack()` on a generated image wipes its pixels (renders came out black). Generate the image, save it to a PNG, then load it from disk (the FBX exporter needs a file path to embed anyway). · first cottage renders black; fixed in `lib/asset.py` · `observed-once`
- 2026-10-12 · On this cloud machine (4 CPUs, no GPU) Cycles CPU renders 800×600 at 48 samples + OIDN in ~13.5 s, while Eevee (Mesa llvmpipe) takes ~51 s for the first frame and ~27 s afterwards. Use Cycles for previews. · `scratchpad bench`, both engines timed in one run · `observed-once`
- 2026-10-12 · Design buildings at human scale from the start: a 5.5-stud Roblox character needs ~7.5-stud doors and ~11-stud storeys. The first cottage pass at "realistic-looking" sizes had doors shorter than the character and had to be rebuilt 1.5× larger. · `previews/house_cottage.jpg` v1 vs v2 · `observed-once`
- 2026-10-12 · Bevelling every small box blows triangle budgets (a bevelled box is ~44 tris vs 12). Bevel only parts large enough to catch light (walls, roofs, big stones); keep timbers, frames and battens plain. · cottage 7.1k → 4.8k tris with no visible loss · `observed-once`
- 2026-10-12 · `bpy_extras.io_utils.axis_conversion(to_forward='Z', to_up='Y')` maps Blender (x, y, z) to (−x, z, y), so a −Y-facing Blender front becomes Roblox −Z (LookVector). Pinned by `tests/test_pipeline.py`; Studio confirmation pending (A3). · `observed-once`

## Process: stacked PRs (2026-10-12)
- A PR stacked on another PR's branch merges **into that branch**, not into main, even after the lower PR has
  merged. #37 (build slots) landed on `forge/02-blender-fl0055-world` and never reached main until FORGE-05
  re-targeted it (#38). Rule: as soon as the lower PR merges, retarget the stacked PR's base to `main`
  (`update_pull_request base=main`) and merge main into its head. Then confirm with `git show origin/main:<file>`
  after the merge.
- A branch that contains the same commit twice (once through main, once through the stale stacked base) can
  show "dirty" on GitHub even when local `git merge` is clean. Merging current main into the head and pushing
  clears it.
- 2026-10-12 · Commit an asset the moment a fresh review passes it, before asking for any optional improvement. bush, plant_grass and resource_ore all passed round 1 and then failed after "nice to have" changes. Only bush and grass could be restored, because only their passing code was in git. · reviews/bush.json, resource_ore.json history · `observed-once`
- 2026-10-12 · Cap the review loop at 3 rounds per generator. After that, park it with a written change of strategy instead of iterating. Repeated rounds of the same approach (stacked-blob birch crowns, layered cliff slabs, masonry quarry joints) failed for the same reason each time. · GENERATORS.md "Parked" sections · `observed-once`
- 2026-10-13 · Decide a cross-kit visual element (kingdom emblems) as one shared helper **before** generators draw their own. Emblems were drawn by 5 separate helpers (castle, farm, civic, village, char); fresh rounds 4–6 kept finding a different defect in each (crescent finial, retired flame, three oak designs, cog-like suns). Unifying on `_kingdom_props_common` outlines fixed classes of defects at once; the per-generator rounds did not converge. · reviews/char_soldier.md, building_smithy.md rounds 4–6; GENERATORS.md "Parked: kingdom emblem polish" · `repeated`
- 2026-10-13 · Judge emblems in grayscale at the gameplay strip, not only in colour hero views: a pale disc on an ivory roundel inside a thin dark ring read as a "C"/crescent off-axis (luma, not hue, decides it). · scratchpad sun diagnosis; reviews/castle_*.md round 4 · `observed-once`
