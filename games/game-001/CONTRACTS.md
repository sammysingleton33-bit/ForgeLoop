# game-001 contracts: AI Kingdoms (v0.4-g11g, 2026-10-19; G12 rows are effective as their PRs merge (#208: Types, Caps, DuelModel, config Duel; #209: SupportModel, config Support; #216: Ledger, LeadershipService; #217: Kit arena, crowd, gear and Layout.arena), the rest is a draft; G13 VS-1 rows are effective; G13.8 follows FL-0079/FL-0088)

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
- Rigs come from `Kit.character` (G10): the part-built rig (≤ 11 parts) or the mesh rig (Root + ≤ 16 MeshParts, v0.4-g11d), joined by Motor6Ds named after `Sim/Pose.JOINTS` and by Welds, with no Humanoid and no Animator. Rigs are pooled.
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
- What the Kit builds itself is primitive Parts only (Block, Wedge, CornerWedge, Cylinder, Ball). There is no runtime CSG and no PartOperation, and the Kit never creates a MeshPart.
- Imported meshes (D-057) are only cloned from the asset source (`Kit.setAssetSource`): `Kit.prop` ids and the citizen kit. Without the asset, the part-built model is returned, so every Rojo build runs before an import.
- No function yields.
- **Asset source (v0.4-g11d).** The server and each client have their own Kit. Each sets its source to `ReplicatedStorage.Forge.Assets`, or nil when `Forge` or `Assets` is missing. `Kit.prop`, `Kit.character` and `Kit.portrait` read it at call time.
  - Server: `WorldService`, when it builds the world.
  - Client: `FeedbackKitController` (FORGE-04, #211), in `new()`. The Loader runs every `new()` before any `start()`, so `EntityController`'s first rig, the first `Kit.portrait` and the client's `Kit.prop` all see it. A rig built before the call stays part-built in the pool.
- **Mesh rigs (v0.4-g11d; D-057 (10); FL-0135, #207).** `Kit.character` (through `Kit/CharacterMesh`) builds a segmented MeshPart rig when all of these hold:
  - the kit data `Kit/CharacterMeshData` (generated by `art/char_kit/rig_to_luau.py`) has pieces and a valid assembly for this kind and job (lookup below);
  - `<source>.CitizenKit` holds every non-empty piece that this kind, job, look and kingdom resolve to: a MeshPart named by piece id, with a MeshId and the data's size (±0.1 stud per axis).

  Otherwise it returns the part-built rig, whole, never a mix. The choice is made per build, so one match, and even one assembly, can show both kinds (without `crest_azure`, only azure soldiers are part-built). Bad art data falls back and never errors.

  The committed data has had pieces since #220 (after #226: 117 pieces, 111 with a mesh, and 13 assemblies; v0.4-g11g), so every rig stays part-built until the owner imports the kit (`art/IMPORT_CHARACTERS.md`: `Forge.Assets.CitizenKit`, saved as `roblox/assets/CitizenKit.rbxm`).
  - **Assembly lookup.** The style comes from `Character.styleOf`: kind `governor` is a governor; kind `soldier` or job `soldier` is a soldier; everyone else is a citizen.
    - Citizens: `job`, then the `woodcutter`/`lumberjack` alias, then `idle`.
    - Soldiers: `soldier_<job>` (unless the job is `soldier`), then `soldier`.
    - Governors: `governor`.
  - **Both rigs:**
    - Root: anchored, invisible, `Kit.CHARACTER_ROOT_HEIGHT` (3.2) above the feet, pivot at the feet.
    - Motor6Ds are named after the moving part, parented to Part0, with axis-aligned joint frames: `Torso` off the Root; `Head`, `LeftArm`, `RightArm`, `LeftLeg` and `RightLeg` off the Torso.
    - At most one `Tool`: off the RightArm, or off the Torso (TorsoTool: the hauler's sack). Idle citizens have no `Tool` on the part-built rig. A mesh rig has one only if its assembly has a tool piece.
    - Every part is CanCollide, CanTouch and CanQuery false and Massless. No Humanoid, no Animator.
    - Model attributes: KitKind, KitJob, KitRootHeight, and KitLook (`Kit.lookKey(look, kingdom)`, where the kingdom is passed only for a soldier with a known kingdom).
    - Kingdom-coloured parts carry KitTint, so `Kit.setKingdomColor` recolours both.
  - **Part-built rig only:** ≤ 11 parts (`Kit.CHARACTER_MAX_PARTS`, unchanged).
  - **Mesh rig only:**
    - Parts: the Root + 6 to 16 MeshParts: one base piece per joint above, at most one Tool, and extras (`CharacterMesh.MAX_PIECES` = 16; a mirrored piece counts twice). The converter and the Kit specs enforce the 16; `Kit.character` does not check it.
    - Part names:
      - a base piece takes its motor's name;
      - the assembly's `hair` piece is the part `Hair` (HairWeld);
      - its `acc` (or `accessory`) piece is `Accessory` (AccessoryWeld);
      - other extras are named by piece id (`<id>_<joint>` when mirrored) and welded by `PieceWeld`.
    - Model attributes: KitMesh = true and KitAssembly.
    - Attributes on every MeshPart:
      - KitPiece and KitSlot;
      - KitHeadwear (Hair), KitAccessory (Accessory) and KitTool (Tool) hold the piece id, not the part-built names (`strawhat`, `crest_spire`);
      - KitDetail on pieces tagged `detail`;
      - KitAccent = job on `cloth` pieces of citizens whose job is not `idle`.
    - No Face Decal. SmoothPlastic. An imported TextureID or SurfaceAppearance is kept but never required; every other child, attribute and tag of a piece is stripped.
  - **Triangle budget per rig (`CharacterMesh.BUDGET`, summed from each piece's declared `tris`):** citizens ≤ 1,000 (body ≤ 900, tool ≤ 150); soldiers and governors ≤ 1,500; each mesh ≤ 20,000 (`CharacterMesh.MAX_MESH_TRIS`). Who checks it:
    - `rig_to_luau.py` rejects more than 16 pieces and any piece outside 1..20,000 triangles, and warns when the worst case is over budget;
    - the Kit specs fail on any of the three, for all 1,728 looks: the six citizen jobs in one kingdom colour, and soldiers and governors in each of the four kingdoms and neutral. They run on the placeholder kit, and on the committed kit once it has pieces;
    - `Kit.character` does not check budgets at runtime.
  - `Kit.characterLod` is unchanged (one part, never a mesh).
```lua
Kit.build(type: BuildingType, level: number, stage: number | "complete", kingdomColor: Color3): Model
	-- PrimaryPart; attachments Door, WorkSpot1..n, DropOff (storehouse), Rally (barracks)
Kit.footprint(type: BuildingType, level: number): Vector2           -- the one source for canPlace and the build ghost
Kit.character(kind: EntityKind, job: JobId, kingdomColor: Color3, look: CitizenLook?, kingdom: KingdomId?): Model
	-- look, kingdom: G13.2. Returns the mesh rig or the part-built rig, whole, never a mix (rules above; v0.4-g11d);
	-- part-built: ≤ 11 parts (anchored root, torso, head, 2 arms, 2 legs, tool, + Hair welded to Head, no motor; D-032; a citizen without a tool may wear an Accessory welded to Head instead; + at most 2 rigid detail parts for headwear or tool, welded to Head or Tool, no motor, D-048);
	-- mesh (D-057): Root + 6 to 16 rigid MeshParts on the same Motor6D tree (the converter and the specs enforce the 16); both: Motor6Ds named after the moving part (Sim/Pose.JOINTS);
	-- CanCollide, CanTouch and CanQuery false; pooled client rig template
Kit.regalia(kingdomColor: Color3): { Accessory }                     -- ruler crown + cape (R15 and R6 attachments)
Kit.prop(assetId: string): Model                                     -- a clone of the Model named assetId directly in the asset source if present, else a part-built stand-in
Kit.regionMarkers(polygon: { Vector2 }, kingdomColor: Color3): Model -- border flags for a claimed region
Kit.NEUTRAL_COLOR: Color3
Kit.setKingdomColor(model: Model, color: Color3)                     -- recolours trims and banners in place (every KitTint part; mesh rigs too)
Kit.setAssetSource(folder: Instance?)                                -- (v0.4-g11d) ReplicatedStorage.Forge.Assets or nil; read by Kit.prop and the citizen kit (its CitizenKit child)
Kit.characterMeshAvailable(): boolean                                -- (v0.4-g11d) kit data has pieces and the source has a CitizenKit child (pieces are checked per build)
Kit.characterMeshStatus(): { pieces: number, assemblies: number, source: boolean, folder: boolean, available: boolean,
	missing: { string }, meshBuilds: number, fallbackBuilds: number, lastFallback: string? }   -- (v0.4-g11d) diagnostics only;
	-- missing: every non-empty data piece absent or unusable in CitizenKit; lastFallback: why the last attempted mesh build fell back
```
- **What WorldService does**, at server start, all from `world/Layout.luau`:
  - builds terrain with `Fill*` primitives, one per Layout feature (no single huge `WriteVoxels`; if it is used, at most 64×64×16 voxels per frame), through a thin terrain adapter that Lune specs can record;
  - places the Crown Arena once, neutral, at `Layout.arena` (tag `CrownArena`, `Workspace.World.Arena`; G12.6, v0.4-g11g);
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

## G12. Crown Arena and support (D-029, D-053; design: `design/crown-arena.md`; effective row by row as the arena PRs merge)
**Effective on main since #208 (v0.4-g11d):** the G12.1 type block, `DuelModel` and `Caps` in G12.2, config `Duel`, and G12.3. **Effective on main since #209 (v0.4-g11e):** `SupportModel` in G12.2 and config `Support`. **Effective on main since #216 (v0.4-g11f):** `Ledger` and `LeadershipService` in G12.2 (FL-0069 slice 1) and config `Support.reputationCategories`. **Effective on main since #217 (v0.4-g11g):** the G12.6 FORGE-02 Kit additions and `Layout.arena`. **Still a draft** (shapes to build against; a change is announced in a handoff): the other G12.2 services, the G12.4 remotes, the G12.5 events and the G12.6 hooks. A row becomes effective when the PR that implements it merges (Crownfall handoff 2026-10-18).

### G12.1 Types (`src/shared/Arena/Types.luau`, FORGE-01; on main since #208)
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
-- (v0.4-g11d) the duel types G12.2 names; FORGE-05's fairness harness uses the same shapes
export type Modifier = { source: string, kind: string, stat: string?, magnitude: number?, duration: number?,
	condition: string?, earliest: number?, lead: number?, uses: number?, slot: boolean?, affectsOpponent: boolean? }
	-- one support effect on one duellist. source, e.g. "tier:adoring", "perk:reforge", "perk:fineWares", "crowdRally" (SupportModel's, v0.4-g11e);
	--   modifiers with the same source are one trigger and one slot (Crowd Rally is two effects)
	-- kind: "passive" | "trigger" | "heal" | "telegraph"; stat (passive, trigger): "damageReduction" | "damage" | "staminaRegen"
	-- magnitude: a fraction (+6 % = 0.06; heal: of max HP); duration: seconds (trigger, heal, telegraph)
	-- condition: "hpBelow:<share>" | "staminaOut" | "opponentHeavy" | "hype"; earliest: first duel second it may fire
	--   (nil = the quiet start); lead, uses: telegraph only (seconds earlier the opponent's heavy shows; heavies covered)
	-- slot: a passive that takes a trigger slot (Fine Wares); affectsOpponent: always refused (G12.3)
export type DuellistSetup = { weapon: Weapon?, armour: Armour?, modifiers: { Modifier }? }
export type DuelInput = { action: DuelAction?, inRange: boolean, facing: boolean }
export type DuelEvent = { t: number, kind: string, side: string, data: { [string]: any }? }   -- side "a" | "b"; "draw" only on ended
```
- `KingdomId` and `EntityId` are G2's. `Arena/Types.luau` re-exports them from `Kingdom/Types` (v0.4-g11f), so its `KingdomId` is G2's four-kingdom union, no longer a `string` stand-in.
- `MatchPhase` gains `"Arena"` between `Endgame` and `Results` with FL-0071 (G3). It is not in #208. The change is additive, and `PacingService:phaseDurations` gains `Arena` (today only the `match30` mode has it).
- `CitizenService:inspect` already returns `loyalty: number` (`CitizenView`, G13.2). It gains `role: KeyRole?` and `petition: { id: string, text: string, need: ResourceBag?, expiresAt: number }?` (additive; not on main yet).

### G12.2 Server APIs (FORGE-01)
```lua
-- pure, deterministic, no Roblox APIs, injected clock/RNG where needed; FORGE-05's harness requires them directly
-- SupportModel (src/shared/Arena/SupportModel.luau, on main since #209): no clock and no randomness (v0.4-g11e)
-- config? is a whole config Support table (not merged); nil = config Support. SupportModel exports two types:
export type Sample = { t: number, components: { [string]: number } }   -- components: SupportComponent → 0..100
export type KeyCitizen = { role: string, citizenId: number?, name: string?, loyalty: number, alive: boolean }   -- role: a KeyRole
SupportModel.score(samples: { Sample }, ruler: { now: number }, config?): (number, SupportTier, { [string]: number })
	-- (v0.4-g11e) only samples with a finite t ≤ now count, each equally, in any order. A missing, non-number or
	-- non-finite value counts as 50; the rest is clamped 0..100. Per componentOrder component: wholeMatchShare × the mean
	-- of those samples + (1 − wholeMatchShare) × the mean of those in (now − recentSeconds, now], or the whole mean alone
	-- when none is that recent; no sample, or a non-finite now, gives 50. score = those values averaged by
	-- components[c].weight, clamped 0..100; tier = tierOf(score); breakdown = each component's value
SupportModel.tierOf(score: number, config?): SupportTier
	-- (v0.4-g11e) the first tier in tierOrder whose min ≤ score, else the last; a non-finite score (NaN, ±inf) reads as 50
SupportModel.trend(samples: { Sample }, ruler: { now: number }, config?): number
	-- (v0.4-g11e) the mean one-sample score (that sample's weighted mean) in (now − trendSeconds, now] minus the mean in
	-- (now − 2 × trendSeconds, now − trendSeconds]; 0 when either window is empty
SupportModel.offers(keyCitizens: { KeyCitizen }, tier: SupportTier, config?): ({ TriggerOffer }, slots: number)
	-- (v0.4-g11e) each role keeps its first living key citizen; in roleOrder, that citizen's perk is offered if their
	-- loyalty ≥ offer.pledgedLoyalty (power "pledged", "empowered" from offer.empoweredLoyalty), with citizenId,
	-- citizenName (= name), role and loyalty. condition is the perk's `when` text (not the modifier condition); effect
	-- is its `effect` text with {magnitude} filled ("6 %"; a telegraph's lead "0.15"). Then, if the tier has crowdRally,
	-- a crowdRally offer: no citizen, power "empowered", crowdRally's `when` and `effect`. Perks are offered at every
	-- tier; slots is the tier's slot count (Hostile 0). An unknown tier errors ("SupportModel: unknown tier '<tier>'",
	-- as in modifiers; v0.4-g11f).
SupportModel.modifiers(tier: SupportTier, picks: { { trigger: string, power: string } }, config?): { Modifier }
	-- (v0.4-g11e) the list for DuellistSetup.modifiers. First the tier's passive blessing: one passive per stat in its
	-- `passive` (order damageReduction, damage, staminaRegen; source "tier:<tier>"; Adoring and Loyal have two, the rest
	-- none). Then per pick, source "perk:<trigger>" and the perk's numbers, with perk[power] as magnitude or lead:
	--   trigger: stat, magnitude, duration, condition; heal: magnitude, duration, condition;
	--   telegraph: lead, uses, duration, condition (no magnitude); passive: stat, magnitude, slot = true.
	-- crowdRally: source "crowdRally", two triggers (damageReduction, staminaRegen) with its duration and condition;
	-- power is not read. No modifier has earliest (= the quiet start).
	-- Errors on an unknown tier, more picks than slots, a trigger picked twice (crowdRally too; v0.4-g11f), crowdRally
	-- on a tier without it, an unknown trigger, or a perk power other than "pledged" or "empowered" (v0.4-g11f; also
	-- one whose perk value is not a number). It does not run Caps.check or check picks against offers.
-- DuelModel (src/shared/Arena/DuelModel.luau, on main since #208): no clock and no randomness; re-exports DuelInput, DuelEvent
DuelModel.new(config?, a: DuellistSetup, b: DuellistSetup, seed: number): DuelState
	-- (v0.4-g11d) config: config Duel `{ rules, weapons, armour }`, or its `rules` alone (weapons and armour then come from
	-- config Duel); nil = config Duel. A missing weapon/armour is "swordShield"/"medium"; an unknown one errors. seed is
	-- kept but unused. DuelState is not an exported type (`any`); `view` and `snapshot` are its read API.
DuelModel.step(state: DuelState, inputs: { a: DuelInput?, b: DuelInput? }, dt: number): { DuelEvent }
	-- DuelInput = { action: DuelAction?, inRange: boolean, facing: boolean }; DuelService derives inRange/facing from real positions
	-- (v0.4-g11d) inputs is a table ({} = no input). An attack can land only if inRange and facing were true when it
	-- started (else `miss`). light/heavy start only from idle, parry/dodge from idle or block, each only with enough
	-- stamina; block starts from idle, blockEnd ends a block; any other action (busy, unknown) is ignored. A dt that is
	-- not finite or is ≤ 0 steps nothing; a dt over 1 s is clamped to 1 s; after `ended`, step returns {}.
DuelModel.view(state: DuelState, side: "a" | "b"): { t, hp, stamina, canAct, blocking, opponentHp }        -- (v0.4-g11d)
	-- canAct = idle, blocking = in block; hp and opponentHp are not clamped (below 0 after a KO)
DuelModel.snapshot(state: DuelState): { t, suddenDeath, ended, winner, reason, a: SideView, b: SideView }  -- (v0.4-g11d)
	-- SideView = { hp, hpShare, stamina, staminaShare, state, hype, weapon, armour }; no triggers in reserve
	-- state: "idle" | "windup" | "recover" | "block" | "parry" | "dodge" | "stagger"; hpShare ≥ 0, hp is not clamped;
	-- winner and reason are nil until the duel ends
DuelModel.CONFIG, DuelModel.WEAPONS, DuelModel.ARMOUR     -- config Duel rules / weapons / armour (v0.4-g11d)
-- Caps (src/shared/Arena/Caps.luau, on main since #208); G12.3 numbers
Caps.check(modifiers: { Modifier }): (boolean, string?)              -- true, or false and the first problem
Caps.problems(modifiers: { Modifier }): { string }                   -- every problem as a sentence; {} = within the caps (v0.4-g11d)
Caps.NUMBERS                                                         -- G12.3 as frozen data (v0.4-g11d)
	-- { passivePerStat, passiveCombined, maxTriggers, triggerMaxSeconds, triggerMaxMagnitude, totalPerStat, healPerDuel,
	--   healPerTrigger, quietStartSeconds, stats = { "damageReduction", "damage", "staminaRegen" } }; bonuses and healing
	--   are fractions (0.05 = +5 %), maxTriggers a count, the rest seconds
-- Ledger (src/shared/Arena/Ledger.luau, on main since #216): pure, no clock (the caller passes t), no randomness (v0.4-g11f)
Ledger.new(config?): Ledger                     -- export type Ledger; config? is a whole config Support table; nil = config Support
Ledger.record(ledger, kingdom: KingdomId, userId: number?, act: string, magnitude: number?, t: number): (LeadershipMoment?, string?)
	-- (v0.4-g11f) act is a key of config Support `acts`, else nil, "unknown_act" (never invented). delta = acts[act].delta ×
	-- magnitude (a nil, NaN or non-number magnitude is 1; clamped 0..2, so it never flips the sign); 0 gives nil, "no_effect".
	-- A ruler component (components[c].scope "ruler": conduct, valour) moves the (kingdom, userId) level: starts 50, 0..100.
	-- Any other component (the reputation acts) moves the kingdom offset: starts 0, −20..20. Valour gains per (kingdom,
	-- userId) in a rolling 60 s add up to at most valourCapPerMinute: a gain is trimmed to the room left; no room gives
	-- nil, "capped". The moment's delta is the applied one (after magnitude and trim; the 0..100 / ±20 clamp does not
	-- change it); text is acts[act].text. The last Ledger.MAX_TOTAL (1600) moments of all kingdoms together are kept;
	-- dropping one leaves levels as they are.
Ledger.level(ledger, kingdom, userId: number?, component: string): number    -- 0..100; Ledger.START_LEVEL (50) if never moved
Ledger.offset(ledger, kingdom, component: string): number                    -- ±Ledger.MAX_OFFSET (20); 0 if never moved
Ledger.moments(ledger, kingdom, userId: number?, limit: number): { LeadershipMoment }
	-- newest first, at most floor(limit); userId nil = every moment of the kingdom; a userId = that ruler's and the kingdom's own (userId nil)
-- LeadershipService (src/server/Services/LeadershipService.luau, on main since #216, FL-0069 slice 1; v0.4-g11f)
-- boots with the game services; dependency MatchService, optional ReputationService (registry:find). Clock: the match sim's
-- `sim.time`. Every call first checks MatchService's host.match.roundId: a new round starts the ledger and the samples over.
LeadershipService:record(kingdom: KingdomId, userId: number?, act: string, magnitude: number?): LeadershipMoment?
	-- (v0.4-g11f) Ledger.record at sim.time; fires `acted` and returns the moment. nil for a non-string kingdom or act, a
	-- kingdom not in sim.kingdoms (an unpopulated or fallen one still records), a userId not among that kingdom's rulers
	-- (warn once per kingdom and ruler per round) or a Ledger refusal (an unknown act: warn once per act per round).
	-- userId nil records for the kingdom: a conduct or valour act then moves the no-ruler level, which is sampled only
	-- while the kingdom has no seated ruler.
LeadershipService:getMoments(kingdom: KingdomId, userId: number?, limit: number): { LeadershipMoment }   -- Ledger.moments (v0.4-g11f)
LeadershipService:samples(kingdom: KingdomId, userId: number?): { Sample }   -- SupportModel's Sample (v0.4-g11f)
	-- the stored series itself (not a copy), oldest first, at most 400 (oldest dropped); {} if none. userId nil = the
	-- series of a kingdom with no seated ruler. SupportModel.score and trend read exactly this.
LeadershipService:sample()   -- one sampling round (v0.4-g11f)
	-- the service's own loop calls it every sampling.intervalSeconds of wall time (env.wait). It does nothing while
	-- sim.active is false or less than intervalSeconds of sim.time has passed since the last sample, so a loop round
	-- that sees less (e.g. after a server hitch over 1 s, which MatchHost does not catch up) is skipped. Else, for each
	-- alive and populated kingdom in sim.kingdomOrder: one { t = sim.time, components } per seated ruler, or one under
	-- userId nil when none is seated. All seven components, 0..100:
	--   reputation: mean of ReputationService:getKingdomReputation over config reputationCategories (no service, or no
	--     number among them: 50), + the kingdom offset
	--   happiness, morale: the kingdom's conditions; stability: Consequences.effectiveStability (stability − unrestPressure);
	--     all three 50 when the kingdom has no conditions table
	--   loyalty: mean loyalty of the kingdom's living citizens (50 if none); conduct, valour: that ruler's Ledger.level
LeadershipService.acted: Signal<(kingdom: KingdomId, userId: number?, act: string, component: SupportComponent, delta: number)>
	-- (v0.4-g11f) fired by every recorded act, delta as applied; G12.5 `LeadershipAct` is not on the GameEvents bus yet
-- services (not on main yet)
SupportService:getView(kingdom: KingdomId, userId: number): SupportView
ArenaService:getState(): ArenaState
ArenaService.stageChanged: Signal<(ArenaState)>
DuelService.events: Signal<(duelId: string, DuelEvent)>
```
- Producers of acts (BuildingService, ProductionService, MilitaryService, CitizenService, Interaction) call `LeadershipService:record` through `registry:find` and never compute support themselves. No producer calls it on main yet (v0.4-g11f): FL-0069 slice 1 (#216) is the ledger, the sampling and this API. Still to come in FL-0069: the act producers, citizen loyalty from memory events, key citizens per role, petitions and `Kingdom.FulfilPetition`, and the `inspect` additions (G12.1).
- Support is computed only by SupportModel. DuelService (not built yet) builds each duellist's list with `SupportModel.modifiers` (v0.4-g11e). That function errors on a repeated pick (v0.4-g11f) but does not check picks against offers, so the caller enforces G12.4 `Arena.Choose` (triggers distinct, ⊆ own offers, ≤ slots). DuelService runs `Caps.check` on each duellist's whole modifier list before `DuelModel.new`, because the caps are per duellist and per duel. A refusal is logged and the modifier dropped, never applied. DuelModel does not validate the modifiers it is given. Every non-passive modifier needs a `condition` DuelModel can evaluate (v0.4-g11d). `Caps.check` refuses a trigger, heal or telegraph without one (G12.3; v0.4-g11f), and DuelModel no longer errors on one with no `condition`: it never fires (v0.4-g11f). With config Support, every non-passive SupportModel modifier has one (v0.4-g11e).
- Trigger conditions are evaluated inside DuelModel, from each modifier's `condition` (v0.4-g11d; this replaces "by DuelService from DuelModel events"):
  - **Latching.** Conditions latch per side and stay met. `staminaOut` and `hype` latch when they happen, also in the quiet start. `hpBelow:<share>` (HP share strictly below `<share>`) latches the first time it holds at a step where a trigger with that condition may fire. So a `staminaOut` or `hype` met in the quiet start fires as soon as the trigger may.
  - **`opponentHeavy`** is not latched. It fires on the opponent's first heavy wind-up once the trigger may fire.
  - **Telegraphs.** A fired telegraph covers the opponent's next `uses` heavies (default 1) while it lasts, and each covered heavy's `heavyWindup.warned` is its `lead` (0 if it has none; v0.4-g11f). With `opponentHeavy`, the first covered heavy is the one that fired it.
  - **Unknown conditions** never hold, and neither does a missing or non-string one: that trigger never fires and `step` does not error (v0.4-g11f). A malformed share such as `hpBelow:.` still errors in `step` once its trigger may fire; Caps refuses it.
  - **Grouping.** Non-passive modifiers that share a `source` fire together, on the first one's `condition`, `earliest` and `duration`.
  - **When.** A trigger fires once, never before `max(rules.quietStart, earliest)`. Conditions are checked only while both sides have HP.
  - **Effects.** Passives apply all duel and add up. Of the active triggers on one stat, only the strongest applies. Healing is spread over the trigger's duration and never passes max HP. No random roll exists in the support chain.
- Config `Duel.luau` (`ReplicatedStorage.Forge.Config.Duel`, FORGE-01; v0.4-g11d) has this shape:
  - `rules`: `{ maxHp, maxStamina, staminaRegen, lightCost, heavyCost, blockHitCost, parryCost, parryWindow, dodgeTime, staggerTime, guardBreakTime, lightRecover, heavyRecover, timeCap, suddenDeathDamage, hardCap, quietStart, hypeParry, hypeHit, hypeCombo, comboWindow }`
  - `weapons`: `{ [Weapon]: { light, heavy, lightWindup, heavyWindup, blockFactor, guardDamage } }`
  - `armour`: `{ [Armour]: { reduction, regen, dodgeCost } }`

  Every number is PROVISIONAL and is tuned only from the fairness harness report (FL-0076). The caps are not in it, except `rules.quietStart`: that is G12.3's quiet start and must not be set below 10 s. `tests/sim/ArenaCaps.spec` checks that config Duel's `rules.quietStart` ≥ `Caps.NUMBERS.quietStartSeconds` (v0.4-g11f); `DuelModel.new` does not check a config it is given.
- Config `Support.luau` (`ReplicatedStorage.Forge.Config.Support`, FORGE-01; v0.4-g11e) has this shape:
  - `components`: `{ [SupportComponent]: { weight, scope } }` (weights add up to 100; `scope` is `"kingdom"`, or `"ruler"` for conduct and valour) and `componentOrder`
  - `sampling`: `{ intervalSeconds, wholeMatchShare, recentSeconds }` and `trendSeconds`
  - `tierOrder` and `tiers`: `{ [SupportTier]: { min, passive: { [stat]: fraction }, slots, crowdRally: boolean } }`
  - `offer`: `{ pledgedLoyalty, empoweredLoyalty }`; `roleOrder` and `roles`: `{ [KeyRole]: { perk: TriggerId, building, petition } }`
  - `perks` (every TriggerId but `crowdRally`): `{ kind, stat?, pledged, empowered, duration?, uses?, condition?, effect, when }`. `pledged`/`empowered` are the magnitude, or a telegraph's lead in seconds. `condition` is the DuelModel condition and `when` the player-facing text. `effect` is player-facing text with a `{magnitude}` placeholder; its other numbers ("for 6 s") are written out. `fineWares` (a passive) has no duration or condition.
  - `crowdRally`: `{ duration, damageReduction, staminaRegen, condition, effect, when }` (`effect` is fixed text)
  - `acts`: `{ [actId]: { component, delta, text } }` (the ruler decisions LeadershipService records; `delta` is signed, `text` pre-authored), `valourCapPerMinute`, and `reputationCategories` (v0.4-g11f): the Reputation categories whose mean is the reputation component (all but `fear`)

  Every number is PROVISIONAL (BRIEF §16.9). Trim C (FORGE-00 ruling, FL-0076; pinned by `tests/sim/SupportModel.spec`): Adoring's passive equals Loyal's (+1 % damage reduction, +1 % stamina regeneration) and Field Remedy heals 3 % / 5 % of max HP. The same spec checks that every tier × set of distinct picks up to its slots × power (one power per set) passes `Caps.check`. SupportModel does not read `scope`, `intervalSeconds`, `roles[r].building`/`petition`, `acts`, `valourCapPerMinute` or `reputationCategories`. LeadershipService reads `sampling.intervalSeconds` and `reputationCategories`, and its `Arena/Ledger` reads `scope`, `acts` and `valourCapPerMinute` (v0.4-g11f). Nothing reads `roles[r].building`/`petition` yet.
- End of a duel (v0.4-g11d):
  - **KO** (`ko`): the side still above 0 HP wins. Defeat is a kneel and a yield (presentation).
  - **Time cap.** At `rules.timeCap` the higher HP wins (`timeCap`). A tie starts sudden death, with all damage × `rules.suddenDeathDamage`.
  - **Draw.** Both at ≤ 0 HP in the same step (`draw`), or `rules.hardCap` reached (`hardCap`). `ended` then has side `"draw"`, and the match falls back to Crown Points (G3: a nil `arenaEnded` winner).

DuelModel events (`DuelEvent`; `t` is duel seconds; v0.4-g11d). `Arena.Events` (G12.4) is built from them.

| kind | side | data |
|---|---|---|
| `hit` | the hitter (a blocked hit is still a `hit`) | `{ damage: number, heavy: boolean, targetHp: number, targetHpShare: number }` (damage and targetHp in HP; targetHp ≥ 0) |
| `miss` | the attacker (not in range or not facing when it started) | none |
| `dodged` | the dodger | none |
| `parry` | the parrier (a `stagger` for the attacker follows) | none |
| `stagger` | who is staggered (parried, or a block with no stamina left) | none |
| `staminaOut` | who reached 0 stamina (once per side per duel) | none |
| `heavyWindup` | the attacker | `{ impactAt: number, warned: number }` (warned: the defender's active telegraph `lead`, else 0; a telegraph without a `lead` gives 0, never nil, v0.4-g11f) |
| `triggerFired` | the side it helps | `{ source: string }` (the modifier `source`; passives never fire) |
| `hype` | whose crowd meter reached 100 (it restarts at 0) | none |
| `ended` | the winner, or `"draw"` | `{ winner: "a" \| "b" \| "draw", loser: ("a" \| "b")?, reason: "ko" \| "timeCap" \| "hardCap" \| "draw", hpA: number, hpB: number, durationSec: number }` (hpA/hpB ≥ 0) |

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

- **Where each row is held (v0.4-g11d).** `Caps.NUMBERS` in `src/shared/Arena/Caps.luau` holds the numbers. `Caps.check` refuses modifier lists that break these rows: passive, trigger count and "each once", duration and magnitude, total per stat, healing, quiet start (`earliest` only), opponent and weak support. DuelModel applies the rest at run time: one firing per trigger, nothing before `rules.quietStart`, and on one stat only the strongest active trigger counts. The fairness harness measures the outcome bounds (FL-0076).
- **The table is parsed.** FORGE-05's `tests/fairness/Caps.spec` reads it. Keep two cells per row and these ten row labels. Change a number only together with `CapsContract` (which `CapsCheck` reads), `Caps.NUMBERS` and the DECISIONS entry.
- **How `Caps` counts (v0.4-g11d):**
  - **Slots.** A trigger slot is one distinct `source` among the `trigger`, `heal` and `telegraph` modifiers and the passives with `slot` (Fine Wares). Effects that share a `source`, like Crowd Rally's two, take one slot. A `trigger`, `heal` or `telegraph` with the same `source`, `kind` and `stat` listed twice is refused, and so is a passive with `slot` whose `source` already took a slot earlier in the list, e.g. Fine Wares twice (v0.4-g11f). Other passives listed twice add up.
  - **Duration and magnitude.** `trigger`, `heal` and `telegraph` need a positive duration of ≤ 8 s. The +10 % cap applies to `trigger`. Healing has its own two caps.
  - **Always refused:** an unknown kind; an unknown stat on a passive or trigger; `affectsOpponent`; a negative or non-finite magnitude (a telegraph's magnitude is not read); an `earliest` under 10 s; a `trigger`, `heal` or `telegraph` whose `condition` is not `hpBelow:<share>` (a decimal, 0 < share ≤ 1), `staminaOut`, `hype` or `opponentHeavy` (v0.4-g11f).
  - **Not capped:** a telegraph's `lead` and `uses`.

### G12.4 Client remotes (area `Arena` → FORGE-01; additions to `Kingdom` and `Sim`)
| Remote | Kind | Args → result, or payload |
|---|---|---|
| `Arena.State` / `Arena.GetState` | serverEvent / function | `ArenaState` (public to every player) |
| `Arena.Vote` | function | `(candidateUserId: integer)` → `boolean`; co-rulers of a qualified kingdom, `vote` stage only |
| `Arena.Choose` | function | `(weapon: enum Weapon, armour: enum Armour, triggers: array(enum TriggerId, 3))` → `(ok, reason?)`; champion only, `loadout` stage, triggers distinct, ⊆ own offers and ≤ slots (v0.4-g11e) |
| `Arena.Action` | event | `(action: enum DuelAction)`; champion only, `duel` stage; burst 8, 12/s |
| `Arena.Events` | serverEvent | batched `{ { t: number, kind: string, side: "a" \| "b" \| "draw", data: { [string]: any }? } }` (hit, parry, stagger, staminaOut, heavyWindup, triggerFired, hype, ended), built from DuelModel's events (G12.2), which also has `miss` and `dodged`. FORGE-00 ruling 2026-10-18 (v0.4-g11d): `ended` has side = the winner, or `"draw"` when the duel was cancelled or both champions dropped, and the match result then falls back to Crown Points (G3 `arenaEnded(nil)`). DuelModel's own `draw` and `hardCap` endings also have side `"draw"` (G12.2). `triggerFired` has `data = { trigger: TriggerId, citizenName: string? }`. DuelModel's `triggerFired` carries only `{ source }`, so the server adds both fields before sending (not built yet). **The other data is an agreed DRAFT (v0.4-g11f; FORGE-01 and FORGE-04, 2026-10-19).** FORGE-04's crowd director reads it on main (#221; G12.6). Its producer is not on main: FORGE-01's DuelRunner (#224) is not merged, and no server code sends `Arena.Events` yet. The relay sends shares, never DuelModel's raw HP. `hit`: `{ damageShare: number, hpShare: number, heavy: boolean? }` (damage / max HP, 0..1; the target's HP share after the hit). `hype`: no data (sent only when the meter is full). `ended`: `data = { reason }`. `triggerFired`: `citizenName` is nil for the Crowd Rally. The `data` of `parry`, `stagger`, `staminaOut` and `heavyWindup` is not fixed yet (the crowd reads none). |
| `Kingdom.Support` / `Kingdom.GetSupport` | serverEvent to the ruler / function | the caller's `SupportView` (in-match meter, perk previews) |
| `Kingdom.FulfilPetition` | function | `(petitionId: string(1,32))` → `(ok, reason?)`; spends the petition's `need` through TreasuryService |

### G12.5 Events (appended to the GameEvents bus by FORGE-05 when the arena services land, FL-0069 to FL-0071, as D-024)
| Event | Producer | Payload |
|---|---|---|
| `LeadershipAct` | FORGE-01 | (KingdomId, userId?, act, component, delta). Not in `Contracts/GameEvents` and not fired yet; `LeadershipService.acted` carries the same values, delta as applied (v0.4-g11f) |
| `KeyCitizenChanged` | FORGE-01 | (KingdomId, KeyRole, entityId?, loyalty) |
| `ArenaStarted` | FORGE-01 | (ArenaState) |
| `SupportTriggered` | FORGE-01 | (duelId, userId, TriggerId, citizenId?) |
| `DuelEnded` | FORGE-01 | (duelId, winnerUserId?, loserUserId?, { durationSec, triggersFired, hpLeft, reason }) — both ids nil on a draw (G12.2 end of a duel; v0.4-g11d) |

### G12.6 Client and asset hooks
- FORGE-01 `src/client/Controllers/DuelController.luau`: `act(action: DuelAction)`, `getState(): ArenaState`, `events: Signal<(ArenaEvent)>`. It is the only sender of `Arena.Action`. FORGE-04's InputMode binds keys, touch and gamepad to `act`; FORGE-03's arena HUD and FORGE-04's crowd director read `events`.
- **FORGE-02 Kit additions (v0.4-g11g; effective on main since #217, FL-0072; interim art under D-051, headless evidence only, nothing seen in Studio).** `Kit/Arena`, `Kit/Crowd` and `Kit/Gear`, exported by `Kit/Kit`. Primitive Parts only, no yields, no scripts.
```lua
Kit.arena(colorA: Color3?, colorB: Color3?): Model              -- the venue; a nil colour gives that side the neutral dress
Kit.arenaDress(model: Model, colorA: Color3?, colorB: Color3?)  -- destroys and rebuilds DressA and DressB (known defect below)
Kit.crowdFigure(kingdomColor: Color3, role: KeyRole?, variant: number?): Model  -- an unknown role errors
Kit.crowdPoolKey(color: Color3, role: KeyRole?, variant: number?): string      -- "<hue style>.<role or 'crowd'>.<variant>"
Kit.armour(armour: Armour, kingdomColor: Color3?): { Accessory }  -- nil colour = neutral; an unknown armour errors
Kit.weapon(weapon: Weapon, kingdomColor: Color3?): Tool           -- nil colour = neutral; an unknown weapon errors
Kit.ARENA            -- the Kit/Arena module: PART_BUDGET { target = 700, cap = 900 }, FOOTPRINT (75, 74), RING_RADIUS 23,
                     -- DUEL_RADIUS 21, SPAWN_X 13, FLOOR_TOP 1.12, SPAWN_HEIGHT 3, SEATS_PER_STAND 72, ...
Kit.CROWD_ROLES      -- G12.1 KeyRole order: blacksmith, healer, captain, provisioner, elder, merchant
Kit.CROWD_MAX_PARTS (4), Kit.CROWD_ROLE_MAX_PARTS (8), Kit.CROWD_VARIANTS (12), Kit.CROWD_HEIGHT (5)
Kit.ARMOURS = { "light", "medium", "heavy" }; Kit.WEAPONS = { "swordShield", "greatsword", "spear", "mace" }
```
- **Arena model.** PrimaryPart `Root`, the invisible 75 × 74 plate; pivot at the ring centre on the ground. X is the gate axis (Gate A at -X), Z the stand axis (Stand A at -Z); side B is side A turned 180°. 349 parts neutral; `KitArena.spec` keeps every kingdom pairing ≤ 700 (worst 487) and under the cap of 900. Model attributes `KitType` ("arena"), `ArenaDuelRadius` (21), `ArenaSeatsPerStand` (72), `KitColorA`, `KitColorB`.
- **Arena attachments**, all on `Root`. The seat, rail, royal, gate and spawn attachments look at the ring along -Z, so `PivotTo(attachment.WorldCFrame)` faces the ring. For each side X = A, B:
  - `StandX_Row<r>_Seat<s>`: r = 1 (front, lowest) to 4; s = 1 to 18, left to right for a figure on the seat facing the ring (Seat1 is on its left). The royal-box gap is skipped, so the numbers stay contiguous. 72 a stand. Attributes `Stand`, `Row`, `Seat`.
  - `StandX_Rail<n>`, n = 1 to 6, left to right in the same way: the key citizens' places on the rail podium, in `Kit.CROWD_ROLES` order. Attributes `Stand`, `Rail`.
  - `StandX_Royal<n>`, n = 1 to 3: the royal box's chairs (attributes `Stand`, `Royal`). `StandX_RoyalBox`: the box's centre at deck level.
  - `GateX`: the champion's gate threshold. `SpawnX`: the champion's start mark, 3 studs above the ring floor, facing the other mark. Attribute `Side`.
  - Plus one `Centre`, the ring centre on the floor. The duel ring has no attachment of its own: it is parts (the painted `RingLine` at radius 21) and the `ArenaDuelRadius` attribute.
- **Arena dress.** Every part that carries a kingdom (caps, banners, plaques, chairs, riser bands, the champion's rug) is in the sub-model `DressA` or `DressB`. With a kingdom colour, each dress shows the kingdom's tower-cap silhouette and its emblem, never colour alone (D-033, D-039); a neutral colour gives plain caps and no emblems. Every dress part carries `KitSide`; the kingdom-coloured ones also carry `KitTint`.
  - `Kit.setKingdomColor(model.DressA, c)` recolours that side and re-forms its emblems to `c`'s kind. It keeps the caps as built and does not update `KitColorA`/`KitColorB`. Called on the whole arena, it paints both sides one colour.
  - Nothing on main calls `Kit.arenaDress` yet. FORGE-01's ArenaService is meant to call it once the two kingdoms are known.
  - **Known defect on main (Lune probe):** `Kit.arenaDress` builds the new dress in the Kit's build frame and ignores where the model stands. On the placed `CrownArena`, the new `DressA`/`DressB` appear around the world origin, not at the arena. The rebuilt parts also miss WorldService's decoration physics: they keep CanTouch, and the high ones collide.
- **Who places it (WorldService, server).** At server start, in the build thread, when `Layout.arena` exists: after the zones, build-slot markers and objective zones, and before props and `ready`. WorldService builds one `Kit.arena()` (neutral) and renames it `CrownArena`. It pivots it at ground height under `Layout.arena.cframe`, with that frame's rotation (yaw only), and sets the attribute `RegionId`. It parents the model to `Workspace.World.Arena` and tags it `CrownArena` (find it with `CollectionService:GetTagged("CrownArena")[1]`).
  - Decoration physics are the same as for props. No part fires Touched, the Root plate is not queryable, and parts whose bottom is more than `COLLIDE_HEIGHT` (7) above the base do not collide.
  - WorldService builds the world once per server, and no game code removes or hides the arena (only `WorldService:destroy()` removes `Workspace.World`). So it stands, neutral, for the whole match.
  - `WorldService.stats.arenaParts` counts its parts at build; `stats.parts` includes them.
- **Crowd figure.** Model `CrowdFigure` (`CrowdFigure_<role>` with a role). PrimaryPart `Body`. The pivot is on the feet and the front is -Z, so `fig:PivotTo(seat.WorldCFrame)` stands it on a seat facing the ring.
  - No Root, Humanoid, Motor6D or script. Every part is Anchored, has CanCollide, CanTouch and CanQuery false, and casts no shadow.
  - An ordinary figure is 4 parts (Body, Head, Crest, Arms). A key citizen is 7 parts (captain) or 8 (the other roles). The build asserts the caps of 4, and 8 with a role (v0.4-g11a).
  - `variant` defaults to 1 and wraps over 12.
  - The crest shape follows the build colour's hue style; `KitTint` parts recolour. So pool by `Kit.crowdPoolKey`.
  - Attributes `KitCrowd`, `KitRole` ("none" without a role), `KitVariant`, `KitStyle`, `KitCrest`, `KitHeight`.
  - Client-only is a rule; the Kit does not check it.
- **Armour** is Accessories (never a Tool), one per body attachment. Each has a `Handle` holding one Attachment named for that body attachment, with the other parts welded to the Handle. Every part is unanchored and Massless, with CanCollide, CanTouch and CanQuery false. Attributes `KitArmour`, `KitPiece`. Fit on R15 and R6 is unverified in Studio.
  - light (3): `KitLightCap` (HatAttachment), `KitLightJerkin` (BodyFrontAttachment), `KitLightCloak` (BodyBackAttachment);
  - medium (4): `KitMediumHelm` (Hat), `KitMediumMail` (BodyFront), `KitMediumPauldronLeft` and `KitMediumPauldronRight` (LeftCollarAttachment, RightCollarAttachment);
  - heavy (5): `KitHeavyHelm` (Hat), `KitHeavyPlate` (BodyFront), `KitHeavyBack` (BodyBack), `KitHeavyPauldronLeft` and `KitHeavyPauldronRight` (Left and Right Collar).
- **Weapon** is one `Tool` named by the weapon id: a `Handle` plus welded parts.
  - `RequiresHandle` is true and `CanBeDropped` false. `Grip` holds it blade up, front -Z.
  - No scripts. No part collides or touches; hits are resolved on the server.
  - Attributes `KitWeapon`, `KitHands` (1: swordShield, mace; 2: greatsword, spear) and `KitReach` (the tip's height above the grip, in studs).
  - The swordShield shield is part of the same one-hand Tool.
- **Layout.arena** (`world/Layout.luau`). `footprint` and `regionId` are additions to the draft shape:
```lua
arena = {
	cframe = CFrame.new(141, 0, -27),  -- the arena frame on the ground (yaw only): X = gate axis, Z = stand axis
	duelRadius = 21,                   -- from cframe.Position: the painted ring (= Kit.ARENA.DUEL_RADIUS)
	spawnA = cframe * CFrame.new(-13, 4.12, 0) * CFrame.Angles(0, -math.pi / 2, 0),  -- looks +X, at spawnB
	spawnB = cframe * CFrame.new(13, 4.12, 0) * CFrame.Angles(0, math.pi / 2, 0),    -- looks -X, at spawnA
	footprint = Vector2.new(75, 74),   -- the Root plate (X = gate axis); WorldPlan keeps decor off it
	regionId = "heartland",
}
```
- The site is not the map centre, where the roads, the hub plaza and the watchtower zone meet. It is east of the watchtower, with its centre inside `heartland` (x ≤ 150). The part beyond x = 150, including `spawnB` (x = 154) and Gate B, lies outside that polygon.
- The ground under the site is flat at y = 0 (`ArenaLayout.spec`). So the placed `SpawnA`/`SpawnB` equal `spawnA`/`spawnB`, and the ring floor is at `cframe.Y + Kit.ARENA.FLOOR_TOP` (1.12), which equals `spawnA.Y - 3`.
- Crowd figures and reactions are client-only (FORGE-04). The server sends no per-figure data; the crowd is derived from `ArenaState`, `Arena.Events` and kingdom population.
  - **Crowd director (v0.4-g11f, #221; reads the G12.4 draft relay).** `Feedback/CrowdDirector` reads `kind` and `side`, plus `hit` `damageShare`, `hpShare` (else DuelModel's `targetHpShare`) and `heavy`, and `triggerFired` `trigger` (else `source` without `"perk:"`) and `citizenName`. It never reads `hit`'s raw `damage` (HP points) or `ended`'s `reason`. Every field is optional; a missing one degrades quietly. A hit is major when `heavy` is true or `damageShare` ≥ config `Crowd.moments.bigHit`; the HP share drives near-death and comeback. Perk names come from config `Crowd.triggerNames` (every G12.1 TriggerId; design §3 and §4); an unknown id reads "their pledge", a missing `citizenName` "A citizen". `CrowdDirector.spec` fails unless FORGE-03's `UI/ArenaText.TRIGGERS` has the same ids and names. An `ended` with side `"draw"` or no side, and a crowning with no winner, are `Crowd.endings.calledOff` for both stands: no payoff, no sound, and `onEvent`/`finish` return nothing more. Unknown kinds (so `miss`, `dodged`) and sides are ignored.

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
- **Portrait (FORGE-02).** `Kit.portrait(kind, job, kingdomColor, look, kingdom?) -> Model` returns the rig that `Kit.character` builds for the same arguments, with the same look (v0.4-g11d):
  - which rig: the part-built rig (≤ 11 parts), or the mesh rig under the G10 conditions;
  - every part is anchored, and the motors and welds are kept;
  - it carries a `PortraitFocus` attachment (head and shoulders) for a ViewportFrame camera. The framing includes every part joined to the Head by Welds, directly or through other Welds (never across a Motor6D);
  - a mesh portrait has no `Face` Decal;
  - a portrait built before its Kit's asset source is set (on a client: `FeedbackKitController`, G10) is part-built.

  The portrait and the world rig must look identical.
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
- v0.4-g11g (2026-10-19) FORGE-00: G12.6 follows #217 as merged (FORGE-02 FL-0072, interim art under D-051; headless evidence only, not seen in Studio). The FORGE-02 Kit additions and `Layout.arena` are effective. Real signatures: `Kit.arena(colorA?, colorB?)` (Color3s; nil gives the neutral dress), the new `Kit.arenaDress`, `Kit.crowdFigure(kingdomColor, role?, variant?)`, `Kit.armour(armour, kingdomColor?)` returning Accessories and `Kit.weapon(weapon, kingdomColor?)` returning one Tool, plus `Kit.ARENA`, `CROWD_*`, `crowdPoolKey`, `ARMOURS` and `WEAPONS`. G12.6 lists the arena's attachments: 72 `StandX_Row<r>_Seat<s>` a stand (numbered from the left of a seated figure facing the ring), `StandX_Rail1..6`, `StandX_Royal1..3`, `StandX_RoyalBox`, `GateA/B`, `SpawnA/B` and `Centre`; the duel ring has no attachment. It also gives the part counts (arena 349 neutral, cap 900; crowd 4, key citizens 7–8) and the `DressA`/`DressB` sub-models. `Layout.arena` gains `footprint` and `regionId`. It sits at (141, 0, -27) in the heartland, not at the map centre. WorldService places it once at server start, before `ready` (tag `CrownArena`), so it stands for the whole match. Nothing calls `Kit.arenaDress` yet, so it stays neutral. On the placed arena, `Kit.arenaDress` would build the dress at the world origin (known defect, FORGE-02). G10 lists the WorldService step. Additive: the rows were a draft, and the colour arguments are optional.
- v0.4-g11g (2026-10-19) FORGE-00: G10 follows #226 as merged (FORGE-02 FL-0135 silhouette pass, interim art). Only the kit data changed: `Kit/CharacterMeshData` has 117 pieces (111 with a mesh) and 13 assemblies. The assembly `soldier_swordsman` is renamed `soldier_knight`, so the soldier keys are `soldier`, `soldier_archer` and `soldier_knight`. Every unit still reaches the Kit as job `soldier` (`Sim/Replication`), so every soldier builds `soldier` for now. The hauler wears `hat_hauler` and has no `hair` slot, so its mesh rig has no `Hair` part. Seven `gear_*` Torso extras replace the two aprons and two satchels and give the builder, miner and woodcutter one each. G10 now says the committed data has had pieces since #220, so only the owner's import is left; until then every rig is part-built. No rule, D-057 budget, part name, attribute or signature changed. Over all 1,728 looks in every kingdom and neutral, every assembly has at most 16 pieces and stays within budget: citizens ≤ 966 of 1,000 (body ≤ 878 of 900, tool ≤ 102 of 150), soldiers and governor ≤ 978 of 1,500. Additive. Job `swordsman` now falls back to `soldier`, and no caller passes it.
- v0.4-g11f (2026-10-19) FORGE-00: G12 follows #218 as merged (FORGE-01 FL-0070/71, input validation). `Caps.check` refuses a trigger, heal or telegraph without a condition DuelModel can evaluate (`hpBelow:<share>` with 0 < share ≤ 1, `staminaOut`, `hype`, `opponentHeavy`), and a slotted passive whose `source` already took a slot (Fine Wares twice). DuelModel no longer errors on an active modifier with no condition (it never fires). A telegraph without a `lead` gives `heavyWindup.warned = 0`, not nil. `SupportModel.modifiers` errors on a repeated pick and on a perk power other than `pledged`/`empowered`. `SupportModel.offers` gives a clean "unknown tier" error. `Arena/Types` re-exports `KingdomId`/`EntityId` from `Kingdom/Types`, which closes the G12.1 open item. `tests/sim/ArenaCaps.spec` pins config Duel's `rules.quietStart` ≥ 10 s. G12.3 Slots now says that a passive without `slot` listed twice is not refused (it adds up). No signature changed. Stricter input: an active modifier with a missing or unknown condition, or a repeated slotted passive, used to pass `Caps.check` and is now refused (no config Support output is one); `KingdomId` narrows from `string` to G2's union (type only).
- v0.4-g11f (2026-10-19) FORGE-00: G12 follows #216 as merged (FORGE-01 FL-0069 slice 1). `Arena/Ledger` and `LeadershipService` are effective. G12.2 replaces the two draft LeadershipService rows with the real API: `Ledger.new`/`record`/`level`/`offset`/`moments`, and `LeadershipService:record` (now returns `LeadershipMoment?`), `getMoments`, `samples` (SupportModel `Sample` series, one per seated ruler, at most one round per 30 s of `sim.time`), `sample()` and the `acted` signal. Acts are keys of config `Support.acts`, and magnitude is clamped 0..2. Conduct and valour are per-ruler levels (start 50, 0..100), and reputation acts move a kingdom offset (±20). Valour gains are capped per rolling minute (`valourCapPerMinute`). Config `Support` gains `reputationCategories`. No producer calls `record` yet. G12.5 `LeadershipAct` is not on the bus yet (`acted` carries its values). G12.1 is unchanged. Additive (the replaced rows were a draft; `record` gains a return value).
- v0.4-g11f (2026-10-19) FORGE-00: G12.4 `Arena.Events` records the relay data FORGE-01 and FORGE-04 agreed on 2026-10-19, as a DRAFT: shares only, `hit` `{ damageShare, hpShare, heavy? }`, `hype` with no data, `ended` `{ reason }`, and `triggerFired` as ruled (`citizenName` nil for the Crowd Rally). The data of `parry`, `stagger`, `staminaOut` and `heavyWindup` stays open. Its consumer, FORGE-04's crowd director, merged in #221 (FL-0074). Its producer, FORGE-01's DuelRunner (#224), has not, and nothing sends the remote yet. G12.6 says what the crowd reads: `source` when `trigger` is missing, DuelModel's `targetHpShare` when `hpShare` is, and never raw `damage`. Perk names come from config `Crowd.triggerNames`, which `CrowdDirector.spec` keeps equal to FORGE-03's `ArenaText.TRIGGERS`. A draw, an `ended` with no side, or a crowning with no winner is "called off" for both stands. Additive (the row was a draft).
- v0.4-g11e (2026-10-19) FORGE-00: G12 follows #209 as merged (FORGE-01 FL-0070). `SupportModel` and config `Support` are effective. G12.2 replaces the draft SupportModel rows with the real ones: `score(samples: { Sample }, ruler: { now }, config?)`, `tierOf`, `trend`, `offers(keyCitizens: { KeyCitizen }, tier, config?)` and `modifiers(tier, picks, config?)`. `modifiers` builds the `{ Modifier }` list for `DuellistSetup.modifiers` (sources `tier:<tier>`, `perk:<trigger>`, `crowdRally`; no Caps, offer or repeat check). The draft types `SupportSample`, `RulerRecord` and `KeyCitizenRecord` were never in code; SupportModel exports `Sample` and `KeyCitizen`. G12.2 adds the config `Support` shape with trim C (FL-0076): Adoring's passive equals Loyal's (+1 %/+1 %) and Field Remedy heals 3 %/5 %. G12.1's `Modifier` source example reads `perk:fineWares`. `Arena/Types`, G12.3 and the draft services are unchanged. G12.4 `Arena.Choose` triggers must be distinct (draft row). Additive (the replaced rows were a draft).
- v0.4-g11d (2026-10-19) FORGE-00: G12 follows #208 as merged. Its Types, Caps, DuelModel and config `Duel` rows are effective; the rest stays a draft (SupportModel #209 is not on main). G12.1 adds `Modifier`, `DuellistSetup`, `DuelInput` and `DuelEvent`. G12.2 has the real signatures (`DuelModel.new(config?)`, `view`, `snapshot`, `CONFIG`/`WEAPONS`/`ARMOUR`; `Caps.problems`, `Caps.NUMBERS`), DuelModel's event kinds and data, config `Duel` and the end-of-duel rules. G12.2 also corrects the wording: trigger conditions are evaluated inside DuelModel, not by DuelService, and every non-passive modifier needs a `condition`. G12.3 numbers are unchanged; new notes say which rows `Caps` checks and which DuelModel applies. G12.4 `Arena.Events` (FORGE-00 ruling 2026-10-18): `ended` side may be `"draw"` (Crown Points decide), and `triggerFired` data is `{ trigger, citizenName? }`. G12.5 `DuelEnded` ids are nil on a draw. Additive, except that `side: "draw"` is a new value consumers must handle.
- v0.4-g11d (2026-10-19) FORGE-00: G10 imported-mesh rigs (D-057, FL-0135, #207). `Kit.character` and `Kit.portrait` return a segmented MeshPart rig (Root + ≤ 16 MeshParts, the same Motor6D names and tree) when the kit data has pieces and `Forge.Assets.CitizenKit` holds every piece that build needs. Otherwise they return the part-built rig, whole, chosen per build. The ≤ 11-part cap now applies to the part-built rig only. The converter and the specs check a per-rig triangle budget: citizens 1,000 (body 900, tool 150), soldiers and governors 1,500. G10 now documents `Kit.setAssetSource`, `Kit.characterMeshAvailable` and `Kit.characterMeshStatus`, and the client sets the source in `FeedbackKitController` (#211). G10's `Kit.character` line now shows G13.2's `look` and `kingdom`, and the G13.8 portrait and G4 rendering wording follow. No signature changed. The committed kit data is empty, so every rig is still part-built. Additive.
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
