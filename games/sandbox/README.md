# games/sandbox — integration place (owner: FORGE-05, except per-area config files)

The genre-agnostic place where every system is exercised together until Game #1 is approved (D-009).

| Path | In the place | Owner |
|---|---|---|
| `config/Game.luau` | `ReplicatedStorage.Forge.Config.Game` (`id = "sandbox"`) | FORGE-05 |
| `config/{Rounds,Spawns,Hazards,Combat}.luau` | `ReplicatedStorage.Forge.Config.*` | FORGE-01 |
| `config/{Items,Currencies,RewardTables,Products,Shop,UITheme}.luau` | same | FORGE-03 |
| `config/{Onboarding,Quests,DailyRewards,Sounds,Analytics}.luau` | same | FORGE-04 |
| `map/` (added by FL-0044) | children of `Workspace` (Rojo mapping added with FL-0044, interfaces §1) | FORGE-05 |

Config files are reached from any tree with `require("@game/ReplicatedStorage/Forge/Config/<File>")`
(roblox/README.md, "Requires"). Build and check: `bash roblox/scripts/check.sh`.
