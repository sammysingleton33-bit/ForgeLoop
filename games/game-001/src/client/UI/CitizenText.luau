--!strict
--[[
	UI/CitizenText — the few sentences the citizen card and the conversation panel say themselves:
	refusal reasons from `Kingdom.Choose` (CONTRACTS G13.3) and connection failures. Everything a
	citizen says (question, answers, reaction, effect texts) comes from the server payload and the
	content library, never from here.

		CitizenText.reason(code?) -> string     a Kingdom.Choose refusal reason as a sentence
		CitizenText.unreachable() -> string     the call failed or the server dropped it
		CitizenText.NOTHING -> string           Kingdom.Converse returned nil
		CitizenText.CANT_INSPECT -> string      Sim.Inspect returned nil (not yours, or gone)
		CitizenText.UNAVAILABLE -> string       the server has no Kingdom.Converse / Kingdom.Choose yet
		CitizenText.GONE -> string              the citizen of an open conversation is gone
		CitizenText.COST_UNKNOWN, CONFIRM_KICKER, CONFIRM, BACK   the confirm step (B1) and fail-closed costs
		CitizenText.chance(c?) -> string        a risk's chance (0..1) as a whole percent: "30 %";
		                                        "<1 %" / ">99 %" at the ends, "?" when unknown
		CitizenText.hiddenRisks(n) -> string    "+2 more risks": the answer has more than the panel lists
	The reason codes are FORGE-03's proposal to FORGE-01 (handoff
	production/handoffs/2026-10-12-forge-03-to-forge-01-conversation-ui.md). Unknown codes get a
	generic sentence, never the raw code.
]]

local CitizenText = {}

local REASONS: { [string]: string } = {
	-- FORGE-01's Kingdom.Choose codes (handoff 2026-10-13-forge-01-to-forge-03-refusal-codes.md;
	-- FORGE-05 L4 on #77): not_offered = no open conversation for this ruler (never opened, already
	-- answered, or another ruler's)
	not_offered = "That conversation is over. Talk to them again.",
	unknown_citizen = "They're no longer here.",
	not_in_match = "The match isn't running",
	not_eligible = "They've moved on from that. Ask again later.",
	stale = "They've moved on from that. Ask again later.",
	expired = "That moment has passed.",
	answered = "You already answered them.",
	unknown_response = "That answer isn't open any more.",
	not_ruler = "Only a ruler of this kingdom can answer.",
	not_yours = "That citizen isn't one of yours.",
	not_owner = "That citizen isn't one of yours.",
	gone = "They're no longer here.",
	not_found = "They're no longer here.",
	cost = "The treasury can't pay for that answer.",
	insufficient = "The treasury can't pay for that answer.",
	phase = "Conversations are closed right now.",
	rate = "Slow down a moment, then try again.",
}

CitizenText.GENERIC = "That answer couldn't be given. Try again later."
CitizenText.NOTHING = "Nothing on their mind right now"
CitizenText.CANT_INSPECT = "Can't inspect that citizen"
CitizenText.UNAVAILABLE = "Conversations aren't available yet"
CitizenText.GONE = "They're no longer here."
-- An answer whose cost the panel can't show is never sent (FORGE-05 L4 on #66).
CitizenText.COST_UNKNOWN = "Its cost can't be shown"
-- The second step for an answer with a cost or a risk (FORGE-05 B1 on #66).
CitizenText.CONFIRM_KICKER = "CHOOSE THIS ANSWER?"
CitizenText.CONFIRM = "Choose"
CitizenText.BACK = "Back"

function CitizenText.reason(code: any): string
	if code == nil then
		return CitizenText.GENERIC
	end
	return REASONS[tostring(code)] or CitizenText.GENERIC
end

function CitizenText.unreachable(): string
	return "Couldn't reach the server. Try again."
end

-- Whole percent, never a misleading 0 % or 100 % for a chance strictly between them.
function CitizenText.chance(c: number?): string
	if c == nil then
		return "?"
	elseif c > 0 and c < 0.005 then
		return "<1 %"
	elseif c < 1 and c >= 0.995 then
		return ">99 %"
	end
	return `{math.floor(c * 100 + 0.5)} %`
end

function CitizenText.hiddenRisks(n: number): string
	return if n == 1 then "+1 more risk" else `+{n} more risks`
end

return table.freeze(CitizenText)
