--!strict
--[[
	UI/PetitionModel — the citizen card's arena perk preview and open petition (FL-0073; design crown-arena.md §4, §7;
	CONTRACTS G12 v0.4-g11e: CitizenService:inspect gains `role: KeyRole?` and `petition: { id, text, need?, expiresAt }?`).
	Pure; no instances. UI/CitizenCard draws both, CitizenCardController feeds them.

		PetitionModel.perk(view) -> Perk?   nil unless the view has a known key role (config Support.roles)
			Perk = { role, roleName, trigger, perkName, icon, loyalty, power: "none" | "pledged" | "empowered",
			         headline, effect, when, next: string? }
			The effect and condition texts are FORGE-01's SupportModel.offers output for this citizen at the pledged
			(80) and empowered (95) loyalty, so the card says exactly what the loadout picker will offer:
				below 80   "At 80 loyalty, Bram will lend you Reforge"   + effect, "When your HP first drops below 50 %",
				           next = nil, and `toGo` the loyalty still missing
				80..94     "Bram stands with you: Reforge (Pledged)"     next = "At 95: <empowered effect>"
				95+        "Bram stands with you: Reforge (Empowered)"
		PetitionModel.petition(view, now, balances?) -> Petition?   nil without a petition (id and text)
			Petition = { id, text, cost: { { id, amount, name, icon } }, costUnknown, short: { [id]: true },
			             need: string? ("Need 20 Wood"), left: string ("4 min left" | "Under a minute left"),
			             expired: boolean, canFulfil: boolean }
			A need the card can't show (not a known resource, not a whole amount) fails closed: costUnknown, no
			Fulfil. The server decides (Kingdom.FulfilPetition spends the need through TreasuryService).
		PetitionModel.reason(code?) -> string   a Kingdom.FulfilPetition refusal as a sentence (never the raw code)
		PetitionModel.FULFIL / FULFILLED        button and notice words
]]

local ArenaText = require("./ArenaText")
local CitizenModel = require("./CitizenModel")
local CitizenText = require("./CitizenText")
local Support = require("@game/ReplicatedStorage/Forge/Config/Support")
local SupportModel = require("@game/ReplicatedStorage/Game/Arena/SupportModel")

local PetitionModel = {}

PetitionModel.FULFIL = "Fulfil"
PetitionModel.FULFILLED = "Petition fulfilled"
PetitionModel.UNAVAILABLE = "Petitions aren't open yet"

local REASONS: { [string]: string } = {
	insufficient = "The treasury can't cover it yet.",
	cost = "The treasury can't cover it yet.",
	expired = "That petition has lapsed.",
	unknown_petition = "That petition is no longer open.",
	not_found = "That petition is no longer open.",
	fulfilled = "That petition was already fulfilled.",
	not_ruler = "Only a ruler of this kingdom can fulfil it.",
	not_yours = "That citizen isn't one of yours.",
	not_owner = "That citizen isn't one of yours.",
	not_in_match = "The match isn't running.",
	rate = "Slow down a moment, then try again.",
}
PetitionModel.GENERIC = "That petition couldn't be fulfilled. Try again later."

function PetitionModel.reason(code: any): string
	if code == nil then
		return PetitionModel.GENERIC
	end
	return REASONS[tostring(code)] or PetitionModel.GENERIC
end

local function firstName(view: any): string
	local name = if type(view.name) == "string" and view.name ~= "" then view.name else "They"
	return string.match(name, "^(%S+)") or name
end

-- SupportModel's offer for this citizen at the given loyalty (the server's own words for the effect and condition).
local function offerAt(role: string, name: string, loyalty: number): any
	local ok, offers =
		pcall(SupportModel.offers, { { role = role, name = name, loyalty = loyalty, alive = true } }, "loyal")
	if not ok then
		return nil
	end
	for _, o in offers do
		if o.role == role then
			return o
		end
	end
	return nil
end

local function capital(s: string): string
	return string.upper(string.sub(s, 1, 1)) .. string.sub(s, 2)
end

function PetitionModel.perk(view: any): any
	if type(view) ~= "table" or type(view.role) ~= "string" then
		return nil
	end
	local role = view.role
	local roleDef = Support.roles[role]
	if roleDef == nil then
		return nil
	end
	local name = firstName(view)
	-- The power follows the raw loyalty, as SupportModel.offers compares it (79.6 is not pledged; FORGE-07 L1 on #227);
	-- the shown number is rounded down so it never reads 80 below the threshold.
	local raw = if type(view.loyalty) == "number" and view.loyalty == view.loyalty
		then math.clamp(view.loyalty, 0, 100)
		else 0
	local loyalty = math.floor(raw)
	local pledgedAt, empoweredAt = Support.offer.pledgedLoyalty, Support.offer.empoweredLoyalty
	local power = if raw >= empoweredAt then "empowered" elseif raw >= pledgedAt then "pledged" else "none"
	local shown = offerAt(role, name, math.max(raw, pledgedAt))
	local empowered = offerAt(role, name, empoweredAt)
	if shown == nil then
		return nil
	end
	local trigger = ArenaText.trigger(roleDef.perk)
	local headline = if power == "none"
		then `At {pledgedAt} loyalty, {name} will lend you {trigger.name}`
		else `{name} stands with you: {trigger.name} ({ArenaText.POWER[power]})`
	return {
		role = role,
		roleName = ArenaText.ROLES[role] or capital(role),
		trigger = roleDef.perk,
		perkName = trigger.name,
		icon = trigger.icon,
		loyalty = loyalty,
		power = power,
		toGo = if power == "none" then math.max(1, math.ceil(pledgedAt - raw)) else nil,
		headline = headline,
		effect = shown.effect,
		when = `When {shown.condition}`,
		next = if power == "pledged" and empowered then `At {empoweredAt}: {empowered.effect}` else nil,
	}
end

local function minutesLeft(seconds: number): string
	if seconds < 60 then
		return "Under a minute left"
	end
	local m = math.ceil(seconds / 60)
	return if m == 1 then "1 min left" else `{m} min left`
end

function PetitionModel.petition(view: any, now: number, balances: { [string]: number }?): any
	local p = if type(view) == "table" then view.petition else nil
	if type(p) ~= "table" or type(p.id) ~= "string" or p.id == "" or type(p.text) ~= "string" or p.text == "" then
		return nil
	end
	local cost, unknown = CitizenModel.costs(p.need)
	local priced = CitizenModel.price({ cost = cost, costUnknown = unknown }, balances)
	local expiresAt = if type(p.expiresAt) == "number" then p.expiresAt else nil
	local remaining = if expiresAt then expiresAt - now else math.huge
	local expired = remaining <= 0
	return {
		id = p.id,
		text = p.text,
		cost = cost,
		costUnknown = unknown,
		short = priced.short,
		need = priced.need,
		left = if expired then "Lapsed" elseif expiresAt then minutesLeft(remaining) else nil,
		expired = expired,
		canFulfil = not expired and not unknown and priced.need == nil,
	}
end

PetitionModel.COST_UNKNOWN = CitizenText.COST_UNKNOWN

return table.freeze(PetitionModel)
