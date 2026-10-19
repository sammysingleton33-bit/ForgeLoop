--!strict
--[[
	UI/ArenaIntroModel — the two-sided versus card before the duel (FL-0073; design crown-arena.md §7 "Intro",
	CONTRACTS G12.1 ArenaState / Duellist). Pure; no instances. UI/ArenaIntroCard draws it.

		ArenaIntroModel.view(arena, lookup, userId, now) -> View?   nil unless the stage is "intro"
			lookup = { kingdom: (KingdomId) -> { id, name, color? }?, name: (userId) -> string? }
			View = { clock?, left: Card, right: Card, mine: boolean (the local player is a champion) }
			Card = { side, champion, kingdomName, kingdomId, color: Color3, emblem, tier { name, color }, score,
			         weapon { name, icon }, armour { name, icon }, reasons: { string } (≤ 3),
			         triggers: { { id, name, icon, citizen? } }, ai }
		The local player's side is on the left (the "a" side for a spectator). Every reason is the server's
		pre-authored moment text (LeadershipMoment.text), never user input; a duellist with none says so.
		A trigger shows its citizen ("Bram · Blacksmith") when the server sends Duellist.triggerCitizens (an
		optional field asked of FORGE-01, handoff 2026-10-19-forge-03-to-forge-01-arena-ui); without it, the
		trigger's name and icon only.
]]

local ArenaText = require("./ArenaText")
local Format = require("@game/ReplicatedStorage/Forge/UI/Format")
local HudModel = require("./HudModel")
local LoadoutModel = require("./LoadoutModel")
local Theme = require("@game/ReplicatedStorage/Forge/UI/Theme")

local ArenaIntroModel = {}

ArenaIntroModel.REASONS = 3

local function card(side: string, d: any, lookup: any): any
	local k = if type(d.kingdom) == "string" and lookup.kingdom then lookup.kingdom(d.kingdom) else nil
	local kingdomName = if k and k.name then k.name else tostring(d.kingdom or "?")
	local champion = if d.isAI == true then `{kingdomName}'s champion` else nil
	if champion == nil and type(d.userId) == "number" and lookup.name then
		champion = lookup.name(d.userId)
	end
	local tier = ArenaText.tier(d.tier)
	local reasons = {}
	for _, r in if type(d.reasons) == "table" then d.reasons else {} do
		if type(r) == "string" and r ~= "" and #reasons < ArenaIntroModel.REASONS then
			table.insert(reasons, r)
		end
	end
	local triggers = {}
	local citizens = if type(d.triggerCitizens) == "table" then d.triggerCitizens else {}
	for _, id in if type(d.triggers) == "table" then d.triggers else {} do
		local info = ArenaText.trigger(id)
		local c = citizens[id]
		local citizen = nil
		if type(c) == "table" and type(c.name) == "string" then
			local role = ArenaText.ROLES[c.role]
			citizen = if role then `{c.name} · {role}` else c.name
		end
		table.insert(triggers, { id = id, name = info.name, icon = info.icon, citizen = citizen })
	end
	local weapon = ArenaText.weapon(d.weapon)
	local armour = ArenaText.armour(d.armour)
	return {
		side = side,
		champion = champion or `{kingdomName}'s champion`,
		kingdomId = d.kingdom,
		kingdomName = kingdomName,
		color = if k then HudModel.color(k) else Theme.tincture(tostring(d.kingdom)),
		emblem = HudModel.EMBLEMS[d.kingdom] or "crest",
		tier = { name = tier.name, color = Theme.color(tier.color) },
		score = if type(d.score) == "number" then math.floor(d.score + 0.5) else nil,
		weapon = { name = weapon.name, icon = weapon.icon },
		armour = { name = armour.name, icon = armour.icon },
		reasons = reasons,
		noReasons = if #reasons == 0 then "No deeds remembered yet" else nil,
		triggers = triggers,
		noTriggers = if #triggers == 0 then "No perks" else nil,
		ai = d.isAI == true,
	}
end

function ArenaIntroModel.view(arena: any, lookup: any, userId: number?, now: number): any
	if type(arena) ~= "table" or arena.stage ~= "intro" then
		return nil
	end
	if type(arena.a) ~= "table" or type(arena.b) ~= "table" then
		return nil
	end
	local mine = LoadoutModel.side(arena, userId)
	local leftSide = mine or "a"
	local rightSide = if leftSide == "a" then "b" else "a"
	local left = arena[leftSide] :: any
	local right = arena[rightSide] :: any
	local secondsLeft = if type(arena.endsAt) == "number" then math.max(0, arena.endsAt - now) else nil
	return {
		clock = if secondsLeft then Format.clock(secondsLeft) else nil,
		mine = mine ~= nil,
		left = card(leftSide, left, lookup or {}),
		right = card(rightSide, right, lookup or {}),
	}
end

return table.freeze(ArenaIntroModel)
