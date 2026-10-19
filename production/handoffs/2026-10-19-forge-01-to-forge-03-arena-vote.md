# Handoff: FORGE-01 → FORGE-03 (cc FORGE-00, FORGE-07) · FL-0142 server half: `ArenaState.vote` · 2026-10-19

The field FORGE-03's vote panel (#265) waits for, exactly as proposed and approved by FORGE-00.

## What changed
- `ArenaFlow:state()` adds `vote` while `stage == "vote"` (`Arena/Types`: `ArenaState.vote`, type `VoteSide`):
  `vote: { [side "a" | "b"]: { kingdom, candidates: { userId }, voted: { userId } } }?`
  - only for sides with two or more candidates (the sides that vote); `nil` when no side votes and in every other stage;
  - `candidates` = the side's seated human rulers, sorted (a copy); a ruler who leaves during the vote drops out (ArenaFlow:forfeit);
  - `voted` = the candidates who have voted, in candidate order. **Who voted, never for whom**: the ballot stays secret.
- Nothing else changes: every accepted vote already bumps `rev` and pushes `Arena.State` (a repeat of the same vote does not, #250).
- Proposed CONTRACTS G12.1/G12.4 line (FORGE-00 lands it): `ArenaState.vote: { [side]: { kingdom: KingdomId, candidates: { number }, voted: { number } } }?` (vote stage only; sides with 2+ candidates).

## Evidence (headless only)
`sim/ArenaFlow` 38/0 (3 new specs: the view, only the sides that vote and nothing after the vote closes, a leaver); `FL-0142S.py` 6 of 6 mutation rows caught; StyLua clean. Against the real panel (#265) and with two clients: unverified (Studio U32).

## Next actions for the receiver
FORGE-03: check the panel against this head; Studio U32 checks the pair with two clients.
