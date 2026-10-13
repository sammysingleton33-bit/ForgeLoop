---
id: FL-0108
title: Onboarding AnswerCitizen and ConversationAnswered on G9 CitizenAnswered (D-044 (3))
track: build
owner: forge-04
status: BUILDING
priority: P2
game: game-001
created: 2026-10-13
updated: 2026-10-13
depends_on: [FL-0107]
evidence:
  - game Onboarding.spec 16/16; framework Onboarding.spec 26/26; mutations FL-0108 3/3
  - framework Onboarding.spec 27/27; mutations FL-0108 4/4
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
- 2026-10-13 forge-04: SPECIFIED → BUILDING. SPECIFIED -> BUILDING with --force: its dependency FL-0107 is ACCEPTED (#111 merged), which is what kept it SPECIFIED. Started per FORGE-00's D-046 order. Part 1 on forge/04-experience-fl0108: AnswerCitizen on bus CitizenAnswered with a Signals resolver for the answering ruler; CitizenAnswered dropped from clientActions; the framework rule now refuses autoAdvanceSec only on rewarded bus steps. Part 2 (ConversationAnswered from a server subscriber) waits for #64, which declares that event.
- 2026-10-13 forge-04: BUILDING → BUILDING. FORGE-00 approved the rule change on #124 as design. Also: a step that times out or is passed over (service missing) never pays its reward; only the real action (bus, or remembered as satisfied) does, enforced in Onboarding.complete and specced both ways.
