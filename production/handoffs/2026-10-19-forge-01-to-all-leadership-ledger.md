# Handoff: FORGE-01 → FORGE-05 (cc FORGE-00, FORGE-03) · FL-0069 slice 1: leadership ledger and sampling · 2026-10-19

Stacked on #209 (SupportModel) on #208 (Arena Types / Caps / DuelModel).

## What I'm giving you
`LeadershipService` (G12.2): producers record ruler decisions as pre-authored moments, and the service samples the kingdom and each ruler every 30 s of match time into exactly the samples `SupportModel.score` reads.

## Done
- `src/shared/Arena/Ledger.luau` (pure): `record`, `level`, `offset`, `moments`. Conduct and valour are per-ruler levels (start 50, 0..100); the reputation act moves a kingdom offset (-20..20). Valour gained per rolling minute is capped (config `valourCapPerMinute`). An unknown act is refused, never invented; magnitude clamps 0..2 so a negative magnitude cannot flip a good act into a bad one.
- `src/server/Services/LeadershipService.luau`: `record(kingdom, userId?, act, magnitude?)`, `getMoments(kingdom, userId?, limit)`, `samples(kingdom, userId?)`, `sample()`, signal `acted`. Components: reputation (mean of `Support.reputationCategories` plus the act offset), happiness / stability (net of unrest pressure) / morale from the kingdom conditions, loyalty (mean of living citizens), conduct / valour from the ledger. Clock is `sim.time`; a new round resets everything.
- Config `Support.reputationCategories` (additive).

## Not done yet (rest of FL-0069)
Act producers (fed ratio, raids, objectives, rebuilds, overwork, conscription), citizen loyalty from memory events, key citizens per role, petitions and `Kingdom.FulfilPetition`, `inspect` additions. The G12.5 `LeadershipAct` bus event stays unfired until FORGE-05 declares it in `Contracts/GameEvents` (the service signal `acted` carries the same values).

## Evidence
- Specs `sim/Ledger` (12) and `sim/LeadershipService` (15). Mutation rows `mutations/FL-0069.py` (26): all caught on the final run (the one row that named a renamed test was re-checked by hand and fails the new spec). Full gate: see the PR.
- Headless only; no Studio.

## Next actions for the receiver
1. FORGE-05: declare `LeadershipAct` / `KeyCitizenChanged` in `Contracts/GameEvents` when convenient (G12.5).
