# game-001 contracts: AI Kingdoms (v0.4-g1, 2026-10-12)

Game-level contracts that sit on top of the framework contracts in `docs/architecture/interfaces.md`. The rules are the same:
- Code against these contracts now, using test doubles for anything not built yet.
- Additive changes in your own area are fine.
- Breaking changes need FORGE-00 approval in `DECISIONS.md`.

Each owner implements its section. All of them consume it.

## G1. Layout and requires (D-022)
- `games/game-001/src/shared` → `ReplicatedStorage.Game`
- `src/server` → `ServerScriptService.Game`
- `src/client` → `StarterPlayerScripts.Game`
- `config` → `ReplicatedStorage.Forge.Config`
- The project file is `games/game-001/default.project.json` (FORGE-05).
- Services live in `src/server/Services/` and controllers in `src/client/Controllers/`. The framework Loader discovers them next to the framework's own. The `Def.new(env, registry)` lifecycle is unchanged (interfaces §3).
- Requires:
  - Within the game tree, use relative paths.
  - To reach the framework, use `@game/ReplicatedStorage/Forge/...`.
  - From game server/client code to game shared code, use `@game/ReplicatedStorage/Game/...`.
  - Framework code never requires game code.
- Game remotes are declared in `src/shared/<Area>/Remotes.luau` under area names `Kingdom`, `Sim`, `Build`, `Army`, `Economy`, `Match` and `Experience`. RemoteService discovers them via `env.sharedModules("Remotes")` across both Forge and Game trees (FORGE-05 extends discovery).

## G2. Core ids and types (`src/shared/Kingdom/Types.luau`, FORGE-01)
```lua
export type KingdomId = "crimson" | "azure" | "emerald" | "gold"
export type ResourceId = "food" | "wood" | "stone" | "gold"          -- "iron" added at VS-2 (additive)
export type EntityId = number                                         -- server-assigned, unique per match, never reused
export type EntityKind = "citizen" | "soldier" | "governor"
export type JobId = "idle" | "farmer" | "woodcutter" | "miner" | "builder" | "hauler" | "soldier"
export type BuildingType = "keep" | "house" | "farm" | "storehouse" | "lumbercamp" | "quarry" | "barracks" | "watchtower" | "wall" | "gate"
export type MatchPhase = "Lobby" | "Founding" | "Expansion" | "Conflict" | "Endgame" | "Results"
export type Kingdom = { id: KingdomId, name: string, color: Color3, rulers: { number }, isAI: boolean, keepBuildingId: number?, crownPoints: number, alive: boolean }
export type Building = { id: number, kingdom: KingdomId, type: BuildingType, level: number, cframe: CFrame, footprint: Vector2,
	state: "planned" | "constructing" | "complete" | "damaged" | "destroyed", progress: number, hp: number, maxHp: number }
export type ResourceBag = { [ResourceId]: number }
```

## G3. Match and kingdoms (FORGE-01)
```lua
MatchService:getPhase(): MatchPhase
MatchService:getEndsAt(): number?                  -- serverTimeNow deadline of the current phase
MatchService.phaseChanged: Signal<(MatchPhase, { endsAt: number? })>
KingdomService:getKingdom(id: KingdomId): Kingdom
KingdomService:getKingdomOf(player): KingdomId?
KingdomService:assign(player, preferred: KingdomId?): KingdomId    -- balances humans; parties stay together
KingdomService:addCrownPoints(id, amount: number, reason: string)
KingdomService.membershipChanged: Signal<(player, KingdomId?)>
```
- Players are mapped to `Teams` (one per kingdom) for chat and leaderboards.
- Empty kingdoms are flagged `isAI = true` and run by GovernorService (VS-2).

