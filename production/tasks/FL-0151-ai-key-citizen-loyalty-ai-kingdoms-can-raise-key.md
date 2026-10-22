---
id: FL-0151
title: "AI key-citizen loyalty: AI kingdoms can raise key citizens to pledged (D-062)"
track: build
owner: forge-01
status: READY
priority: P1
game: game-001
created: 2026-10-22
updated: 2026-10-22
depends_on: []
evidence: []
---

# AI key-citizen loyalty: AI kingdoms can raise key citizens to pledged (D-062)

## Outcome
An AI kingdom that rules well ends up with loyal key citizens, so its champion can earn support perks in the Crown Arena, as a human's can.

## Context
- D-062. FORGE-01 measured this on the FL-0149 stack (seeds 11-13): AI key citizens peak at loyalty 54, while a perk needs 80 (95 for the strong one), so AI kingdoms get 0 perks each. ConversationService skips kingdoms with no ruler, and nothing else raises AI loyalty.
- AI coverage of roles is already good: 3.44 of 4 roles per AI kingdom by Endgame.

## Requirements
- An AI-only path to loyalty. Human rules stay unchanged. FORGE-01 picks the mechanism: a scripted AI answer to petitions or conversations, or a prosperity drift. Keep it deterministic per seed.
- Target: at the arena, a thriving AI kingdom has about 1 or 2 pledged key citizens and a struggling one has 0. Put the rate in config so it can serve as a difficulty knob.
- Additive contract changes only.

## Validation
- Specs for the mechanism and its determinism.
- FullMatch over 8 seeds: pledged key citizens per AI kingdom at the arena, and perks offered.
- A full FairnessGate run stays PASS.
- Owner playtest tunes the target. Unverified until then.

## Completion criteria
- [ ] Merged after FORGE-07's review, with the 8-seed table in the PR.
- [ ] The FairnessGate stays PASS.

## Log
- 2026-10-22 forge-00: filed from D-062. Comes after FL-0149 and the arena PR (qualify), before FL-0150.
- 2026-10-22 forge-00: SPECIFIED → READY. Filed from D-062
