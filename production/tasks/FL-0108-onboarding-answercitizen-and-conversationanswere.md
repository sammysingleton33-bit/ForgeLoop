---
id: FL-0108
title: Onboarding AnswerCitizen and ConversationAnswered on G9 CitizenAnswered (D-044 (3))
track: build
owner: forge-04
status: SPECIFIED
priority: P2
game: game-001
created: 2026-10-13
updated: 2026-10-13
depends_on: [FL-0107]
evidence: []
---

# Onboarding AnswerCitizen and ConversationAnswered on G9 CitizenAnswered (D-044 (3))

## Outcome
The AnswerCitizen onboarding step and the `ConversationAnswered` analytics event are driven by the server's G9 `CitizenAnswered` event instead of a client report or a direct call from ConversationService.

## Context
- D-044 (3) and (4); CONTRACTS G9 and G11 (v0.4-g9c).
- Depends on FL-0107. #64 currently expects ConversationService to call `AnalyticsService:event`; this task replaces that with a subscription.

## Requirements
- `Onboarding.luau` AnswerCitizen: `trigger = { bus = "CitizenAnswered" }`, with a Signals resolver that credits the answering player.
- Remove `CitizenAnswered` from `clientActions`, and remove the client `report("CitizenAnswered")` call. That call is FORGE-03/FORGE-01 code, so hand it off to its owner.
- `ConversationAnswered` is logged by a FORGE-04 server subscriber on the G9 event. ConversationService never calls AnalyticsService.
- `Subjects.missing` stays clean for both configs.

## Validation
Automated: specs for the step trigger and the analytics subscriber; `mutations.py` rows; `bash roblox/scripts/check.sh`. Studio: the onboarding AnswerCitizen step completes after a real answer.

## Completion criteria
- [ ] Both are wired to the G9 event, with specs.
- [ ] A review verdict on the PR.

## Log
