---
id: FL-0089
title: Reputation screen, HUD reputation strip and kingdom conditions (G13.4)
track: build
owner: forge-03
status: REVIEW
priority: P0
game: game-001
created: 2026-10-12
updated: 2026-10-12
depends_on: [FL-0080]
context: [games/game-001/design/living-kingdom.md, games/game-001/CONTRACTS.md, games/game-001/BRIEF.md, games/game-001/content/SPEC.md]
estimate_h: 4
evidence:
  - bash roblox/scripts/check.sh OVERALL PASS (see PR)
  - ReputationModel.spec (16) + ReputationUI.spec (16, end to end over RemoteService and ReputationDoubles); 7 mutations + the M1 no-rebuild check each fail a spec
  - games/game-001/design/ui/screenshots/luau rep-* (14) and design/ui/screenshots rep-* prototype (5), reviewed; FL-0059/FL-0087 drawer scenes re-shot for the moved drawer
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
- 2026-10-12 forge-03: READY → BUILDING. FORGE-03 (subagent): reputation strip, ReputationPanelController screen, kingdom conditions on G13.4 with a ReputationDoubles server double
- 2026-10-12 forge-03: BUILDING → REVIEW. PR stacked on #25/#34/#41: strip + screen + conditions; text only from the content library (FL-0083 pending); Studio steps for the user in the handoff
