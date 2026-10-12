--!strict
--[[
	Experience/KingdomSignals — AI Kingdoms gameplay signals that FORGE-04 consumes.

	STATUS: PROPOSED additive GameEvents (interfaces §4) for FORGE-01 to declare and fire, see
	production/handoffs/2026-10-12-forge-04-to-forge-01-kingdom-signals.md. None of them is declared
	in Contracts/GameEvents yet, so Experience services subscribe through Experience/Bus, which skips
	undeclared names (systems stay inert and log once). If FORGE-01 renames one, change it here only.

	Every proposed event uses one payload shape, so consumers need no per-event adapters:
		(player: Player?, info: { matchId: string, kingdomId: string, ... })
	`player` is the ruler who owns the acting kingdom (nil for AI kingdoms). Events with a second
	party carry that party's userId in `info` (OTHER_PARTY below). `position` (Vector3) is where the
	thing happened, for positional audio/VFX and citizen reactions.

	| Event               | info fields (besides matchId, kingdomId)                                       |
	| KingdomFounded      | isAi: boolean, position                                                         |
	| CitizenTaskChanged  | citizenId, task, previousTask?, position                                        |
	| ResourceProduced    | resource ("Food" | "Wood" | "Stone" | "Gold"), amount, total, buildingId?, position |
	| ConstructionStarted | buildingId, buildingType, position                                              |
	| BuildingCompleted   | buildingId, buildingType, level, position                                       |
	| BuildingUpgraded    | buildingId, buildingType, level, position                                       |
	| KingdomUpgraded     | tier                                                                            |
	| UnitsRecruited      | unitType, count, position                                                       |
	| BattleStarted       | battleId, defenderKingdomId, defenderUserId?, position                           |
	| BattleEnded         | battleId, defenderKingdomId, defenderUserId?, winnerKingdomId, attackerLosses, defenderLosses, position |
	| SiegeStarted        | siegeId, defenderKingdomId, defenderUserId?, targetBuildingId?, position         |
	| SiegeEnded          | siegeId, defenderKingdomId, defenderUserId?, outcome ("Breached" | "Repelled" | "Abandoned"), position |
	| TerritoryChanged    | regionId, fromKingdomId?, fromUserId?, position                                 |
	| MoraleChanged       | morale (0-100), previous (0-100), reason                                        |
	| KingdomEventStarted | eventId ("Festival" | "Plague" | "Raid" | "Drought" | ...), severity (1-3)       |
	Match lifecycle reuses existing events: RoundStateChanged/RoundEnded (mode "kingdoms",
	roundId = matchId) and PlayerEliminated (cause "Conquered").
]]

local KingdomSignals = {}

KingdomSignals.PROPOSED = table.freeze({
	"KingdomFounded",
	"CitizenTaskChanged",
	"ResourceProduced",
	"ConstructionStarted",
	"BuildingCompleted",
	"BuildingUpgraded",
	"KingdomUpgraded",
	"UnitsRecruited",
	"BattleStarted",
	"BattleEnded",
	"SiegeStarted",
	"SiegeEnded",
	"TerritoryChanged",
	"MoraleChanged",
	"KingdomEventStarted",
})

-- info key holding the userId of the second party, per event (they are told too: "your town is under siege")
KingdomSignals.OTHER_PARTY = table.freeze({
	BattleStarted = "defenderUserId",
	BattleEnded = "defenderUserId",
	SiegeStarted = "defenderUserId",
	SiegeEnded = "defenderUserId",
	TerritoryChanged = "fromUserId",
})

KingdomSignals.RESOURCES = table.freeze({ "Food", "Wood", "Stone", "Gold" })

function KingdomSignals.isProposed(name: string): boolean
	return table.find(KingdomSignals.PROPOSED, name) ~= nil
end

return table.freeze(KingdomSignals)
