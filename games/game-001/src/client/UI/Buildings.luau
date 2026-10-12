--!strict
--[[
	UI/Buildings — how the AI Kingdoms screens present each CONTRACTS G2 `BuildingType`: display
	name, icon, menu category and one line of description. Presentation only: costs come from
	`Treasury.GetCosts` / config Costs (G6), footprints from `Kit.footprint` (G10), and whether a spot
	is valid only from the server (`Build.CanPlace`).

		Buildings.get(type) -> Info?            Info = { type, name, icon, category, buildable, description }
		Buildings.menu(category) -> { Info }    buildable types of one menu tab, in menu order
		Buildings.CATEGORIES                    { { id, label, icon } } the build menu tabs
		Buildings.name(type) -> string          the display name ("Lumber Camp"), or the raw type
	The keep is never built from the menu (one per kingdom, placed at Founding); it is upgraded from
	the Kingdom panel.
]]

export type Info = {
	type: string,
	name: string,
	icon: string,
	category: string,
	buildable: boolean,
	description: string,
}

local Buildings = {}

Buildings.CATEGORIES = table.freeze({
	table.freeze({ id = "economy", label = "Economy", icon = "food" }),
	table.freeze({ id = "civic", label = "Homes", icon = "house" }),
	table.freeze({ id = "military", label = "Military", icon = "army" }),
})

-- Menu order inside each category = order in this list.
local LIST: { Info } = {
	{
		type = "keep",
		name = "Keep",
		icon = "keep",
		category = "civic",
		buildable = false,
		description = "The heart of your kingdom. Citizens nearby cheer when it grows.",
	},
	{
		type = "farm",
		name = "Farm",
		icon = "farm",
		category = "economy",
		buildable = true,
		description = "Farmers grow food here. Food feeds every citizen and soldier.",
	},
	{
		type = "lumbercamp",
		name = "Lumber Camp",
		icon = "lumbercamp",
		category = "economy",
		buildable = true,
		description = "Woodcutters fell nearby trees and bring the logs here.",
	},
	{
		type = "quarry",
		name = "Quarry",
		icon = "quarry",
		category = "economy",
		buildable = true,
		description = "Miners cut stone and dig gold close to the quarry.",
	},
	{
		type = "storehouse",
		name = "Storehouse",
		icon = "storehouse",
		category = "economy",
		buildable = true,
		description = "A drop-off point: haulers deliver goods to the nearest one.",
	},
	{
		type = "house",
		name = "House",
		icon = "house",
		category = "civic",
		buildable = true,
		description = "Homes for your citizens. More houses, more people.",
	},
	{
		type = "barracks",
		name = "Barracks",
		icon = "barracks",
		category = "military",
		buildable = true,
		description = "Recruits and trains soldiers for your kingdom.",
	},
	{
		type = "watchtower",
		name = "Watchtower",
		icon = "watchtower",
		category = "military",
		buildable = true,
		description = "A lookout over your lands.",
	},
	{
		type = "wall",
		name = "Wall",
		icon = "wall",
		category = "military",
		buildable = true,
		description = "A stone wall segment to close your borders.",
	},
	{
		type = "gate",
		name = "Gate",
		icon = "gate",
		category = "military",
		buildable = true,
		description = "A gate in your walls that your people can pass.",
	},
}

local byType: { [string]: Info } = {}
for _, info in LIST do
	table.freeze(info)
	byType[info.type] = info
end

function Buildings.get(buildingType: string): Info?
	return byType[buildingType]
end

function Buildings.name(buildingType: string): string
	local info = byType[buildingType]
	return if info then info.name else buildingType
end

function Buildings.menu(category: string): { Info }
	local out = {}
	for _, info in LIST do
		if info.buildable and info.category == category then
			table.insert(out, info)
		end
	end
	return out
end

function Buildings.categoryLabel(category: string): string
	for _, c in Buildings.CATEGORIES do
		if c.id == category then
			return c.label
		end
	end
	return category
end

return table.freeze(Buildings)
