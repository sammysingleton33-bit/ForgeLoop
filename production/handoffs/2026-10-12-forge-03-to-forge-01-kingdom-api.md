# Handoff: forge-03 → forge-01 · AI Kingdoms kingdom API (proposal) · 2026-10-12

## What I need / what I'm giving you
The user made **AI Kingdoms** Game #1 (directive to FORGE-03, 2026-10-12; FORGE-00 is asked to record it).
The UI and economy for the first playable loop (see resources → pick a building → read its costs →
build → see it confirmed) are built and tested headlessly against **test doubles of the API below**.
Please confirm or amend this API before you build KingdomService / KingdomController, so we don't
end up with two data models. Reply with a handoff file or a PR comment; I will adapt my side.

Nothing here edits your paths. The doubles live in my test folder and never ship in the place.

## Proposed split (who owns what)
| Concern | Owner | Where |
|---|---|---|
| Kingdom ownership (player ↔ kingdom), territory, plots, placement, citizens and their jobs, construction timers, army units, combat, standings | **FORGE-01** | `KingdomService` (server), `KingdomController` (client), `Gameplay.*` remotes, your config keyed by item id (footprint, model asset id, hit points, unit stats) |
| Resource ledgers (food, wood, stone, gold) per kingdom, building/unit **costs, levels, requirements, limits, production rates, housing, storage** | **FORGE-03** | `EconomyTreasuryService`, `shared/Economy/{Bundle,Wallet,Currencies,Construction}`, `Config.Items` / `Config.Currencies` |
| Construction menu, kingdom HUD, kingdom panel, notifications fallback | **FORGE-03** | `client/Controllers/UIController`, `client/UI/Kingdom/*` |

The rule both sides share is `Construction:check(kingdomView, treasuryBalances, buildingId, uid?)`
(`roblox/src/shared/Economy/Construction.luau`). The UI shows its verdict; KingdomService must call
it again server-side before spending (never trust the client).

## Server API you would provide (KingdomService)
```lua
KingdomService:createKingdom(player, opts?) -> kingdomId      -- opens the treasury: EconomyTreasuryService:open(kingdomId, { members = { player }, caps = catalog:storageCaps(view) })
KingdomService:kingdomOf(player) -> kingdomId?
KingdomService:snapshot(kingdomId) -> KingdomSnapshot
KingdomService:build(player, buildingId, plotId?) -> (ok, reason?, uid?)
KingdomService:upgrade(player, uid) -> (ok, reason?)
KingdomService:assignWorkers(player, uid, count) -> (ok, reason?)
```
Build / upgrade must, in this order: `catalog:check(...)` with `EconomyTreasuryService:balances(kingdomId)`
→ refuse with `check.reason` → `EconomyTreasuryService:spend(kingdomId, check.cost, txId, "build:<buildingId>")`
with a server-generated `txId` (e.g. `build:<kingdomId>:<n>`) → only on success create the instance /
start the timer. Spend is all-or-nothing and idempotent per txId, so a retry with the same txId never
double-charges.

Production: every N seconds grant `catalog:production(view)` (per minute) pro rata with
`EconomyTreasuryService:grant(kingdomId, bundle, "prod:<kingdomId>:<tick>", "production")`.
When a Storehouse completes: `EconomyTreasuryService:setCaps(kingdomId, catalog:storageCaps(view))`.

## Snapshot the UI reads (KingdomSnapshot)
```lua
{
	kingdomId: string, name: string, ownerUserId: number, tincture: string, -- "azure" | "gules" | "vert" | "purpure" | "or" | "sable"
	version: number,              -- increases on every change; clients keep the highest
	hall: number,                 -- Town Hall level
	territory = { tiles: number },
	rank: number?, kingdoms: number?,  -- standings teaser (optional)
	citizens = { total, housing, idle, working, building },
	builders = { busy: number, total: number },
	buildings = { { uid, buildingId, level, state = "constructing" | "upgrading" | "ready",
	                workers, startedAt?, completesAt? } },  -- times in server time (GetServerTimeNow)
}
```
`level` is the completed level (0 while first constructed); an upgrading building keeps producing
at its current level.

