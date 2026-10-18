--!strict
--[[
	UI/ArmyText — every player-facing sentence of the army drawer, the objective tracker and the
	slice summary (FL-0060), in one place so the wording stays consistent and testable.

		ArmyText.reason(reason?) -> string        reason string from Army.Recruit (FORGE-01); unknown
		                                          reasons get a generic sentence, never the raw code;
		                                          nil (no answer) = the server could not be reached
		ArmyText.soldiers(n) -> string            "soldier" / "soldiers"
		ArmyText.recruitCta(n) -> string          "Recruit 3 soldiers"
		ArmyText.recruited(n) -> string           toast title "3 soldiers recruited"
		ArmyText.each(seconds) -> string          "0:08 each"
		ArmyText.upkeep(food) -> string           "Upkeep 4 Food/min"
		ArmyText.objectiveName(id) -> string      "watchtower" -> "Watchtower", "old_ford" -> "Old Ford"
		ArmyText.lasted(seconds) -> string        "Lasted 12:34"
		plus the constant sentences below (ArmyText.<NAME>).
	The reason vocabulary is FORGE-01's Army.Recruit (#70: Sim/Military, MatchHost), nothing else.
]]

local Format = require("@game/ReplicatedStorage/Forge/UI/Format")

local ArmyText = {}

-- Army.Recruit's codes as FORGE-01's server sends them (#70, Sim/Military + MatchHost; FORGE-05 on
-- #63). A nil reply is a dropped call (invalid or rate-limited): the server never sends a code for it.
local REASONS: { [string]: string } = {
	not_in_match = "The match isn't running",
	match_not_active = "The match isn't running",
	kingdom_eliminated = "Your kingdom has fallen",
	not_ruler = "Only rulers can do that",
	not_found = "That barracks no longer exists",
	not_owner = "That barracks isn't yours",
	not_barracks = "Soldiers train at a barracks",
	barracks_not_ready = "Finish building the barracks first",
	requires_barracks_level = "Upgrade the barracks first",
	-- no free bunk: soldiers sleep in the barracks, never in house beds (D-041; 4/8/12/16 per level)
	recruit_cap = "No free bunks. Upgrade the barracks or build another",
	-- D-055: a kingdom's standing army has a ceiling (15 soldiers), bunks or not
	army_cap = "Your army is at its limit. No more soldiers for now",
	cannot_afford = "Not enough resources",
	unknown_unit = "Those soldiers can't be trained here",
	invalid_args = "Those soldiers can't be trained here",
	unknown_command = "That order can't be given",
}

ArmyText.GENERIC = "That didn't work. Try again."
-- nil: the call was dropped or rate-limited (both answer nil), so never claim the server is down
ArmyText.UNREACHABLE = "No answer from the server. Try again in a moment."

-- Army drawer
ArmyText.TITLE = "Army"
ArmyText.TAB = "Army"
ArmyText.YOUR_ARMY = "Your army"
ArmyText.UNIT_NAME = "Soldier"
ArmyText.UNIT_DESCRIPTION = "Soldiers march, fight and capture towers for your kingdom."
ArmyText.RECRUIT_LINE = "Recruit soldiers"
ArmyText.HOW_MANY = "How many"
ArmyText.RECRUITING = "Recruiting…"
ArmyText.LOADING = "Loading your kingdom…"
ArmyText.NO_BARRACKS_CTA = "Build a Barracks first"
ArmyText.NO_BARRACKS = "Build a Barracks to recruit soldiers."
ArmyText.UNFINISHED_CTA = "Finish the barracks first"
ArmyText.UNAVAILABLE = "Not available yet"
ArmyText.RECRUIT_FAILED = "Couldn't recruit"
ArmyText.RECRUITED_BODY = "They train at the barracks"
ArmyText.SEND_TITLE = "Send to capture"
ArmyText.SEND = "Send to capture"
ArmyText.SEND_DESCRIPTION = "Idle soldiers march to the nearest tower you don't hold and take it."
ArmyText.SENT = "Sent"
ArmyText.SENT_STATUS = "Sent to the nearest tower"
-- The order is an event: nothing confirms it, so the toast says what was sent, not what happened
-- (FORGE-05 low 5 on #63).
ArmyText.SENT_TOAST = "Orders sent"
ArmyText.SENT_TOAST_BODY = "To the nearest tower"
ArmyText.SEND_DEFAULT = "Idle soldiers march to the nearest tower"
ArmyText.NO_SOLDIERS = "No soldiers yet"
ArmyText.NO_SOLDIERS_STATUS = "Recruit soldiers first"
ArmyText.ALL_MINE = "Every tower is yours"
ArmyText.UNKNOWN_COUNT = "—"

-- Objective tracker
ArmyText.OBJECTIVES = "Objectives"
ArmyText.NEUTRAL = "Neutral"
ArmyText.YOURS = "Yours"
ArmyText.YOU = "You"
ArmyText.STATUS_NEUTRAL = "Send soldiers to capture it"
ArmyText.STATUS_FOREIGN = "Send soldiers to take it"
ArmyText.STATUS_MINE = "No one is challenging you"
ArmyText.CONTESTED = "Contested: nobody gains"
ArmyText.TAP_TO_CLOSE = "tap to close"

-- Slice summary
ArmyText.MATCH_OVER = "Match over"
ArmyText.VICTORY = "Victory"
ArmyText.WINS = "wins the match"
ArmyText.YOU_WIN = "Your kingdom wins"
ArmyText.NO_WINNER = "No winner"
ArmyText.NO_WINNER_SUB = "Nobody won the match"
ArmyText.STANDINGS = "Standings"
ArmyText.CROWN_POINTS = "Crown Points"
ArmyText.CONTINUE = "Continue"
ArmyText.YOU_TAG = "you"
ArmyText.AI_TAG = "AI"

function ArmyText.reason(reason: any): string
	if reason == nil then
		return ArmyText.UNREACHABLE
	end
	return REASONS[tostring(reason)] or ArmyText.GENERIC
end

function ArmyText.soldiers(n: number): string
	return if n == 1 then "soldier" else "soldiers"
end

function ArmyText.recruitCta(n: number): string
	return `Recruit {n} {ArmyText.soldiers(n)}`
end

function ArmyText.recruited(n: number): string
	return `{n} {ArmyText.soldiers(n)} recruited`
end

function ArmyText.each(seconds: number): string
	return `{Format.clock(seconds)} each`
end

function ArmyText.upkeep(food: number): string
	return `Upkeep {Format.amount(food)} Food/min`
end

function ArmyText.objectiveName(id: string): string
	local words = {}
	for word in string.gmatch(id, "[^_%s]+") do
		table.insert(words, string.upper(string.sub(word, 1, 1)) .. string.sub(word, 2))
	end
	return if #words > 0 then table.concat(words, " ") else id
end

function ArmyText.lasted(seconds: number): string
	return `Lasted {Format.clock(seconds)}`
end

return table.freeze(ArmyText)
