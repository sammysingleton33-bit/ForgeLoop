# Handoff: forge-01 → forge-00 · AI Kingdoms ownership + tasks · 2026-10-12

## What I need / what I'm giving you
The user has directed FORGE-01 (2026-10-12) to build **AI Kingdoms**: four competing kingdoms, up to four
human rulers each, AI citizens, 30–45 min matches. It supersedes the jungle-survival game for FORGE-01.
I need explicit ownership of new kingdom-specific paths before I create files in them, plus a DECISIONS
entry and task files so the work is tracked.

## Ownership requested for FORGE-01 (add to the FORGE-01 row in `docs/workflows/team.md`)
| Path | Purpose |
|---|---|
| `roblox/src/server/Services/{Kingdom,Citizen,Match,Army,Construction,Territory,Diplomacy}*` | server hosts for the simulation (tick loop, commands, world view) |
| `roblox/src/client/Controllers/{Kingdom,Ruler,Army}*` | client state for kingdom snapshots and ruler commands (screens stay FORGE-03) |
| `games/*/config/{Kingdoms,Buildings,Units,Citizens,Match}.luau` | gameplay data per game (same rule as `Rounds`/`Spawns`/`Hazards`/`Combat`) |

Already owned and used without a request: `roblox/src/shared/Gameplay/` (pure simulation lives in
`shared/Gameplay/Kingdom/`; remotes in `shared/Gameplay/Remotes.luau`), `roblox/src/shared/Core/`,
`roblox/tests/unit/{core,gameplay}/`, `roblox/studio-tests/gameplay.md`, Remote/Round/Spawn/Combat/Data/Player services.

Until you answer I build only inside owned paths; the server/client hosts stay unpushed to any PR.

## Proposed decisions / tasks (yours to accept, change or reject)
1. DECISIONS: Game #1 = AI Kingdoms (user directive to FORGE-01, 2026-10-12). Kingdom match state is
   in-memory per server; permanent progression only through DataService namespaces (`game`), never mixed.
2. New FORGE-01 tasks (one PR each, D-013): Kingdom simulation core (resources, buildings, citizens AI,
   job board) · first playable milestone (ruler + ~10 citizens + build order + second player join) ·
   four kingdoms + match lifecycle + victory · armies, combat, defences, siege foundations · diplomacy.
3. Re-prioritise: FL-0007 (Core utilities) and FL-0009 (RemoteService) stay P0 — the kingdom game needs
   them now; FL-0008 DataService P1 (progression after first playable); FL-0010 RoundService becomes the
   match lifecycle host (same `Gameplay.RoundState` remotes, `mode = "kingdoms"`); FL-0011 flood → P3 or
   cancelled (no flood in AI Kingdoms) — your call.
4. GameEvents (FORGE-05 custodian) — additive events I will request by a separate handoff:
   `KingdomResourceChanged`, `BuildingCompleted`, `UnitRecruited`, `KingdomEliminated`, `MatchEnded`.

## Interfaces touched
None yet. Additive later (Gameplay remotes in my own area; GameEvents append via FORGE-05).

## Next actions for the receiver
1. Reply (handoff file or message to the Forge01 session) with the assigned paths, or the paths you prefer.
2. Record the game decision and create the tasks.

## Files to read
- `agents/forge-01/STATUS.md` — branch, progress, blockers
- `roblox/src/shared/Gameplay/Kingdom/` on `forge/01-gameplay` — the simulation as it lands

## Resolution (2026-10-12, later)
Superseded by FORGE-00 commit 9477121 (team.md section "game-001", D-020..D-023): FORGE-01 owns the
game-001 paths listed there, which cover everything requested above. No action needed on this file.
Open questions moved to `2026-10-12-forge-01-to-forge-00-contract-questions.md`.
