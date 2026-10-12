# game-001 contracts: AI Kingdoms (v0.4-g4, 2026-10-12; G12 is a VS-2 draft; G13 VS-1 rows are effective)

Game-level contracts that sit on top of the framework contracts in `docs/architecture/interfaces.md`. The rules are the same:
- Code against these contracts now.
- Additive changes in your own area are fine.
- Breaking changes need FORGE-00 approval in `DECISIONS.md`.

Each owner implements its section. All of them consume it.

**Cross-worker dependencies (D-028).**
- **Services:** reach another worker's service through the registry: `registry:get` for hard dependencies declared in `dependencies`, `registry:find` in `start()` for optional ones. Specs pass a local double.
- **Modules required by path:** `Kingdom/Types`, `Kit/Kit`, `World/Layout`, config `Resources` and `Costs`. The Lune harness always loads the real file and has no per-spec override, so each owner lands a **contract stub** in hours 0–2, and FORGE-05 merges the stubs right after FL-0046:
  - FORGE-01 `src/shared/Kingdom/Types.luau` (exactly G2);
  - FORGE-02 `src/shared/Kit/Kit.luau` (G10 API returning boxes with the named attachments) and `world/Layout.luau` (G10.1 schema, one plot filled);
  - FORGE-03 config `Resources.luau` and `Costs.luau` (placeholder numbers).

  Nobody creates a file in another owner's path.
- **Task `depends_on`** means "needed before integration and acceptance", not "before you start".

## G1. Layout and requires (D-022, D-026)
| Source | DataModel |
|---|---|
| Framework mounts of `roblox/default.project.json`, unchanged, including `roblox/assets` → `ReplicatedStorage.Forge.Assets` | as framework |
| `games/game-001/src/shared` | `ReplicatedStorage.Game` |
| `games/game-001/world` | `ReplicatedStorage.Game.World` (read-only data for server and clients) |
| `games/game-001/src/server` | `ServerScriptService.Game` |
| `games/game-001/src/client` | `StarterPlayer.StarterPlayerScripts.Game` |
| `games/game-001/config` (including `Game.luau`, FORGE-05) | `ReplicatedStorage.Forge.Config` |

- The project file is `games/game-001/default.project.json` (FORGE-05). It also sets:
  - `Players.CharacterAutoLoads = false` (G3 spawn);
  - the Workspace streaming properties of D-025.
- Services live in `src/server/Services/` and controllers in `src/client/Controllers/`. Only ModuleScripts directly inside those folders are loaded. The Loader discovers both trees, and the `Def.new(env, registry)` lifecycle is unchanged (interfaces §3).
- **Names are unique across both trees.** A game service, controller or remote area may not reuse a framework name (D-026). A duplicate fails the boot.
- Requires:
  - Within one mount, use relative paths.
  - To reach the framework, use `@game/ReplicatedStorage/Forge/...`.
  - To reach game shared code or world data, use `@game/ReplicatedStorage/Game/...`, e.g. `@game/ReplicatedStorage/Game/Kit/Kit` and `@game/ReplicatedStorage/Game/World/Layout`.
  - Framework code never requires game code.
- **Remote areas** are declared in `src/shared/<Area>/Remotes.luau`:
  - `Kingdom`, `Sim`, `Build`, `Army`, `Match` → FORGE-01;
  - `Treasury` → FORGE-03;
  - `Feedback` → FORGE-04.

  `env.sharedModules("Remotes")` spans both trees (FORGE-05, FL-0046). A duplicate area or `<Area>.<Action>` fails the boot.

## G2. Core ids and types (`src/shared/Kingdom/Types.luau`, FORGE-01)
```lua
export type KingdomId = "crimson" | "azure" | "emerald" | "gold"
export type ResourceId = "food" | "wood" | "stone" | "gold"          -- "iron" added at VS-2 (additive)
export type EntityId = number                                         -- server-assigned, unique per match, never reused, ≤ 65,535 (u16 on the wire)
export type EntityKind = "citizen" | "soldier" | "governor"
export type JobId = "idle" | "farmer" | "woodcutter" | "miner" | "builder" | "hauler" | "soldier"
export type BuildingType = "keep" | "house" | "farm" | "storehouse" | "lumbercamp" | "quarry" | "barracks" | "watchtower" | "wall" | "gate"
export type MatchPhase = "Lobby" | "Founding" | "Expansion" | "Conflict" | "Endgame" | "Results"
export type Kingdom = { id: KingdomId, name: string, color: Color3, rulers: { number }, isAI: boolean, keepBuildingId: number?,
	crownPoints: number, regions: { string }, alive: boolean }                     -- regions: claimed Layout region ids
export type Building = { id: number, kingdom: KingdomId, type: BuildingType, level: number, cframe: CFrame, footprint: Vector2,
	state: "planned" | "constructing" | "complete" | "damaged" | "destroyed", progress: number, hp: number, maxHp: number,
	placedBy: number? }                                                             -- userId; nil for starting buildings
export type ResourceBag = { [ResourceId]: number }
```

## G3. Match and kingdoms (FORGE-01)
```lua
MatchService:getPhase(): MatchPhase
MatchService:getEndsAt(): number?                  -- serverTimeNow deadline of the current phase; nil = untimed
MatchService.phaseChanged: Signal<(MatchPhase, { endsAt: number? })>
KingdomService:getKingdom(id: KingdomId): Kingdom
KingdomService:getKingdomOf(player): KingdomId?
KingdomService:assign(player, preferred: KingdomId?): KingdomId
KingdomService:addCrownPoints(id, amount: number, reason: string)
KingdomService.membershipChanged: Signal<(player, KingdomId?)>
```
- **Teams.** KingdomService creates four `Team`s with `AutoAssignable = false`. Each has a fixed, distinct named `TeamColor` from `Kingdoms.luau` (e.g. Crimson, Bright blue, Dark green, Bright yellow), never `BrickColor.new(Color3)`. `assign` sets `Player.Team`.
- **Assignment.** Players with the same `Player.PartyId` go to the same kingdom; humans are balanced after that. Specs mock the party data; Studio tests use the Party Simulator. A free "join this kingdom" choice is VS-2.
- **Spawn (D-026).** `CharacterAutoLoads` is false. After `WorldService.ready` and `assign`, KingdomService:
  1. calls `player:LoadCharacterAsync()`;
  2. pivots the character to `Layout.plots[k].spawn`;
  3. attaches `Kit.regalia(color)`.

  It does the same on every respawn.
