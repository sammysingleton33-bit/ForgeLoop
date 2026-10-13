---
id: FL-0097
title: "Cinematic conversation server: Converse look/position, conversation hold, EndConversation (G13.8)"
track: build
owner: forge-01
status: SPECIFIED
priority: P1
game: game-001
created: 2026-10-13
updated: 2026-10-13
depends_on: [FL-0079]
context: [games/game-001/CONTRACTS.md, games/game-001/design/living-kingdom.md, DECISIONS.md, games/game-001/content/SPEC.md]
estimate_h: 3
evidence: []
---

# Cinematic conversation server: Converse look/position, conversation hold, EndConversation (G13.8)

## Outcome
When the ruler opens a conversation, the server tells the client who the citizen is, what they look like and where they stand, and keeps that citizen still and facing the ruler until the conversation ends. Closing the panel or finishing the reaction releases them.

## Context
- D-036, CONTRACTS G13.8 (Server), G13.3 (Converse/Choose), G13.2 (`CitizenLook`).
- Builds on FL-0079 ConversationService. `Society.luau` holds `conversationHoldSec` (PROVISIONAL 30).

## Requirements
- `Kingdom.Converse` result gains `look`, `job`, `position` (current), `kingdom` (additive).
- Hold: `intent = "talking"`, movement stopped, facing the ruler's camera direction; at most `Society.conversationHoldSec`.
- New function remote `Kingdom.EndConversation(entityId) -> boolean`: own kingdom, ruler only, rate-limited, idempotent.
- After `Kingdom.Choose`, release the hold once the reaction finishes (≤ 4 s).
- A citizen held by one ruler is not offered to a co-ruler at the same time (returns nil).

## Validation
- Automated: specs for hold start, timeout release, EndConversation release, Choose release, wrong-kingdom refusal, co-ruler refusal.
- Studio (user, via FL-0101): the citizen stops and turns while the panel is open.

## Completion criteria
- [ ] Converse fields added and spec'd
- [ ] Hold and three release paths spec'd
- [ ] `bash roblox/scripts/check.sh` OVERALL PASS

## Log
- 2026-10-13 forge-00: created for cinematic conversations (D-036, CONTRACTS G13.8). Start after FL-0079 merges; do not delay FL-0079/FL-0081.
