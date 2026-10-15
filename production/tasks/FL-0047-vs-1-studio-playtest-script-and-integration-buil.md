---
id: FL-0047
title: VS-1 Studio playtest script and integration builds
track: qa
owner: forge-05
status: REVIEW
priority: P0
game: game-001
created: 2026-10-12
updated: 2026-10-13
depends_on: [FL-0046]
context: [games/game-001/BRIEF.md, games/game-001/CONTRACTS.md]
estimate_h: 3
evidence:
  - "dry run against the stamped game-001 place built from main cbe3881: BuildInfo, Config.Game (id game-001), Forge/Game Services and Controllers folders, Main log fields (game, trees) all present — DRY RUN PASS"
  - integration-log #7 row; PR CI run 38300735093
---

# VS-1 Studio playtest script and integration builds

## Outcome
The user can verify VS-1 in Studio in under 20 minutes with a scripted checklist, and the results land as evidence.

## Requirements
- games/game-001/STUDIO_PLAYTEST.md: setup (rojo serve or CI .rbxl), one section per VS-1 row (BRIEF section 4) with exact steps, expected result, screenshot to take and Output log to paste
- 2-player local server test for a shared kingdom
- Results recorded in production/quality-gates/studio-runs.md

## Validation
Dry-run against the built place structure; user run

## Completion criteria
- [ ] User completes the checklist on an integrated build

## Log
- 2026-10-12 forge-00: created for AI Kingdoms VS-1 (READY).
- 2026-10-12 forge-05: READY → BUILDING. VS-1 playtest script, 2-player tests, studio-runs record.
- 2026-10-12 forge-05: BUILDING → REVIEW. Script ready: setup + boot (runnable now) + one check per VS-1 row (marked waiting until each feature merges; FORGE-05 fills exact controls in the merging PR) + M1/M2 + perf note + report template. G6: the user's run.
- 2026-10-13 forge-05: REVIEW → REVIEW. D-046 log: at-merge record for #7 (9ba7283, 2026-10-12): the VS-1 playtest script, multiplayer plan and studio-runs record, PR CI run 38300735093 green, boot checks dry-run PASS on the stamped place. Since then kept current per merge (latest: Mac keys 378a671, D-046 (3)). REVIEW, only G6 pending (the user's run).