- **Phase durations.** MatchService calls `registry:find("PacingService")` in `start()` and uses `PacingService:phaseDurations(mode)` (G11). It falls back to built-in defaults when PacingService is absent. PacingService never calls MatchService.
- **VS-1 slice mode.** These are interim rules for Studio testing, pending the user's decisions §16.3 and §16.4:
  - Lobby lasts 0 s. Founding starts on the first join and is untimed. Late joiners are assigned.
  - The first `ObjectiveCaptured` fires `MatchEnded { winner }` and moves the match to Results. This ends the slice only; it is not a victory rule.
  - Starting buildings exist for all four kingdoms. Starting citizens are spawned for a kingdom when its first ruler joins. AI kingdoms stay idle until VS-2 governors.
- Empty kingdoms are flagged `isAI = true` and run by GovernorService (VS-2).


- **Clarifications (FORGE-01 questions, 2026-10-12):**
  - The pre-match countdown runs in `Lobby`, which carries `endsAt` while it runs. `Founding` starts the simulation.
  - **Victory is PROVISIONAL and the user's decision (BRIEF §16.4).** Default in config `Match.luau`: last keep standing ends the match early; otherwise most Crown Points at the end of Endgame wins; ties share the win. It must be config-driven and never described as decided. **From VS-2 (D-029):** the match ends in the Crown Arena (G12); Crown Points decide who qualifies, and last keep standing becomes a coronation.
  - **Diplomacy/PvP is PROVISIONAL and the user's decision (BRIEF §16.2).** Default: war from Conflict onward; peace by mutual consent; no betrayal mechanics. It is behind a config flag and not needed for VS-1.

## G4. Entities and replication (FORGE-01; D-023 as amended by D-025, D-026)
- The server owns all entity state and simulates it at fixed ticks: decisions ≈10 Hz, movement ≈20 Hz. Decisions are staggered round-robin across frames, never all on one frame.
- `EntityService` API:
```lua
EntityService:spawn(kind: EntityKind, kingdom: KingdomId, job: JobId, position: Vector3): EntityId
EntityService:get(id): EntityState?          -- server only
EntityService:despawn(id, reason: string)
EntityService.spawned / .despawned / .jobChanged: Signal
export type EntityState = { id: EntityId, kind: EntityKind, kingdom: KingdomId, job: JobId, name: string, position: Vector3, yaw: number,
	action: "idle" | "walk" | "work" | "carry" | "fight" | "flee" | "celebrate" | "dead",   -- 8 values = 3 bits on the wire
	carrying: ResourceId?, hp: number, mood: number, memory: { { event: string, kingdom: KingdomId?, at: number } } }
```

**Snapshots.** Remote `Sim.Snapshot` is an `unreliableServerEvent` carrying one `buffer` per event. The layout is documented in `src/shared/Sim/SnapshotCodec.luau`.
- **Header (8 B):**
  - `serverTime` f32: seconds since match start (`Match.State` carries `startedAtServerTime`);
  - `seq` u16: per tick, compared with wrap-around;
  - `chunk` u8: `index << 4 | count`;
  - `n` u8: records in this event.
- **Record (10 B):**
  - `id` u16;
  - `x`, `y`, `z` i16 at 1/8 stud (the world fits within ±4,000 studs);
  - `yaw` u8;
  - `state` u8: action in 3 bits, carrying in 3 bits.
- **Size:**
  - At most 80 records per event (808 B).
  - `SnapshotCodec` asserts raw size ≤ 900 B and never counts on compression. The engine drops unreliable payloads over 1,000 B.
- **Rate:**
  - 10 Hz with a ≈200 ms interpolation delay (20 Hz / 100 ms if the measured bandwidth allows).
  - Idle and working entities are refreshed round-robin about once per second.
- **Who gets what:**
  - VS-1: every client gets every entity.
  - VS-2 adds interest tiers: near (≤150 studs) at full rate, far at 2 Hz. Target ≤ 20 KB/s per player.

**Reliable traffic.** Fields that rarely change are not in the snapshot.
- `Sim.Events` (serverEvent) sends one buffer per player per tick. It batches:
  - spawn records `{ id, kind, job, kingdom }`;
  - despawns and job changes;
  - discrete cues: `deposit`, `hit`, `die`, `celebrate`.

  Looping work animations (chop, mine, hammer, carry) derive from action + job. There are no per-swing events. `hpPct` is sent here when it changes (VS-2).
- `Sim.GetEntities` (function): the client calls it after connecting its handlers. It returns one buffer with every live entity: spawn record + current state.

**Client rules (EntityController).**
- Drop snapshots older than the newest applied `seq`.
- Ignore unknown ids, because a snapshot can arrive before its spawn.
- Keep a despawned-id set, so a late snapshot never brings back a despawned entity.

**Rendering (D-026).**
- Rigs come from `Kit.character`: at most 8 parts joined by Motor6Ds, with no Humanoid and no Animator. Rigs are pooled.
- Animation is procedural, through `Motor6D.Transform`, by action and job. The pose maths is a pure module tested in Lune.
- Roots move with `workspace:BulkMoveTo(..., Enum.BulkMoveMode.FireCFrameChanged)`.

**Streaming (D-025).**
- Rigs live under a client-created Folder in Workspace, never under a server-created model, so they are never streamed out.
- Client code never needs far-away tagged instances. Positions come from `Layout` and remotes.
- Entity LOD beyond 150 studs is custom (a one-part stand-in, or hidden). Do not plan on SLIM for Kit models.

