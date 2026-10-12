---
id: FL-0088
title: Conversation panel and citizen card v2 (G13.2, G13.3)
track: build
owner: forge-03
status: READY
priority: P0
game: game-001
created: 2026-10-12
updated: 2026-10-12
depends_on: [FL-0079]
context: [games/game-001/design/living-kingdom.md, games/game-001/CONTRACTS.md, games/game-001/BRIEF.md, games/game-001/content/SPEC.md]
estimate_h: 6
evidence: []
---

# Conversation panel and citizen card v2 (G13.2, G13.3)

## Outcome
Selecting a citizen shows who they are (traits, loyalty, family, friends, memories). When they have something to say, a conversation opens with their question and 2–4 answers. The answer shows their reaction and what changed (VS-1 rows 4b and 9).

## Requirements
- Citizen card v2 (extends FL-0065) shows the `CitizenView` fields.
- `ConversationController`:
  - shows the question and options from `Kingdom.Converse`;
  - sends `Kingdom.Choose`;
  - shows the reaction text and effect chips (resources, loyalty, reputation).
- Shows only the text from the content library. Never hard-code dialogue.
- Long text wraps; phone first.

## Validation
UI specs for 2, 3 and 4 options, long text and the effect chips. Prototype screenshots. Studio: one full conversation.

## Completion criteria
- [ ] Studio evidence (user playtest per games/game-001/STUDIO_PLAYTEST.md, BuildInfo sha + screenshots or video) before ACCEPTED

## Log
- 2026-10-12 forge-00: created for the production priorities update (D-030) (READY).
