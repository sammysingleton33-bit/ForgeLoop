---
id: FL-0107
title: G9 CitizenAnswered event from ConversationService (D-044 (3))
track: build
owner: forge-01
status: REVIEW
priority: P1
game: game-001
created: 2026-10-13
updated: 2026-10-13
depends_on: [FL-0079]
evidence:
  - "check.sh OVERALL PASS on main 5309b48e + branch: game-001 1154/0, ConversationService spec 27/0, selene 0/0; mutations 5/5 caught (run before the main merge, which only added the contract row)"
---

# G9 CitizenAnswered event from ConversationService (D-044 (3))

## Outcome
When a ruler's answer to a citizen is accepted on the server, a G9 `CitizenAnswered` event fires once. Onboarding and analytics can then count an answer without trusting a client report.

## Context
- D-044 (3); CONTRACTS G9 row `CitizenAnswered` (v0.4-g9c).
- Depends on #77 (FL-0079 ConversationService) being merged. Start after it, and after the #77 N3 fix.
- FORGE-04 consumes the event in FL-0108.

## Requirements
- Add `CitizenAnswered` to `Contracts/GameEvents`. This is additive; FORGE-05 reviews it as a shared-contract change.
- ConversationService fires `(player, KingdomId, citizenId, decisionId, secondsOpen?)` exactly once per accepted `Kingdom.Choose`, after effects are applied.
  - It never fires on a refused choice, on a repeat, or on a closed conversation.
  - `secondsOpen` is the server time since the request's bubble appeared. Use nil if that time is unknown.
- Payloads stay server-only (G9). No client remote changes.

## Validation
Automated: a spec shows that an accepted Choose fires once with the right payload, and that refused, duplicate and expired choices fire nothing. Run `bash roblox/scripts/check.sh`.

## Completion criteria
- [ ] The event is in GameEvents and fired by ConversationService, with a spec.
- [ ] A FORGE-07 (or D-040 fallback) verdict on the PR.

## Log
- 2026-10-13 forge-01: SPECIFIED → READY. Contract row landed on main (#109); moving on.
- 2026-10-13 forge-01: READY → BUILDING. Contract row landed on main (#109); moving on.
- 2026-10-13 forge-01: BUILDING → TESTING. Contract row landed on main (#109); moving on.
- 2026-10-13 forge-01: TESTING → REVIEW. ConversationService fires G9 CitizenAnswered once per accepted Kingdom.Choose, after effects; secondsOpen from the bubble; nothing on refused/unaffordable/expired. PR on forge/01-gameplay-fl0107.
