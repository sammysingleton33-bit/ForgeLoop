# game-001 contracts: AI Kingdoms (v0.4-g11c, 2026-10-19; G12 is a VS-2 draft; G13 VS-1 rows are effective; G13.8 follows FL-0079/FL-0088)

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
MatchService.mode: "slice" | "match"           -- read-only; config Match.mode, PROVISIONAL (v0.4-g9c, D-044 (5)); "match30" only if FL-0096 picks it
KingdomService:getKingdom(id: KingdomId): Kingdom
KingdomService:getKingdomOf(player): KingdomId?
KingdomService:assign(player, preferred: KingdomId?): KingdomId?   -- nil when no kingdom can take the player (v0.4-g8)
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
  - **Full match by default (v0.4-g11, D-053, #187).** `Match.mode` defaults to `"match"` and `Match.pvp.enabled` to true. Governors rule every kingdom without a human from match start. A kingdom whose keep falls is eliminated: its human rulers become spectators (G8 `Match.Spectate`), and `join` answers `eliminated` for it. Each kingdom is capped at `Citizens.maxPerKingdom` (60) citizens and `Military.maxSoldiers` (15) soldiers, living plus training (D-055). Studio debug: `match.mode slice|match` restarts the match in that mode, so the slice above stays testable.
    - `MatchService:registerArena(handler?)`: `handler.beginArena(qualifiers: { KingdomId }): boolean` and `handler.cancelArena(reason: string)?`. It is called once when Endgame ends with two or more kingdoms standing. `true` means the duel runs while the match waits in Endgame. `false`, an error or no handler gives the Crown Points result at once. `MatchService:arenaEnded(winner: KingdomId?): boolean` ends the match with reason `arena`. A winner outside the duel, a nil winner, or no report within `Match.arena.maxSeconds` (600) falls back to Crown Points. `MatchPhase` gets its `Arena` value with G12 (FL-0071); until then the duel runs inside `Endgame`.
    - The `MatchEnded` summary carries `reason: "conquest" | "time" | "objective" | "arena"`. This is a summary field, not part of the G9 payload.
    - Players turned away with `match_full` wait in `Match.waiting` and are seated after the returning players in the next world.
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
- `Sim.GetEntities` (function) `(afterId?) -> (buffer, nextAfterId?)`: the client calls it after connecting its handlers. Each call returns one page of at most 49 "full" records (spawn record + current state, ≤ 900 B; our G4 budget, not an engine limit) with `id > afterId`, in ascending id order. `nextAfterId` is nil on the last page; the client calls again with it until it is nil. `afterId` is nil or an integer 0..65535 (v0.4-g10b, #127).

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
InputModeController:set(mode: "explore" | "build" | "edit"); .mode; .changed: Signal  -- FORGE-04 (FL-0053/FL-0090; "edit" FL-0121, G13.9); "command" is VS-2
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
- **Births (D-045).** A birth takes no treasury food while ProductionService runs. It needs `fedRatio` ≥ `Society.food.wellFedAtLeast` and a free bed (PROVISIONAL).
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
| `Kingdom.State` / `Kingdom.GetState` | serverEvent / function | `{ kingdoms: { Kingdom }, mine: KingdomId?, diplomacy? }` on change / on request. `diplomacy` (v0.4-g11b) is the viewer's relations, open proposals and asks, the shape FORGE-03 pinned in #182 |
| `Kingdom.Diplomacy` (v0.4-g11b, D-054) | function | `(action: "declareWar" \| "proposePeace" \| "acceptPeace", target: KingdomId(1,16))` → `(ok, tag?)`; burst 3, 1/s. `declareWar` from the senior ruler → `(true, "declared")`; from another ruler → `(true, "asked")`, and the senior gets `Kingdom.WarAsk`. `proposePeace`: any ruler. `acceptPeace`: senior only, else `(false, "not_senior")`. A ruler seated after Founding began is locked from `declareWar`/`acceptPeace` for 120 s: `(false, "newcomer_lock")`. Sim codes pass through: `invalid_args`, `unknown_kingdom`, `grace_period`, `already_at_war`, `peace_cooldown`, `not_at_war`, `no_proposal`, `not_in_match`, `match_not_active`, `kingdom_eliminated`. The senior is the longest-seated present ruler and loses seniority after 90 s idle. Governors are exempt |
| `Kingdom.WarAsk` (v0.4-g11b) | serverEvent | `(requesterUserId, requesterName, target: KingdomId)` to the senior ruler when a co-ruler asks for war |
| `Kingdom.Gather` | function | `(nodeId: string(1,32))` → `(true, ResourceId, amount)` or `(false, errorCode)`; the server checks distance and cooldown |
| `Kingdom.SetJobQuota` | function | `(job: "farmer" \| "woodcutter" \| "miner" \| "builder", count: integer(0,50))` → `(ok, errorCode?)` (calls `requestWorkers`). Haulers take the citizens left over and soldiers come from the barracks, so neither has a quota |
| `Match.State` / `Match.GetState` | serverEvent / function | `(phase, endsAtServerTime?, startedAtServerTime)` |
| `Match.Ended` | serverEvent | the `MatchEnded` payload (G9) |
| `Match.Spectate` (v0.4-g11) | serverEvent | `(spectating: boolean, info?: { reason: "eliminated" \| "match_full", kingdomId: KingdomId?, by: KingdomId?, standing: { KingdomId } })`. `true` when a ruler's kingdom falls, or for a player arriving or returning with no seat; `false` when seated again in the next match. `Kingdom.State.mine` is nil for a spectator, and a fallen kingdom has `alive = false` |
| `Build.Buildings` / `Build.GetBuildings` | serverEvent / function | changed `{ Building }` per tick / all buildings |
| `Build.CanPlace` | function | `(type: enum, position: vector3, rot: integer(0,3))` → `(boolean, string?)`; burst 10, 10/s (ghost tint) |
| `Build.Place` | function | same args → `(buildingId?, reason?)` |
| `Build.Upgrade` | function | `(buildingId: integer)` → `(boolean, string?)` |
| `Army.Recruit` | function | `(barracksId: integer, unitType: enum{"soldier"}, count: integer(1,10))` → `(boolean, string?)`. Reasons include `army_cap` (v0.4-g11, D-055: 15 standing soldiers per kingdom, living plus training, checked before `recruit_cap`) |
| `Army.Command` | event | `(unitIds: array(integer, 50), kind: enum, targetPos: optional(vector3), targetId: optional(string(1,32)))` |
| `Army.Objectives` / `Army.GetObjectives` | serverEvent / function | `ObjectiveService:list()` |
| `Sim.Snapshot`, `Sim.Events`, `Sim.GetEntities` | see G4 | |
| `Sim.Focus` (v0.4-g11c, D-055 (5)) | event (client → server) | `(focus: Vector3)`. Y is ignored and X/Z are clamped to the map; burst 8, 5/s. Used **only** for interest selection, never for authority. A focus older than `Match.interest.focusStaleSeconds` (3 s) falls back to the character. In the full match each player's `Sim.Snapshot` is interest-selected: entities within `nearRadius` (200) go out every snapshot, the rest every `farEvery`th (5) tick, and the player's own soldiers always. The slice still broadcasts everything |
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
| `BuildingMoved` (v0.4-g9i, G13.9) | FORGE-01 | (Building, player?, from: { position: Vector3, rot: number }, slotId: string?). Never re-fires `BuildingPlaced`. |
| `ResourceGathered` | FORGE-01 | (player?, KingdomId, ResourceId, amount, source: "ruler" \| "citizen") |
| `UnitsRecruited` | FORGE-01 | (player, KingdomId, count) |
| `ObjectiveCaptured` | FORGE-01 | (objectiveId, KingdomId) |
| `KingdomEliminated` | FORGE-01 | (KingdomId, by: KingdomId?) |
| `CitizenAnswered` (declared in `Contracts/GameEvents` by #109; fired from FL-0107; D-044 (3)) | FORGE-01 (ConversationService) | (player, KingdomId, citizenId: number, decisionId: string, secondsOpen: number?), once per accepted `Kingdom.Choose`. **Attribution:** the answering ruler only. The citizen id stays out of analytics and onboarding info (D-050 (5), #124). |
| `ConsequenceChanged` (v0.4-g10c; declared in `Contracts/GameEvents` by FORGE-05, fired by FORGE-01; D-052 (5), #125) | FORGE-01 (ConsequenceService) | (kingdomId: KingdomId, rule: "strike" \| "shortage" \| "riot" \| "rebellion", on: boolean, info: { occupation: string?, buildingId: number?, instigator: number?, entityIds: { number }?, count: number }). Exactly once per start and once per end, with the same values as `ConsequenceService.changed`, except that a `rebellion` fires only its start (one-shot with a cooldown, gated off in VS-1). A rule still running when its kingdom is eliminated, or when a new world resets the service, never fires its end, so listeners treat a start without an end as possible and clear their notices on elimination or reset; `count` is the number of citizens, or 1 for a building. Listener: FORGE-04's notices, one per start and end to that kingdom's rulers (texts are FORGE-04's). Server bus only. |
| `WarChanged` (v0.4-g11c, FL-0134) | FORGE-01 (MatchHost) | (kingdomId, otherId, atWar: boolean, by: userId?). WarDeclared: kingdomId = declarer, otherId = target, atWar true. PeaceMade: kingdomId = acceptor, otherId = proposer, atWar false. `by` is the ruler, nil for a governor. Nothing fires for pairs broken by elimination |
| `SiegeChanged` (v0.4-g11c) | FORGE-01 (Sim/WarWatch) | (kingdomId, on: boolean, { byKingdomIds, buildingId }). Once per start (first enemy keep damage after a quiet spell) and once per end (20 s without keep damage) |
| `RaidChanged` (v0.4-g11c) | FORGE-01 (Sim/WarWatch) | (kingdomId, on: boolean, { byKingdomIds, count, position: Vector3 }). Once per start and once per end (10 s without threats). `position` is the threats' centroid on the ground plane. A fallen kingdom ends no siege or raid; listeners clear on MatchEnded |
| `MatchEnded` | FORGE-01 | ({ winner: KingdomId?, standings: { { kingdom: KingdomId, crownPoints: number } }, durationSec: number }) |

- Producers fire each event exactly once, per framework rules.
- FORGE-04 (announcer, onboarding, analytics) and FORGE-03 subscribe and never call producer internals.
- Client UI learns through G8 remotes (e.g. the slice summary uses `Match.Ended`), never from G9 directly.
- **Funnel attribution:**
  - "spawn" = `KingdomJoined`;
  - "first build placed" credits `Building.placedBy`;
  - building completions and captures credit every current member of the kingdom.
  - `ResourceGathered`: a ruler gather (`source = "ruler"`) credits that player; a citizen deposit credits every current member. So "first gather" means the kingdom's economy started (D-044 (2)).
  - "first recruit" credits the player named in `UnitsRecruited`.
  - Attribution is implemented once, in `Feedback/Signals.luau` (`Signals.subjects`), and onboarding and analytics both use it. Nobody re-implements it.
  - **Funnel order (v0.4-g6).** The analytics funnel credits a step to a player only if that player already holds the previous step.
    - Example: a co-ruler who never placed a building is not credited "first building complete" or "first capture".
    - Reason: Roblox counts skipped funnel steps as completed, so kingdom-wide credit would inflate the steps before it.
    - The G9 events themselves are unchanged, and onboarding and the announcer still react to kingdom-wide events.

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
	-- ≤ 11 parts (anchored root, torso, head, 2 arms, 2 legs, tool, + Hair welded to Head, no motor; D-032; + at most 2 rigid detail parts for headwear or tool, welded to Head or Tool, no motor, D-048); Motor6Ds named after the moving part;
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
    - **Client-reported steps (`clientActions`, D-044 (4)).** These are allowed only for UI moments that have no server event (`CitizenInspected`, `GoalAcknowledged`). They complete only the reporting player's current step and grant nothing. They may feed that player's onboarding funnel step, but no other analytics event. `CitizenAnswered` moves to the G9 event once it exists.
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
- FORGE-02 Kit additions: `Kit.arena(): Model` (two stands with `StandA`/`StandB` seat attachments, royal boxes, gate, duel ring), `Kit.crowdFigure(kingdomColor, role: KeyRole?): Model` (≤ 4 parts, client-only; a figure with a `role`, i.e. one of the six key citizens, may have ≤ 8 parts for its readable prop, v0.4-g11a), `Kit.armour(armour: Armour, kingdomColor): { Accessory }`, `Kit.weapon(weapon: Weapon): Tool`. Layout gains `arena = { cframe: CFrame, duelRadius: number, spawnA: CFrame, spawnB: CFrame }` at the neutral map centre, visible during the whole match.
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
- **Runtime semantics** live in `content/SPEC.md` §6–§8 (lands with FL-0083, PR #53). The server follows them:
- **ContentQuery API added by FL-0083 follow-ups (PR #67, #-next).** All of these are pure:
  - `fireDecision(..., listeners?)` returns decayed, clamped, apply-as-given values. Each listener gets its final loyalty.
  - `fireAction(event, ctx, rulerHistories, creditedRulers, kingdomHistory, now, listeners?)` is the single anti-farming point for `actions.csv`. **One call per event, never one per ruler.**
    - `rulerHistories` maps userId to that ruler's farm history. `creditedRulers` lists the rulers who get the reputation: the attributed actor, or every co-ruler for kingdom-wide events.
    - Each firing returns `rulers = { { ruler, multiplier, rep } }`, each ruler decayed by their own history. Kingdom conditions and listener loyalty are computed and recorded once per firing.
    - A missing history, a ruler listed twice, or a citizen repeated across listeners is an error, and nothing is recorded (v0.4-g7).
  - `citizenKey(citizen)` resolves `id`, then `entityId`, then `key`.
  - `LOYALTY_CLAMP` = speaker 25, family/friends/rivals 10, kingdom 5.
  - `startLoyalty(chemistry)` = `floor(50 + chemistry/4 + 0.5)`.
  - `choicePreview(scenarioId, responseId, fillNames)` returns `{ cost?, risks? }` exactly as the G13.3 option extras.
    - `fillNames` is **required**: the conversation's `{ name, ruler, kingdom, occupation }`, plus `family`, `friend` and `rival` when the scenario uses them. A nil `fillNames` is an error.
    - `cost` is omitted when the answer is free. To pay, use `decisionEffects(response.decision).cost`, which is always a table, never the preview.
  - `choiceRisks(decisionId, fillNames)` returns `{ { text, chance } }` for consequences with chance < 1. The text is fully filled. The panel shows the chance; content text never repeats it (`{chance}` is refused in risk notices).
  - `repeatMultiplier` returns 0 once 32 firings are in the window (`MAX_FARM_HISTORY`).
  - **Presentation (v0.4-g10, SPEC v1.5; all optional, ignoring them changes no gameplay):**
    - `reactionFor(responseId, loyalty?)` returns `{ text, tone, emotion?, expression?, gesture?, delivery?, bubble_s?, band }`. It picks the `high` band when loyalty ≥ `LOYALTY_BANDS.high` (70, PROVISIONAL) and that band has text, `low` when loyalty ≤ `LOYALTY_BANDS.low` (30), and otherwise `base`. **Servers send this text as the G13.3 reaction.**
    - `questionFor(scenarioId, citizen, ctx)` returns `{ text, emotion?, expression?, gesture?, delivery?, variantId? }`: the first matching question variant (`trait:` or `cond:` selector), or else the base question.
    - `presentation(scenarioId)` returns `{ urgency?, delivery_mode?, thought_bubble_s? }`.
    - `GESTURE_CUE` maps a gesture to a G13.3 cue (bow, salute, cower, celebrate, grumble).
    - Clients may show emotion and expression on the G13.8 portrait (FORGE-03/FORGE-04). Nothing waits on them.
  - Servers use these and do not re-implement decay, clamps or start loyalty.
  - `ContentQuery.fireDecision` is the single anti-farming point. It decays gains in reputation, loyalty, kingdom conditions and chemistry; losses are never decayed. Apply its result as given.
  - Scenarios marked `locked` are offered only after an `unlock_scenario` consequence. The server sets `CitizenState.unlocked[id]`.
  - Co-rulers:
    - a conversation uses the acting ruler's reputation;
    - thought selection uses the highest reputation among the co-rulers, and `decision.<id>` is true if any co-ruler chose it;
    - farm history is kept per ruler for reputation, and per kingdom for loyalty and conditions.
  - Action rows map their audience to loyalty reach as SPEC §6.9 says. Civilians and soldiers are split by job.

### G13.2 Population (FORGE-01; looks FORGE-02) — VS-1
```lua
-- src/shared/Kingdom/Types.luau (additive)
export type Category = "compassion" | "honor" | "competence" | "courage" | "authority" | "fear"
export type CitizenLook = { skin: number, hair: number, hairColor: number, outfit: number }   -- palette indices, Kit-defined ranges
export type CitizenView = { entityId: EntityId, name: string, occupation: string, job: JobId, traits: { string },
	mood: number, loyalty: number, obedience: number, intent: string, lastMemory: string?, memories: { string },
	family: { string }, friends: { string }, rivals: { string }, familyIds: { EntityId }, friendIds: { EntityId }, rivalIds: { EntityId },
	hasRequest: boolean, look: CitizenLook }  -- *Ids aligned index for index with the name lists; look is always a valid CitizenLook (Kit.normalizeLook) (v0.4-g10b, #127)
```
- **Population per match.** `CitizenService` generates the starting population from the match seed using Content `Names`, `Traits` and `Occupations`. Each citizen gets 2–3 traits (never an opposite pair), chemistry −20..+20, loyalty, a household family, 1–3 friends and 0–1 rival. Same seed → same population (spec). VS-1 size: 12 per populated kingdom.
- **Chemistry and memories.** Chemistry is rolled once per citizen and may drift at most ±5 from its rolled value (`ContentQuery.driftChemistry`). Memories set by content are **pinned**: the G5 cap of 8 never evicts them.
- **Inspect.** `CitizenService:inspect(entityId)` returns `CitizenView`. It is a superset of the G5 fields, so `Sim.Inspect` callers keep working.
- **Soldier kingdom marker (D-033(3), FORGE-05 colour-vision check).** Soldiers wear a helmet, so their 9th part is a **helmet crest shaped per kingdom**, matching the tower style: crimson spire, azure square, emerald plume, gold dome. That keeps friend and foe distinguishable without colour. `Kit.character(kind, job, kingdomColor, look?, kingdom: KingdomId?)` takes an optional `kingdom` for this. FORGE-01 passes it for soldiers. VS-1 acceptance requires it.
- **Looks.** Hair is the 9th rig part, welded to the Head (D-032). The look travels once per entity in the reliable `spawn` entity event (G4), never in the 10 B snapshot record. `Kit.character(kind, job, kingdomColor, look: CitizenLook?)` gains the optional `look` (FORGE-02; omitted = default look).
- **Population remote** (FORGE-03 job panel, FL-0065). `Kingdom.Population` is a serverEvent to members and `Kingdom.GetPopulation` a function. Both carry `CitizenService:getPopulation(myKingdom)` (G5), including `quotaRev: number`, which rises with every accepted quota change (v0.4-g10b, #127).

### G13.3 Conversations (FORGE-01 server; FORGE-03 panel; FORGE-04 bubbles) — VS-1
| Remote | Kind | Args → result, or payload |
|---|---|---|
| `Kingdom.Converse` | function | `(entityId: integer)` → `{ entityId, scenarioId, speaker: { name, occupation }, question, options: { { id, text } } }?`. Own kingdom only, ruler only. nil when the citizen has nothing to say. Burst 4, 2/s |
| `Kingdom.Choose` | function | `(entityId: integer, scenarioId: string(1,48), responseId: string(1,48))` → `(ok, { reaction: string, effects: { { kind: string, text: string } } }?, reason?)`. The server re-checks eligibility, then applies `decisionEffects`: cost and resources through TreasuryService, reputation, loyalty with reach, kingdom conditions, consequences, memory. Idempotent per `(entityId, scenarioId)` showing |

- `Sim.Events` gains three kinds, sent to the kingdom's members:
  - `thought` `{ entityId, scenarioId, text, icon: "request" | "concern" | "idea" }`
  - `reaction` `{ entityId, text, tone: "happy" | "angry" | "sad" | "neutral" }`
  - `strike` `{ occupation, on: boolean, entityIds: { EntityId } }`. `entityIds` lists exactly the citizens whose strike state changed (the server strikes only the least loyal share of an occupation). Clients mark only those citizens and never fan out by occupation (v0.4-g6).
    - **Riot (v0.4-g10c, D-050 (1d), #125).** A `strike` whose `occupation` is `riot` (`EventCodec.RIOT`; no real occupation has that id) marks a riot: `entityIds` are the citizens who started or stopped rioting. Rioters are not on strike. Clients show their own riot placard and never pass it to strike handlers. While a riot burns a building, its model carries the attribute `Burning = true`, which is absent otherwise.
  - `cue` `{ entityId?, entityIds: { EntityId }?, occupation?, cue: string }` for consequence cues. Vocabulary: celebrate, grumble, salute, bow, cower, strike_placard, work_fast, rest, hammer. Unknown cues fall back to the reaction tone.
    - An occupation-wide or kingdom-wide cue that should show on citizens carries the affected ids in `entityIds`, chosen by the server.
    - A cue with neither `entityId` nor `entityIds` shows only on the HUD or the keep, never on citizens.
    - Lists are bounded by the kingdom's population.
- Options from `Kingdom.Converse` may also carry `cost: ResourceBag?` and `risks: { { text: string, chance: number } }?`, both from `ContentQuery.choicePreview`. Every risk is shown before the player chooses (model decision 7).
- At most `Society.openRequests` (PROVISIONAL 3) thought bubbles are open per kingdom at a time. The list is refreshed every 20 s.

### G13.4 Reputation and kingdom conditions (FORGE-01; screen FORGE-03) — VS-1
```lua
ReputationService:get(userId: number): { values: { [Category]: number }, history: { { t: number, category: Category, delta: number, text: string, source: string } } }
ReputationService:apply(userId: number, source: string, delta: { [Category]: number }, text: string)   -- delta is already decayed by ContentQuery.fireDecision; clamps 0..100
```
- `Kingdom` (G2) gains `happiness`, `stability` and `morale` (0–100). They are kingdom conditions and are kept separate from reputation.
- **Time units.** Every history and memory time `t` is **server time**, on the same scale as G3 `endsAt` (`workspace:GetServerTimeNow()`). The server converts the sim's injected clock to that scale. Clients show `GetServerTimeNow() - t` as "x min ago". Match-relative times appear only where a field says so explicitly.
- Remotes:
  - `Kingdom.Reputation`: serverEvent to the ruler.
  - `Kingdom.GetReputation`: function returning `{ values, history (latest 30), kingdom: { happiness, stability, morale } }`.
- Consequence thresholds, rates and windows live in config `Society.luau` (FORGE-01), never in code.
- **Reputation action events.** `content/reputation/actions.csv` fires on these events, all produced by FORGE-01 and appended to the GameEvents bus as D-024 did:
  - VS-1: `FoodShortage`, `RulerVisited`, `ObjectiveLost`, `PhaseEndedWellFed`.
  - VS-2: `RaidDefended`, `RaidAbandoned`, `EnemyAttacked`, `EnemyFarmsBurned`, `TruceBroken`, `DeserterExecuted`, `DeserterForgiven`.
  - Suggested payloads are in SPEC §8.
  - Fear relaxes over time at a rate in `Society.luau`, so fear is not one-way.

### G13.5 Construction on plots (FORGE-01 logic; FORGE-02 Layout and Kit; FORGE-03 menus) — VS-1
- **Build slots (G10.1, additive).** `Layout.plots[k].buildSlots = { { id: string, center: Vector3, size: "S" | "M" | "L", rot: number } }`, at least 8 per kingdom. WorldService tags each slot's ground marker `BuildSlot` with attribute `SlotId`.
- **Remotes.**
  - `Build.PlaceSlot`: `(slotId: string(1,32), type: enum BuildingType)` → `(buildingId?, reason?)`.
    - **Turn (v0.4-g9h, additive; the user's first Studio feedback).** A third, optional argument, `turn: integer(0,3)?`, gives quarter turns relative to the slot's facing. Omitted or 0 keeps today's behaviour, facing the street. The building's `rot` = `(slot.rot + turn) % 4`, replicated and rebuilt exactly as for `Build.Place`.
      - The turned footprint must fit. `Fit.fits(type, size, turn?)` swaps the footprint's axes for odd turns, so a half turn always fits and a quarter turn fits only when the swapped footprint fits; otherwise the reason is `does_not_fit`.
      - The plot picker offers only the turns that fit, and its ghost shows the facing.
      - Owners: FORGE-01 (server and `Fit`), FORGE-03 (picker Turn control).
    - Plots take only the building types that sit on a plot. `wall` and `gate` are line structures (VS-2, placed on territory lines). The server refuses them on a plot with reason `not_on_plot`, even though they fit physically. Fit stays purely physical; this is placement policy, and the server enforces it, not only the picker (v0.4-g9a, #89 L3).
  - `Build.Slots` / `Build.GetSlots`: own kingdom's slots `{ id, size, occupiedBy: number? }`.
  - `Build.Place` stays as it is.
- **BuildingType (G2, additive, used from VS-2):** `"mine" | "blacksmith" | "market" | "infirmary" | "granary" | "shrine"`. The Kit returns a labelled part-built stand-in until FORGE-02 models each type.
- **Levels and times.** `Costs.building(type, level).buildSeconds` drives build and upgrade time, scaled by the builders on site. Barracks proposal: 8 / 18 / 35 / 60 s (FORGE-03, PROVISIONAL). `Kit.build(type, level, …)` must differ visibly per level (FORGE-02).
- **One source per number (FORGE-05 finding L4, 2026-10-12).**
  - `Costs.luau` (FORGE-03) is canonical for **cost, buildSeconds and the number of levels** (`Costs.maxLevel(type)`).
  - `Buildings.luau` (FORGE-01) holds only **gameplay stats** per type and level, for exactly levels `1..Costs.maxLevel(type)`: housing/popCap, storage, production rate, barracks `bunks` (D-041; soldiers sleep in bunks, never in beds) and `requires` (e.g. keep level).
  - `Buildings.luau` never repeats a cost or a time, and the server sim reads costs and times from `Costs`.
  - UI reads costs from `Costs` and stats from `Buildings`.
  - FORGE-05 adds an integration spec: every (type, level) in one file exists in the other, and no field appears in both.
- **Fit rule (FORGE-05 finding M2).** A structure fits a slot when `Kit.footprint(type, Costs.maxLevel(type))` fits inside `Layout.slotSizes[slot.size]` on both axes (slot-local X = width, Y = depth).
  - The rule is implemented once, as the pure `src/shared/Build/Fit.luau` (FORGE-01: `Fit.fits(type, size): boolean`, `Fit.typesFor(size): { BuildingType }`).
  - The server (`Build.PlaceSlot`) and the plot picker both call it. Nobody re-implements it.
  - The rule is **purely physical**: any structure whose footprint fits may use the slot. With today's footprints, S fits house, lumber camp, quarry, storehouse and watchtower; M also fits barracks; L also fits farm. That is accepted for VS-1.
  - The class list in `Layout.luau` comments is placement guidance, not a rule. Placing resource buildings near their nodes is a gameplay choice for the player.
  - The interim client copy (`UI/SlotFit`) is gone: since #88 the plot picker calls `Fit.typesFor` (D-038).

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

### G13.8 Cinematic conversations (D-036; first version after FL-0079 and FL-0088 land)
- **Server (FORGE-01).**
  - The `Kingdom.Converse` result gains `look: CitizenLook`, `job`, `position: Vector3` (the citizen's current position) and `kingdom`.
  - While a conversation is open, the citizen is **held**: its intent reads "Talking (with the ruler)", it stops moving, and it turns to face **the ruler's character** (server-side; the server cannot know the client camera). The conversation camera (FORGE-04, `focusOn`) places itself in front of the citizen's face (v0.4-g9e, ruling on #108). The hold lasts at most `Society.conversationHoldSec` (PROVISIONAL 30 s) or ends at `Kingdom.EndConversation(entityId: integer) -> boolean`, a new function remote (own kingdom, rate-limited).
  - After `Kingdom.Choose`, the hold lasts until the client closes the stage (`Kingdom.EndConversation`), **at most 12 s** (= the UI's longest reading time), so the citizen stays framed while the reaction is read. An emergency (alarm, attack) or the ruler leaving still releases it at once (v0.4-g9f, ruling on the B14 gate).
  - **Presentation tags (optional, v0.4-g10; SPEC v1.5).**
    - The `Kingdom.Converse` result may carry `presentation = { emotion?, expression?, gesture?, delivery?, urgency?, variantId? }`. It comes from `ContentQuery.questionFor` / `presentation`, and the question text is the variant's, filled.
    - A successful `Kingdom.Choose` result may carry `tone`, `emotion?`, `expression?`, `gesture?`, `delivery?`, `bubble_s?` and `band?` ("base" | "high" | "low") next to `reaction`, from `ContentQuery.reactionFor(responseId, loyalty)`. The reaction text is the band's.
    - Every field is optional. A client that ignores them shows plain text, and gameplay never depends on them.
    - The server sends only the enum values that SPEC v1.5 validates; no free text beyond what is filled from content.
    - Producer: FORGE-01 (FL-0110). Consumer: FORGE-03 (FL-0111), and FORGE-04's poses through `GESTURE_CUE`.
- **Portrait (FORGE-02).** `Kit.portrait(kind, job, kingdomColor, look, kingdom?) -> Model` returns the same ≤ 9-part rig as `Kit.character`, with the same look. It also carries a `PortraitFocus` attachment (head and shoulders) for a ViewportFrame camera. The portrait and the world rig must look identical.
- **UI (FORGE-03).** `ConversationController`:
  - The portrait ViewportFrame rises from the bottom (about 0.35 s).
  - It shows a speech bubble with the question, then 2–4 choices with cost and risk chips.
  - It then shows the reaction text and the consequence chips, and closes.
  - The world stays visible: no full-screen cover, dim at most 20 %.
  - It fires `ConversationController.opened(entityId, position)` and `.closed(entityId)`.
- **Camera and presentation (FORGE-04).**
  - On `opened`, `RulerCameraController:focusOn(position, { duration = 0.6 })` eases to about 25–35 studs from the citizen, framing them off-centre so the portrait does not cover them. On `closed`, `RulerCameraController:restore()` returns to the saved overview.
  - A reduced-motion setting cuts instantly instead.
  - Reaction poses and emotes play on the portrait and the world rig, keyed by the reaction tone or emotion.
- **Content (FORGE-06).** Lines are written for this presentation: short questions and reactions, with optional emotion and gesture metadata (SPEC columns added by FORGE-00).
- **Integration (FORGE-05).** Studio rows on STUDIO_PLAYTEST: focus and return, portrait matches the world look, a choice applies its effects, closing mid-conversation releases the hold.

### G13.9 Base editing (FORGE-01 logic and remotes; FORGE-03 edit-mode UI; FORGE-04 input mode and camera) — B16 (v0.4-g9i; D-049)
- **Remotes (area Build, additive).**
  - `Build.CanMove(buildingId: integer(1,1e6), position: vector3, rot: integer(0,3))` → `(boolean, reason?)`; burst 10, 10/s (ghost tint).
  - `Build.Move(buildingId, position, rot)` → `(ok, reason?)`; burst 4, 2/s. `rot` is absolute, as for `Build.Place`.
  - `Build.MoveToSlot(buildingId, slotId: string(1,32), turn: integer(0,3)?)` → `(ok, reason?)`; burst 4, 2/s. Position = the slot centre; facing = the slot's rot + `turn` quarter turns (as `Build.PlaceSlot` g9h); `Fit.fits(type, size, turn)`.
- **Atomic and in place.** A move is one server command: it validates, then changes position, facing, placement shape and slot, or changes nothing. The building keeps its id, type, level, construction or upgrade progress, paid cost, hit points, `placedBy`, recruit queue and workers. A move never charges, refunds, completes or re-places anything, and never re-fires `BuildingPlaced`. There is no server-side "lifted" state; dragging is client-only.
- **Validation.** The `Build.Place` geometry (bounds, the placement shape against every *other* standing building, resource nodes, objective zones, the no-build areas and the unit and ruler clearance below, with the placement gap), but the destination must lie inside the **keep's own territory circle**, never in a claimed region (v0.4-g9j). Limits, keep level and cost are not checked: a move doesn't add a building.
- **Who and when.** Any ruler of the kingdom may move its buildings, except the keep, in any active phase.
  - **Under attack, per building (v0.4-g9j):** refused when an at-war unit targets or focuses the building, an at-war unit is within its range + 30 of the old or new shape, the building took damage in the last 10 s, or it is burning. The kingdom alarm also refuses moves, as a UX rule only.
  - A kingdom can't move anything for 30 s after a war declaration or peace that involves it.
  - Each building waits `Buildings.moveCooldown` (**10 s**) between moves.
  - A moved storehouse, lumber camp or quarry **settles for 30 s**: it takes no deliveries and gives no gather bonus.
  - The cooldown and settling use sim time.
  - A move to the same spot and facing succeeds and does nothing.
- **Consequences.** Citizens working, building or resting at the building go back to walking to its new place, with their claims kept. Homes, beds, bunks, storage and the treasury don't change. A barracks keeps its queue, and new soldiers appear at its new Rally.
- **Slots.** `Build.Move` frees the building's slot; `Build.MoveToSlot` takes the new one, inside the same command. A building may turn on its own slot. Walls and gates never go on a slot (`not_on_plot`); single sections move with `Build.Move`. Slots themselves don't move (D-049).
- **Reasons.** Those of `Build.Place`/`Build.PlaceSlot`, plus `not_found`, `not_movable` (the keep), `under_attack`, `alarm` and `cooldown`.
- **Replication.** `Build.Buildings` re-sends a building whose position or facing changed. The **server's** WorldView re-pivots the Kit model without a rebuild, and clients get it through part replication (v0.4-g9j correction).
- **Shared placement rules (Place, PlaceSlot, Move; v0.4-g9j).** Each of these refuses with `blocked`:
  - a shape within an objective's radius plus the placement gap;
  - a shape on a crop field, plot road (avenue and cross street) or the spawn pad (Kingdom Layout `reservedAreas()` plus world/Layout data);
  - a shape containing a living unit of any kingdom or a ruler's character position plus 3 studs.
  Slot occupancy uses the same placement gap, so a slot never reads free while placing on it is refused.
- **Events.** G9 `BuildingMoved` (FORGE-01; declared in `GameEvents.luau` by FORGE-05, the custodian): `(Building, player?, from: { position: Vector3, rot: number }, slotId: string?)`.
- **Input and camera (FORGE-04, additive to G4.1/G13.6).**
  - `InputModeController` mode `"edit"`: a tap selects only the player's own buildings and own plots. The input layer can't know occupancy. Whether a plot is a valid MoveToSlot target (free, or the building's own) is decided by FORGE-03's snap and, finally, by the server (`slot_occupied`). Selecting a building in edit mode doesn't move the camera; while moving, a tap aims the ghost (v0.4-g10a, #157).
  - `RulerCameraController` keeps the overview in edit mode and adds `setEditDrag(active)` (drag-pan off, edge-pan on while dragging).
- **Phase 2 (not B16).** Multi-select (`Build.MoveMany`, all-or-nothing), layout presets within a match, and wall drag (`Build.PlaceLine`/`MoveLine`, with VS-2 walls).

## Changelog
- v0.4-g11c (2026-10-19) FORGE-00: G9 `WarChanged`, `SiegeChanged`, `RaidChanged` (FL-0134) and G8 `Sim.Focus` with the full-match interest tiers (`Match.interest`, D-055 (2), (5)). Additive. Re-landed on main by #213 (#198 + #201).
- v0.4-g11b (2026-10-19) FORGE-00: G8 `Kingdom.Diplomacy` and `Kingdom.WarAsk` (D-054 player war and peace, senior ruler, newcomer lock), plus `Kingdom.State.diplomacy`. Additive. Rows from #195 as merged.
- v0.4-g11a (2026-10-19) FORGE-00: G12.6 key-citizen crowd figures (with a `role`) may have up to 8 parts, so the six key props (satchel, plume, staff, basket, scales, banner) read. That is 12 figures, about +48 parts in the arena-phase budget; other crowd figures stay at 4 (FORGE-02 FL-0072 D-019 finding). Additive.
- v0.4-g11 (2026-10-18) FORGE-00: G3 full match by default (match mode, PvP, governors, elimination, the D-055 caps, `match.mode` debug), Crown Arena hooks (`registerArena`/`arenaEnded`, `Match.arena.maxSeconds`), `MatchEnded.reason`, the `Match.waiting` seat queue. G8 `Match.Spectate` and `Army.Recruit` `army_cap`. Additive. Rows from FORGE-01's FL-0125 handoff (#187).
- v0.4-g10d (2026-10-16) FORGE-00: G9 `ConsequenceChanged` wording: a rebellion fires only its start; a rule cut short by elimination or a world reset fires no end (FORGE-07 L1/L2 on #173). Wording only.
- v0.4-g10c (2026-10-15) FORGE-00: G13.3 a `strike` with occupation `riot` marks a riot (rioters are not strikers); burning building models carry `Burning`. G9 gains `ConsequenceChanged` (start and end of strike, shortage, riot, rebellion). Additive. Owed at #125's merge (D-052 (5)).
- v0.4-g10b (2026-10-15) FORGE-00: G4 `Sim.GetEntities` is paged (≤ 49 full records per page, `nextAfterId`); G13.2 `CitizenView` gains `familyIds`/`friendIds`/`rivalIds` and a normalized look; G5 population gains `quotaRev` (FL-0109, #127). G9 `CitizenAnswered` attribution: the answering ruler only (#124, D-050 (5)).
- v0.4-g10a (2026-10-15) FORGE-00: G4.1 `InputModeController:set` includes `"edit"`. G13.9 edit-mode taps select own buildings and own plots; validity is decided by the snap and the server; no camera jump on select (FORGE-07 #142 L2/L3, #157).
- v0.4-g10 (2026-10-13) FORGE-00: G13.1 presentation functions from SPEC v1.5: `reactionFor` (loyalty bands), `questionFor` (question variants), `presentation`, `GESTURE_CUE`. Additive. G13.8: optional presentation tags on the `Kingdom.Converse` and `Kingdom.Choose` results (FORGE-03 proposal, FL-0110/FL-0111). (Drafted as g9 in #96; renumbered after g9a/g9b landed on main.)
- v0.4-g9j (2026-10-15) FORGE-00: G13.9 hardened after an adversarial code review of the base-editing rules:
  - destinations only in the keep's own territory circle;
  - per-building under-attack, damage and burning refusals, and a 30 s lockout after war or peace;
  - a 10 s cooldown, and 30 s settling for moved drop-offs;
  - shared no-build areas (fields, plot roads, spawn pad) and unit and ruler clearance for Place, PlaceSlot and Move;
  - slot occupancy uses the placement gap;
  - the server re-pivots the model.
  Closes drop-off chasing, builder stall, frontier teleport, siege dodge, peacetime trap and character trap.
- v0.4-g9i (2026-10-15) FORGE-00: G13.9 base editing (`Build.CanMove`/`Move`/`MoveToSlot`, atomic in-place moves, G9 `BuildingMoved`, the "edit" input mode) and the objective-zone placement rule. Additive. Source: the user's first Studio feedback; rules from a code investigation (D-049).
- v0.4-g9h (2026-10-13) FORGE-00: G13.5 `Build.PlaceSlot` takes an optional `turn` (quarter turns relative to the slot's facing; the turned footprint must fit, `Fit.fits(type, size, turn?)`). Additive. The user's first Studio feedback: placing on a plot could not be rotated (free placement already rotates with R).
- v0.4-g9g (2026-10-13) FORGE-00: G10 rigs may have up to 11 parts: 2 more rigid detail parts (headwear brim/crown, tool handle/head), welded to Head or Tool with no Motor6D, so poses and `Sim/Pose.JOINTS` are unchanged (D-048, the user's first Studio feedback: citizens and tools too plain).
- v0.4-g9f (2026-10-13) FORGE-00: G13.8 after `Kingdom.Choose`, the hold lasts until `EndConversation`, capped at 12 s (was: at most 4 s). The citizen no longer walks off while the reaction is on screen (FORGE-05 B14 gate finding).
- v0.4-g9e (2026-10-13) FORGE-00: G13.8 held citizen faces the ruler's character, not the camera direction (the server cannot know the camera), and the intent text is "Talking (with the ruler)"; the conversation camera frames the citizen's face. This follows #108 as built.
- v0.4-g9d (2026-10-13) FORGE-00: G7 births follow upkeep health instead of spending treasury food (D-045). ProductionService stays the only food consumer.
- v0.4-g9c (2026-10-13) FORGE-00, rulings on FORGE-04's #98 questions (D-044). These are additive:
  - G3 lists `MatchService.mode`.
  - G9 adds the planned `CitizenAnswered` event and the attribution of `ResourceGathered` and `UnitsRecruited`, and says attribution lives in `Feedback/Signals`.
  - G11 sets the rule for client-reported onboarding steps.
- v0.4-g9b (2026-10-13) FORGE-00: G13.5 drops the interim `UI/SlotFit` allowance; #88 deleted it and the picker calls `Fit.typesFor`. Wording only. The header now names the latest version.
- v0.4-g9a (2026-10-13) FORGE-00: G13.5 `Build.PlaceSlot` refuses `wall`/`gate` on plots (`not_on_plot`), enforced on the server (#89 L3).
- v0.4-g8a (2026-10-13) FORGE-00: G13.5 Buildings stats name barracks `bunks` instead of a recruit cap (D-041). Wording only.
- v0.4-g8 (2026-10-13) FORGE-00, ruling on the three #31 contract nits (backlog audit): the contract follows the shipped code. `assign` returns `KingdomId?`; `Kingdom.Gather` returns `(true, ResourceId, amount)` or `(false, errorCode)`; `Kingdom.SetJobQuota` covers farmer/woodcutter/miner/builder and returns `(ok, errorCode?)`. The v0.4-g7 G13.1 signatures arrive with PR #83.
- v0.4-g7 (2026-10-13) FORGE-00, content follow-ups round 2 (FORGE-05 #67 review). G13.1 now gives exact signatures: `fireAction` takes one call per event with `rulerHistories` and `creditedRulers`; `choicePreview` requires `fillNames`; `choiceRisks(decisionId, fillNames)`; cost is paid from `decisionEffects`; the farm cap gives multiplier 0. Breaking for open PRs #68 and #77; a migration note is in their handoff.
- v0.4-g6 (2026-10-13) FORGE-00, rulings on FORGE-05's #42 and #64 reviews: G13.3 `strike` carries `entityIds` and `cue` may carry `entityIds` (additive; no client fan-out by occupation); G9 funnel credits a step only after the player's previous step.
- v0.4-g5 (2026-10-13) FORGE-00: G13.1 ContentQuery API list (fireAction, citizenKey, LOYALTY_CLAMP, startLoyalty, choicePreview/choiceRisks); G13.8 cinematic conversations (D-036).
- v0.4-g4 (2026-10-13) FORGE-00: G13.2 soldier kingdom crest (D-033). G13.4 history and memory `t` is server time. G10 rigs may have 9 parts (a Hair part welded to the Head, no motor; D-032). Content review follow-ups:
  - G13.1 runtime semantics (fireDecision, locked scenarios, co-rulers, actions);
  - G13.2 chemistry drift ±5 and pinned memories;
  - G13.3 `cue` event and option cost/risks;
  - G13.4 reputation action events and fear relaxation.

  G13.5 clarifications: one source per number (`Costs` = cost/time/levels, `Buildings` = stats only) and one shared `Build/Fit` rule. G4.1 camera modes renamed: `overview` is the aerial management default and `follow` is walk mode. In explore mode a tap selects. The `Kingdom.Population` remote is added. G13 living kingdom (D-030) is additive. VS-1 rows are effective now: content modules and ContentQuery; generated population with `CitizenView` and `look`; `Kingdom.Converse` and `Kingdom.Choose`; the thought, reaction and strike events; ReputationService and kingdom conditions; build slots and `Build.PlaceSlot`; throne seat, aerial camera and the selection signal; debug presets. New BuildingTypes take effect from VS-2.
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
