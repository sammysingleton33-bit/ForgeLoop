--!strict
--[[
	UI/HudModel — what the kingdom HUD and the Kingdom panel show, as data (pure, no instances).

		HudModel.banner(store) -> Banner?          nil until the player has a kingdom
			Banner = { id, name, emblem, color: Color3, keepLevel, regions, crownPoints, sub }
		HudModel.members(store, nameOf, localUserId) -> { { userId, name, initial, you } }
			nameOf(userId) -> string?  (Players:GetPlayerByUserId(...).DisplayName); unknown ids show "Ruler"
		HudModel.timer(match?, now) -> { phase, clock?, label? }?     top-bar chip
		HudModel.queue(store) -> { Chip }          my buildings being built, oldest first
			Chip = { id, type, name, icon, category, progress (0..1), waiting, level }
		HudModel.standings(store) -> { { id, name, emblem, color, crownPoints, regions, ai, me, rank } }
		HudModel.EMBLEMS[kingdomId] -> icon name   (ART_DIRECTION §3, as the world: crown, star, oak leaf, sun)
		HudModel.color(kingdom) -> Color3          `kingdom.color` from the server, else the theme tincture
]]

local Buildings = require("./Buildings")
local Format = require("@game/ReplicatedStorage/Forge/UI/Format")
local Text = require("./Text")
local Theme = require("@game/ReplicatedStorage/Forge/UI/Theme")

local HudModel = {}

HudModel.EMBLEMS = table.freeze({
	crimson = "emblem_crown",
	azure = "emblem_star",
	emerald = "emblem_oak",
	gold = "emblem_sun",
})

function HudModel.color(kingdom: any): Color3
	if typeof(kingdom.color) == "Color3" then
		return kingdom.color
	end
	return Theme.tincture(kingdom.id)
end

local function plural(n: number, word: string): string
	return `{n} {word}{if n == 1 then "" else "s"}`
end

function HudModel.banner(store: any): any
	local kingdom = store:mine()
	if kingdom == nil then
		return nil
	end
	local keep = store:keep()
	local keepLevel = if keep then keep.level else 1
	local regions = if type(kingdom.regions) == "table" then #kingdom.regions else 0
	local crownPoints = if type(kingdom.crownPoints) == "number" then kingdom.crownPoints else 0
	return {
		id = kingdom.id,
		name = if type(kingdom.name) == "string" then kingdom.name else kingdom.id,
		emblem = HudModel.EMBLEMS[kingdom.id] or "crest",
		color = HudModel.color(kingdom),
		keepLevel = keepLevel,
		regions = regions,
		crownPoints = crownPoints,
		sub = `Keep Lv {keepLevel} · {plural(regions, "region")} · {Format.amount(crownPoints)} Crown Points`,
	}
end

function HudModel.members(store: any, nameOf: (number) -> string?, localUserId: number?): { any }
	local kingdom = store:mine()
	local out = {}
	if kingdom == nil or type(kingdom.rulers) ~= "table" then
		return out
	end
	for _, userId in kingdom.rulers do
		if type(userId) == "number" then
			local name = nameOf(userId) or "Ruler"
			table.insert(out, {
				userId = userId,
				name = name,
				initial = string.upper(string.sub(name, 1, 1)),
				you = userId == localUserId,
			})
		end
	end
	-- You first, then the others in the server's order.
	table.sort(out, function(a, b)
		return a.you and not b.you
	end)
	return out
end

-- The full match's phases in order (CONTRACTS G3; D-053 (1)). A timed phase on this list gets the phase
-- track and the next phase's name (FL-0129); any other phase (Lobby, an Arena phase not listed yet) shows
-- only its name and clock. The slice's Founding is untimed, so the slice never shows the track.
HudModel.PHASES = table.freeze({ "Founding", "Expansion", "Conflict", "Endgame", "Results" })
-- What the next phase opens, said beside its name (D-053 (2): war from Conflict on).
HudModel.NEXT_NOTE = table.freeze({ Conflict = "war opens" })

function HudModel.timer(match: any, now: number): any
	if match == nil then
		return nil
	end
	local phase = Text.phase(match.phase)
	if match.endsAt then
		local label = if match.phase == "Lobby" then "until the match starts" else "left"
		local step = table.find(HudModel.PHASES, match.phase)
		local nextPhase = if step then HudModel.PHASES[step + 1] else nil
		return {
			phase = phase,
			clock = Format.clock(match.endsAt - now),
			label = label,
			step = step, -- 1..#PHASES on the track; nil = no track
			steps = if step then #HudModel.PHASES else nil,
			next = if nextPhase then Text.phase(nextPhase) else nil,
			nextNote = if nextPhase then HudModel.NEXT_NOTE[nextPhase] else nil,
		}
	elseif match.startedAt and match.phase ~= "Lobby" and match.phase ~= "Results" then
		return { phase = phase, clock = Format.clock(now - match.startedAt), label = "match time" }
	end
	return { phase = phase }
end

function HudModel.queue(store: any): { any }
	local out = {}
	for _, building in store:myBuildings() do
		if building.state == "planned" or building.state == "constructing" then
			local info = Buildings.get(building.type)
			local progress = if type(building.progress) == "number" then math.clamp(building.progress, 0, 1) else 0
			table.insert(out, {
				id = building.id,
				type = building.type,
				name = Buildings.name(building.type),
				icon = if info then info.icon else "build",
				category = if info then info.category else "economy",
				progress = progress,
				waiting = building.state == "planned",
				level = building.level,
			})
		end
	end
	return out
end

function HudModel.standings(store: any): { any }
	local mine = store:mine()
	local out = {}
	for _, kingdom in store:kingdoms() do
		table.insert(out, {
			id = kingdom.id,
			name = if type(kingdom.name) == "string" then kingdom.name else kingdom.id,
			emblem = HudModel.EMBLEMS[kingdom.id] or "crest",
			color = HudModel.color(kingdom),
			crownPoints = if type(kingdom.crownPoints) == "number" then kingdom.crownPoints else 0,
			regions = if type(kingdom.regions) == "table" then #kingdom.regions else 0,
			ai = kingdom.isAI == true,
			me = mine ~= nil and kingdom.id == mine.id,
		})
	end
	table.sort(out, function(a, b)
		if a.crownPoints ~= b.crownPoints then
			return a.crownPoints > b.crownPoints
		end
		return a.name < b.name
	end)
	for i, row in out do
		row.rank = i
	end
	return out
end

return table.freeze(HudModel)
