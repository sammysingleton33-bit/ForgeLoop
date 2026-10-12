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
	The reason codes are FORGE-03's proposal to FORGE-01 (handoff
	production/handoffs/2026-10-12-forge-03-to-forge-01-conversation-ui.md). Unknown codes get a
	generic sentence, never the raw code.
]]

local CitizenText = {}

local REASONS: { [string]: string } = {
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

function CitizenText.reason(code: any): string
	if code == nil then
		return CitizenText.GENERIC
	end
	return REASONS[tostring(code)] or CitizenText.GENERIC
end

function CitizenText.unreachable(): string
	return "Couldn't reach the server. Try again."
end

return table.freeze(CitizenText)
