---
id: FL-0104
title: "VS-1 polish (FORGE-01): aerial-view LOD focus (#39 M1), G13.7 debug hooks, soldier kingdom crest plumbing"
track: build
owner: forge-01
status: REVIEW
priority: P0
game: game-001
created: 2026-10-13
updated: 2026-10-13
depends_on: [FL-0049]
context: [games/game-001/CONTRACTS.md, DECISIONS.md, games/game-001/STUDIO_PLAYTEST.md]
estimate_h: 3
evidence:
  - "main ab70493: check.sh PASS (game-001 1077/0 on d3525db+#91); ownership PASS 6 files; CI run 38362247731 green; LOD repro visible 1,2 -> 4,5,6 in overview; 5/5 mutations"
  - EntityService 11, EntityController 25 specs pass; mutations 8/8 caught; Studio unverified
  - "main c8572f4: check.sh PASS on 2570c47+#101 (game-001 1105/0) and combined with #103+#106 on d094380 (1111/0); CI 3/3 on 8e17348; Sim.Events 12 spawns after reseed; 3/3 mutations"
  - "main 751138b: vs1.strike and vs1.request verified headless in Studio mode in the #77 review (placards on farmers, thought event); live servers have no debug remotes"
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
- 2026-10-13 forge-05: BUILDING → BUILDING. Merged #91 (ab70493, D-040 fallback verdict on efc16c2): LOD centre = camera focus in overview, soldier crest kingdom arg, debugReseed. Still BUILDING: debugStrike/debugRequest ship with #77; M1 follow-up: reseeded looks are not sent to connected clients (EntityService:251 / EntityController:350). Lows: L1 LOD radius fixed at 150 at every zoom; L2 reseed depends on job mix.
- 2026-10-13 forge-01: BUILDING → BUILDING. Still BUILDING until merged: #91 follow-ups M1 (a reseeded look reaches connected clients: EntityService re-sends the spawn on a look-key change, EntityController swaps the rig), L1 (overview LOD hide distance = max(150, 1.25 x zoom)), L2 (reseed message names the job-mix dependence)
- 2026-10-13 forge-05: BUILDING → BUILDING. Merged #101 (c8572f4, FORGE-05 D-040 fallback verdict on 8e17348; star by FORGE-00): #91 M1 (reseeded looks reach connected clients), L1 (overview LOD follows the zoom), L2 (reseed message). Still BUILDING only for debugStrike/debugRequest, which ship in #77; then REVIEW with G6 (row 4 at full zoom-out, reseed flow).
- 2026-10-13 forge-05: BUILDING → REVIEW. #77 merged (751138b) with the G13.7 debugStrike/debugRequest hooks; with #91 and #101 every FL-0104 item is on main. REVIEW, only G6 pending (STUDIO_PLAYTEST row 4 at full zoom-out, vs1.reseed / vs1.request / vs1.strike).
