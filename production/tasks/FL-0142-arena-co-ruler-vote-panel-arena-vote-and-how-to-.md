---
id: FL-0142
title: Arena co-ruler vote panel (Arena.Vote) and How to play text
track: build
owner: forge-03
status: REVIEW
priority: P1
game: game-001
created: 2026-10-19
updated: 2026-10-19
depends_on: []
evidence:
  - economy/ 548/0; ArenaVote 15/0; FL-0142-vote.py 21/21; FL-0138-howto.py 36/36; renders arena-vote* phone-se+desktop opened; Studio U32 unverified
---

# Arena co-ruler vote panel (Arena.Vote) and How to play text

## Outcome
When a kingdom with two or more seated rulers qualifies, its rulers vote for their champion in a small panel. How to play describes the vote as it works.

## Context
- No client code sends `Arena.Vote` on main (B22, e8ea78c). The vote stage waits out its 10 s, and leadership picks the champion.
- `HowToPlayModel.luau:136` says co-rulers vote. Solo play never shows the gap.
- `Arena.Vote(candidate) -> boolean` (G12.4). The candidates come from `ArenaState`, through `DuelController:getState()` and `stateChanged`.

## Requirements
- A vote panel in the `vote` stage, for seated rulers of a qualifying kingdom only. Show the candidates and a countdown, send `Arena.Vote`, and show the result.
- Read the state from DuelController; make no new remote calls.
- Make the How to play arena card text match.
- Specs; phone and desktop layouts.

## Validation
- Automated: `check.sh` green.
- Studio (user): two clients in one kingdom reach the arena. Both see the panel, a vote picks the champion, and the panel closes at the loadout.

## Completion criteria
- [ ] PR into main, reviewed by FORGE-07, gated by FORGE-05.

## Log
- 2026-10-19 FORGE-00: created from the v0.4-g11k pass. P1, B23.
- 2026-10-19 forge-03: READY → BUILDING. Vote panel against a proposed additive ArenaState.vote field (asked FORGE-01/FORGE-00: vote-stage state has no candidates on main); dark until served
- 2026-10-19 forge-03: BUILDING → REVIEW. Vote panel built; dark until FORGE-01 adds ArenaState.vote (handoff 2026-10-19-forge-03-to-forge-01-arena-vote)
