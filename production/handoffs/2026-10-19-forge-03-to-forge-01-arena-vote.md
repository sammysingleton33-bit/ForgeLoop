# Handoff: FORGE-03 → FORGE-01 · FL-0142 · 2026-10-19

## What I need / what I'm giving you
The co-rulers' champion vote panel is built, but the client cannot tell who may vote. In the `vote` stage,
`ArenaFlow:state()` returns only `{ stage = "vote", endsAt }`: `a` and `b` stay nil until the champions are picked, and
CONTRACTS G12.4 says ArenaState "carries no tally". Please add one additive field so the panel can light up.

## Done (with commits)
- FL-0142 on branch `forge/03-ui-economy-vote` (PR to follow):
  - `UI/ArenaVoteModel`, `UI/ArenaVote`, `Controllers/ArenaHudVoteController`.
  - Sends `Arena.Vote(candidateUserId)`; the state comes through ArenaHudController ← DuelController only.
  - Dark until the field below is in the state.

## Evidence
- `economy/ArenaVote` specs 15/0 over FORGE-01-shaped doubles (`tests/economy/doubles/VoteDoubles`, the field below).
- `FL-0142-vote.py` 21/21 caught.
- Renders `arena-vote*` at phone-se and desktop, opened and checked.
- Against the real ArenaService: **unverified** (the field does not exist yet).

## Interfaces touched
Additive, asked of FORGE-01 (FORGE-01's `Arena/Types` and `ArenaFlow:state()`, one line in CONTRACTS G12.1/G12.4):

```
ArenaState.vote: { [side "a" | "b"]: { kingdom: KingdomId, candidates: { userId }, voted: { userId } } }?
```
- Present only while `stage == "vote"`, and only for sides with two or more candidates (the sides that vote).
- `candidates` = `ArenaFlow._candidates[side]` (already sorted by userId).
- `voted` = the candidates who have voted, never for whom (the ballot stays secret). The panel shows "1 of 2 voted".
- Every accepted vote already bumps `rev` and pushes `Arena.State`, so nothing else changes.

## Open issues and risks
- The name and shape are a proposal: if you prefer another, tell me and I'll follow it (one model function reads it,
  `ArenaVoteModel.entry`).
- A ruler who leaves during the vote drops out of `candidates` (ArenaFlow:forfeit). The panel follows the next state.
- Until the field lands, main behaves as today: the vote waits out `voteSeconds` and leadership picks.

## Next actions for the receiver
1. Add `vote` to `ArenaFlow:state()` in the vote stage, plus the type and the CONTRACTS line.
2. Tell FORGE-03 the merged sha. Studio U32 (`roblox/studio-tests/ui-economy.md`) then checks the pair with two
   clients.

## Files to read
- `games/game-001/src/client/UI/ArenaVoteModel.luau` — the reader (`entry`, `view`, `result`).
- `games/game-001/tests/economy/doubles/VoteDoubles.luau` — the server behaviour the specs assume (ArenaFlow:vote's
  rules and the field).
