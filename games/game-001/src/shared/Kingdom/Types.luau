--!strict
--[[
	Kingdom/Types — core ids and types of game-001, exactly as CONTRACTS G2 (v0.4-g3).

	Values (stable order, used for encoding and validation)
		Types.KINGDOM_IDS   { "crimson", "azure", "emerald", "gold" }
		Types.RESOURCE_IDS  { "food", "wood", "stone", "gold" }
		Types.ENTITY_KINDS  { "citizen", "soldier", "governor" }
		Types.JOB_IDS       { "idle", "farmer", "woodcutter", "miner", "builder", "hauler", "soldier" }
		Types.BUILDING_TYPES{ "keep", "house", "farm", "storehouse", "lumbercamp", "quarry", "barracks",
		                      "watchtower", "wall", "gate" }
		Types.MATCH_PHASES  { "Lobby", "Founding", "Expansion", "Conflict", "Endgame", "Results" }
		Types.BUILDING_STATES { "planned", "constructing", "complete", "damaged", "destroyed" }
		Types.is(listName, value): boolean   -- e.g. Types.is("KINGDOM_IDS", "azure")
]]

export type KingdomId = "crimson" | "azure" | "emerald" | "gold"
export type ResourceId = "food" | "wood" | "stone" | "gold"
export type EntityId = number
export type EntityKind = "citizen" | "soldier" | "governor"
export type JobId = "idle" | "farmer" | "woodcutter" | "miner" | "builder" | "hauler" | "soldier"
export type BuildingType =
	"keep"
	| "house"
	| "farm"
	| "storehouse"
	| "lumbercamp"
	| "quarry"
	| "barracks"
	| "watchtower"
	| "wall"
	| "gate"
export type MatchPhase = "Lobby" | "Founding" | "Expansion" | "Conflict" | "Endgame" | "Results"
export type Kingdom = {
	id: KingdomId,
	name: string,
	color: Color3,
	rulers: { number },
	isAI: boolean,
	keepBuildingId: number?,
	crownPoints: number,
	regions: { string }, -- claimed Layout region ids
	alive: boolean,
	happiness: number, -- kingdom conditions 0..100 (G13.4), separate from reputation
	stability: number,
	morale: number,
}
export type Building = {
	id: number,
	kingdom: KingdomId,
	type: BuildingType,
	level: number,
	cframe: CFrame,
	footprint: Vector2,
	state: "planned" | "constructing" | "complete" | "damaged" | "destroyed",
	progress: number,
	hp: number,
	maxHp: number,
	placedBy: number?, -- userId; nil for starting buildings
}
export type ResourceBag = { [ResourceId]: number }

local Types = {}

Types.KINGDOM_IDS = table.freeze({ "crimson", "azure", "emerald", "gold" })
Types.RESOURCE_IDS = table.freeze({ "food", "wood", "stone", "gold" })
Types.ENTITY_KINDS = table.freeze({ "citizen", "soldier", "governor" })
Types.JOB_IDS = table.freeze({ "idle", "farmer", "woodcutter", "miner", "builder", "hauler", "soldier" })
Types.BUILDING_TYPES = table.freeze({
	"keep",
	"house",
	"farm",
	"storehouse",
	"lumbercamp",
	"quarry",
	"barracks",
	"watchtower",
	"wall",
	"gate",
})
Types.MATCH_PHASES = table.freeze({ "Lobby", "Founding", "Expansion", "Conflict", "Endgame", "Results" })
Types.BUILDING_STATES = table.freeze({ "planned", "constructing", "complete", "damaged", "destroyed" })

function Types.is(listName: string, value: any): boolean
	local list = (Types :: any)[listName]
	assert(type(list) == "table", `Types.is: unknown list '{listName}'`)
	return type(value) == "string" and table.find(list, value) ~= nil
end

return table.freeze(Types)