## G4. Entities and replication (FORGE-01, D-023)
- The server owns all entity state and simulates it at fixed ticks (decisions ≈10 Hz, movement ≈20 Hz).
- `EntityService` API:
```lua
EntityService:spawn(kind: EntityKind, kingdom: KingdomId, job: JobId, position: Vector3): EntityId
EntityService:get(id): EntityState?          -- server only
EntityService:despawn(id, reason: string)
EntityService.spawned / .despawned / .jobChanged: Signal
export type EntityState = { id: EntityId, kind: EntityKind, kingdom: KingdomId, job: JobId, position: Vector3, yaw: number,
	action: "idle" | "walk" | "work" | "carry" | "fight" | "flee" | "celebrate" | "dead", carrying: ResourceId?, hp: number,
	mood: number, memory: { { event: string, kingdom: KingdomId?, at: number } } }
```
- Wire format to clients:
  - **Snapshots:** remote `Sim.Snapshot`, an `unreliableServerEvent` carrying a `buffer`. The layout is documented in `src/shared/Sim/SnapshotCodec.luau`: per entity `id u32, x/y/z f32, yaw u8, action u8, job u8, kingdom u8, carrying u8, hpPct u8`. It is interest-managed per player (nearby entities at full rate, distant ones at lower rate).
  - **Reliable events:** `Sim.EntitySpawned`, `Sim.EntityDespawned` and `Sim.EntityEvent` (id, eventName, payload) for animation cues such as "chop", "hammer", "deposit", "hit" and "die".
  - **Client side:** `EntityController` renders pooled rigs (appearance from `Kit` by kind/job/kingdom), interpolates about 100 ms behind, and exposes `EntityController.rendered: Signal<(EntityId, Model)>` for FORGE-04 VFX/audio hooks.

## G5. Citizens and jobs (FORGE-01)
- Each citizen runs a utility AI. It scores needs (hunger, rest), the assigned job, and threats (raid nearby → flee to keep), then executes the job's state machine.
- Each job state machine runs: go to work spot → work for N s → produce goods → carry them to the nearest storehouse → deposit.
- Builders run: go to a building site → hammer → `ConstructionService:contribute`.
- `CitizenService` API:
```lua
CitizenService:setJob(entityId, job: JobId): boolean
CitizenService:requestWorkers(kingdom, job: JobId, count: number)
CitizenService:getPopulation(kingdom): { total: number, byJob: { [JobId]: number }, cap: number }
```
- Deposits go through the treasury: `TreasuryService:deposit(kingdom, resource, amount, txId, "citizen:<job>")`.
- `txId` = `"dep:<entityId>:<tripSeq>"`, so replays never double-count.
- Memory entries change behaviour, e.g. citizens who were raided recently flee sooner and work slower. Memory is bounded at ≤ 8 entries per citizen.

## G6. Buildings, construction and territory (FORGE-01; FORGE-02 provides visuals)
- `BuildingService` and `ConstructionService` API:
```lua
BuildingService:canPlace(kingdom, type: BuildingType, cframe: CFrame): (boolean, string?)   -- territory, terrain, overlap, cost
BuildingService:place(player, type: BuildingType, cframe: CFrame): (number?, string?)     -- charges via TreasuryService:spend
BuildingService:upgrade(player, buildingId): (boolean, string?)
ConstructionService:contribute(buildingId, workSeconds: number)
BuildingService.stateChanged: Signal<(Building)>
TerritoryService:owner(position: Vector3): KingdomId?
TerritoryService:claim(kingdom, regionId: string, reason: string)
```
- **Visuals contract with FORGE-02.** FORGE-01 never builds geometry itself. It calls `Kit.build(type, level, stage, kingdomColor)` from `ReplicatedStorage.Game.Kit`, which returns a Model with a PrimaryPart and named attachment points (`Door`, `WorkSpot1..n`, `DropOff`). The stage is 1..3 while constructing, then "complete".
- Building costs and build times come from config `Costs.luau` (FORGE-03): `Costs.building(type, level) -> { cost: ResourceBag, buildSeconds: number }`.

## G7. Treasury and economy (FORGE-03)
- `TreasuryService` API:
```lua
TreasuryService:get(kingdom): ResourceBag
TreasuryService:canAfford(kingdom, cost: ResourceBag): boolean
TreasuryService:spend(kingdom, cost: ResourceBag, txId: string, sink: string): boolean     -- atomic: all or nothing, never negative
TreasuryService:deposit(kingdom, resource: ResourceId, amount: number, txId: string, source: string): boolean -- idempotent per txId
TreasuryService.changed: Signal<(KingdomId, ResourceBag, { [ResourceId]: number })>          -- new totals, deltas
```
- Clients learn treasury state via `Economy.Treasury`, a serverEvent sent to kingdom members: `(totals, deltas)`.
- Clients get the cost catalogue via the `Economy.GetCosts` function.
- Upkeep (food per citizen/soldier per minute) is charged by `ProductionService` (FORGE-03) using population from `CitizenService:getPopulation`.

