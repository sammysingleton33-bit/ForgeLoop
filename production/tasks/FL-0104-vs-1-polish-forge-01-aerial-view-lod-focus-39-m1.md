---
id: FL-0104
title: "VS-1 polish (FORGE-01): aerial-view LOD focus (#39 M1), G13.7 debug hooks, soldier kingdom crest plumbing"
track: build
owner: forge-01
status: BUILDING
priority: P0
game: game-001
created: 2026-10-13
updated: 2026-10-13
depends_on: [FL-0049]
context: [games/game-001/CONTRACTS.md, DECISIONS.md, games/game-001/STUDIO_PLAYTEST.md]
estimate_h: 3
evidence: []
---

# VS-1 polish (FORGE-01): aerial-view LOD focus (#39 M1), G13.7 debug hooks, soldier kingdom crest plumbing

## Outcome
In the aerial view every citizen of the kingdom is visible, Studio testers can trigger the G13.7 debug presets, and soldiers wear their kingdom's helmet crest.

## Context
- Backlog audit 2026-10-13: #39 M1 (EntityController focus uses the character, so citizens more than 150 studs from the ruler are hidden in the overview); G13.7 presets vs1.reseed/vs1.request/vs1.strike fail closed because no `debugReseed`, `debugRequest`, `debugStrike` exist; CONTRACTS G13.2 crest needs `kingdom` passed to `Kit.character` (PR #81 adds the Kit side).

## Requirements
- LOD centre = `RulerCameraController:getFocus()` in overview mode (character in walk mode).
- Implement the three debug hooks the G13.7 presets call (Studio-only, through DebugCommands).
- Pass `kingdom` to `Kit.character` for soldiers in EntityController.buildRig once #81 merges.

## Validation
- Automated: specs for the LOD centre per camera mode, each hook, and the crest argument.
- Studio (user): STUDIO_PLAYTEST row 4 (citizens visible across the plot), presets in rows 4 and 9.

## Completion criteria
- [ ] LOD focus fixed
- [ ] Three hooks added
- [ ] Crest plumbing added

## Log
- 2026-10-13 forge-00: created from the backlog audit (D-038) (READY).
- 2026-10-13 forge-01: READY → BUILDING. LOD centre from RulerCameraController focus in overview; G13.7 debug hooks; soldier crest kingdom arg