### G4.1 Client API (consumed by FORGE-03 and FORGE-04)
```lua
EntityController.rendered: Signal<(EntityId, Model)>
EntityController.released: Signal<(EntityId, Model)>                      -- fired before a rig returns to the pool
EntityController.event: Signal<(EntityId, cue: string, payload: any, Model?)>
EntityController:pick(screenPos: Vector2): EntityId?
EntityController:getModel(id: EntityId): Model?
InteractionController.gathered: Signal<(nodeId: string, ResourceId, amount: number)>   -- FORGE-01
InputModeController:set(mode: "explore" | "build"); .mode; .changed: Signal  -- FORGE-04 (FL-0053/FL-0090); "command" is VS-2
InputModeController.selected: Signal<(kind: "citizen" | "building" | "slot" | "none", id: number | string)>   -- G13.6
RulerCameraController:setMode(mode: "overview" | "follow")                    -- FORGE-04; "overview" = aerial management view (VS-1 default, D-030), "follow" = walk mode
```
- FORGE-04 hooks feedback only on these signals and on G9 events. Only EntityController decodes `Sim.*`.
- Mobile input (amended by D-030):
  - In the default overview mode the ruler sits on the throne, and the camera pans, pinches and rotates.
  - In explore mode a tap **selects** (G13.6): citizen, building or plot. Ruler gathering is optional in VS-1.
  - In build mode a tap places.
  - In follow (walk) mode the ruler moves with the default thumbstick.

## G5. Citizens and jobs (FORGE-01)
- Each citizen runs a utility AI. It scores needs (hunger, rest), the assigned job, and threats (raid nearby → flee to keep), then executes the job's state machine.
- Each job state machine runs: go to a work spot (`Layout.resourceNodes[i].workSpots` or a building `WorkSpot`) → work for N s → produce goods → carry them to the nearest storehouse `DropOff` → deposit.
- Builders run: go to a building site → hammer → `ConstructionService:contribute`.
- `CitizenService` API:
```lua
CitizenService:setJob(entityId, job: JobId): boolean
CitizenService:requestWorkers(kingdom, job: JobId, count: number)
CitizenService:getPopulation(kingdom): { total: number, byJob: { [JobId]: number }, cap: number }   -- soldiers count in byJob.soldier
CitizenService:setFedRatio(kingdom, ratio: number)        -- 0..1, set by ProductionService each upkeep tick; drives hunger
CitizenService:inspect(entityId): { name: string, job: JobId, mood: number, intent: string, lastMemory: string? }?
```
- The starting population comes from `Citizens.luau` `startingPopulation`, for example farmer 3, woodcutter 3, miner 2, builder 2, hauler 2.
- Deposits go through the treasury: `TreasuryService:deposit(kingdom, resource, amount, txId, "citizen:<job>")`.
- `txId` = `"dep:<entityId>:<tripSeq>"`, so replays never double-count.
- Citizens never draw food themselves. Hunger follows the kingdom's fed ratio (G7).
- **Memory** is bounded at ≤ 8 entries per citizen and changes behaviour; for example, citizens who were raided recently flee sooner and work slower.
- **VS-1 visible reactions:**
  - citizens near the keep `celebrate` when it reaches level 2;
  - a ruler visit adds a `rulerVisited` memory and raises mood, at most once per citizen per few minutes.
- The day/night routine is VS-2. VS-1 runs at a fixed time of day.


- **Job semantics (FORGE-01 question, 2026-10-12):**
  - `miner` works stone and gold, choosing by kingdom need.
  - `hauler` is the generalist: it carries goods to the storehouse, builds when idle, and is the pool `requestWorkers` draws from.

## G6. Buildings, construction and territory (FORGE-01; FORGE-02 provides visuals)
- `BuildingService`, `ConstructionService` and `TerritoryService` API:
```lua
BuildingService:canPlace(kingdom, type: BuildingType, cframe: CFrame): (boolean, string?)   -- territory, build zone, overlap (Kit.footprint), cost
BuildingService:place(player, type: BuildingType, cframe: CFrame): (number?, string?)     -- charges via TreasuryService:spend; sets placedBy
BuildingService:upgrade(player, buildingId): (boolean, string?)
ConstructionService:contribute(buildingId, workSeconds: number)
BuildingService.stateChanged: Signal<(Building)>
TerritoryService:owner(position: Vector3): KingdomId?
TerritoryService:claim(kingdom, regionId: string, reason: string)                         -- regionId from Layout.regions
```
- **Starting state.** At Founding start, BuildingService places `Buildings.luau` `starting` (keep L1, storehouse, farm, lumbercamp, quarry) as `complete` at `Layout.plots[k].anchors`.
- **Navigation.** On placement, BuildingService links the building's `Door` to the nearest `Layout.nav` node.
- **Visuals contract with FORGE-02.** FORGE-01 never builds geometry itself.
  - It calls `Kit.build(type, level, stage, kingdomColor)` (G10), with stage 1..3 while constructing, then `"complete"`.
  - Each stage replaces the whole previous Model; parts are never added to an existing one.
  - Footprints come from `Kit.footprint(type, level)`.
  - On claim, TerritoryService places `Kit.regionMarkers(region.polygon, color)` so that territory is visible.
- **Costs** come from config `Costs.luau` (FORGE-03):
  - `Costs.building(type, level) -> { cost: ResourceBag, buildSeconds: number }`;
  - `Costs.unit(unitType) -> { cost: ResourceBag, trainSeconds: number, upkeepFood: number }`.

## G7. Treasury and economy (FORGE-03)
- `TreasuryService` API:
```lua
TreasuryService:get(kingdom): ResourceBag
TreasuryService:canAfford(kingdom, cost: ResourceBag): boolean
TreasuryService:spend(kingdom, cost: ResourceBag, txId: string, sink: string): boolean     -- atomic: all or nothing, never negative
TreasuryService:spendUpTo(kingdom, resource: ResourceId, amount: number, txId: string, sink: string): number -- takes min(balance, amount); returns it
TreasuryService:deposit(kingdom, resource: ResourceId, amount: number, txId: string, source: string): boolean -- idempotent per txId
TreasuryService.changed: Signal<(KingdomId, ResourceBag, { [ResourceId]: number })>          -- new totals, deltas
```
- **Upkeep.** ProductionService is the only food consumer. Each minute it:
  1. takes `spendUpTo(kingdom, "food", upkeep, txId, "upkeep")`, where upkeep counts citizens and soldiers from `getPopulation`;
  2. calls `CitizenService:setFedRatio(kingdom, taken / upkeep)`.
