--!strict
--[[
	RewardTables (ReplicatedStorage.Forge.Config.RewardTables). Owned by FORGE-03.

	Content: Game #1 "AI Kingdoms" cosmetic rewards (items in Items.luau). Every weight, cost and
	pity rule below is a PROVISIONAL balance proposal for the user's approval, not an approved value.

	Fields (validated at startup by shared/Economy/RewardTables.luau; unknown fields are rejected)
		id      string  [a-z][a-z0-9_]*, at most 32 bytes, unique
		name    string  shown to players
		tiers   { Tier } at least one; each rarity at most once; shown in rarity order
			rarity  "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary"
			weight  number > 0: chance of the tier = weight / sum of the table's tier weights
			items   { { itemId: string, weight: number, qty: integer? } } at least one; cosmetic items
			        whose own rarity equals the tier's; chance inside the tier = weight / sum of the
			        tier's item weights; qty defaults to 1 and may not exceed the item's maxStack
		pity    { afterOpens: integer >= 1, minRarity: rarity }?  the afterOpens-th open since the last
		        result at or above minRarity is guaranteed to be at or above it (lower tiers removed,
		        remaining weights renormalised); some tier must be at or above minRarity
		cost    { currency: string, amount: integer >= 1 }?  nil = earned through gameplay, no cost

	Policy (interfaces §7, AGENTS.md): every table shows its possible outcomes and its numerical odds,
	taken from RewardTables.odds — the exact distribution the server samples. Validation rejects a
	table where any possible outcome would be shown as 0.00%. Crowns are not robuxPurchasable
	(Currencies.luau), so both tables are earned / soft-currency random rewards, not paid random;
	making Crowns purchasable with Robux would turn the Royal Chest into a paid random item that needs
	the PolicyService gate (canBuyPaidRandom).

	Proposed odds (from the weights; the UI shows the computed values, not these comments)
		chest_banners  Common 60%, Uncommon 25%, Rare 10%, Epic 4%, Legendary 1%;
		               the 10th open without an Epic or better: Epic 80%, Legendary 20%
		match_reward   Common 70%, Uncommon 20%, Rare 7%, Epic 2.5%, Legendary 0.5%
]]

export type Rarity = "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary"
export type TierItem = { itemId: string, weight: number, qty: number? }
export type Tier = { rarity: Rarity, weight: number, items: { TierItem } }
export type RewardTableDef = {
	id: string,
	name: string,
	tiers: { Tier },
	pity: { afterOpens: number, minRarity: Rarity }?,
	cost: { currency: string, amount: number }?,
}

local RewardTables: { RewardTableDef } = {
	{
		id = "chest_banners",
		name = "Royal Chest",
		cost = { currency = "crowns", amount = 100 },
		pity = { afterOpens = 10, minRarity = "Epic" }, -- "Epic or better guaranteed within 10 opens"
		tiers = {
			{ rarity = "Common", weight = 60, items = { { itemId = "banner_oak", weight = 1 } } },
			{ rarity = "Uncommon", weight = 25, items = { { itemId = "banner_lion", weight = 1 } } },
			{ rarity = "Rare", weight = 10, items = { { itemId = "banner_dragon", weight = 1 } } },
			{ rarity = "Epic", weight = 4, items = { { itemId = "crest_phoenix", weight = 1 } } },
			{ rarity = "Legendary", weight = 1, items = { { itemId = "crest_sun", weight = 1 } } },
		},
	},
	{
		id = "match_reward",
		name = "Match Reward", -- earned at the end of a match; no cost, no pity
		tiers = {
			{ rarity = "Common", weight = 700, items = { { itemId = "banner_oak", weight = 1 } } },
			{ rarity = "Uncommon", weight = 200, items = { { itemId = "banner_lion", weight = 1 } } },
			{ rarity = "Rare", weight = 70, items = { { itemId = "banner_dragon", weight = 1 } } },
			{ rarity = "Epic", weight = 25, items = { { itemId = "crest_phoenix", weight = 1 } } },
			{ rarity = "Legendary", weight = 5, items = { { itemId = "crest_sun", weight = 1 } } },
		},
	},
}

return table.freeze(RewardTables)
