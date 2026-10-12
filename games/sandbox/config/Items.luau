--!strict
--[[
	Items (ReplicatedStorage.Forge.Config.Items). Owned by FORGE-03.

	Content: Game #1 "AI Kingdoms" (see Currencies.luau for the provisional location). Costs,
	build times and production rates are provisional balance proposals for the user's approval.

	Common fields (validated by shared/Economy/ItemRegistry.luau)
		id           string  [a-z][a-z0-9_]*, unique across all items
		kind         "building" | "unit" | "cosmetic"
		name         string
		description  string
		icon         string  icon name (UITheme.icons)
		rarity       "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary"
		maxStack     integer? inventory stack cap (cosmetics; default 1)
		equipSlot    string?  cosmetics only: "banner" | "crest"

	kind = "building": `building` (validated by shared/Economy/Construction.luau)
		category     "economy" | "civic" | "military"   (construction menu tab)
		maxCount     integer  most a kingdom may own
		prebuilt     boolean? every kingdom starts with one at level 1 (the Town Hall)
		levels       { Level } level 1 = construction, level n > 1 = upgrade from n - 1
			cost       { [currencyId]: integer }  match currencies only, all > 0 (empty only for
			           level 1 of a prebuilt building)
			buildSec   integer  construction/upgrade time (0 only for that prebuilt level)
			requires   { { building: string, level: integer } }?  completed buildings needed
			workers    integer? citizens that can work here
			produces   { [currencyId]: integer }? per worker per minute
			housing    integer? citizens this building houses
			storage    integer? added to every match currency cap
	kind = "unit": `unit` (army recruitment; combat stats belong to FORGE-01's config)
		cost, trainSec, requires (as above), housing (population used)

	Gameplay-only data (footprint, model asset id, hit points, combat stats) belongs to FORGE-01's
	config keyed by the same item id (proposal in the FORGE-01 kingdom API handoff).
]]

export type Bundle = { [string]: number }
export type Requirement = { building: string, level: number }
export type BuildingLevel = {
	cost: Bundle,
	buildSec: number,
	requires: { Requirement }?,
	workers: number?,
	produces: Bundle?,
	housing: number?,
	storage: number?,
}
export type ItemDef = {
	id: string,
	kind: "building" | "unit" | "cosmetic",
	name: string,
	description: string,
	icon: string,
	rarity: "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary",
	maxStack: number?,
	equipSlot: string?,
	building: {
		category: "economy" | "civic" | "military",
		maxCount: number,
		prebuilt: boolean?,
		levels: { BuildingLevel },
	}?,
	unit: {
		cost: Bundle,
		trainSec: number,
		requires: { Requirement }?,
		housing: number,
	}?,
}

local TH2 = { { building = "townhall", level = 2 } }
local TH3 = { { building = "townhall", level = 3 } }

local Items: { ItemDef } = {
	-- Civic -----------------------------------------------------------------------------------
	{
		id = "townhall",
		kind = "building",
		name = "Town Hall",
		description = "Seat of your kingdom. Upgrade it to unlock new buildings and levels.",
		icon = "townhall",
		rarity = "Common",
		building = {
			category = "civic",
			maxCount = 1,
			prebuilt = true,
			levels = {
				{ cost = {}, buildSec = 0, housing = 6 }, -- prebuilt: every kingdom starts with it
				{ cost = { wood = 150, stone = 100, gold = 40 }, buildSec = 45, housing = 8 },
				{ cost = { wood = 300, stone = 250, gold = 120 }, buildSec = 90, housing = 10 },
			},
		},
	},
	{
		id = "house",
		kind = "building",
		name = "House",
		description = "Homes for new citizens. More citizens means more workers.",
		icon = "house",
		rarity = "Common",
		building = {
			category = "civic",
			maxCount = 8,
			levels = {
				{ cost = { wood = 30 }, buildSec = 12, housing = 4 },
				{ cost = { wood = 40, stone = 20 }, buildSec = 20, housing = 7, requires = TH2 },
			},
		},
	},
	{
		id = "storehouse",
		kind = "building",
		name = "Storehouse",
		description = "Raises how much of every resource your kingdom can hold.",
		icon = "storehouse",
		rarity = "Common",
		building = {
			category = "civic",
			maxCount = 2,
			levels = {
				{ cost = { wood = 50, stone = 20 }, buildSec = 15, storage = 250 },
				{ cost = { wood = 80, stone = 60 }, buildSec = 25, storage = 500, requires = TH2 },
			},
		},
	},
	-- Economy ---------------------------------------------------------------------------------
	{
		id = "farm",
		kind = "building",
		name = "Farm",
		description = "Workers grow food for your citizens and army.",
		icon = "farm",
		rarity = "Common",
		building = {
			category = "economy",
			maxCount = 6,
			levels = {
				{ cost = { wood = 40 }, buildSec = 15, workers = 3, produces = { food = 6 } },
				{
					cost = { wood = 60, stone = 25 },
					buildSec = 25,
					workers = 4,
					produces = { food = 8 },
					requires = TH2,
				},
			},
		},
	},
	{
		id = "lumbercamp",
		kind = "building",
		name = "Lumber Camp",
		description = "Workers fell trees and bring back wood.",
		icon = "lumbercamp",
		rarity = "Common",
		building = {
			category = "economy",
			maxCount = 4,
			levels = {
				{ cost = { wood = 20, food = 10 }, buildSec = 12, workers = 3, produces = { wood = 6 } },
				{
					cost = { wood = 40, stone = 20 },
					buildSec = 22,
					workers = 4,
					produces = { wood = 8 },
					requires = TH2,
				},
			},
		},
	},
	{
		id = "quarry",
		kind = "building",
		name = "Quarry",
		description = "Workers cut stone for upgrades and defences.",
		icon = "quarry",
		rarity = "Common",
		building = {
			category = "economy",
			maxCount = 3,
			levels = {
				{ cost = { wood = 50, food = 20 }, buildSec = 18, workers = 3, produces = { stone = 4 } },
				{
					cost = { wood = 80, stone = 30, gold = 10 },
					buildSec = 30,
					workers = 4,
					produces = { stone = 6 },
					requires = TH2,
				},
			},
		},
	},
	{
		id = "goldmine",
		kind = "building",
		name = "Gold Mine",
		description = "Workers dig gold to pay your army.",
		icon = "goldmine",
		rarity = "Common",
		building = {
			category = "economy",
			maxCount = 2,
			levels = {
				{
					cost = { wood = 60, stone = 40 },
					buildSec = 25,
					workers = 2,
					produces = { gold = 3 },
					requires = TH2,
				},
				{
					cost = { wood = 100, stone = 80 },
					buildSec = 40,
					workers = 3,
					produces = { gold = 5 },
					requires = TH3,
				},
			},
		},
	},
	-- Military --------------------------------------------------------------------------------
	{
		id = "barracks",
		kind = "building",
		name = "Barracks",
		description = "Trains soldiers to defend and expand your kingdom.",
		icon = "barracks",
		rarity = "Common",
		building = {
			category = "military",
			maxCount = 1,
			levels = {
				{ cost = { wood = 80, stone = 60, gold = 20 }, buildSec = 30, requires = TH2 },
				{ cost = { wood = 120, stone = 100, gold = 60 }, buildSec = 45, requires = TH3 },
			},
		},
	},
	{
		id = "watchtower",
		kind = "building",
		name = "Watchtower",
		description = "Spots raiders early and guards your borders.",
		icon = "watchtower",
		rarity = "Common",
		building = {
			category = "military",
			maxCount = 4,
			levels = {
				{
					cost = { wood = 40, stone = 50 },
					buildSec = 20,
					requires = { { building = "barracks", level = 1 } },
				},
			},
		},
	},
	-- Units (army recruitment) ----------------------------------------------------------------
	{
		id = "militia",
		kind = "unit",
		name = "Militia",
		description = "Cheap spear-carriers. Quick to train.",
		icon = "militia",
		rarity = "Common",
		unit = {
			cost = { food = 20, gold = 5 },
			trainSec = 8,
			housing = 1,
			requires = { { building = "barracks", level = 1 } },
		},
	},
	{
		id = "archer",
		kind = "unit",
		name = "Archer",
		description = "Strikes from range. Strong behind walls.",
		icon = "archer",
		rarity = "Common",
		unit = {
			cost = { food = 25, wood = 15, gold = 10 },
			trainSec = 10,
			housing = 1,
			requires = { { building = "barracks", level = 1 } },
		},
	},
	{
		id = "knight",
		kind = "unit",
		name = "Knight",
		description = "Armoured cavalry. Expensive and powerful.",
		icon = "knight",
		rarity = "Common",
		unit = {
			cost = { food = 40, gold = 30 },
			trainSec = 15,
			housing = 2,
			requires = { { building = "barracks", level = 2 } },
		},
	},
	-- Cosmetics (persistent, earned with Crowns or reward tables) -----------------------------
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