- In VS-1, any kingdom member may spend. Co-ruler spending permissions are VS-2.
- Client remotes: `Treasury.Changed`, `Treasury.Get` and `Treasury.GetCosts` (G8 table).


- **Treasury capacity (FORGE-01 question, 2026-10-12):** VS-1 has no storage cap. Storehouses are drop-off points only. A cap would be a later pacing/economy decision by FORGE-03 with FORGE-04.

## G8. Military, objectives and client remotes (FORGE-01 unless noted)
```lua
MilitaryService:recruit(player, barracksId: number, unitType: "soldier", count: number): (boolean, string?) -- spends Costs.unit; units appear at the barracks `Rally`
MilitaryService:command(player, unitIds: { EntityId }, order: { kind: "move" | "attack" | "capture" | "guard", targetPos: Vector3?, targetId: string? })
ObjectiveService:list(): { { id: string, kind: "capture", position: Vector3, radius: number, owner: KingdomId?, progress: { [KingdomId]: number } } }
ObjectiveService.captured: Signal<(objectiveId: string, KingdomId)>
```
- **Objective model.** ObjectiveService builds each objective from `Layout.objectives` with `Kit.build("watchtower", 1, "complete", Kit.NEUTRAL_COLOR)`.
- **Capture.**
  - Progress increases while only one kingdom's units or rulers stand in the radius.
  - On capture, ObjectiveService recolours the tower with `Kit.setKingdomColor`, claims `objective.regionId`, and adds Crown Points.
- **VS-1 command.** The VS-1 command UI is a Send-to-capture button: `Army.Command` with empty `unitIds` means all of my kingdom's idle soldiers. Free selection and target picking are VS-2.
- **Client remotes.** All are validated. `function` and `event` remotes are rate-limited per player. Remotes that send to "members" go to kingdom members; the others go to every player.

| Remote | Kind | Args → result, or payload |
|---|---|---|
| `Kingdom.State` / `Kingdom.GetState` | serverEvent / function | `{ kingdoms: { Kingdom }, mine: KingdomId? }` on change / on request |
| `Kingdom.Gather` | function | `(nodeId: string(1,32))` → `(ok, ResourceId?, amount?)`; the server checks distance and cooldown |
| `Kingdom.SetJobQuota` | function | `(job: enum JobId, count: integer(0,50))` → `boolean` (calls `requestWorkers`) |
| `Match.State` / `Match.GetState` | serverEvent / function | `(phase, endsAtServerTime?, startedAtServerTime)` |
| `Match.Ended` | serverEvent | the `MatchEnded` payload (G9) |
| `Build.Buildings` / `Build.GetBuildings` | serverEvent / function | changed `{ Building }` per tick / all buildings |
| `Build.CanPlace` | function | `(type: enum, position: vector3, rot: integer(0,3))` → `(boolean, string?)`; burst 10, 10/s (ghost tint) |
| `Build.Place` | function | same args → `(buildingId?, reason?)` |
| `Build.Upgrade` | function | `(buildingId: integer)` → `(boolean, string?)` |
| `Army.Recruit` | function | `(barracksId: integer, unitType: enum{"soldier"}, count: integer(1,10))` → `(boolean, string?)` |
| `Army.Command` | event | `(unitIds: array(integer, 50), kind: enum, targetPos: optional(vector3), targetId: optional(string(1,32)))` |
| `Army.Objectives` / `Army.GetObjectives` | serverEvent / function | `ObjectiveService:list()` |
| `Sim.Snapshot`, `Sim.Events`, `Sim.GetEntities` | see G4 | |
| `Sim.Inspect` | function | `(entityId: integer)` → `CitizenService:inspect` result, own kingdom only |
| `Treasury.Changed` (FORGE-03) | serverEvent to members | `(totals, deltas)` |
| `Treasury.Get` / `Treasury.GetCosts` (FORGE-03) | function | the caller's kingdom `ResourceBag` / the cost catalogue |

- No CFrame crosses the wire. The server builds `CFrame.new(position) * CFrame.Angles(0, rot * math.pi / 2, 0)`.

## G9. Game events (framework §4 bus; payloads are server-only)
The events are appended to `Contracts/GameEvents` by FORGE-05 in FL-0046 (D-024). Until then, reading them throws.

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
- FORGE-04 (announcer, onboarding, analytics) and FORGE-03 subscribe and never call producer internals.
- Client UI learns through G8 remotes (e.g. the slice summary uses `Match.Ended`), never from G9 directly.
- **Funnel attribution:**
  - "spawn" = `KingdomJoined`;
  - "first build placed" credits `Building.placedBy`;
  - building completions and captures credit every current member of the kingdom.

## G10. Kit and world (FORGE-02; D-021 as amended by D-026)
`src/shared/Kit/Kit.luau` is required as `@game/ReplicatedStorage/Game/Kit/Kit`.
- It builds only from primitive Parts (Block, Wedge, CornerWedge, Cylinder, Ball). There is no runtime CSG and no PartOperation.
- No function yields.
- Curved or complex shapes come later as imported meshes, through `Kit.prop` ids.
```lua
Kit.build(type: BuildingType, level: number, stage: number | "complete", kingdomColor: Color3): Model
	-- PrimaryPart; attachments Door, WorkSpot1..n, DropOff (storehouse), Rally (barracks)
Kit.footprint(type: BuildingType, level: number): Vector2           -- the one source for canPlace and the build ghost
Kit.character(kind: EntityKind, job: JobId, kingdomColor: Color3): Model
	-- ≤ 8 parts (anchored root, torso, head, 2 arms, 2 legs, tool); Motor6Ds named after the moving part;
	-- CanCollide, CanTouch and CanQuery false; pooled client rig template
Kit.regalia(kingdomColor: Color3): { Accessory }                     -- ruler crown + cape (R15 and R6 attachments)
Kit.prop(assetId: string): Model                                     -- imported mesh from Forge.Assets if present, else a part-built stand-in
Kit.regionMarkers(polygon: { Vector2 }, kingdomColor: Color3): Model -- border flags for a claimed region
Kit.NEUTRAL_COLOR: Color3
Kit.setKingdomColor(model: Model, color: Color3)                     -- recolours trims and banners in place
```
- **What WorldService does**, at server start, all from `world/Layout.luau`:
  - builds terrain with `Fill*` primitives, one per Layout feature (no single huge `WriteVoxels`; if it is used, at most 64×64×16 voxels per frame), through a thin terrain adapter that Lune specs can record;
  - places props and forests, spread across frames;
  - applies `world/Lighting.luau`;
  - then fires `WorldService.ready` (`WorldService:isReady(): boolean`) and logs the build time in ms.
