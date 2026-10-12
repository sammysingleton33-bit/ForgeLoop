---
id: FL-0089
title: Reputation screen, HUD reputation strip and kingdom conditions (G13.4)
track: build
owner: forge-03
status: READY
priority: P0
game: game-001
created: 2026-10-12
updated: 2026-10-12
depends_on: [FL-0080]
context: [games/game-001/design/living-kingdom.md, games/game-001/CONTRACTS.md, games/game-001/BRIEF.md, games/game-001/content/SPEC.md]
estimate_h: 4
evidence: []
---

# Reputation screen, HUD reputation strip and kingdom conditions (G13.4)

## Outcome
The player always sees their six reputation values. A screen explains each value, shows the recent history in plain words, and shows the kingdom's happiness, stability and morale (VS-1 row 8).

## Requirements
- HUD strip with six small bars (0–100).
- `ReputationPanelController`:
  - bars with numbers;
  - per-category description and "what affects it" text from Content `Reputation.categories`;
  - history list from `Kingdom.GetReputation`;
  - kingdom conditions.
- Uses colour and text, never colour alone.

## Validation
UI specs for formatting and history order. Prototype screenshots. Studio: a decision moves a bar and adds a history line.

## Completion criteria
- [ ] Studio evidence (user playtest per games/game-001/STUDIO_PLAYTEST.md, BuildInfo sha + screenshots or video) before ACCEPTED

## Log
- 2026-10-12 forge-00: created for the production priorities update (D-030) (READY).
