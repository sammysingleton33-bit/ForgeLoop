---
id: FL-0099
title: "Cinematic conversation UI: rising portrait, speech bubble, answers, consequence chips (G13.8)"
track: build
owner: forge-03
status: SPECIFIED
priority: P1
game: game-001
created: 2026-10-13
updated: 2026-10-13
depends_on: [FL-0088, FL-0097, FL-0098]
context: [games/game-001/CONTRACTS.md, games/game-001/design/living-kingdom.md, DECISIONS.md, games/game-001/content/SPEC.md]
estimate_h: 4
evidence: []
---

# Cinematic conversation UI: rising portrait, speech bubble, answers, consequence chips (G13.8)

## Outcome
Opening a conversation feels like turning to face one of your people: their portrait rises from the bottom, a speech bubble shows the request, the ruler picks one of 2–4 answers, and the reaction and consequences appear while the kingdom stays visible behind.

## Context
- D-036, CONTRACTS G13.8 (UI), G13.3; extends the FL-0088 ConversationController. Effect chips and risk chips as in FL-0088 (`choicePreview`, `choiceRisks`).

## Requirements
- Portrait ViewportFrame from `Kit.portrait` rises in about 0.35 s; speech bubble with the question; 2–4 answers with cost and risk chips; reaction text and consequence chips; then close.
- World stays visible: no full-screen cover, dim at most 20 %.
- Fire `opened(entityId, position)` and `closed(entityId)`; call `Kingdom.EndConversation` on close without a choice.
- Phone layout at 844×390 shows 4 answers without overlap; reduced-motion skips the rise animation.

## Validation
- Automated: CitizenUI/Conversation specs for open → choose → close and open → cancel → EndConversation.
- Render: Luau UI screenshots on PC and phone sizes, reviewed by eye.
- Studio (user, via FL-0101).

## Completion criteria
- [ ] Cinematic panel merged with specs
- [ ] Screenshots reviewed

## Log
- 2026-10-13 forge-00: created for cinematic conversations (D-036, CONTRACTS G13.8). First version after FL-0088 merges and FL-0097/FL-0098 interfaces exist; refine afterwards.