- **What WorldService does not do:** it dresses plots with props only and never calls `Kit.build` for buildings. BuildingService and ObjectiveService do that.
- **Tags.** WorldService tags `ResourceNode`, `BuildZone` and `ObjectiveZone` with the attributes `NodeId`, `ZoneId` and `ObjectiveId`, equal to the Layout ids. Tags are for visuals and client hints only. The sim reads Layout and never reads tags.

### G10.1 Layout schema (`world/Layout.luau`, FORGE-02; pure data; stub in hours 0–2)
```lua
{
	plots = { [KingdomId] = { spawn: CFrame, regionId: string,
		anchors: { keep: CFrame, storehouse: CFrame, farm: CFrame, lumbercamp: CFrame, quarry: CFrame },
		buildZones: { { id: string, center: Vector3, size: Vector2 } } } },
	nav = { nodes: { [number]: Vector3 }, edges: { { number } } },            -- edges are {a, b}; cost = distance
	resourceNodes = { { id: string, resource: ResourceId, assetId: string, cframe: CFrame, amount: number,
		regrowSec: number, workSpots: { Vector3 }, navNode: number } },
	objectives = { { id: string, kind: "capture", cframe: CFrame, radius: number, regionId: string, navNode: number } },
	regions = { [string]: { kingdom: KingdomId?, polygon: { Vector2 } } },
	-- visual features (river spline, roads, forests, terrain regions): FORGE-02's own shape
}
```
- Every position lies within ±4,000 studs (snapshot quantisation, G4).
- FORGE-01 builds its path graph from `Layout.nav` plus the building `Door` links. It does not use PathfindingService (D-023).

## G11. Experience hooks (FORGE-04)
- `PacingService:phaseDurations(mode: "slice" | "match"): { Lobby: number, Founding: number, Expansion: number, Conflict: number, Endgame: number, Results: number }` returns seconds from config `Pacing.luau`; `math.huge` means untimed. MatchService pulls it (G3).
- **No game-tree duplicates of framework services.** VS-1 uses the framework services and controllers, fed by game config:
  - onboarding: OnboardingService (FL-0025) with `Onboarding.luau`. Steps are triggered by G9 events; the first step is on `KingdomJoined`.
  - announcements: `AnnouncerService` turns G9 events into kingdom-scoped messages shown through `NotificationController`.
  - audio: `AudioController` with `Sounds.luau`.
- VS-1 has no persistence (D-027): onboarding and settings progress is kept for the session only when DataService is absent.

## G12. Crown Arena and support (DRAFT for VS-2; D-029; design: `design/crown-arena.md`)
**Do not implement in VS-1.** Shapes are stable enough for stubs, prototypes and the fairness harness. FORGE-00 freezes G12 as v0.5 when VS-2 starts; changes before then are announced in a handoff.

### G12.1 Types (`src/shared/Arena/Types.luau`, FORGE-01)
```lua
export type SupportTier = "adoring" | "loyal" | "divided" | "restless" | "hostile"
export type SupportComponent = "reputation" | "happiness" | "stability" | "morale" | "loyalty" | "conduct" | "valour"
export type KeyRole = "blacksmith" | "healer" | "captain" | "provisioner" | "elder" | "merchant"
export type TriggerId = "reforge" | "fieldRemedy" | "calledWarning" | "heartyRations" | "rallyingHymn" | "fineWares" | "crowdRally"
export type LeadershipMoment = { t: number, kingdom: KingdomId, userId: number?, act: string, component: SupportComponent,
	delta: number, text: string }                                         -- text is pre-authored, never user input
export type TriggerOffer = { trigger: TriggerId, citizenId: EntityId?, citizenName: string?, role: KeyRole?,
	loyalty: number?, power: "pledged" | "empowered", condition: string, effect: string }   -- crowdRally has no citizen
export type SupportView = { kingdom: KingdomId, userId: number, score: number, tier: SupportTier, trend: number,
	breakdown: { [SupportComponent]: number }, moments: { LeadershipMoment }, offers: { TriggerOffer }, slots: number }
export type Weapon = "swordShield" | "greatsword" | "spear" | "mace"
export type Armour = "light" | "medium" | "heavy"
export type Duellist = { userId: number, kingdom: KingdomId, isAI: boolean, tier: SupportTier, score: number,
	weapon: Weapon?, armour: Armour?, triggers: { TriggerId }, reasons: { string } }   -- reasons: top 3 moment texts
export type ArenaStage = "qualify" | "vote" | "loadout" | "intro" | "duel" | "crowning" | "done"
export type ArenaState = { stage: ArenaStage, endsAt: number?, a: Duellist?, b: Duellist?, coronation: KingdomId?, winner: number? }
export type DuelAction = "light" | "heavy" | "block" | "blockEnd" | "parry" | "dodge"
```
- `MatchPhase` gains `"Arena"` between `Endgame` and `Results` at VS-2 (additive; `PacingService:phaseDurations` gains `Arena`).
- `CitizenService:inspect` gains `loyalty: number`, `role: KeyRole?` and `petition: { id: string, text: string, need: ResourceBag?, expiresAt: number }?` (additive).

