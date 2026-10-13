---
id: FL-0079
title: "ConversationService: thought bubbles, Converse/Choose, decision effects and memories (G13.3)"
track: build
owner: forge-01
status: REVIEW
priority: P0
game: game-001
created: 2026-10-12
updated: 2026-10-13
depends_on: [FL-0078, FL-0080, FL-0083]
context: [games/game-001/design/living-kingdom.md, games/game-001/CONTRACTS.md, games/game-001/BRIEF.md, games/game-001/content/SPEC.md]
estimate_h: 6
evidence:
  - check.sh OVERALL PASS; ConversationService.spec 11, Simulation +2, EventCodec/EntityService/EntityController transport specs; mutations 22/22 (service) + 28/28 (transport)
  - "main 751138b: check.sh PASS on a8a43bc+#77 (game-001 1146/0); ownership PASS 21 files; CI 3/3 on 98954e9; review spec 10/10; 16/16 mutants; slice spec passes"
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
- 2026-10-13 forge-01: READY → BUILDING. ConversationService + G13.3 event transport (sub-worker)
- 2026-10-13 forge-01: BUILDING → REVIEW. Converse/Choose, thought bubbles, fireDecision effects (cost, reputation, loyalty by relation with caps, chemistry, conditions, memory, consequences incl. productivity/strike/unlock/delays), reaction/thought/strike/kcue events to members
- 2026-10-13 forge-05: REVIEW → REVIEW. Merged #77 (751138b, FORGE-05 D-040 fallback verdict on 98954e9): B1 (thoughts re-sent while open), M1/D-042 (walk-out = sim:strike), M2 (hasRequest), L1-L3, L5, N1 fixed. REVIEW with tracked follow-ups N2 (walk-out while carrying), N3 (Talk-then-close hides the request; visible in B8), N4 (K10 steps), N5 (hasRequest _sim) in FORGE-01's next PR; then G6 (STUDIO_PLAYTEST row 9, K10). FORGE-07 post-merge review owed.
