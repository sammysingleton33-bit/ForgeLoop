---
id: FL-0056
title: "Characters: citizens by job, soldier, ruler crown and cape"
track: asset
owner: forge-02
status: READY
priority: P0
game: game-001
created: 2026-10-12
updated: 2026-10-12
depends_on: [FL-0054]
context: [games/game-001/BRIEF.md, games/game-001/CONTRACTS.md]
estimate_h: 4
evidence: []
---

# Characters: citizens by job, soldier, ruler crown and cape

## Outcome
Entities and rulers read clearly at gameplay distance in kingdom colours (VS-1 rows 2 and 4).

## Requirements
- Kit.character(kind, job, colour) (D-026):
  - at most 8 parts (anchored root, torso, head, 2 arms, 2 legs, tool), joined by Motor6Ds named after the moving part;
  - CanCollide, CanTouch and CanQuery false; no Humanoid;
  - job tools and props; readable at gameplay distance.
- Kit.regalia(colour): crown and cape accessories for R15 and R6 player avatars. KingdomService attaches them at spawn.
- Lands before FL-0055's full world, because EntityController (FL-0049) renders from Kit.character.

## Validation
- Specs for part counts, joint names and collision flags.
- Preview contact sheets scored (D-019).
- Studio screenshots.

## Completion criteria
- [ ] Studio evidence (user playtest per games/game-001/STUDIO_PLAYTEST.md, BuildInfo sha + screenshots) before ACCEPTED

## Log
- 2026-10-12 forge-00: created for AI Kingdoms VS-1 (READY).
- 2026-10-12 forge-00: plan review fixes (CONTRACTS v0.4-g2, D-024 to D-028): P0; ≤8-part Motor6D rigs instead of R15, regalia accessories, ahead of FL-0055
