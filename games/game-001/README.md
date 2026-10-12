# games/game-001 — AI Kingdoms: build, run and test (owner of this file: FORGE-05)

Design: `BRIEF.md`. Contracts: `CONTRACTS.md` (FORGE-00). Who owns which folder:
`docs/workflows/team.md`, section "game-001" (checked by the ownership gate G8).

## Layout (D-022, CONTRACTS G1)

| Source | In the place | Notes |
|---|---|---|
| `src/shared/` | `ReplicatedStorage.Game` | game shared code, one folder per area (`Sim/`, `Kingdom/`, `Kit/`, `Economy/`, `Experience/`) |
| `src/server/Services/` | `ServerScriptService.Game.Services` | game services; booted with the framework's |
| `src/client/Controllers/` | `StarterPlayerScripts.Game.Controllers` | game controllers; booted with the framework's |
| `config/` | `ReplicatedStorage.Forge.Config` | game config (`Game.luau` = id `game-001`) |
| `tests/<area>/` | not in the place | Lune specs, run over this project |
| `world/` | **not mapped yet** | Rojo fails on a missing `$path`; FORGE-05 adds `world/` → `ReplicatedStorage.Game.World` in the PR that lands the first file there (FORGE-02 handoff) |
| `../../roblox/src/*`, `../../roblox/assets` | `ReplicatedStorage.Forge`, `ServerScriptService.Forge`, `StarterPlayerScripts.Forge`, `Forge.Assets` | the framework, unchanged |

`Workspace` is not mapped, so `rojo serve` never deletes what Studio or WorldService puts there.

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
