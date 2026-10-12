--!strict
--[[
	Contracts/Types — shared payload types (docs/architecture/interfaces.md §4, contract v0.3).

	Types
		RoundState   = "Lobby" | "Intermission" | "Countdown" | "Active" | "Results"
		RoundResult  = { roundId, mode, startedAt, endedAt, participants, winners }
		RewardResult = { tableId, rarity, itemId, qty, pityTriggered }

	Values
		Types.ROUND_STATES: { RoundState }        -- the five states, in round order
		Types.isRoundState(value): boolean

	Contract changes go through FORGE-05 review and FORGE-00 approval (additive = fine).
]]

export type RoundState = "Lobby" | "Intermission" | "Countdown" | "Active" | "Results"

export type RoundParticipant = {
	userId: number,
	placement: number,
	eliminations: number,
	survivedSec: number,
}

export type RoundResult = {
	roundId: string,
	mode: string,
	startedAt: number,
	endedAt: number,
	participants: { RoundParticipant },
	winners: { number }, -- userIds
}

export type RewardResult = {
	tableId: string,
	rarity: string,
	itemId: string,
	qty: number,
	pityTriggered: boolean,
}

local Types = {}

local ROUND_STATES: { RoundState } = { "Lobby", "Intermission", "Countdown", "Active", "Results" }
Types.ROUND_STATES = table.freeze(ROUND_STATES)

function Types.isRoundState(value: any): boolean
	return type(value) == "string" and table.find(Types.ROUND_STATES, value :: any) ~= nil
end

return table.freeze(Types)
