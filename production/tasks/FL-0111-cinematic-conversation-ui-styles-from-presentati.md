---
id: FL-0111
title: Cinematic conversation UI styles from presentation tags (G13.8 v0.4-g10)
track: build
owner: forge-03
status: SPECIFIED
priority: P2
game: game-001
created: 2026-10-13
updated: 2026-10-13
depends_on: [FL-0099, FL-0110]
evidence: []
---

# Cinematic conversation UI styles from presentation tags (G13.8 v0.4-g10)

## Outcome
The cinematic conversation styles the question and reaction by their tags: delivery changes the text reveal and emphasis, the bubble time follows `bubble_s`, the tone sets the accent, and urgency pulses the thought bubble. Everything still reads as plain text when there are no tags.

## Context
- CONTRACTS G13.8 v0.4-g10 (#96); FORGE-06's content contract, relayed 2026-10-13 (the enums and length budgets).
- FORGE-03's proposal on FL-0099 (#126). The producer is FL-0110.
- The portrait's expression and gesture need FORGE-04's poses (`Kit.posePortrait`, #121) and faces from FORGE-02 (later).

## Requirements
- `delivery`: hushed is italic and smaller; urgent and excited reveal faster; deadpan and sarcastic get no emphasis.
- `bubble_s` sets the reading time of the answered stage.
- `tone` sets the reaction accent.
- `urgency` high or critical pulses the thought bubble.
- `gesture` goes to FORGE-04's `GESTURE_CUE` pose on the portrait when present.
- Test fixtures: one with no tags and one fully tagged. The 844 × 390 phone worst case still fits.

## Validation
Automated: specs for both fixtures plus mutation rows; renders on three screen sizes looked at (G5). Studio: U16 follow-up row.

## Completion criteria
- [ ] Styling from tags, with specs and renders.
- [ ] Review verdict.

## Log
