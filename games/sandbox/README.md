# games/sandbox — AI Kingdoms integration place (owner: FORGE-05, except per-area config files)

The place where every system is exercised together. Since 2026-10-12 it is the **AI Kingdoms**
vertical-slice integration place (user direction in the FORGE-05 launch instruction; FORGE-00 records
the decision and creates `games/game-001/` when it formalises the game brief).

| Path | In the place | Owner |
|---|---|---|
| `config/Game.luau` | `ReplicatedStorage.Forge.Config.Game` (`id = "sandbox"`) | FORGE-05 |
| `config/Map.luau` | `ReplicatedStorage.Forge.Config.Map` — map tag/attribute contract | FORGE-05 |
| `config/{Rounds,Spawns,Hazards,Combat}.luau` | `ReplicatedStorage.Forge.Config.*` | FORGE-01 |
| `config/{Items,Currencies,RewardTables,Products,Shop,UITheme}.luau` | same | FORGE-03 |
| `config/{Onboarding,Quests,DailyRewards,Sounds,Analytics}.luau` | same | FORGE-04 |
| `map/*.model.json` | `Workspace.ForgeMap` — **generated** by `roblox/scripts/gen_sandbox_map.luau` | FORGE-05 |

Config files are reached from any tree with `require("@game/ReplicatedStorage/Forge/Config/<File>")`
(roblox/README.md, "Requires"). Build and check: `bash roblox/scripts/check.sh`.

## Map v0 (FL-0044)

World plan (studs, +Y up, North = −Z; picture: `map-plan.png`): a 720 × 720 grass field with invisible edge walls.

- **Centre:** 64 × 64 cobblestone plaza with the lobby `SpawnLocation` (the only one in the map, so
  every player joins here), a well, and a banner pole in each kingdom's colour at each road mouth.
- **Four kingdoms**, `South` (+Z), `East` (+X), `North` (−Z), `West` (−X), centred 210 studs out.
  Each is the same layout rotated: a 170 × 170 walled territory with its gate facing the plaza, a
  cobblestone road from the gate to the ruler's dais, the keep (with four towers and roof caps in the
  kingdom colour), a stockpile, three villager homes, a forest (Wood), a quarry (Stone), a farm
  (Food) and three marked build plots.
- **Neutral gold mines** on the four diagonals (`Neutral-Gold-SE/NE/NW/SW`), between kingdoms.
- Seeded wild trees and boulders outside the territories; 426 parts in total.

Banner colours (map only; kingdom display names/colours belong to game config): South red, East
blue, North green, West gold.

### Tags (CollectionService) and attributes — full table in `config/Map.luau`

| Tag | Count | On | Attributes |
|---|---|---|---|
| `ForgeLobbySpawn` | 1 | `SpawnLocation` (Neutral) | — |
| `ForgePlayArea` | 1 | invisible bounds part (720 × 240 × 720) | — |
| `ForgeKingdom` | 4 | `Model` per kingdom | `KingdomId` |
| `ForgeKeep` | 1 / kingdom | keep base part | `KingdomId` |
| `ForgeRulerSpawn` + `ForgeSpawn` | 1 / kingdom | ruler's dais | `KingdomId` |
| `ForgeStockpile` | 1 / kingdom | stockpile platform | `KingdomId` |
| `ForgeVillagerSpawn` | 1 / kingdom | invisible pad by the homes | `KingdomId` |
| `ForgeRallyPoint` | 1 / kingdom | invisible pad inside the gate | `KingdomId` |
| `ForgeBuildPlot` | 3 / kingdom | 16 × 16 plot | `KingdomId`, `PlotId` (`<Kingdom>-Plot-<n>`) |
| `ForgeResourceNode` | 3 / kingdom + 4 neutral | forest floor / quarry / farm / mine patch | `KingdomId` (`Neutral` for mines), `Resource`, `NodeId` |

`ForgeFloodProbe` (from the flood-game plan in FL-0044) is **not** in the map: AI Kingdoms has no
flood. Add it back through `config/Map.luau` if a flood hazard returns.

### Changing the map
1. Edit the layout in `roblox/scripts/gen_sandbox_map.luau` (tags/attributes in `config/Map.luau`).
2. `lune run roblox/scripts/gen_sandbox_map.luau`, then `bash roblox/scripts/check.sh`.
3. Look at it: regenerate the top-down plan `games/sandbox/map-plan.png` with
   `python3 roblox/scripts/render_map_plan.py games/sandbox/map games/sandbox/map-plan.png` (Pillow;
   layout only) and check it in Studio (`roblox/STUDIO_TEST_PLAN.md`, S4).
