--!strict
--[[
	Currencies (ReplicatedStorage.Forge.Config.Currencies). Owned by FORGE-03.

	Content: Game #1 "AI Kingdoms" (user directive 2026-10-12). It lives in the sandbox config
	until FORGE-00 creates games/game-001 and FORGE-05 maps it (handoff
	production/handoffs/2026-10-12-forge-03-to-forge-00-ai-kingdoms.md). Numbers are provisional
	balance proposals, not approved values.

	Fields
		id                string  [a-z][a-z0-9_]*, unique
		name              string  shown to players
		scope             "match"   kingdom treasury resource: reset every match, never saved
		                  "profile" player wallet, saved in the `economy` namespace (interfaces §5)
		icon              string  icon name (UITheme.icons)
		start             integer balance a new treasury/wallet starts with
		cap               integer base maximum (Storehouses raise match caps; Construction.storageCaps)
		robuxPurchasable  boolean true when any Robux product grants this currency: random rewards
		                          bought with it are then paid random (interfaces §7)
		description       string  one line for tooltips
	Validated at startup by shared/Economy/Currencies.luau (order in this list = display order).
]]

export type CurrencyDef = {
	id: string,
	name: string,
	scope: "match" | "profile",
	icon: string,
	start: number,
	cap: number,
	robuxPurchasable: boolean,
	description: string,
}

local Currencies: { CurrencyDef } = {
	{
		id = "food",
		name = "Food",
		scope = "match",
		icon = "food",
		start = 100,
		cap = 500,
		robuxPurchasable = false,
		description = "Feeds citizens and soldiers. Farms produce it.",
	},
	{
		id = "wood",
		name = "Wood",
		scope = "match",
		icon = "wood",
		start = 150,
		cap = 500,
		robuxPurchasable = false,
		description = "Used for almost every building. Lumber Camps produce it.",
	},
	{
		id = "stone",
		name = "Stone",
		scope = "match",
		icon = "stone",
		start = 50,
		cap = 300,
		robuxPurchasable = false,
		description = "Needed for upgrades and defences. Quarries produce it.",
	},
	{
		id = "gold",
		name = "Gold",
		scope = "match",
		icon = "gold",
		start = 50,
		cap = 300,
		robuxPurchasable = false,
		description = "Pays for soldiers and advanced buildings. Gold Mines produce it.",
	},
	{
		id = "crowns",
		name = "Crowns",
		scope = "profile",
		icon = "crown",
		start = 0,
		cap = 1000000000,
		robuxPurchasable = false,
		description = "Earned by playing matches. Spent on kingdom banners and crests.",
	},
}

return table.freeze(Currencies)
