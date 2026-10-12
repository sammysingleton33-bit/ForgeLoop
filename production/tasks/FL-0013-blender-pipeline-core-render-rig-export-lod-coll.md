---
id: FL-0013
title: "Blender pipeline core: render rig, export, LOD, collision, validation, manifest"
track: asset
owner: forge-02
status: READY
priority: P0
game: factory
created: 2026-10-12
updated: 2026-10-12
depends_on: []
estimate_h: 8
evidence: []
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
- blender/scripts/check.sh

## Validation
check.sh rebuilds a small set and validates; render images opened and reviewed

## Completion criteria
- [ ] check.sh green
- [ ] README documents budgets, scale, Studio import steps

## Log
- 2026-10-12 forge-00: created (READY).
