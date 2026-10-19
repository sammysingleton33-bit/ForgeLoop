---
id: FL-0072
title: Crown Arena venue, crowd figures, armour and weapon sets (Kit)
track: asset
owner: forge-02
status: READY
priority: P2
game: game-001
created: 2026-10-12
updated: 2026-10-12
depends_on: []
context: [games/game-001/design/crown-arena.md, games/game-001/CONTRACTS.md, games/game-001/BRIEF.md]
estimate_h: 16
evidence: []
---

# Crown Arena venue, crowd figures, armour and weapon sets (Kit)

## Outcome
The Crown Arena exists as a colourful, readable venue at the neutral map centre, visible all match, with two stands that fill with kingdom-coloured crowd figures; key citizens are recognisable by their role props, and rulers wear distinct armour and weapon sets (design §5, §7).

## Context
D-029; design §5, §7; CONTRACTS G12.6 (Kit additions, `Layout.arena`), G10, D-019 visual gate, D-026 primitive Parts. **VS-1 asset tasks come first;** this is slack-time work.

## Requirements
- `Kit.arena()` (stands with `StandA`/`StandB` seat attachments, royal boxes, gate, duel ring), `Kit.crowdFigure(color, role?)` (≤ 4 parts, client-only), `Kit.armour(armour, color)`, `Kit.weapon(weapon)`; primitives only, no yields.
- `Layout.arena = { cframe, duelRadius, spawnA, spawnB }` at the map centre, inside ±4,000 studs.
- Role props: hammer (blacksmith), satchel (healer), helmet plume (captain), basket (provisioner), staff (elder), scales (merchant).
- Part budget: arena ≤ 1,500 parts; crowd figure ≤ 4 parts.

## Validation
Lune specs for Kit part counts and attachments. Renders or Studio screenshots of the arena from the ruler camera and from the stands, scored per D-019; readable at gameplay distance on a phone screenshot.

## Completion criteria
- [ ] Visual review scored per D-019 (screenshots committed as small previews)

## Log
- 2026-10-12 forge-00: created for the Crown Arena (D-029, VS-2) (READY).
- 2026-10-19 forge-02: branch forge/02-blender-fl0072-arena pushed (no PR): Kit.arena, crowdFigure, armour, weapon, Layout.arena, WorldService placement; headless gates green (check.sh exit 0); D-019 two rounds done, still NEEDS-WORK on crowd variation, key-citizen props, light armour and mace (see art/reviews/kit-architecture.md and the FL-0072 handoff); status unchanged.
