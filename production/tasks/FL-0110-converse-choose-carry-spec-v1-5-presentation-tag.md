---
id: FL-0110
title: Converse/Choose carry SPEC v1.5 presentation tags (G13.8 v0.4-g10)
track: build
owner: forge-01
status: SPECIFIED
priority: P2
game: game-001
created: 2026-10-13
updated: 2026-10-13
depends_on: [FL-0083, FL-0097]
evidence: []
---

# Converse/Choose carry SPEC v1.5 presentation tags (G13.8 v0.4-g10)

## Outcome
A conversation's question and reaction reach the client with their optional presentation tags (emotion, expression, gesture, delivery, urgency, bubble time, loyalty band), so the cinematic UI can style them. Question variants and loyalty-band reactions are chosen on the server.

## Context
- CONTRACTS G13.8 v0.4-g10 (#96), from FORGE-03's proposal on FL-0099.
- ContentQuery `questionFor`, `presentation` and `reactionFor` arrive with #96 (SPEC v1.5).
- Start after #96 and the B14 cinematic set (#108) are merged.

## Requirements
- The `Kingdom.Converse` result adds `presentation = { emotion?, expression?, gesture?, delivery?, urgency?, variantId? }`, and the question text comes from `questionFor` (the variant chosen on the server, filled).
- A successful `Kingdom.Choose` result adds `tone`, `emotion?`, `expression?`, `gesture?`, `delivery?`, `bubble_s?` and `band?`, from `reactionFor(responseId, loyalty)`, using the citizen's loyalty at the moment of choosing.
- All fields are optional. With no tags in the content, the payloads match today's apart from any new nil fields.
- No gameplay change.

## Validation
Automated: specs for an untagged scenario (no new fields) and a tagged fixture (every field present and an allowed enum value); high/low loyalty band selection; a question variant chosen by trait. `bash roblox/scripts/check.sh`.

## Completion criteria
- [ ] Fields present, with specs.
- [ ] Review verdict.

## Log
