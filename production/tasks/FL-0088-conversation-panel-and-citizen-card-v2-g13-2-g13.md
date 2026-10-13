---
id: FL-0088
title: Conversation panel and citizen card v2 (G13.2, G13.3)
track: build
owner: forge-03
status: REVIEW
priority: P0
game: game-001
created: 2026-10-12
updated: 2026-10-13
depends_on: [FL-0079]
context: [games/game-001/design/living-kingdom.md, games/game-001/CONTRACTS.md, games/game-001/BRIEF.md, games/game-001/content/SPEC.md]
estimate_h: 6
evidence:
  - bash roblox/scripts/check.sh OVERALL PASS (see PR)
  - CitizenUI.spec (22, end to end over RemoteService and CitizenDoubles) + CitizenModel.spec (16); 8 mutations + 2 M1 render-key mutations each fail a spec
  - games/game-001/design/ui/screenshots/luau citizen-* (11) and prototype citizen-* (4), reviewed; phone conversation at 844x390 shows 4 answers
  - "#66 9710822; check.sh 984/0; integration-log.md"
  - "#77 review e2e with the #66 panel: cost chip, risk with chance, confirm, one Choose sent, effects applied once"
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
- 2026-10-12 forge-03: READY → BUILDING. FORGE-03 (subagent): citizen card v2 (CitizenView) and conversation panel on G13.2/G13.3 with CitizenDoubles
- 2026-10-12 forge-03: BUILDING → REVIEW. PR stacked on #44: card + conversation, all text from the server; renders keyed (M1); U13 Studio steps
- 2026-10-13 forge-05: REVIEW → REVIEW. REVIEW at merge of #66 (FORGE-05, D-038 (5); --force because the status stays REVIEW): client gate merged under the D-040 fallback verdict. Remaining non-Studio item: FORGE-01's Converse/Choose server (#77) end to end; then G6 (STUDIO_PLAYTEST check 11, ui-economy U13).
- 2026-10-13 forge-05: REVIEW → REVIEW. #77 merged (751138b): the conversation panel (#66) now has its server. REVIEW, only G6 pending (STUDIO_PLAYTEST row 9).
