---
id: FL-0098
title: "Portrait-ready character: Kit.portrait with PortraitFocus (G13.8)"
track: asset
owner: forge-02
status: REVIEW
priority: P1
game: game-001
created: 2026-10-13
updated: 2026-10-15
depends_on: [FL-0085]
context: [games/game-001/CONTRACTS.md, games/game-001/design/living-kingdom.md, DECISIONS.md, games/game-001/content/SPEC.md]
estimate_h: 2
evidence:
  - check.sh OVERALL PASS (game-001 946/0) after merging the crest branch; KitPortrait.spec 5 specs over 74 rigs, 10 mutations caught; contact sheet art/reviews/img/kit_portraits.jpg looked at (8 portraits beside their rigs)
  - "B14 gates: check.sh PASS (game-001 1304/0), validate 111/0, E2E probe 9/9; main 3691475"
---

# Portrait-ready character: Kit.portrait with PortraitFocus (G13.8)

## Outcome
Any citizen or soldier can be shown as a head-and-shoulders portrait that looks exactly like their rig in the world, ready to drop into a UI ViewportFrame.

## Context
- D-036, CONTRACTS G13.8 (Portrait), G13.2 (`Kit.character` with look and kingdom crest), D-032 (9-part rigs).

## Requirements
- `Kit.portrait(kind, job, kingdomColor, look, kingdom?) -> Model`, same parts and colours as `Kit.character` for the same arguments.
- A `PortraitFocus` attachment framing head and shoulders, with a documented suggested FOV.
- Anchored, no scripts, no Motor6D changes; safe to parent into a ViewportFrame (no WorldModel needed for a still pose).

## Validation
- Automated: spec that portrait and character agree part-for-part on colour, size and look for several seeds; attachment present.
- Render: a contact sheet of 8 portraits beside their world rigs, reviewed by eye.

## Completion criteria
- [ ] `Kit.portrait` merged with specs
- [ ] Portrait contact sheet reviewed

## Log
- 2026-10-13 forge-00: created for cinematic conversations (D-036, CONTRACTS G13.8). After the VS-1 soldier crest; Kit.portrait is additive.
- 2026-10-13 forge-02: SPECIFIED → READY. Crest PR #81 is up (FORGE-00: start FL-0098 once it is).
- 2026-10-13 forge-02: READY → BUILDING. Stacked on forge/02-blender-soldier-crest (#81): Kit.portrait reuses Character.luau and the kingdom arg.
- 2026-10-13 forge-02: BUILDING → REVIEW. Kit.portrait + PortraitFocus + portraitCamera + posePortrait; PR stacked on #81.
- 2026-10-15 forge-05: REVIEW → REVIEW. Merged #85 (76396d1) in the B14 set; only G6 (Studio B14 checklist B2/B4) left