### G12.2 Server APIs (FORGE-01)
```lua
-- pure, deterministic, no Roblox APIs, injected clock/RNG where needed; FORGE-05's harness requires them directly
SupportModel.score(samples: { SupportSample }, ruler: RulerRecord, config): (number, SupportTier, { [SupportComponent]: number })
SupportModel.offers(keyCitizens: { KeyCitizenRecord }, tier: SupportTier, config): ({ TriggerOffer }, slots: number)
DuelModel.new(config, a: DuellistSetup, b: DuellistSetup, seed: number): DuelState
DuelModel.step(state: DuelState, inputs: { a: DuelInput?, b: DuelInput? }, dt: number): { DuelEvent }
	-- DuelInput = { action: DuelAction?, inRange: boolean, facing: boolean }; DuelService derives inRange/facing from real positions
Caps.check(modifiers: { Modifier }): (boolean, string?)              -- src/shared/Arena/Caps.luau; G12.3 numbers
-- services
LeadershipService:record(kingdom: KingdomId, userId: number?, act: string, magnitude: number?)  -- act ids from config Support.luau
LeadershipService:getMoments(kingdom: KingdomId, userId: number?, limit: number): { LeadershipMoment }
SupportService:getView(kingdom: KingdomId, userId: number): SupportView
ArenaService:getState(): ArenaState
ArenaService.stageChanged: Signal<(ArenaState)>
DuelService.events: Signal<(duelId: string, DuelEvent)>
```
- Producers of acts (BuildingService, ProductionService, MilitaryService, CitizenService, Interaction) call `LeadershipService:record` through `registry:find` and never compute support themselves.
- Support is computed only by SupportModel. Every modifier DuelService applies passes `Caps.check` first; a refusal is logged and the modifier dropped.
- Trigger conditions are evaluated by DuelService from DuelModel events (HP thresholds, stamina out, heavy wind-up, hype full). No random roll exists in the support chain.

### G12.3 Fairness caps (contract; change only with a DECISIONS entry)
| Cap | Value |
|---|---|
| Passive blessing per stat / combined | ≤ +5 % / ≤ +8 % |
| Support triggers per duel (perks + Crowd Rally) | ≤ 3, each once |
| Trigger duration / magnitude | ≤ 8 s / ≤ +10 % (damage reduction, damage, stamina regeneration) |
| Total support bonus on one stat at any moment | ≤ +15 % |
| Support healing per duel | ≤ 10 % of max HP (single trigger ≤ 8 %) |
| Quiet start | no trigger in the first 10 s |
| Same-stat active triggers | do not stack; the stronger applies |
| Effects on the opponent | none (no stun, root, disarm, damage or reveal) |
| Weak support | never below baseline stats |
| Outcome bounds (fairness harness, PROVISIONAL, BRIEF §16.9d) | equal skill Adoring vs Hostile wins 55–65 %; one skill tier better with Hostile beats Adoring ≥ 60 %; no setup > 70 % vs equal-skill baseline |

### G12.4 Client remotes (area `Arena` → FORGE-01; additions to `Kingdom` and `Sim`)
| Remote | Kind | Args → result, or payload |
|---|---|---|
| `Arena.State` / `Arena.GetState` | serverEvent / function | `ArenaState` (public to every player) |
| `Arena.Vote` | function | `(candidateUserId: integer)` → `boolean`; co-rulers of a qualified kingdom, `vote` stage only |
| `Arena.Choose` | function | `(weapon: enum Weapon, armour: enum Armour, triggers: array(enum TriggerId, 3))` → `(ok, reason?)`; champion only, `loadout` stage, triggers ⊆ own offers and ≤ slots |
| `Arena.Action` | event | `(action: enum DuelAction)`; champion only, `duel` stage; burst 8, 12/s |
| `Arena.Events` | serverEvent | batched `{ { t: number, kind: string, side: "a" \| "b", data: { [string]: any }? } }` (hit, parry, stagger, staminaOut, heavyWindup, triggerFired, hype, ended) |
| `Kingdom.Support` / `Kingdom.GetSupport` | serverEvent to the ruler / function | the caller's `SupportView` (in-match meter, perk previews) |
| `Kingdom.FulfilPetition` | function | `(petitionId: string(1,32))` → `(ok, reason?)`; spends the petition's `need` through TreasuryService |

### G12.5 Events (appended to the GameEvents bus by FORGE-05 when VS-2 starts, as D-024)
| Event | Producer | Payload |
|---|---|---|
| `LeadershipAct` | FORGE-01 | (KingdomId, userId?, act, component, delta) |
| `KeyCitizenChanged` | FORGE-01 | (KingdomId, KeyRole, entityId?, loyalty) |
| `ArenaStarted` | FORGE-01 | (ArenaState) |
| `SupportTriggered` | FORGE-01 | (duelId, userId, TriggerId, citizenId?) |
| `DuelEnded` | FORGE-01 | (duelId, winnerUserId, loserUserId, { durationSec, triggersFired, hpLeft }) |

### G12.6 Client and asset hooks
- FORGE-01 `src/client/Controllers/DuelController.luau`: `act(action: DuelAction)`, `getState(): ArenaState`, `events: Signal<(ArenaEvent)>`. It is the only sender of `Arena.Action`. FORGE-04's InputMode binds keys, touch and gamepad to `act`; FORGE-03's arena HUD and FORGE-04's crowd director read `events`.
- FORGE-02 Kit additions: `Kit.arena(): Model` (two stands with `StandA`/`StandB` seat attachments, royal boxes, gate, duel ring), `Kit.crowdFigure(kingdomColor, role: KeyRole?): Model` (≤ 4 parts, client-only), `Kit.armour(armour: Armour, kingdomColor): { Accessory }`, `Kit.weapon(weapon: Weapon): Tool`. Layout gains `arena = { cframe: CFrame, duelRadius: number, spawnA: CFrame, spawnB: CFrame }` at the neutral map centre, visible during the whole match.
- Crowd figures and reactions are client-only (FORGE-04). The server sends no per-figure data; the crowd is derived from `ArenaState`, `Arena.Events` and kingdom population.

