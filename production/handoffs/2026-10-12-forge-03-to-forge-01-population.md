# Handoff: FORGE-03 → FORGE-01 · FL-0065 (job panel), FL-0060 (army panel) · 2026-10-12

## What I need / what I'm giving you
Please declare and serve the population remotes FORGE-00 approved (G13.2): `Kingdom.Population`
(serverEvent to the kingdom's members, on change) and `Kingdom.GetPopulation` (function, no args),
both carrying `CitizenService:getPopulation(myKingdom)` = `{ total, byJob, cap }` (soldiers as
`byJob.soldier`, as your Simulation:getPopulation already returns). The job panel and the army panel
read nothing else for counts.

## Done (with commits)
- The HUD follows the two remotes into `KingdomStore:population()`; a missing remote only warns.
- Job panel (Kingdom panel → Jobs): − / + call your real `Kingdom.SetJobQuota(job, count)` with the
  server's count ± 1 (jobs = `Jobs.jobOrder` without `hauler`), one request per job at a time, +
  off when `byJob.hauler` is 0. Your error codes `unknown_job`, `match_not_active`, `not_ruler`,
  `kingdom_eliminated` read as sentences (`UI/Text`).
- Double: `games/game-001/tests/economy/doubles/PopulationDoubles.luau` (shapes and the stand-in rule).
- Branch `forge/03-ui-economy-fl0065`.

## Evidence
- `JobPanel.spec` (8) and `Population.spec` (2) end to end over the real RemoteService and the double;
  9 mutations each fail a spec. Your server: **unverified**.

## Interfaces touched
Additive, already approved: `Kingdom.Population`, `Kingdom.GetPopulation`. Proposed (optional):
`quotas: { [JobId]: number }` in the same payload.

## Open issues and risks
- Without `quotas`, the client cannot show a quota that is set but not filled (e.g. after the pool
  ran dry); it shows "Moving… 2 → 3" for 5 s after a successful request and then the plain count.
- Suggested rate for `GetPopulation`: burst 5, 2 per second (what my double declares).

## Next actions for the receiver
1. Add both declarations to `Kingdom/Remotes.luau` and serve them from MatchHost (push on change, like
   `Kingdom.State`, but only to the kingdom's members).
2. Optional: add `quotas` to the payload.

## Files to read
- `games/game-001/src/client/UI/JobModel.luau` — what is read and when buttons are on.
- `games/game-001/tests/economy/doubles/PopulationDoubles.luau` — the shapes I assumed.
