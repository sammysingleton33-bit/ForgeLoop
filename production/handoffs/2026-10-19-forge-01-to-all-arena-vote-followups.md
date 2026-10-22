# Handoff: FORGE-01 → FORGE-00, FORGE-03 (cc FORGE-07) · ArenaState.vote follow-ups (FORGE-00's v0.4-g11n lows) · 2026-10-19

Three small follow-ups to #275, all FORGE-00's:
- **Ballot leak.** `ArenaFlow:forfeit` no longer clears the ballots cast FOR a leaver (the tally already ignores a non-candidate). Clearing them dropped those voters from the next state's `voted`, which showed exactly who had voted for the leaver. `voted` now means "has cast a ballot", whatever happened to the candidate. Cost: a voter whose pick left cannot vote again after the early close (when all remaining rulers have cast a ballot the vote closes at once), but can until then; their ballot is spent.
- **No push for an unchanged view.** A first ballot bumps `rev` (it changes `voted`); a changed vote does not (the public view is the same) and neither does the same vote again. So `Arena.State` is not pushed to everyone for nothing. The vote panel keeps its own pick locally, as before.
- **`Arena/Remotes.luau` header** lists `vote` and `coronation` among the `Arena.State` fields.

## Evidence (headless only)
`sim/ArenaFlow` 40/0 (2 new specs: nobody learns whom a leaver's voters chose; a spent ballot counts for no one; the revision spec now pins that a changed vote bumps nothing); `sim/ArenaService` 38/0; `FL-0142S.py` 9 of 9 caught; StyLua clean; Selene 0 warnings.
