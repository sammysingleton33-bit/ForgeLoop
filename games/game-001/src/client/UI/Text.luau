--!strict
--[[
	UI/Text — every player-facing sentence the kingdom screens show for a server reply or a cost
	check, in one place so the wording stays consistent and testable.

		Text.reason(reason?) -> string         reason string from Build.CanPlace / Place / Upgrade
		Text.missing(cost, have) -> string?    "Need 20 Wood and 10 Stone"; nil when covered (fits a button)
		Text.phase(phase?) -> string           MatchPhase as shown in the top bar
		Text.list(words) -> string             "a, b and c"
	Reason strings belong to FORGE-01 (BuildingService); the ones mapped here are the vocabulary
	proposed in production/handoffs/2026-10-12-forge-03-to-forge-01-build-ui.md. Unknown reasons get a
	generic sentence, never the raw code.
]]

local Bundle = require("@game/ReplicatedStorage/Forge/Economy/Bundle")
local Format = require("@game/ReplicatedStorage/Forge/UI/Format")
local Resources = require("@game/ReplicatedStorage/Forge/Config/Resources")

local Text = {}

local REASONS: { [string]: string } = {
	territory = "Outside your territory",
	zone = "Not on open building ground",
	overlap = "Too close to another building",
	blocked = "Something is in the way",
	cost = "Not enough resources",
	insufficient = "Not enough resources",
	phase = "You can't build right now",
	no_kingdom = "You don't rule a kingdom yet",
	not_owner = "That building isn't yours",
	not_found = "That building no longer exists",
	max_level = "Already at the highest level",
	busy = "Finish building it first",
	unknown_type = "That building can't be built",
	rate = "Slow down a moment, then try again",
	-- Kingdom.SetJobQuota and other sim commands (FORGE-01 Sim/Commands error codes)
	unknown_job = "That job can't be changed",
	match_not_active = "The match isn't running",
	not_ruler = "Only rulers can do that",
	kingdom_eliminated = "Your kingdom has fallen",
}

function Text.reason(reason: any): string
	if reason == nil then
		return "Couldn't reach the server. Try again."
	end
	return REASONS[tostring(reason)] or "That didn't work. Try again."
end

function Text.list(words: { string }): string
	return Format.list(words)
end

function Text.missing(cost: { [string]: number }, have: { [string]: number }): string?
	local short = Bundle.missing(have, cost)
	if Bundle.isEmpty(short) then
		return nil
	end
	local parts = {}
	for _, entry in Bundle.ordered(short, Resources.ids) do
		local def = Resources.defs[entry.id]
		table.insert(parts, `{Format.amount(entry.amount)} {if def then def.name else entry.id}`)
	end
	return "Need " .. Format.list(parts)
end

local PHASES: { [string]: string } = {
	Lobby = "Gathering",
	Founding = "Founding",
	Expansion = "Expansion",
	Conflict = "Conflict",
	Endgame = "Endgame",
	Results = "Results",
}

function Text.phase(phase: string?): string
	return if phase then PHASES[phase] or phase else ""
end

return table.freeze(Text)
