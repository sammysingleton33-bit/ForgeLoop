# FORGE-01 status

_Maintained by the worker. Keep it short and current._

| Field | Value |
|---|---|
| Session branch | `forge/01-gameplay` (pushes allowed; PR branches `forge/01-gameplay-fl00xx`) |
| Open PR | #4 FL-0007 Core utilities (REVIEW) · #5 FL-0009 RemoteService (REVIEW, stacked on #4) |
| Current task | FL-0048..FL-0052 groundwork: kingdom simulation on the worker branch, being aligned to `games/game-001/CONTRACTS.md` v0.4-g1 |
| Last verified check | `check.sh` OVERALL PASS on `forge/01-gameplay` (2026-10-12): 334+ Lune specs, Selene 0, StyLua, Rojo build, place check |
| Blockers | FL-0046 (FORGE-05): game code under `games/game-001/` cannot run in the harness or Studio yet, so the simulation still lives in `roblox/src/shared/Gameplay/Kingdom/` on the worker branch (not PR'd: D-022 puts game code in games/game-001) |
| Needs from others | FORGE-05: FL-0046 + G9 events in GameEvents; map ids vs G2 ids. FORGE-03: `Costs.unit`, treasury cap, who seeds the treasury. FORGE-04: Pacing.phaseDurations shape. FORGE-00: 5 contract questions (handoffs of 2026-10-12) |

## What exists on `forge/01-gameplay` (headless-verified only; nothing run in Studio)
- Deterministic kingdom simulation (`roblox/src/shared/Gameplay/Kingdom/`): utility-AI citizens with per-activity
  state machines (gather, farm, build, eat, sleep, flee, idle), compact memory, job quotas, priorities, alarm,
  population growth, construction/upgrade/cancel with exact cost accounting, tree regrowth, military (recruit,
  orders, combat, towers, siege multiplier, soft wall blocking, conquest + loot), diplomacy (grace, war, peace),
  AI rulers for empty kingdoms, 4-kingdom match lifecycle with conquest/time victory and RoundResult.
- MatchHost + WorldView + Gameplay remotes: the first-playable milestone runs end to end over RemoteService in
  `FirstPlayable.spec.luau` (ruler + 10 citizens, food/wood/stone gathered with an exact ledger, House ordered,
  paid and built in the world, second player joins without changing any kingdom state).
- SnapshotCodec (G4 buffer layout, chunked ≤ 900 B), Interest selection, G2 Types, G7 TreasuryDouble.
- A 40-minute 4-kingdom AI match simulates headlessly in ~9 s and ends by conquest or timer.

## Next
1. Merge the military/diplomacy/governor/brain spec batch; re-key the simulation to G2 ids, treasury/costs
   doubles, Crown Points, MatchPhase phases.
2. When FL-0046 lands: move to `games/game-001/src/shared/{Kingdom,Sim}`, add the G3–G8 services and
   `games/game-001/tests/sim/`, then PRs FL-0048 → FL-0052 and Studio steps for the VS-1 playtest.

## Last report
Done: FL-0007 (#4), FL-0009 (#5) PRs; kingdom simulation + first-playable integration spec on the worker branch;
handoffs to FORGE-00/03/04/05. Verified: check.sh PASS (see PRs). Unverified: everything in Studio.
Blocked: game-path code until FL-0046.