## Remotes (yours, `shared/Gameplay/Remotes.luau`)
```lua
{ name = "Gameplay.KingdomState",    kind = "serverEvent" },                                  -- (snapshot) to the kingdom's members
{ name = "Gameplay.GetKingdomState", kind = "function", args = {} },                         -- () -> snapshot?
{ name = "Gameplay.Build",           kind = "function", args = { V.string(1, 32), V.optional(V.string(1, 32)) } }, -- (buildingId, plotId?) -> (ok, reason?, uid?)
{ name = "Gameplay.Upgrade",         kind = "function", args = { V.string(1, 32) } },        -- (uid) -> (ok, reason?)
{ name = "Gameplay.AssignWorkers",   kind = "function", args = { V.string(1, 32), V.integer(0, 50) } }, -- (uid, count) -> (ok, reason?)
```
Mine (`shared/Economy/Remotes.luau`, already declared): `Economy.Treasury` serverEvent
`(snapshot, change?)` and `Economy.GetTreasury` function. Refusal reasons the UI already words:
`cost`, `insufficient`, `requirement`, `limit`, `builders`, `max_level`, `busy`, `not_found`,
`no_kingdom`, `no_idle`, `no_slots` (`client/UI/Kingdom/Text.luau`).

## Client API (KingdomController)
`.state: KingdomSnapshot?`, `.changed: Signal(state)`, `:build(buildingId, plotId?)`,
`:upgrade(uid)`, `:assignWorkers(uid, count)` (each returns the remote's reply). UIController finds
it with `registry:find("KingdomController")`.

Round timer: UIController already listens to `Gameplay.RoundState` and calls `Gameplay.GetRoundState`
(interfaces §4 v0.3). Optional, additive: expose `RoundController.endsAtServerTime` so screens need
not listen to the remote themselves.

## Evidence (headless; nothing run in Studio)
- `bash roblox/scripts/check.sh` at `83761e7` on `forge/03-ui-economy`: OVERALL PASS — 348 Lune specs,
  Selene 0/0, StyLua clean, Rojo build, place check.
- `roblox/tests/unit/ui/KingdomUI.spec.luau` (10 specs) drives the real UIController against the
  doubles: build spends exactly once, deltas float on the pills, a toast appears and the queue chip
  tracks construction; refusals become error toasts; workers and a confirmed Town Hall upgrade work.
- `roblox/tests/unit/economy/EconomyTreasuryService.spec.luau` (10 specs): exactly-once change
  events, idempotent replays, malformed client calls dropped, production pays 18/min for 3 farmers.

## Interfaces touched
Additive proposals only (new Gameplay remotes in your area, KingdomService/KingdomController
APIs, `Economy.*` remotes in mine). No change to `Contracts/`. If you want a `KingdomChanged`
GameEvent for quests/analytics, that is an additive contract change for FORGE-05/FORGE-00.

## Open issues and risks
- **Plots / placement:** the proposal lets `plotId` be nil (server picks a free plot). A placement
  mode with a ghost preview would be your controller; the build menu can hand off to it later.
- **Teams:** one player per kingdom is assumed; `EconomyTreasuryService:setMembers` already
  supports several.
- **Food upkeep** for citizens/army is not modelled yet (balance proposal for the user).
- Numbers in `Config.Items` are provisional proposals awaiting the user's approval.

## Next actions for the receiver
1. Read `roblox/tests/unit/economy/doubles/KingdomDoubles.luau`: it implements exactly this
   proposal (≈ 300 lines) and can be a starting point for KingdomService.
2. Reply: accept, or list changes (names, payload fields, reasons).
3. When your RemoteService / Core/RemoteClient / Validate land, tell me: UIController currently
   reaches RemoteClient through `env.sharedModules("RemoteClient").Core` so the place boots without it.

## Files to read
- `roblox/src/shared/Economy/Construction.luau` — the shared rule set (check, production, housing, storage)
- `roblox/src/server/Services/EconomyTreasuryService.luau` — treasury API
- `roblox/tests/unit/economy/doubles/KingdomDoubles.luau` — the proposal as code
- `games/sandbox/config/Items.luau` — buildings and units (economy fields)
