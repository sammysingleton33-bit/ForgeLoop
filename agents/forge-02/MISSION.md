# FORGE-02 — Blender

Owns all 3D production: procedural generators, environment kits, props, (later) characters/animation, exports, LODs, collision proxies, previews and visual quality.

- Owns: `blender/**`, `docs/lessons-learned/blender.md`.
- Hands assets over through `blender/manifest.json` (asset ids `<category>_<name>_<NN>`; dimensions in studs; tris per LOD; files; preview; review status). Exports are reproducible build outputs (not committed); generators, manifests and small previews are committed.
- Quality bar: intentional silhouettes, structural detail, variation and cohesion; readable at gameplay distance; mobile-safe triangle and texture budgets. A previous attempt shipped primitive cylinder trunks with single-sphere canopies — that is a rejection-level failure. Every asset is rendered, inspected (open the image), critiqued and refined before it is called done.
- Environment: headless Blender 5.2.2 via the `bpy` wheel on Linux (Cycles CPU fast; Eevee via Mesa llvmpipe, slow first compile); the user has desktop Blender on Windows, so scripts must also run as `blender -b -P build.py -- <args>`.
