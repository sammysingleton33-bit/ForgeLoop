# games/game-001 — AI Kingdoms: build, run and test (owner of this file: FORGE-05)

Design: `BRIEF.md`. Contracts: `CONTRACTS.md` (FORGE-00). Who owns which folder:
`docs/workflows/team.md`, section "game-001" (checked by the ownership gate G8).

## Layout (D-022, CONTRACTS G1)

| Source | In the place | Notes |
|---|---|---|
| `src/shared/` | `ReplicatedStorage.Game` | game shared code, one folder per area (`Sim/`, `Kingdom/`, `Kit/`, `Treasury/`, `Feedback/`, …; area names per CONTRACTS v0.4-g2) |
| `src/server/Services/` | `ServerScriptService.Game.Services` | game services; booted with the framework's |
| `src/client/Controllers/` | `StarterPlayerScripts.Game.Controllers` | game controllers; booted with the framework's |
| `config/` | `ReplicatedStorage.Forge.Config` | game config (`Game.luau` = id `game-001`) |
| `tests/<area>/` | not in the place | Lune specs, run over this project |
| `world/` | `ReplicatedStorage.Game.World` | FORGE-02's layout data (`Layout.luau`, CONTRACTS G10.1). A separate mount: require it as `@game/ReplicatedStorage/Game/World/Layout` from every tree, `src/shared` included (a relative path would cross mounts). `world/.gitkeep` keeps the folder for Rojo until real files exist. |
| `../../roblox/src/*`, `../../roblox/assets` | `ReplicatedStorage.Forge`, `ServerScriptService.Forge`, `StarterPlayerScripts.Forge`, `Forge.Assets` | the framework, unchanged |

`Workspace` has no `$path`, so `rojo serve` never deletes what Studio or WorldService puts there.

