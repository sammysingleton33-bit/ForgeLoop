---
id: FL-0102
title: DRAFT dialogue starter pack and variants for cinematic conversations (D-035, D-036)
track: design
owner: forge-06
status: READY
priority: P1
game: game-001
created: 2026-10-13
updated: 2026-10-13
depends_on: [FL-0083]
context: [games/game-001/CONTRACTS.md, games/game-001/design/living-kingdom.md, DECISIONS.md, games/game-001/content/SPEC.md]
estimate_h: 4
evidence: []
---

# DRAFT dialogue starter pack and variants for cinematic conversations (D-035, D-036)

## Outcome
A small, clearly labelled DRAFT starter pack of conversations written for the cinematic presentation lets the team test VS-1 row 9 and the cinematic flow, without counting as approved dialogue.

## Context
- D-035 (FORGE-06 rules), D-036, CONTRACTS G13.8 (Content), `content/SPEC.md`, `content/README.md`, FL-0095 (user review).

## Requirements
- At least 8 scenarios across common occupations, each with 2–4 answers that are real trade-offs across the six reputation categories; reactions in each tone; one follow-up chain.
- Short questions and reactions that read well in a speech bubble beside a portrait.
- Every row's `notes` start with `DRAFT`; nothing marked approved without the user's approval of those exact lines.
- Delivered as a PR from `forge/06-dialogue-*` in ForgeLoop, with a changelog and a review queue for the user.
- Emotion and gesture metadata in notes until FORGE-00 adds the SPEC columns.

## Validation
- Headless: `content.py validate` 0 errors, `content.py check` clean, `python3 -m pytest -q tools/tests` passing; lint warnings read and answered.
- User review of the workbook (FL-0095).

## Completion criteria
- [ ] Starter pack PR merged as DRAFT
- [ ] Review queue sent to the user

## Log
- 2026-10-13 forge-00: created for cinematic conversations (D-036, CONTRACTS G13.8). Can start now (DRAFT starter pack first).
