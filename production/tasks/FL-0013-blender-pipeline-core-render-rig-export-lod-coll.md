---
id: FL-0013
title: "Blender pipeline core: render rig, export, LOD, collision, validation, manifest"
track: asset
owner: forge-02
status: REVIEW
priority: P0
game: factory
created: 2026-10-12
updated: 2026-10-13
depends_on: []
estimate_h: 8
evidence:
  - "bash blender/scripts/check.sh -> blender check: PASS (images <= 250 KB, manifest schema + cross-checks ok, pytest 19 passed, VERIFY PASS: every committed generator rebuilt from its seed with matching geometry hashes); headless bpy wheel only"
---

# Blender pipeline core: render rig, export, LOD, collision, validation, manifest

## Outcome
A reusable bpy pipeline that turns a generator into reviewed, validated, Roblox-ready exports with previews and manifest entries.

## Requirements
- Deterministic seeds; scene reset; palette/material strategy proven to import correctly into Roblox (research)
- Preview rig with Roblox-character scale proxy, hero + gameplay-distance views, contact sheets
- Export (FBX or glTF; research) with correct axes/scale and base-centre origin; LOD0/LOD1; collision proxies
- Validation report: tris vs budget and import limit, bounds in studs, degenerate geometry, UVs, materials
- build.py CLI (--generator, --variants, --seed, --all) runnable via bpy wheel and desktop Blender
- Budgets (fail check.sh on breach; and on any mesh > 20,000 tris, the Roblox import limit): tree LOD0 <= 4,000 tris, palm <= 3,000, fern/bush <= 1,500, rock <= 1,000, ruin piece <= 1,500; 1 material; palette texture <= 512 px. LOD1 is a Blender-side preview/budget artefact (Roblox auto-LODs via RenderFidelity)
- One export file per asset with only the visual mesh; collision via CollisionFidelity or child `<asset_id>_col`; Model with PrimaryPart; dims as Roblox X/Y/Z (Y up); id regex ^[a-z]+(_[a-z0-9]+)+_\d{2}$ (interfaces section 10)
- Preview rig imitates Roblox (backface culling on); decide with sources between solid leaf geometry and alpha leaf cards (double-sided cost, SurfaceAppearance AlphaMode); validation flags open/zero-thickness geometry where the choice requires it
- manifest.schema.json + per-generator fragments (blender/manifest.d/<generator>.json) merged deterministically; check.sh validates the schema and fails on committed images > 250 KB
- blender/README.md: budgets, Blender-unit to stud scale, axes, export settings; desktop path `blender -b -P blender/build.py -- args` covered by an argv/sys.path unit test (marked unverified until the user runs it)
- blender/scripts/check.sh

## Validation
check.sh rebuilds a small set and validates; render images opened and reviewed

## Completion criteria
- [ ] check.sh green
- [ ] README documents budgets, scale, Studio import steps

## Log
- 2026-10-12 forge-00: created (READY).
- 2026-10-13 forge-02: READY → BUILDING. Pipeline built on forge/02-blender since 2026-10-12; landing on main via this PR (D-038 audit).
- 2026-10-13 forge-02: BUILDING → REVIEW. Pipeline core + 38 generators, fragments, reviews and merged manifest land on main (PR-A). Desktop-Blender path (assets.md A0) unverified until the user runs it.
- 2026-10-18 forge-02: FORGE-07 re-review of #90 (81f129e): B1 (agents/forge-02/STATUS.md conflict) fixed by merging main e4b2a70 and taking main's file. Tracked follow-ups accepted by FORGE-05, not merge blockers: **M1** `.github/workflows/ci.yml` has no Blender job and `blender/scripts/check.sh` prints "SKIP (not PASS)" without bpy (a skipped Blender gate counts as not run), owner FORGE-05: add a CI job using `tools/setup/cloud-setup.sh --blender-only`, or at least the stdlib-only manifest and image-size checks; **M2** 36 of the 38 `preview` paths in `manifest.json` named files that are not committed (209 of the manifest's assets today); `check.sh` now prints a WARN for them (`manifest.warnings()`, ad1cfe0), previews are committed with the PR that renders them. L2: `build.py --merge-only` documented in `blender/README.md`.
