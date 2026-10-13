---
id: FL-0101
title: Integrate cinematic conversations v1; Studio playtest rows and build (G13.8)
track: qa
owner: forge-05
status: SPECIFIED
priority: P1
game: game-001
created: 2026-10-13
updated: 2026-10-13
depends_on: [FL-0097, FL-0098, FL-0099, FL-0100]
context: [games/game-001/CONTRACTS.md, games/game-001/design/living-kingdom.md, DECISIONS.md, games/game-001/content/SPEC.md]
estimate_h: 2
evidence: []
---

# Integrate cinematic conversations v1; Studio playtest rows and build (G13.8)

## Outcome
The user gets a build where selecting a citizen plays the full cinematic conversation, with a Studio checklist to confirm it on their Mac.

## Context
- D-034 (build and review cycle), D-036, CONTRACTS G13.8 (Integration), FL-0093.

## Requirements
- Merge FL-0097..FL-0100 in dependency order; FORGE-06 DRAFT content only as labelled starter content (D-035).
- STUDIO_PLAYTEST rows: camera focus and return; portrait matches the world look; a choice applies its effects; closing mid-conversation releases the hold; phone emulator layout.
- B-build with 'what you can do' and 'not working yet' lists.

## Validation
- Headless: check.sh OVERALL PASS on main.
- Studio (user): the new rows, with screenshots or a recording.

## Completion criteria
- [ ] Rows added
- [ ] B-build delivered
- [ ] User Studio result recorded

## Log
- 2026-10-13 forge-00: created for cinematic conversations (D-036, CONTRACTS G13.8). After FL-0097..FL-0100 land; ship as the next B-build after VS-1 conversations.