## Engine settings in the project (D-025, D-026; checked by the place check)
| Setting | Value | What it means for your code |
|---|---|---|
| `Players.CharacterAutoLoads` | `false` | No character exists until the game spawns one (`player:LoadCharacter()` at the kingdom's keep, FORGE-01). Do not wait for `player.Character` before the player has joined a kingdom. |
| `Workspace.StreamingEnabled` | `true` | Clients only have the parts near them. Client code finds world parts with `WaitForChild`/tags and handles them streaming out; never assume a far part exists on a client. |
| `Workspace.ModelStreamingBehavior` | `Improved` | Models stream as units. |
| `Workspace.StreamOutBehavior` | `Opportunistic` | Far content can be removed from clients. |
| `Workspace.StreamingIntegrityMode` | `PauseOutsideLoadedArea` | A player outside loaded content is paused, not dropped into the void. |
| `Lighting.Technology` | `Future` | Not settable from scripts, so it lives in the project (FORGE-02 request, FL-0055). WorldService applies every other lighting value from `world/Lighting.luau`. |
| `StarterPlayer.EnableMouseLockOption` | `false` | No shift lock: Left Shift is the sprint key, and shift lock would fight the ruler's smooth turning (FORGE-04 request, FL-0053). |

The place check verifies every `$properties` value of the project in the built place; a value Rojo
drops or mis-converts fails `check.sh`.

## Build, serve, test
```bash
bash roblox/scripts/check.sh            # every gate, framework + game-001 (specs, build, place check)
lune run roblox/tests/harness/run.luau --project games/game-001/default.project.json --specs games/game-001/tests
lune run roblox/tests/harness/run.luau --project games/game-001/default.project.json --specs games/game-001/tests Kingdom  # filter
bash roblox/scripts/stamp_build.sh && mkdir -p roblox/build
rojo build games/game-001/default.project.json -o roblox/build/game-001.rbxl   # open this in Studio
rojo serve games/game-001/default.project.json                                  # then Rojo → Connect
```
CI on `main` uploads `forgeloop-game001-<short sha>` (contains `forgeloop-game001-<short sha>.rbxl`):
the integrated AI Kingdoms place for Studio playtests (`STUDIO_PLAYTEST.md`, FL-0047).

## Requires (D-017 as extended by D-022)
- Inside one tree: relative (`require("./Types")`, `require("../Sim/Clock")`).
- Game server/client/config → game shared: `require("@game/ReplicatedStorage/Game/Kingdom/Types")`.
- Game code → framework: `require("@game/ReplicatedStorage/Forge/Core/Signal")`,
  `require("@game/ReplicatedStorage/Forge/Contracts/GameEvents")`, config `.../Forge/Config/Costs`.
- Never: `@game/ServerScriptService/...`, `@game/StarterPlayer/...`, other aliases, requires inside
  functions. **Framework code (`roblox/src`) never requires game code**: the place check and the
  Lune loader reject it.

## Add a game service (or controller) and its spec
`src/server/Services/KingdomService.luau` (owner per team.md):
```lua
--!strict
local Types = require("@game/ReplicatedStorage/Game/Kingdom/Types")

local KingdomService = {}
KingdomService.__index = KingdomService

local Def = { name = "KingdomService", dependencies = { "PlayerService" } } -- must exist in either tree, or the boot gate fails

function Def.new(env, registry) -- no yielding; use env, never game:GetService
	return setmetatable({ _env = env, _players = registry:get("PlayerService") }, KingdomService)
end

return Def
```
`tests/sim/KingdomService.spec.luau`:
```lua
local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect = T.describe, T.it, T.expect
local MockEnv = require("../../../../roblox/tests/mocks/MockEnv")
local Def = require("@game/ServerScriptService/Game/Services/KingdomService") -- specs may reach any tree

describe("KingdomService", function()
	it("assigns a ruler to a kingdom", function()
		local env = MockEnv.new({ seed = 1 })
		-- build it with test doubles for its dependencies, act, assert success and failure paths
	end)
end)
```
Specs in `games/game-001/tests/**` run in `check.sh` step `game-001 specs`.
Harness, mocks and matchers: `roblox/README.md` ("Add a test").

## What the integration gate checks for you (`tests/integration/Boot.spec.luau`, FORGE-05)
Every service in **both** trees is required, validated and booted together under `MockEnv` (and
every controller, as a client with a `LocalPlayer`), then run for 10 virtual seconds. It fails if:
a dependency is missing or cyclic across workers, a name exists in both trees, `new()` yields or
errors, `start()` errors, or a spawned thread errors. Remotes from every area in both trees are
passed in as `env.sharedModules("Remotes")`. An area name with `Remotes` in both the Forge and Game
trees is rejected here and by the place check: game remotes use the areas `Kingdom`, `Sim`, `Build`,
`Army`, `Match`, `Treasury` and `Feedback` (FORGE-00 decision); `Economy` and `Experience` are
framework areas.

If your service needs something `MockEnv` does not provide, write a handoff to FORGE-05; do not
work around the gate.

## Studio debug commands and presets (FL-0068)
Register your own commands and the playtest presets for your rows from your service's `start()`
(`roblox/src/shared/Debug/DebugCommands.luau` has the full API):
```lua
local DebugCommands = require("@game/ReplicatedStorage/Forge/Debug/DebugCommands")
DebugCommands.register({ name = "treasury.grant", label = "Grant 500 of each resource",
	args = { Validate.integer(0, 100000) }, run = function(player, amount) ... return "granted" end })
DebugCommands.registerPreset({ name = "vs1.row6", label = "Row 6 start", steps = { { "treasury.grant", 500 } } })
```
Commands run only in Studio (no remotes exist on live servers), arguments are validated fail-closed
and every command runs under `pcall`. Names are `area.action`; preset names `vs1.row<N>`.
Requested commands per owner: `production/handoffs/2026-10-12-forge-05-to-all-debug-commands.md`.

## Network mocks for entity replication (FL-0067)
`env.mock.remotes` behaves like Roblox for `UnreliableRemoteEvent` payloads:
- a buffer counts exactly `buffer.len` bytes; payloads over **1000 bytes are dropped** (logged with
  `dropped = true`); the engine may compress buffers, so stay well under (D-025: ≤ 900 B);
- buffers are **copied** on send: writing to your buffer after `FireClient` changes nothing on the client;
- `network:holdUnreliable(remote)` then `network:releaseUnreliable(remote, "reverse" | { 3, 1, 2 } | "fifo")`
  delays and reorders deliveries (both directions); `network:dropNext(remote, n)` loses packets.
