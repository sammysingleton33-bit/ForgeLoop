--!strict
--[[
	Items (ReplicatedStorage.Forge.Config.Items) for the sandbox integration place. Owned by
	FORGE-03. Generic cosmetics that exercise the framework economy (FL-0018: ItemRegistry,
	Inventory, RewardTables). Game #1's economy lives in games/game-001/config (Resources, Costs).

	Fields (validated by shared/Economy/ItemRegistry.luau)
		id           string  [a-z][a-z0-9_]*, unique
		kind         "building" | "unit" | "cosmetic"   (only cosmetics are inventory items)
		name, description, icon (UITheme icon name)
		rarity       "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary"
		maxStack     integer? inventory stack cap (default 1)
		equipSlot    string?  cosmetics only: "banner" | "crest"
]]

export type ItemDef = {
	id: string,
	kind: "building" | "unit" | "cosmetic",
	name: string,
	description: string,
	icon: string,
	rarity: "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary",
	maxStack: number?,
	equipSlot: string?,
}

local Items: { ItemDef } = {
	{
		id = "banner_oak",
		kind = "cosmetic",
		name = "Oak Banner",
		description = "A green banner with a golden oak.",
		icon = "banner",
		rarity = "Common",
		equipSlot = "banner",
	},
	{
		id = "banner_lion",
		kind = "cosmetic",
		name = "Lion Banner",
		description = "A crimson banner with a rampant lion.",
		icon = "banner",
		rarity = "Uncommon",
		equipSlot = "banner",
	},
	{
		id = "banner_dragon",
		kind = "cosmetic",
		name = "Dragon Banner",
		description = "A black banner with a silver dragon.",
		icon = "banner",
		rarity = "Rare",
		equipSlot = "banner",
	},
	{
		id = "crest_phoenix",
		kind = "cosmetic",
		name = "Phoenix Crest",
		description = "A crest that glows like embers.",
		icon = "crest",
		rarity = "Epic",
		equipSlot = "crest",
	},
	{
		id = "crest_sun",
		kind = "cosmetic",
		name = "Sun Crest",
		description = "The crest of legendary rulers.",
		icon = "crest",
		rarity = "Legendary",
		equipSlot = "crest",
	},
}

return table.freeze(Items)
