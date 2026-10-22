--!strict
--[[
	UI/ArenaQualifyModel — the Crown Arena's `qualify` stage (FORGE-01's coming arena PR; G12.4 Arena.State additive
	fields as agreed 2026-10-22: `qualifiers: { KingdomId }` side a first = the better Crown Points, and
	`qualifierPoints: { [KingdomId]: number }`, the points frozen when the arena began). Pure; UI/ArenaQualifyCard
	draws it. Every player sees which two kingdoms fight for the crown before the vote; a coronation (one qualifier)
	has no qualify stage, so no banner.

		ArenaQualifyModel.view(state, lookup, mineId, now) -> View?
			nil unless state.stage == "qualify" with two qualifiers
			View = { clock?, note, left: Side, right: Side }
			Side = { id, name, color, emblem, points?, mine }
			note: "Your kingdom fights for the crown" when the local kingdom qualified, else
			      "Two kingdoms fight for the crown"
			lookup.kingdom(id) -> the store's kingdom row (name; HudModel.color reads its colour)
]]

local Format = require("@game/ReplicatedStorage/Forge/UI/Format")
local HudModel = require("./HudModel")

local ArenaQualifyModel = {}

local function side(id: any, state: any, lookup: any, mineId: any): any
	local k = if lookup and lookup.kingdom then lookup.kingdom(id) else nil
	local points = if type(state.qualifierPoints) == "table" then state.qualifierPoints[id] else nil
	return {
		id = id,
		name = if k and k.name then k.name else tostring(id),
		color = HudModel.color(k or { id = id }),
		emblem = HudModel.EMBLEMS[id] or "crest",
		points = if type(points) == "number" then points else nil,
		mine = mineId ~= nil and id == mineId,
	}
end

function ArenaQualifyModel.view(state: any, lookup: any, mineId: any, now: number): any
	if type(state) ~= "table" or state.stage ~= "qualify" then
		return nil
	end
	local q = state.qualifiers
	if type(q) ~= "table" or q[1] == nil or q[2] == nil then
		return nil
	end
	local left = side(q[1], state, lookup, mineId)
	local right = side(q[2], state, lookup, mineId)
	return {
		clock = if type(state.endsAt) == "number" then Format.clock(state.endsAt - now) else nil,
		note = if left.mine or right.mine
			then "Your kingdom fights for the crown"
			else "Two kingdoms fight for the crown",
		left = left,
		right = right,
	}
end

return table.freeze(ArenaQualifyModel)
