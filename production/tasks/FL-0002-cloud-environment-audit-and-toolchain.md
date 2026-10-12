---
id: FL-0002
title: Cloud environment audit and toolchain
track: infra
owner: forge-00
status: ACCEPTED
priority: P0
game: factory
created: 2026-10-12
updated: 2026-10-12
depends_on: []
estimate_h: 1
evidence:
  - 2026-10-12 Rojo 7.7.1, Selene 0.31.0, StyLua 2.6.0, Lune 0.11.0 installed via cargo; bpy 5.2.2 rendered Cycles CPU + Eevee (Mesa llvmpipe) test images
---

# Cloud environment audit and toolchain

## Outcome
The Linux cloud sandbox can run the Roblox CLI toolchain and headless Blender.

## Requirements
- Record OS/hardware, tool versions, network limits

## Validation
rojo/selene/stylua/lune --version; bpy render smoke test (Cycles + Eevee)

## Completion criteria
- [ ] Versions recorded in DECISIONS D-005
- [ ] Known limits recorded (no Studio on Linux; GitHub release downloads blocked by proxy; crates.io/pypi work)

## Log
- 2026-10-12 forge-00: created (ACCEPTED).
