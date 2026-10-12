---
id: FL-0079
title: "ConversationService: thought bubbles, Converse/Choose, decision effects and memories (G13.3)"
track: build
owner: forge-01
status: READY
priority: P0
game: game-001
created: 2026-10-12
updated: 2026-10-12
depends_on: [FL-0078, FL-0080, FL-0083]
context: [games/game-001/design/living-kingdom.md, games/game-001/CONTRACTS.md, games/game-001/BRIEF.md]
estimate_h: 6
evidence: []
---

# "ConversationService: thought bubbles, Converse/Choose, decision effects and memories (G13.3)"

## Outcome
Citizens raise real requests and concerns. The ruler answers through 2–4 choices, and each choice visibly changes the kingdom (VS-1 row 9).

## Requirements
- `ConversationService` (G13.3):
  - builds the ContentQuery context from real state (vocabulary in `content/SPEC.md`; variables it cannot provide yet stay nil);
  - every 20 s, opens up to `Society.openRequests` thought bubbles per kingdom through `ContentQuery.eligibleScenarios`, then sends `thought` events.
- `Kingdom.Converse` and `Kingdom.Choose` (validated, rate-limited, own kingdom only).
- On choose, re-check eligibility, then apply `ContentQuery.decisionEffects`:
  - cost and resources through TreasuryService;
  - reputation through ReputationService, with the repeat multiplier;
  - loyalty through `loyaltyDelta`, with reach for speaker, family, friends, rivals and kingdom;
  - kingdom conditions;
  - consequences in VS-1: productivity boost or strike for the speaker or occupation, `unlock_scenario`, memory and cue;
  - a `reaction` event.
- Never parse strings at runtime. The content arrives pre-parsed.
- At least the three VS-1 DRAFT scenarios in the content library must work end to end.

## Validation
Lune specs:
- eligibility follows real state;
- the choice applies every effect exactly once (treasury txId);
- a repeated decision decays its gains;
- ineligible or forged `Choose` calls are rejected;
- follow-up scenarios unlock.

Studio: answer a hungry farmer and see food, loyalty and reputation move, plus the work boost or the strike.

## Completion criteria
- [ ] `bash roblox/scripts/check.sh` OVERALL PASS with the new specs
- [ ] Studio evidence (user playtest per games/game-001/STUDIO_PLAYTEST.md, BuildInfo sha + screenshots or video) before ACCEPTED

## Log
- 2026-10-12 forge-00: created for the production priorities update (D-030) (READY).
