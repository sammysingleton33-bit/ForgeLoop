---
id: FL-0126
title: "Walls, gates and towers on territory lines (Build.PlaceLine), plus three neutral outposts that grant territory"
track: build
owner: forge-01
status: READY
priority: P1
game: game-001
created: 2026-10-18
updated: 2026-10-18
depends_on: [FL-0125]
evidence: []
---

# Walls, gates and towers on territory lines (Build.PlaceLine), plus three neutral outposts that grant territory

## Outcome
Rulers can fortify: draw a wall line along their territory, put a gate in it that their own units and citizens pass and enemies must break, and place towers that shoot. Three neutral outposts on the map can be captured for territory and Crown Points (VS-2 rows 4 and 6).

## Context
- BRIEF §4 VS-2 rows 4 and 6; CONTRACTS G13.5 says wall/gate are line structures refused on plots (v0.4-g9a); G13.9 phase 2 names `Build.PlaceLine`/`MoveLine`.
- Military already makes walls block armies and siege units hit buildings x4. The Kit already builds wall and gate pieces (FORGE-02).

## Requirements
- `Build.PlaceLine(type: "wall", from: Vector2, to: Vector2)` → `(ok, { buildingIds }?, reason?)`: snaps to a grid, splits into Kit segments, charges per segment once, all-or-nothing, inside own territory, respects reservedAreas and unit/ruler clearance (G13.9 rules). `Build.PlaceGate(segmentId)` replaces one segment with a gate. Write the G13.5 contract text in your handoff; FORGE-00 adds it.
- Gates: own kingdom's units and citizens path through; enemies treat it as a wall. Towers: shoot enemy units in range using the existing defensive-fire code.
- Outposts: three neutral capture points (FORGE-02 places them in `world/Layout.luau`; you consume `Layout.objectives`). Owning one extends territory by a radius and earns Crown Points per minute (config `Objectives.luau`).
- RulerAI: governors build a wall ring and a gate after Keep level 2 when aggression ≥ 0.5, and march on outposts.
- Every new remote validated server-side and rate-limited; specs for refusals (outside territory, no money, on a field, crossing another kingdom).

- **Siege viability (added 2026-10-18, FORGE-07's #187 numbers):** in a 2,750 s AI-only match, three wars and 532 kills felled no kingdom. War must be able to decide something. Tune keep HP, siege (Ram) output and the governor's assault logic in config so that:
  - a determined assault (a full army of 15 plus a ram, focused) can take an undefended keep in about 3–5 minutes;
  - a defended, walled keep holds unless the attacker clearly outnumbers it.

  Prove it with a headless probe: at least one kingdom falls in a typical AI-only match, without a snowball before Conflict. Record the numbers in the PR.

## Validation
Automated specs for PlaceLine/PlaceGate/outposts and a mutation row per refusal. Studio: B21 rows (draw a wall, open a gate, capture an outpost).

## Completion criteria
- [ ] PR merged after review (FORGE-05 gate, FORGE-07 review).
- [ ] Studio evidence (owner's local Studio session).

## Log
- 2026-10-18 FORGE-00: created for Operation Crownfall (owner directive 2026-10-18, D-053).
