# Handoff: FORGE-05 → FORGE-01 · FL-0044 (→ FL-0010, FL-0012, AI Kingdoms gameplay) · 2026-10-12

## What I need / what I'm giving you
The integration place now has an **AI Kingdoms** map (four walled kingdoms around a lobby plaza)
whose gameplay anchors are CollectionService tags with attributes. Please build spawning, kingdom
assignment and match flow against these tags — never against names or positions.

## Done (with commits)
- Map contract `games/sandbox/config/Map.luau` → `require("@game/ReplicatedStorage/Forge/Config/Map")`
  (`Map.TAGS`, `Map.ATTR`, `Map.KINGDOM_IDS = { "South", "East", "North", "West" }`, `Map.RESOURCES`,
  `Map.PER_KINGDOM`).
- Generated map `games/sandbox/map/` → `Workspace.ForgeMap` (generator `roblox/scripts/gen_sandbox_map.luau`).
- Place-check map assertions + `Debug/MapReport` (server logs `map ready kingdoms=4 ...`).
- Branch `forge/05-integration-fl0044`, PR: see `agents/forge-05/STATUS.md` (link added when opened).

## Evidence
- `bash roblox/scripts/check.sh` → OVERALL PASS (7 steps; place check: 4 kingdoms, 52 anchors, 426 parts).
- Negative map gates: a part written with `Position` instead of `CFrame`, a missing RulerSpawn tag,
  an unanchored part + misspelled tag, a hand-edited model file → each exit 1.
- **Unverified in Studio** until the user runs S4 in `roblox/STUDIO_TEST_PLAN.md`.

## Interfaces touched
Additive: new config module `Config/Map` (FORGE-05 file), new `Workspace.ForgeMap`. No contract change.

| Tag | Count | Use it for |
|---|---|---|
| `ForgeLobbySpawn` | 1 (the only SpawnLocation) | where everyone joins / waits between matches |
| `ForgePlayArea` | 1 | bounds (out-of-bounds checks; invisible, no collision/query) |
| `ForgeKingdom` | 4 Models | `KingdomId` attribute; ownership/assignment |
| `ForgeKeep` | 1 / kingdom | the keep core: match target (siege later) |
| `ForgeRulerSpawn` + `ForgeSpawn` | 1 / kingdom | ruler spawn; `ForgeSpawn` kept for FL-0010 compatibility |
| `ForgeStockpile` | 1 / kingdom | villagers deliver resources here |
| `ForgeVillagerSpawn` | ≥1 / kingdom | villager spawn |
| `ForgeRallyPoint` | 1 / kingdom | recruited troops gather here |
| `ForgeBuildPlot` | ≥1 / kingdom (3 now) | construction sites; `PlotId` unique |
| `ForgeResourceNode` | Wood/Stone/Food per kingdom; Gold neutral ×4 | `Resource`, `NodeId` unique, `KingdomId` (`Neutral`) |

Spawn a character at `anchor.CFrame + Vector3.new(0, anchor.Size.Y / 2 + 3, 0)`.
In specs, build tagged parts in `env.Workspace` with `env.CollectionService:AddTag` (see
`roblox/tests/unit/contracts/MapReport.spec.luau` `buildMap()` for a complete minimal map).

## Open issues and risks
- `ForgeFloodProbe` from the original FL-0044 spec is not in the map (no flood in AI Kingdoms);
  FL-0011 (flood hazard) needs re-scoping by FORGE-00.
- Teams: the map does not create `Teams`; kingdom → team mapping is gameplay's choice.
- Need another anchor (e.g. barracks, siege-engine spawn, path waypoints)? Handoff to FORGE-05;
  it is a one-line generator change plus a `Config/Map` entry.

## Next actions for the receiver
1. Read `games/sandbox/config/Map.luau` and `games/sandbox/README.md` (map plan + tag table).
2. Use `Map.TAGS.*` constants in RoundService/SpawnService (FL-0010) and the upcoming kingdom/match services.
3. Reply in a handoff or PR comment if a tag or attribute does not fit your design.

## Files to read
- `games/sandbox/config/Map.luau` — the contract
- `games/sandbox/README.md` — layout, counts
- `roblox/src/shared/Debug/MapReport.luau` — runtime summary pattern
