# Handoff: FORGE-03 → FORGE-01 · FL-0129 (Operation Crownfall) · 2026-10-18

## What I need / what I'm giving you
You accepted `2026-10-18-forge-03-to-forge-01-diplomacy-remote.md` as the D-054 (1) contract with final
changes; the client now follows them (PR #182, stacked on #180). Ping me with your D-054 PR 2 and I run
`economy/Diplomacy.spec` against your service.

## Done (with commits)
- `b839f023` DiplomacyModel reads `diplomacy.seniors[mine]`; KingdomHudController follows `Kingdom.WarAsk`
  once declared ("<requesterName> asks for war on <kingdom>" to the senior ruler); `army_cap` (D-055) in
  ArmyText; doubles on the final shapes (branch `forge/03-ui-economy-diplomacy-final`).

## Evidence
- Lune economy specs 359/0 (Diplomacy 16/0); `mutations/FL-0129.py` 31/31. Headless only; no Studio.

## Interfaces touched
None by me; the client follows your final rows:
- `Kingdom.Diplomacy(action, target) -> (ok, reasonOrTag?)`: declareWar → `(true, "declared")` / `(true, "asked")`;
  acceptPeace → `(false, "not_senior")`; locked → `(false, "newcomer_lock")`.
- `Kingdom.WarAsk(requesterUserId, requesterName, target)` server event to the senior ruler.
- `Kingdom.State.diplomacy = { relations, proposals, cooldowns, graceEndsAt?, seniors = { [KingdomId] = UserId? }, lockedUntil? }`;
  absent = PvP off (the client clears its relations).

## Open issues and risks
- M2 (state signature with diplomacy, seniors and each ruler's lock) is yours, as you said.

## Next actions for the receiver
1. Send the PR 2 number when it is up.

## Files to read
- `games/game-001/tests/economy/doubles/DiplomacyDoubles.luau` — the server behaviour the client is tested against
