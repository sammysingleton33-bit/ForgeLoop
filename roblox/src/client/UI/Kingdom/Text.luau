--!strict
--[[
	UI/Kingdom/Text — every player-facing sentence the kingdom screens show for a rule verdict or a
	server reply. One place, so wording stays consistent and testable.

		Text.reason(check, names) -> string      Construction Check -> CTA / lock text
		Text.serverError(reason?) -> string      reply from Gameplay.Build / Upgrade / AssignWorkers
		Text.requirement(req, names) -> string   "Town Hall Lv 2"
		Text.missing(bundle, currencies) -> string   "20 more Wood and 10 more Stone"
	`names` maps building ids to display names; `currencies` is an Economy/Currencies registry.
]]

local Bundle = require("@game/ReplicatedStorage/Forge/Economy/Bundle")
local Format = require("../Format")

local Text = {}

function Text.requirement(req: { building: string, level: number }, names: { [string]: string }): string
	return `{names[req.building] or req.building} Lv {req.level}`
end

function Text.missing(missing: { [string]: number }, currencies: any): string
	local parts = {}
	for _, entry in Bundle.ordered(missing, currencies:ids()) do
		local def = currencies:get(entry.id)
		table.insert(parts, `{Format.amount(entry.amount)} more {if def then def.name else entry.id}`)
	end
	return Format.list(parts)
end

function Text.reason(check: any, names: { [string]: string }, currencies: any): string
	local reason = check.reason
	if reason == "cost" then
		return "Need " .. Text.missing(check.missing, currencies)
	elseif reason == "requirement" then
		return "Requires " .. Text.requirement(check.unmet[1], names)
	elseif reason == "limit" then
		return `Limit reached ({check.count}/{check.maxCount})`
	elseif reason == "builders" then
		return "All builders are busy"
	elseif reason == "max_level" then
		return "Maximum level"
	elseif reason == "busy" then
		return "Already under construction"
	end
	return "Unavailable"
end

local SERVER: { [string]: string } = {
	cost = "Not enough resources",
	insufficient = "Not enough resources",
	requirement = "A requirement is not met yet",
	limit = "You already have the most allowed",
	builders = "All builders are busy",
	max_level = "Already at maximum level",
	busy = "That building is busy",
	not_found = "That building no longer exists",
	no_kingdom = "You don't rule a kingdom yet",
	no_idle = "No idle citizens: build Houses for more",
	no_slots = "This building has no jobs",
}

function Text.serverError(reason: string?): string
	if reason == nil then
		return "Couldn't reach the server. Try again."
	end
	return SERVER[reason] or "That didn't work. Try again."
end

return table.freeze(Text)