## G8. Military and objectives (FORGE-01)
- Military API:
```lua
MilitaryService:recruit(player, barracksId: number, unitType: "soldier", count: number): (boolean, string?) -- spends via treasury
MilitaryService:command(player, unitIds: { EntityId }, order: { kind: "move" | "attack" | "capture" | "guard", target: Vector3 | number })
ObjectiveService:list(): { { id: string, kind: "capture", position: Vector3, owner: KingdomId?, progress: { [KingdomId]: number } } }
ObjectiveService.captured: Signal<(objectiveId: string, KingdomId)>
```
- Capture rules: progress increases while only one kingdom's units or rulers stand in the radius. A capture awards territory and Crown Points.
- Client remotes:

  | Remote | Kind | Payload / args | Validation |
  |---|---|---|---|
  | `Army.Recruit` | function | — | validated |
  | `Army.Command` | event | — | validated, rate-limited, max 50 unit ids |
  | `Army.Objectives` | serverEvent | objective list | — |
  | `Build.Place` | function | (type, cframe) | — |
  | `Build.Upgrade` | function | (buildingId) | — |
  | `Kingdom.Gather` | function | (nodeId) | ruler harvesting; server checks distance and cooldown |

## G9. Game events (append to the §4 bus; payloads are server-only)
| Event | Producer | Payload |
|---|---|---|
| `KingdomJoined` | FORGE-01 | (player, KingdomId) |
| `MatchPhaseChanged` | FORGE-01 | (MatchPhase) |
| `BuildingPlaced` / `BuildingCompleted` / `BuildingUpgraded` / `BuildingDestroyed` | FORGE-01 | (Building, player?) |
| `ResourceGathered` | FORGE-01 | (player?, KingdomId, ResourceId, amount, source: "ruler" \| "citizen") |
| `UnitsRecruited` | FORGE-01 | (player, KingdomId, count) |
| `ObjectiveCaptured` | FORGE-01 | (objectiveId, KingdomId) |
| `KingdomEliminated` | FORGE-01 | (KingdomId, by: KingdomId?) |
| `MatchEnded` | FORGE-01 | ({ winner: KingdomId?, standings: { { kingdom: KingdomId, crownPoints: number } }, durationSec: number }) |

- Producers fire each event exactly once, per framework rules.
- FORGE-04 (announcer, onboarding, analytics) and FORGE-03 (end-of-match UI) subscribe and never call producer internals.

## G10. Kit and world (FORGE-02)
- `Kit` lives at `src/shared/Kit/` and is consumed by FORGE-01 and FORGE-05:
```lua
Kit.build(buildingType: string, level: number, stage: number | "complete", kingdomColor: Color3): Model
Kit.character(kind: EntityKind, job: JobId, kingdomColor: Color3): Model     -- pooled client rig template
Kit.prop(assetId: string): Model                                            -- uses imported mesh if present in Forge.Assets, else a stand-in
```
- `WorldService` builds terrain and places world props at server start from `games/game-001/world/Layout.luau`. That file defines the kingdom plots (keep anchor, build zones), river spline, forests, quarries, roads, neutral objectives, and resource nodes with ids.
- It tags instances (`ResourceNode`, `BuildZone`, `ObjectiveZone`, `KingdomPlot:<id>`) for FORGE-01's systems.

## G11. Experience hooks (FORGE-04)
- `PacingService` owns phase lengths and difficulty curves from `Pacing.luau`. It feeds `MatchService` with the durations; FORGE-01 reads `Pacing.phaseDurations()`.
- `AnnouncerService` turns G9 events into kingdom-scoped messages via `NotificationController`.
- `OnboardingService` runs the VS-1 guided steps from `Onboarding.luau`, triggered by G9 events.

## Changelog
- v0.4-g1 (2026-10-12) FORGE-00: first game-001 contracts for VS-1.
