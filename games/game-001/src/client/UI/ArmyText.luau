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
	The reason vocabulary is FORGE-01's (Sim/Military: unknown_unit, invalid_args, no_barracks,
	population_cap, cannot_afford) plus the build-UI vocabulary (production/handoffs/
	2026-10-12-forge-03-to-forge-01-build-ui.md); proposed for Army.Recruit in
	production/handoffs/2026-10-12-forge-03-to-forge-01-army-ui.md.
]]

local Format = require("@game/ReplicatedStorage/Forge/UI/Format")

local ArmyText = {}

local REASONS: { [string]: string } = {
	no_barracks = "You need a finished barracks",
	busy = "Finish building the barracks first",
	population_cap = "No room for more people. Build houses first",
	cannot_afford = "Not enough resources",
	cost = "Not enough resources",
	insufficient = "Not enough resources",
	unknown_unit = "Those soldiers can't be trained here",
	invalid_args = "Those soldiers can't be trained here",
	not_owner = "That barracks isn't yours",
	not_found = "That barracks no longer exists",
	no_kingdom = "You don't rule a kingdom yet",
	phase = "You can't recruit right now",
	rate = "Slow down a moment, then try again",
	-- FORGE-01 Sim/Military and Sim/Commands codes (FORGE-05 low 4 on #63)
	recruit_cap = "Your barracks can't train more soldiers. Upgrade it",
	match_not_active = "The match isn't running",
	not_in_match = "The match isn't running",
	not_ruler = "Only rulers can do that",
	kingdom_eliminated = "Your kingdom has fallen",
}

ArmyText.GENERIC = "That didn't work. Try again."
ArmyText.UNREACHABLE = "Couldn't reach the server. Try again."

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
