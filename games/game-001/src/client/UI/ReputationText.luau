--!strict
--[[
	UI/ReputationText — ids, display names, icons and bar colours of the six reputation categories
	(CONTRACTS G13.2 `Category`, design/living-kingdom.md §3) and of the three kingdom conditions
	(G13.4), in display order. Presentation only.

	The prose of each category ("description" and "what affects it") belongs to the content library
	(`Content/Reputation.categories[id] = { name, description, affects }`, FL-0083, FORGE-00). This
	module never invents it: with no content the screen shows names, values and history only.

		ReputationText.IDS -> { Category }                 compassion honor competence courage authority fear
		ReputationText.CATEGORIES[id] -> { id, name, icon, color }   color: a Theme colour name
		ReputationText.CONDITIONS -> { { id, name, icon } }          happiness, stability, morale
		ReputationText.isCategory(id) -> boolean
		ReputationText.fromContent(module) -> Provider?    a provider over a Content/Reputation module
		ReputationText.provider -> Provider?               the default: FORGE-00's content library (FL-0083)
		Provider = (id) -> { name: string?, description: string?, affects: string? }?

	Category prose comes from FORGE-00's content library (`Content/Reputation`, FL-0083, merged in
	#53). ReputationPanelController:setCategoryText(provider) overrides the default (specs inject
	sample text, or nil for "no prose", that way).
	Why the phone strip shows icons and not letters: three categories start with C.
]]

export type Category = "compassion" | "honor" | "competence" | "courage" | "authority" | "fear"
export type CategoryInfo = { id: string, name: string, icon: string, color: string }
export type Text = { name: string?, description: string?, affects: string? }
export type Provider = (id: string) -> Text?

local CONTENT: any = require("@game/ReplicatedStorage/Game/Content/Reputation")

local ReputationText = {}

ReputationText.IDS = table.freeze({ "compassion", "honor", "competence", "courage", "authority", "fear" })

local function info(id: string, name: string, icon: string, color: string): CategoryInfo
	return table.freeze({ id = id, name = name, icon = icon, color = color })
end

ReputationText.CATEGORIES = table.freeze({
	compassion = info("compassion", "Compassion", "rep_compassion", "vert"),
	honor = info("honor", "Honor", "rep_honor", "azure"),
	competence = info("competence", "Competence", "rep_competence", "amber"),
	courage = info("courage", "Courage", "rep_courage", "gules"),
	authority = info("authority", "Authority", "rep_authority", "purpure"),
	fear = info("fear", "Fear", "rep_fear", "textSecondary"),
})

ReputationText.CONDITIONS = table.freeze({
	table.freeze({ id = "happiness", name = "Happiness", icon = "happiness" }),
	table.freeze({ id = "stability", name = "Stability", icon = "stability" }),
	table.freeze({ id = "morale", name = "Army morale", icon = "banner" }),
})

function ReputationText.isCategory(id: any): boolean
	return type(id) == "string" and ReputationText.CATEGORIES[id] ~= nil
end

local function str(v: any): string?
	return if type(v) == "string" and v ~= "" then v else nil
end

-- A provider over a generated Content/Reputation module. Wrong shapes give nil, never an error.
function ReputationText.fromContent(module: any): Provider?
	if type(module) ~= "table" or type(module.categories) ~= "table" then
		return nil
	end
	local categories = module.categories
	return function(id: string): Text?
		local row = categories[id]
		if type(row) ~= "table" then
			return nil
		end
		return { name = str(row.name), description = str(row.description), affects = str(row.affects) }
	end
end

ReputationText.provider = ReputationText.fromContent(CONTENT)

return table.freeze(ReputationText)
