--!strict
--[[
	Game definition for game-001 (ReplicatedStorage.Forge.Config.Game). Owned by FORGE-05.

	AI Kingdoms (D-020; brief: games/game-001/BRIEF.md). The final title is the user's decision
	(BRIEF §16), so displayName is the working name. Main.server/Main.client log `id` at start, so
	every Studio report shows which project was built (sandbox or game-001).

	Reach it from any tree with require("@game/ReplicatedStorage/Forge/Config/Game").
]]

export type GameConfig = {
	id: string,
	displayName: string,
}

local Game: GameConfig = {
	id = "game-001",
	displayName = "AI Kingdoms",
}

return table.freeze(Game)
