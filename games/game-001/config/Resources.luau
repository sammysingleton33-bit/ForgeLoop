--!strict
--[[
	Resources (ReplicatedStorage.Forge.Config.Resources). Owned by FORGE-03 (team.md, game-001).

	The kingdom resources of AI Kingdoms (BRIEF §7, CONTRACTS G2 `ResourceId`). Display order is
	`ids`. Iron arrives at VS-2 (additive). Colours and icons are the HUD's; the treasury, costs and
	upkeep use only the ids.

		local Resources = require("@game/ReplicatedStorage/Forge/Config/Resources")
		for _, id in Resources.ids do print(Resources.defs[id].name) end

	Fields per resource: id, name, icon (UITheme icon name), color (#RRGGBB), description.
]]

export type ResourceId = "food" | "wood" | "stone" | "gold"
export type ResourceDef = {
	id: ResourceId,
	name: string,
	icon: string,
	color: string,
	description: string,
}

local defs: { [string]: ResourceDef } = {
	food = {
		id = "food",
		name = "Food",
		icon = "food",
		color = "#8DBF4B",
		description = "Feeds citizens and soldiers every minute. Farmers grow it.",
	},
	wood = {
		id = "wood",
		name = "Wood",
		icon = "wood",
		color = "#C4844C",
		description = "Used for almost every building. Woodcutters fell it.",
	},
	stone = {
		id = "stone",
		name = "Stone",
		icon = "stone",
		color = "#9FB0C4",
		description = "Needed for the keep, towers and walls. Miners cut it.",
	},
	gold = {
		id = "gold",
		name = "Gold",
		icon = "gold",
		color = "#F2C447",
		description = "Pays for advanced buildings. Miners dig it.",
	},
}

for _, def in defs do
	table.freeze(def)
end

return table.freeze({
	ids = table.freeze({ "food", "wood", "stone", "gold" }) :: { ResourceId },
	defs = table.freeze(defs),
})