## G13. Living kingdom (D-030; design `design/living-kingdom.md`; content `content/SPEC.md`)
Rows marked **VS-1** are part of the first playable. The rest are VS-2 shapes, published now so that the UI and the content can be built in parallel. All changes are additive to G1–G12.

### G13.1 Content (FORGE-00) — VS-1
- **Generated data modules.** `@game/ReplicatedStorage/Game/Content/{Dialogue,Decisions,Consequences,Traits,Names,Occupations,Reputation}` are generated by `tools/content/content.py build` from `games/game-001/content/*.csv`. Never edit them by hand.
- **`Content/ContentQuery`** (pure) provides:
  - `evaluate`
  - `eligibleScenarios`
  - `decisionEffects`
  - `loyaltyDelta`
  - `repeatMultiplier`
  - `REACH`
- **Context.** FORGE-01 builds the context table from the vocabulary in `content/SPEC.md`, e.g. `ctx["kingdom.fed_ratio"]`. A variable the server cannot yet provide stays nil, and a clause on a nil variable is false.

### G13.2 Population (FORGE-01; looks FORGE-02) — VS-1
```lua
-- src/shared/Kingdom/Types.luau (additive)
export type Category = "compassion" | "honor" | "competence" | "courage" | "authority" | "fear"
export type CitizenLook = { skin: number, hair: number, hairColor: number, outfit: number }   -- palette indices, Kit-defined ranges
export type CitizenView = { entityId: EntityId, name: string, occupation: string, job: JobId, traits: { string },
	mood: number, loyalty: number, obedience: number, intent: string, lastMemory: string?, memories: { string },
	family: { string }, friends: { string }, rivals: { string }, hasRequest: boolean, look: CitizenLook }
```
- **Population per match.** `CitizenService` generates the starting population from the match seed using Content `Names`, `Traits` and `Occupations`. Each citizen gets 2–3 traits (never an opposite pair), chemistry −20..+20, loyalty, a household family, 1–3 friends and 0–1 rival. Same seed → same population (spec). VS-1 size: 12 per populated kingdom.
- **Inspect.** `CitizenService:inspect(entityId)` returns `CitizenView`. It is a superset of the G5 fields, so `Sim.Inspect` callers keep working.
- **Looks.** The look travels once per entity in the reliable `spawn` entity event (G4), never in the 10 B snapshot record. `Kit.character(kind, job, kingdomColor, look: CitizenLook?)` gains the optional `look` (FORGE-02; omitted = default look).
- **Population remote** (FORGE-03 job panel, FL-0065). `Kingdom.Population` is a serverEvent to members and `Kingdom.GetPopulation` a function. Both carry `CitizenService:getPopulation(myKingdom)` (G5).

### G13.3 Conversations (FORGE-01 server; FORGE-03 panel; FORGE-04 bubbles) — VS-1
| Remote | Kind | Args → result, or payload |
|---|---|---|
| `Kingdom.Converse` | function | `(entityId: integer)` → `{ entityId, scenarioId, speaker: { name, occupation }, question, options: { { id, text } } }?`. Own kingdom only, ruler only. nil when the citizen has nothing to say. Burst 4, 2/s |
| `Kingdom.Choose` | function | `(entityId: integer, scenarioId: string(1,48), responseId: string(1,48))` → `(ok, { reaction: string, effects: { { kind: string, text: string } } }?, reason?)`. The server re-checks eligibility, then applies `decisionEffects`: cost and resources through TreasuryService, reputation, loyalty with reach, kingdom conditions, consequences, memory. Idempotent per `(entityId, scenarioId)` showing |

- `Sim.Events` gains three kinds, sent to the kingdom's members:
  - `thought` `{ entityId, scenarioId, text, icon: "request" | "concern" | "idea" }`
  - `reaction` `{ entityId, text, tone: "happy" | "angry" | "sad" | "neutral" }`
  - `strike` `{ occupation, on: boolean }`
- At most `Society.openRequests` (PROVISIONAL 3) thought bubbles are open per kingdom at a time. The list is refreshed every 20 s.

### G13.4 Reputation and kingdom conditions (FORGE-01; screen FORGE-03) — VS-1
```lua
ReputationService:get(userId: number): { values: { [Category]: number }, history: { { t: number, category: Category, delta: number, text: string, source: string } } }
ReputationService:apply(userId: number, source: string, delta: { [Category]: number }, text: string)   -- anti-farming per content farm_key; clamps 0..100
```
- `Kingdom` (G2) gains `happiness`, `stability` and `morale` (0–100). They are kingdom conditions and are kept separate from reputation.
- Remotes:
  - `Kingdom.Reputation`: serverEvent to the ruler.
  - `Kingdom.GetReputation`: function returning `{ values, history (latest 30), kingdom: { happiness, stability, morale } }`.
- Consequence thresholds, rates and windows live in config `Society.luau` (FORGE-01), never in code.

### G13.5 Construction on plots (FORGE-01 logic; FORGE-02 Layout and Kit; FORGE-03 menus) — VS-1
- **Build slots (G10.1, additive).** `Layout.plots[k].buildSlots = { { id: string, center: Vector3, size: "S" | "M" | "L", rot: number } }`, at least 8 per kingdom. WorldService tags each slot's ground marker `BuildSlot` with attribute `SlotId`.
- **Remotes.**
  - `Build.PlaceSlot`: `(slotId: string(1,32), type: enum BuildingType)` → `(buildingId?, reason?)`.
  - `Build.Slots` / `Build.GetSlots`: own kingdom's slots `{ id, size, occupiedBy: number? }`.
  - `Build.Place` stays as it is.
