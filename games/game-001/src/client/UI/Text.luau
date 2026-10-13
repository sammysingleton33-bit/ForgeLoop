--!strict
--[[
	UI/Text — every player-facing sentence the kingdom screens show for a server reply or a cost
	check, in one place so the wording stays consistent and testable.

		Text.reason(reason?, context?) -> string   reason string from Build.CanPlace / Place / Upgrade;
		                                       context "slot" for Build.PlaceSlot (a plot's words)
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

-- Every refusal code FORGE-01's server returns (FL-0105; handoff
-- 2026-10-13-forge-01-to-forge-03-refusal-codes.md and the Reasons line of Build/Remotes.luau), and
-- nothing else: a code the server never sends is not vocabulary. Army.Recruit's are UI/ArmyText's,
-- Kingdom.Choose's UI/CitizenText's.
local REASONS: { [string]: string } = {
	-- Build.CanPlace / Build.Place
	-- the server keeps a building's largest-level footprint plus Buildings.placementGap free
	-- (Sim/Footprint, #62): the ghost's outer outline shows that room (FORGE-05 M-2 on #62)
	blocked = "Leave room for upgrades",
	out_of_territory = "Build inside your kingdom",
	out_of_bounds = "That's off the edge of the map",
	cannot_afford = "Not enough resources",
	not_placeable = "That building can't be placed by hand",
	requires_keep_level = "Upgrade your keep first",
	limit_reached = "You have the most of these already",
	unknown_building = "That building can't be built",
	-- Build.Upgrade
	not_found = "That building no longer exists",
	not_owner = "That building isn't yours",
	busy = "Finish building it first",
	max_level = "Already at the highest level",
	-- Kingdom.Gather
	no_character = "Your ruler isn't in the world yet",
	too_far = "Walk closer first",
	cooldown = "Not yet. Try again in a moment",
	depleted = "Nothing left to gather there",
	unknown_node = "There's nothing to gather there",
	-- Kingdom.SetJobQuota and every sim command
	invalid_args = "That request wasn't valid",
	unknown_job = "That job can't be changed",
	match_not_active = "The match isn't running",
	not_in_match = "The match isn't running",
	not_ruler = "Only rulers can do that",
	kingdom_eliminated = "Your kingdom has fallen",
}

-- Build.PlaceSlot's own codes (FORGE-01 FL-0081, BuildingService.placeSlot; the Reasons line of
-- Build/Remotes.luau) in the plot's words. Its other refusals come from the simulation's placement and
-- read as in REASONS, except `blocked`: on a plot that means something stands in the footprint.
local SLOT_REASONS: { [string]: string } = {
	unknown_slot = "This plot isn't yours",
	slot_occupied = "This plot is already built on",
	does_not_fit = "That doesn't fit this plot",
	blocked = "Something is in the way on this plot",
}

function Text.reason(reason: any, context: string?): string
	if reason == nil then
		-- nil: the call was dropped or rate-limited (both answer nil), so never claim the server is down (L8)
		return "No answer from the server. Try again in a moment."
	end
	local key = tostring(reason)
	if context == "slot" and SLOT_REASONS[key] then
		return SLOT_REASONS[key]
	end
	return REASONS[key] or "That didn't work. Try again."
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
