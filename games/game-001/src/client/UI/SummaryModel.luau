--!strict
--[[
	UI/SummaryModel — the end-of-slice summary as data (FL-0060; pure, no instances), from the
	`Match.Ended` remote: the G9 MatchEnded payload { winner: KingdomId?, standings: { { kingdom,
	crownPoints } }, durationSec }. The client never decides who won: it shows what the server sent.

	SummaryModel.normalize(payload) -> Ended?     nil when the payload is not a table; bad standings
		entries are dropped; Ended = { winner: string?, standings: { { kingdom, crownPoints } } (most
		Crown Points first; ties keep the server's order), durationSec: number? }
	SummaryModel.build(ended, store) -> Summary
		Summary = { tone: "win" | "over", kicker, headline, sub, winner: Identity?, duration: string?,
		            standings: { { rank, id, name, color, emblem, crownPoints, points, mine, ai, winner } } }
		Identity as UI/ObjectiveModel.identity (names, colours and AI flags from Kingdom.State).
	SummaryModel.MAX_STANDINGS
]]

local ArmyText = require("./ArmyText")
local Format = require("@game/ReplicatedStorage/Forge/UI/Format")
local ObjectiveModel = require("./ObjectiveModel")

local SummaryModel = {}

SummaryModel.MAX_STANDINGS = 8

local function finite(n: any): boolean
	return type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge
end

function SummaryModel.normalize(payload: any): { [string]: any }?
	if type(payload) ~= "table" then
		return nil
	end
	local standings = {}
	if type(payload.standings) == "table" then
		for _, entry in payload.standings do
			if #standings >= SummaryModel.MAX_STANDINGS then
				break
			end
			if type(entry) == "table" and type(entry.kingdom) == "string" then
				table.insert(standings, {
					kingdom = entry.kingdom,
					crownPoints = if finite(entry.crownPoints) then entry.crownPoints else 0,
					order = #standings + 1,
				})
			end
		end
	end
	table.sort(standings, function(a, b)
		if a.crownPoints ~= b.crownPoints then
			return a.crownPoints > b.crownPoints
		end
		return a.order < b.order
	end)
	for _, entry in standings do
		entry.order = nil
	end
	return {
		winner = if type(payload.winner) == "string" then payload.winner else nil,
		standings = standings,
		durationSec = if finite(payload.durationSec) and payload.durationSec >= 0 then payload.durationSec else nil,
	}
end

function SummaryModel.build(ended: { [string]: any }, store: any): { [string]: any }
	local winner = if ended.winner then ObjectiveModel.identity(store, ended.winner) else nil
	local rows = {}
	for i, entry in ended.standings do
		local who = ObjectiveModel.identity(store, entry.kingdom)
		table.insert(rows, {
			rank = i,
			id = who.id,
			name = who.name,
			color = who.color,
			emblem = who.emblem,
			crownPoints = entry.crownPoints,
			points = Format.amount(entry.crownPoints),
			mine = who.mine,
			ai = who.ai,
			winner = ended.winner == who.id,
		})
	end
	local mineWins = winner ~= nil and winner.mine
	return {
		tone = if mineWins then "win" else "over",
		kicker = if mineWins then ArmyText.VICTORY else ArmyText.MATCH_OVER,
		headline = if winner then winner.name else ArmyText.NO_WINNER,
		sub = if winner == nil then ArmyText.NO_WINNER_SUB elseif mineWins then ArmyText.YOU_WIN else ArmyText.WINS,
		winner = winner,
		duration = if ended.durationSec then ArmyText.lasted(ended.durationSec) else nil,
		standings = rows,
	}
end

return table.freeze(SummaryModel)
