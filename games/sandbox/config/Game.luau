--!strict
--[[
	Sandbox game definition (ReplicatedStorage.Forge.Config.Game). Owned by FORGE-05.

	The sandbox is the integration place; since 2026-10-12 it hosts the AI Kingdoms vertical slice
	(user direction). The map contract is Config/Map.
	Per-area config files in this folder are owned by their areas (docs/workflows/team.md):
	Rounds/Spawns/Hazards/Combat -> FORGE-01; Items/Currencies/RewardTables/Products/Shop/UITheme
	-> FORGE-03; Onboarding/Quests/DailyRewards/Sounds/Analytics -> FORGE-04.

	Reach it from any tree with require("@game/ReplicatedStorage/Forge/Config/Game").
]]

export type GameConfig = {
	id: string,
	displayName: string,
}

local Game: GameConfig = {
	id = "sandbox",
	displayName = "AI Kingdoms (sandbox)",
}

return table.freeze(Game)
