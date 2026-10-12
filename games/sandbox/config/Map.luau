--!strict
--[[
	Map contract v0 for the AI Kingdoms sandbox (ReplicatedStorage.Forge.Config.Map). Owned by FORGE-05.

	The map (games/sandbox/map, built into Workspace.ForgeMap) marks every gameplay anchor with a
	CollectionService tag plus attributes. Gameplay code finds anchors by tag, never by name or
	position, so the map can be redesigned without code changes:

		local Map = require("@game/ReplicatedStorage/Forge/Config/Map")
		for _, part in env.CollectionService:GetTagged(Map.TAGS.RulerSpawn) do
			local kingdomId = part:GetAttribute(Map.ATTR.KingdomId)
		end

	Every tagged anchor is an anchored BasePart, except Kingdom (one Model per kingdom grouping its
	parts). Decoration parts carry no tags. Spawning: put the character at
	anchor.CFrame + Vector3.new(0, anchor.Size.Y / 2 + 3, 0).

	| Tag (Map.TAGS.*)               | Instance          | Per kingdom | Attributes |
	| LobbySpawn  ForgeLobbySpawn    | SpawnLocation     | — (1 total, the only SpawnLocation) | — |
	| PlayArea    ForgePlayArea      | Part (invisible)  | — (1 total, bounds of the playable map) | — |
	| Kingdom     ForgeKingdom       | Model             | 1  | KingdomId |
	| Keep        ForgeKeep          | Part              | 1  | KingdomId — the keep core (siege/match target) |
	| RulerSpawn  ForgeRulerSpawn    | Part              | 1  | KingdomId — also tagged ForgeSpawn (FL-0010 compatibility) |
	| Stockpile   ForgeStockpile     | Part              | 1  | KingdomId — villagers deliver resources here |
	| VillagerSpawn ForgeVillagerSpawn | Part (invisible) | ≥1 | KingdomId |
	| RallyPoint  ForgeRallyPoint    | Part (invisible)  | 1  | KingdomId — troops gather here (troop recruitment) |
	| BuildPlot   ForgeBuildPlot     | Part              | ≥1 | KingdomId, PlotId (unique map-wide) |
	| ResourceNode ForgeResourceNode | Part              | ≥1 per kingdom resource | KingdomId ("Neutral" for contested), Resource, NodeId (unique) |

	Kingdom resources (Wood, Stone, Food) exist in every kingdom; Gold exists only at neutral mines
	between kingdoms, so expanding toward a neighbour is worth fighting over.
	Checked headlessly by roblox/scripts/check_place.luau and logged at server start by
	Debug/MapReport (Studio smoke test S4).
]]

export type KingdomId = "North" | "East" | "South" | "West"
export type ResourceKind = "Wood" | "Stone" | "Food" | "Gold"

local Map = {}

Map.VERSION = 0

Map.TAGS = table.freeze({
	LobbySpawn = "ForgeLobbySpawn",
	PlayArea = "ForgePlayArea",
	Kingdom = "ForgeKingdom",
	Keep = "ForgeKeep",
	RulerSpawn = "ForgeRulerSpawn",
	Spawn = "ForgeSpawn",
	Stockpile = "ForgeStockpile",
	VillagerSpawn = "ForgeVillagerSpawn",
	RallyPoint = "ForgeRallyPoint",
	BuildPlot = "ForgeBuildPlot",
	ResourceNode = "ForgeResourceNode",
})

Map.ATTR = table.freeze({
	KingdomId = "KingdomId",
	Resource = "Resource",
	NodeId = "NodeId",
	PlotId = "PlotId",
})

-- Kingdom ids in map order (clockwise from South). Display names and colours are game config,
-- not map data; BannerColor only tints the map's flags.
Map.KINGDOM_IDS = table.freeze({ "South", "East", "North", "West" } :: { KingdomId })
Map.NEUTRAL = "Neutral"
Map.RESOURCES = table.freeze({ "Wood", "Stone", "Food", "Gold" } :: { ResourceKind })
Map.KINGDOM_RESOURCES = table.freeze({ "Wood", "Stone", "Food" } :: { ResourceKind })
Map.NEUTRAL_RESOURCES = table.freeze({ "Gold" } :: { ResourceKind })

-- Per-kingdom anchor counts: exact numbers, or { min = n } for "at least n".
Map.PER_KINGDOM = table.freeze({
	Keep = 1,
	RulerSpawn = 1,
	Stockpile = 1,
	RallyPoint = 1,
	VillagerSpawn = { min = 1 },
	BuildPlot = { min = 1 },
})

return table.freeze(Map)
