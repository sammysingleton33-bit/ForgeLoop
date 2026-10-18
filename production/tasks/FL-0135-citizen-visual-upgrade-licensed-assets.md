---
id: FL-0135
title: "Citizen and ruler visual upgrade with licensed prebuilt assets: faces, hair, clothing, job identities, rulers, variation (D-057)"
track: asset
owner: forge-02
status: READY
priority: P0
game: game-001
created: 2026-10-18
updated: 2026-10-18
depends_on: []
evidence: []
---

# Citizen and ruler visual upgrade with licensed prebuilt assets: faces, hair, clothing, job identities, rulers, variation (D-057)

## Outcome
In a playable build, citizens look professional and alive. Each has a face, hair, clothing, boots and accessories; farmer, miner, lumberjack, blacksmith, merchant, healer and soldier read at a glance from the aerial camera; rulers have crowns, capes and kingdom detail; and every citizen still varies by its generated look. The same models work in the conversation portrait.

## Context
- The owner's visual review (2026-10-18): the current citizens and general art are unacceptable for launch. D-057 sets the sources, style, budgets and import path.
- The repo is **public**: only CC0 or otherwise redistributable files may be committed.
- This supersedes FL-0118's primitive-part polish.
- Today's rig: ≤ 11 primitive Parts with `Sim/Pose.JOINTS` motors (CONTRACTS G10). Animation is procedural (FORGE-04). Look data comes from G13.2 `look`.

## Requirements
- **Audit first** (short): the Kit character builder, `Kit.portrait`, the look data, the pose driver interface and the Studio/asset path (`Kit.setAssetSource`, `Forge.Assets`). #90's Blender pipeline is the generator base.
- **Pick the source and style once** (D-057 (2)–(3)). FORGE-00's research brief on licences and Roblox technical limits is sent to you as soon as it lands; record the licence and source URL per asset in the manifest.
- **Build a character kit:**
  - a base body (or bodies) with interchangeable heads/faces, hair, clothing colour regions, boots and accessories;
  - job tools and outfits for the seven identities;
  - ruler crown and cape in kingdom colours;
  - soldier kingdom armour.
  - Variation comes from the existing `look` fields (seeded, no new wire fields unless agreed; additive G10/G13.2 rows go in your handoff).
- **Keep the animation working:** the `Pose.JOINTS` names as a segmented MeshPart rig or bones (D-057 (4)); coordinate with FORGE-04 if the pose driver must change.
- **Budgets** (D-057 (5)): measure and record triangles per citizen, draw calls and texture memory, plus the LOD swap.
- **Import-ready batch** (D-057 (6)): FBX/glTF and a manifest, plus one Studio command-bar import script and a one-page procedure for the owner. Until the owner imports, the Kit falls back to the part-built rigs, so builds keep running.
- **Before/after:** renders at the aerial distance (40/170 studs) and in the portrait, old vs new, for D-019.

## Validation
- **Automated:** Kit specs (fallback path, joint names, variation determinism, triangle budget from the manifest).
- **Visual:** a fresh D-019 review of the before/after renders.
- **Studio:** after the owner's import, a B2x row with screenshots at the aerial and portrait views.

## Completion criteria
- [ ] PR merged after review (FORGE-05 gate, FORGE-07 asset-safety and code review).
- [ ] The owner's Studio import done; the upgraded citizens appear in a delivered playable build.
- [ ] Studio screenshot evidence.

## Log
- 2026-10-18 FORGE-00: created from the owner's visual-quality directive (D-057). It supersedes FL-0118.
