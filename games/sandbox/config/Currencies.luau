--!strict
--[[
	Currencies (ReplicatedStorage.Forge.Config.Currencies). Owned by FORGE-03.

	Sandbox integration place: one generic soft currency for the framework economy (FL-0018).
	Game #1's kingdom resources live in games/game-001/config/Resources.luau.

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
		id = "coins",
		name = "Coins",
		scope = "profile",
		icon = "gold",
		start = 0,
		cap = 1000000000,
		robuxPurchasable = false,
		description = "Earned by playing. Spent on banners and crests.",
	},
}

return table.freeze(Currencies)
