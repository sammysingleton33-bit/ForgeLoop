# Interface contracts v0 (2026-10-12)

These contracts let five workers build at the same time. Code against them; use mocks for parts not built yet. Additive changes are fine in your own area; breaking changes need a PR reviewed by FORGE-05 and approved by FORGE-00, with the version bumped below.

Contract version: **0.2** · custodian FORGE-05 · Luau files in `roblox/src/shared/Contracts/`.

## 1. Code layout and requires
- Rojo project `roblox/default.project.json` maps:
  - `roblox/src/shared` → `ReplicatedStorage.Forge`
  - `roblox/src/server` → `ServerScriptService.Forge`
  - `roblox/src/client` → `StarterPlayer.StarterPlayerScripts.Forge`
  - `games/<game>/config` → `ReplicatedStorage.Forge.Config` (the sandbox until Game #1 is approved)
- Requires use **require-by-string with relative paths** (`require("../Core/Signal")`), at the top of the module only (not inside functions). No aliases. This runs identically in Lune tests and in Roblox ([announcement](https://devforum.roblox.com/t/introducing-require-by-string/3405078)). Studio confirmation is smoke test S1 in `roblox/STUDIO_TEST_PLAN.md`.
- One module per file, `PascalCase.luau`. Shared logic is `--!strict`. Entry scripts: `*.server.luau`, `*.client.luau`.
- No `init.luau` modules with children that require each other (Rojo/Luau semantics differ historically). Prefer flat folders.
- **Cross-tree requires** (server or client code → `shared/`, anything → `Config`) cannot use plain relative paths, because the folders sit under different services in the DataModel. The skeleton (FL-0003) defines and tests the one allowed form (expected: Roblox's built-in `@game` alias, e.g. `require("@game/ReplicatedStorage/Forge/Core/Signal")`, mapped for Lune by the harness) and documents it in `roblox/README.md`. Until it is on `main`, keep code that needs cross-tree requires on your branch.

## 2. Environment injection (`Contracts/Env.luau`)
Every service/controller receives an `Env` instead of calling `game:GetService` directly, so Lune tests pass mocks.
```lua
export type Env = {
	isServer: boolean,
	DataStoreService: any, MemoryStoreService: any, Players: any, MarketplaceService: any,
	PolicyService: any, AnalyticsService: any, RunService: any, HttpService: any,
	ReplicatedStorage: any, Workspace: any, TweenService: any, SoundService: any,
	jobId: string,
	now: () -> number,            -- unix seconds (os.time / DateTime in live)
	clock: () -> number,          -- monotonic seconds (os.clock)
	wait: (seconds: number) -> (),
	spawn: (fn: (...any) -> (), ...any) -> (),
	random: (seed: number?) -> any, -- Random.new
	log: (level: "info" | "warn" | "error", message: string, fields: { [string]: any }?) -> (),
	-- v0.2 additions (FORGE-05 implements in Env.live and MockEnv)
	bindToClose: (fn: () -> ()) -> (),        -- game:BindToClose
	serverTimeNow: () -> number,              -- workspace:GetServerTimeNow(); use for client-facing deadlines
	newInstance: (className: string) -> any,  -- Instance.new (mocked in tests)
	sharedModules: (fileName: string) -> { [string]: any }, -- required ReplicatedStorage.Forge.<Area>.<fileName> modules keyed by Area
}
```
`Env.live()` builds the real one inside Roblox; `roblox/tests/mocks/` builds fakes. `jobId` is never empty: in Studio (`game.JobId == ""`) `Env.live()` substitutes a GUID per session.

## 3. Service / controller lifecycle (`Contracts/Loader.luau`)
```lua
-- server: roblox/src/server/Services/<Name>.luau   client: roblox/src/client/Controllers/<Name>.luau
local Def = { name = "RoundService", dependencies = { "PlayerService", "DataService" } }
function Def.new(env: Env, registry: Registry) -- build the instance; no yielding
	local self = setmetatable({}, RoundService)
	self._data = registry:get("DataService")
	return self
end
-- optional on the instance: self:start() (may spawn threads), self:destroy()
return Def
```
The loader discovers every module in `Services/` (server) or `Controllers/` (client), sorts by `dependencies`, calls `new` in order, then `start`. Optional dependencies: `registry:find(name)` returns nil when absent — call it in `start()` or later (every service is constructed by then), not in `new()`. Adding a service never edits another file.

## 4. Game event bus (`Contracts/GameEvents.luau`)
Server-side signals that decouple producers from consumers (quests, analytics, onboarding, rewards).
| Event | Producer | Payload |
|---|---|---|
| `PlayerReady` | FORGE-01 PlayerService | `(player)` — profile loaded, character may not exist yet |
| `RoundStateChanged` | FORGE-01 RoundService | `(state: string, info: { roundId: string, endsAt: number? })` |
| `PlayerEliminated` | FORGE-01 | `(player, info: { roundId: string, cause: string, by: Player? })` |
| `RoundEnded` | FORGE-01 | `(result: RoundResult)` |
| `CurrencyChanged` | FORGE-03 EconomyService | `(player, currency: string, newBalance: number, delta: number, reason: string)` |
| `ItemGranted` | FORGE-03 InventoryService | `(player, itemId: string, qty: number, source: string)` |
| `PurchaseCompleted` | FORGE-03 PurchaseService | `(player, kind: "product" \| "pass", id: number, robux: number?)` |
| `RewardRolled` | FORGE-03 RewardService | `(player, tableId: string, result: RewardResult)` |
| `OnboardingStep` | FORGE-04 OnboardingService | `(player, flow: string, step: number, stepName: string)` |
```lua
export type RoundResult = {
	roundId: string, mode: string, startedAt: number, endedAt: number,
	participants: { { userId: number, placement: number, eliminations: number, survivedSec: number } },
	winners: { number }, -- userIds
}
export type RewardResult = { tableId: string, rarity: string, itemId: string, qty: number, pityTriggered: boolean }
```
Round states are exactly `"Lobby" | "Intermission" | "Countdown" | "Active" | "Results"` (exported type `RoundState`). Add events by appending to the table (additive). Payloads are server-only; clients learn via remotes: FORGE-01 declares `Gameplay.RoundState` (state, roundId, endsAtServerTime), `Gameplay.Eliminated` and `Gameplay.RoundResult` serverEvents; client deadlines use `serverTimeNow`.

## 5. Player data (`DataService`, FORGE-01)
DataStore `ForgeProfiles_v1`, key `u_<UserId>`. Session-locked. Data is split into namespaces so each worker evolves its own schema:
| Namespace | Owner | Examples |
|---|---|---|
| `core` | FORGE-01 | createdAt, lastJoinAt, sessions, playtimeSec |
| `economy` | FORGE-03 | wallets, inventory, equipped, processedReceipts, pity counters |
| `experience` | FORGE-04 | settings, onboarding progress, quests, daily streak |
| `game` | game brief | per-game progress keyed by game id |
```lua
DataService:registerNamespace(name: string, spec: { version: number, defaults: () -> {[string]: any}, migrate: ((data: any, fromVersion: number) -> any)? })
DataService:isLoaded(player): boolean
DataService:waitForLoaded(player, timeoutSec: number): boolean
DataService:get(player, namespace: string): any?          -- read; nil if not loaded. Treat as read-only.
DataService:update(player, namespace: string, fn: (data: any) -> ()): boolean -- false if not loaded or fn errors (no partial write)
DataService:saveNow(player): (boolean, string?)            -- durable write; PurchaseService calls this before PurchaseGranted
DataService.loaded: Signal<(Player)>
DataService.releasing: Signal<(Player)>                    -- last chance to write before the final save
```
Registration happens in `new` of the owning service; DataService loads profiles after all services are constructed.
- Migrations are step-wise: `migrate(data, k)` is called for k = stored … version−1 and returns data at version k+1. A stored version above the registered one → no downgrade: kick with a friendly message and never write. Namespaces/fields this server doesn't know are preserved on save.
- Every save verifies the session lock still belongs to this server (`jobId`); otherwise it writes nothing, marks the profile lost and kicks. The stale-lock steal timeout is at least 3× the autosave interval.
- Strings written to data must be valid UTF-8 (DataStores reject invalid UTF-8).

## 6. Remotes (`RemoteService`, FORGE-01)
Each area declares its remotes in `shared/<Area>/Remotes.luau`; RemoteService aggregates them and creates instances under `ReplicatedStorage.ForgeRemotes`.
```lua
local V = require("../Core/Validate")
return {
	{ name = "Economy.BuyItem", kind = "function", args = { V.string(1, 64), V.integer(1, 99) }, rate = { burst = 5, perSecond = 1 } },
	{ name = "Economy.WalletChanged", kind = "serverEvent" },
	{ name = "Experience.Sfx", kind = "unreliableServerEvent" },
}
```
Kinds: `event` (client→server), `function` (client→server, returns), `serverEvent` (server→client), `unreliableServerEvent`. Names are `<Area>.<Action>`; areas: `Gameplay` (FORGE-01), `Economy` and `UI` (FORGE-03), `Experience` (FORGE-04), `Debug` (FORGE-05). RemoteService discovers declarations with `env.sharedModules("Remotes")`. Instances: `ReplicatedStorage.ForgeRemotes.<Area>.<Action>` (RemoteEvent / RemoteFunction / UnreliableRemoteEvent). Client→server remotes without `rate` get burst 10 / 5 per second; calls with extra arguments are dropped.
- Server: `RemoteService:handle(name, fn(player, ...))`, `:fire(name, player, ...)`, `:fireAll(name, ...)`. Arguments are validated against `args` and rate-limited per player before `fn` runs; invalid calls are dropped and counted.
- Client (`shared/Core/RemoteClient.luau`): `RemoteClient.invoke(name, ...)`, `.send(name, ...)`, `.on(name, fn)`.
- Validators (`shared/Core/Validate.luau`): `string(min,max)`, `integer(min,max)`, `number(min,max)` (finite only), `boolean()`, `enum({...})`, `optional(v)`, `array(v, maxLen)`, `vector3(maxMagnitude)`, `instanceOf(className)`. Each is `(value) -> (boolean, string?)`. `string` measures bytes (`#s`) and rejects invalid UTF-8; `array` rejects tables whose keys are not exactly 1..n.

## 7. Economy (FORGE-03)
```lua
EconomyService:getBalance(player, currency: string): number
EconomyService:grant(player, currency, amount: number, txId: string, source: string): boolean -- idempotent per txId
EconomyService:spend(player, currency, amount: number, txId: string, sink: string): boolean   -- never below 0
InventoryService:grant(player, itemId: string, qty: number, txId: string, source: string): boolean
InventoryService:count(player, itemId): number
RewardService:roll(player, tableId: string, txId: string): RewardResult?  -- server only
RewardTables.odds(tableId): { { rarity: string, itemId: string, probability: number } } -- shared; UI shows these exactly
PurchaseService:registerProduct(productId: number, handler: (player, receipt) -> boolean)
PurchaseService:ownsPass(player, passId: number): boolean
PurchaseService:canBuyPaidRandom(player): boolean -- PolicyService gate; false when unknown
```
Definitions (items, currencies, reward tables, products) are data in `games/<game>/config/` (`Items.luau`, `Currencies.luau`, `RewardTables.luau`, `Products.luau`), validated at startup.

## 8. Experience (FORGE-04)
```lua
AnalyticsService:event(player, name: string, fields: {[string]: any}?)
AnalyticsService:funnel(player, funnel: string, step: number, stepName: string)
AnalyticsService:economy(player, flow: "source" | "sink", currency: string, amount: number, balance: number, txType: string, item: string?)
SettingsService:get(player, key: string): any
-- client
NotificationController:show({ title: string, body: string?, kind: "info" | "reward" | "warning" | "achievement", durationSec: number? })
AudioController:play(soundId: string, opts: { volume: number?, position: Vector3? }?)  -- ids from shared/Experience/Sounds.luau
```
EconomyService calls `registry:find("AnalyticsService")` in `start()` and reports sources/sinks when present.

## 9. UI (FORGE-03 owns components; FORGE-04 consumes)
- No external UI framework in v0: a small builder `client/UI/Create.luau` (`Create(className, props, children)`) + theme tokens `client/UI/Theme.luau` (colors, fonts, text sizes, corner radius, spacing scale). FORGE-03 may propose a framework with evidence in its first PR.
- Components live in `client/UI/Components/` with a doc comment listing props. Minimum set: Button, IconButton, Panel, Modal, Tabs, Grid, ItemCard (rarity frame), CurrencyPill, ProgressBar, Toast.
- `ScreenGui.DisplayOrder` bands: HUD 10–19, menus 20–39, modals 40–59, onboarding 60–69, notifications 70–79, debug 90+.
- Layout zones: top-left currencies, top-centre round state/timer, right edge menu buttons, bottom-centre context actions, top-right notifications stack. Respect safe areas (`ScreenInsets`); touch targets ≥ 44 px on phones.

## 10. Assets (FORGE-02 → everyone)
- `blender/manifest.json` is the hand-over: one entry per asset id `<category>_<name>_<NN>` with dimensions (studs), triangle counts per LOD, files, preview, review status.
- In Roblox, imported models live in `ReplicatedStorage.Forge.Assets` (or `ServerStorage` for server-only) named by asset id. Code refers to assets only by id.
- Until an Open Cloud key exists, import is manual (3D Importer in Studio → save `.rbxm` to `roblox/assets/`), done by FORGE-05 with the user.

## 11. Build identity
`roblox/scripts/stamp_build.sh` writes `roblox/src/shared/BuildInfo.json` (git sha, branch, UTC time; gitignored). In Studio the stamp appears as `ReplicatedStorage.Forge.BuildInfo` and in the server log at start. Every Studio test report quotes the sha.

## Changelog
- 0.1 (2026-10-12) FORGE-00: first version.
- 0.2 (2026-10-12) FORGE-00, additive (prompt review): cross-tree require rule; Env `bindToClose`, `serverTimeNow`, `newInstance`, `sharedModules`, non-empty `jobId`; round state strings + client remotes; step-wise migrations, lock check on every save, UTF-8; remote discovery/instance layout/default rate; Validate byte/UTF-8/array rules.
