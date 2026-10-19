---
id: FL-0144
title: "Missing management HUD in the owner's B22 Studio run: root cause and fix"
track: build
owner: forge-03
status: BUILDING
priority: P0
game: game-001
created: 2026-10-19
updated: 2026-10-19
depends_on: []
evidence: []
---

# Missing management HUD in the owner's B22 Studio run: root cause and fix

## Outcome
On every client, the management HUD (KingdomHud) appears and works in a Studio Play Solo and a two-player run of the next build.

## Context
- The owner's Studio run of B22 (e8ea78c): the kingdom loads, but the HUD is missing or not initialized. D-059 (1).
- Evidence comes first: the owner's Output and the PlayerGui contents, the loader's behaviour, and the HUD's path from join to visible. No UI rewrite.
- With FORGE-05 (loader, Boot spec, gate) and FORGE-00's headless hypothesis check.

## Requirements
- The root cause, stated with file:line, then the minimal fix in the owning files.
- A headless "HUD mounted" check in the Boot spec, so the gate catches this from now on.

## Validation
- Automated: `check.sh` green, including the new Boot check.
- Studio (user): Play Solo, then pick a plot. The HUD shows, the drawer opens, and there are no red lines in the Output.

## Completion criteria
- [ ] Fix merged and in the next playable build.

## Log
- 2026-10-19 FORGE-00: created from the owner's playtest feedback.
