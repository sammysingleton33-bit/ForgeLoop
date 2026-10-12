---
id: FL-0034
title: Run the Windows project inventory script
track: infra
owner: user
status: READY
priority: P0
game: factory
created: 2026-10-12
updated: 2026-10-12
depends_on: []
estimate_h: 0.5
evidence: []
---

# Run the Windows project inventory script

## Outcome
We know where the previous survival-arena place, scripts, Blender files and Script Sync folders are on your PC, without changing anything.

## Requirements
- Run tools/diagnostics/find-roblox-projects.ps1 in PowerShell (read-only)
- Commit the report or paste it into a FORGE-00 chat

## Validation
Report lists found .rbxl/.rbxlx/.blend/.fbx/Rojo projects with paths and dates

## Completion criteria
- [ ] Report saved to production/handoffs/

## Log
- 2026-10-12 forge-00: created (READY).