- **BuildingType (G2, additive, used from VS-2):** `"mine" | "blacksmith" | "market" | "infirmary" | "granary" | "shrine"`. The Kit returns a labelled part-built stand-in until FORGE-02 models each type.
- **Levels and times.** `Costs.building(type, level).buildSeconds` drives build and upgrade time, scaled by the builders on site. Barracks proposal: 8 / 18 / 35 / 60 s (FORGE-03, PROVISIONAL). `Kit.build(type, level, …)` must differ visibly per level (FORGE-02).
- **One source per number (FORGE-05 finding L4, 2026-10-12).**
  - `Costs.luau` (FORGE-03) is canonical for **cost, buildSeconds and the number of levels** (`Costs.maxLevel(type)`).
  - `Buildings.luau` (FORGE-01) holds only **gameplay stats** per type and level, for exactly levels `1..Costs.maxLevel(type)`: housing/popCap, storage, production rate, recruit cap and `requires` (e.g. keep level).
  - `Buildings.luau` never repeats a cost or a time, and the server sim reads costs and times from `Costs`.
  - UI reads costs from `Costs` and stats from `Buildings`.
  - FORGE-05 adds an integration spec: every (type, level) in one file exists in the other, and no field appears in both.
- **Fit rule (FORGE-05 finding M2).** A structure fits a slot when `Kit.footprint(type, Costs.maxLevel(type))` fits inside `Layout.slotSizes[slot.size]` on both axes (slot-local X = width, Y = depth).
  - The rule is implemented once, as the pure `src/shared/Build/Fit.luau` (FORGE-01: `Fit.fits(type, size): boolean`, `Fit.typesFor(size): { BuildingType }`).
  - The server (`Build.PlaceSlot`) and the plot picker both call it. Nobody re-implements it.
  - The rule is **purely physical**: any structure whose footprint fits may use the slot. With today's footprints, S fits house, lumber camp, quarry, storehouse and watchtower; M also fits barracks; L also fits farm. That is accepted for VS-1.
  - The class list in `Layout.luau` comments is placement guidance, not a rule. Placing resource buildings near their nodes is a gameplay choice for the player.
  - Until `Fit.luau` lands, FORGE-03 may keep an interim client copy (`UI/SlotFit`) with the same rule. It switches to `Fit.typesFor` when `Fit.luau` lands, and FORGE-05 checks on review that the two agree.

### G13.6 Throne, camera and selection — VS-1
- **Throne (FORGE-02).** `Kit.build("keep", level, "complete", color)` contains a `Seat` named `Throne` on a raised dais, visible from the aerial camera.
- **Ruler seating (FORGE-01).** After spawn (G3), KingdomService seats the ruler on the throne. In management mode the ruler stays seated. Walk mode (optional in VS-1) unseats.
- **Camera (FORGE-04).** `RulerCameraController` has two modes. They keep the G4.1 names:
  - `overview` (the management view, default): aerial camera with pan, zoom (≈ 40–220 studs) and rotate. PC uses WASD, drag, wheel and Q/E; touch uses drag, pinch and two-finger rotate. The camera is bounded to the map, and the camera's focus point is what loads under streaming.
  - `follow`: walk mode, third person.
- **Selection (FORGE-04).** `InputModeController.selected: Signal<(kind: "citizen" | "building" | "slot" | "none", id: number | string)>`. A tap or click raycasts and resolves the selection:
  - citizen: through `EntityController:pick`;
  - building: through the `BuildingId` attribute;
  - slot: through the `BuildSlot` tag.

  FORGE-03 panels listen to this signal. Nobody else raycasts for selection.

### G13.7 Debug presets (FORGE-05) — VS-1
`DebugCommands` (Studio only) offers:
- `rep.set <category> <n>`
- `citizen.request <entityId> <scenarioId>`
- `kingdom.setFed <ratio>`
- `strike.start <occupation>`
- `population.reseed <seed>`

## Changelog
- v0.4-g4 (2026-10-12) FORGE-00: G13.5 clarifications: one source per number (`Costs` = cost/time/levels, `Buildings` = stats only) and one shared `Build/Fit` rule. G4.1 camera modes renamed: `overview` is the aerial management default and `follow` is walk mode. In explore mode a tap selects. The `Kingdom.Population` remote is added. G13 living kingdom (D-030) is additive. VS-1 rows are effective now: content modules and ContentQuery; generated population with `CitizenView` and `look`; `Kingdom.Converse` and `Kingdom.Choose`; the thought, reaction and strike events; ReputationService and kingdom conditions; build slots and `Build.PlaceSlot`; throne seat, aerial camera and the selection signal; debug presets. New BuildingTypes take effect from VS-2.
- v0.4-g3 (2026-10-12) FORGE-00: G12 Crown Arena and support added as a **draft for VS-2** (D-029). Nothing in G1–G11 changes for VS-1. G3's PROVISIONAL victory default is superseded at VS-2 by the Crown Arena (G12, BRIEF §18).
- v0.4-g2 (2026-10-12) FORGE-00: FORGE-01 clarifications added to G3, G5 and G7 (countdown, job semantics, no VS-1 treasury cap, PROVISIONAL victory/diplomacy defaults); game remote areas `Treasury` and `Feedback`.
- v0.4-g2 (2026-10-12) FORGE-00, review fixes (D-024 to D-028):
  - Breaking changes:
    - snapshot wire format v2 (header, chunks ≤ 900 B, 10 B records);
    - `Sim.EntityEvent` replaced by batched `Sim.Events`, plus `Sim.GetEntities`;
    - `Build.Place` takes `(type, position, rot)`;
    - game areas `Economy` → `Treasury` and `Experience` → `Feedback`;
    - Kit is primitive Parts only, with ≤ 8-part rigs.
  - Additive changes:
    - G1 world/assets mounts and unique names;
    - Teams, party, spawn and slice rules;
    - G4.1 client API;
    - `setFedRatio`, `inspect`, `spendUpTo`, `Costs.unit`;
    - G8 client remote table;
    - G10 `footprint`, `regalia`, `regionMarkers`, `NEUTRAL_COLOR`, `setKingdomColor`, `Rally`, `WorldService.ready`;
    - G10.1 Layout schema;
    - G11 `phaseDurations(mode)`;
    - `Building.placedBy`, `Kingdom.regions`.
- v0.4-g1 (2026-10-12) FORGE-00: first game-001 contracts for VS-1.
