--!strict
--[[
	UI/ArenaHudModel — the duel HUD (FL-0073; design crown-arena.md §4-§5, CONTRACTS G12.1 ArenaState, G12.4
	Arena.Events, G12.2 DuelModel.snapshot). Pure; no instances. UI/ArenaHud draws it.

		ArenaHudModel.new() -> Track      what the client has seen of this duel
		ArenaHudModel.apply(track, event, now)   one Arena.Events entry { t, kind, side, data? }:
			hit          data.targetHpShare -> the other side's HP
			snapshot     data = DuelModel.snapshot (a/b.hpShare, staminaShare, state; suddenDeath; ended): the
			             periodic picture asked of FORGE-01 (handoff 2026-10-19-forge-03-to-forge-01-arena-ui);
			             without it stamina is unknown and the bar says so
			staminaOut   that side's stamina -> 0 (until the next snapshot)
			triggerFired data.source -> that side's trigger fired (shown active for ACTIVE_SEC, then spent)
			ended        data { winner, reason, hpA, hpB }
		ArenaHudModel.reset(track)        a new duel (a different pair of duellists)
		ArenaHudModel.view(track, arena, lookup, userId, now) -> View?   nil unless the stage is "duel"
			View = { clock?, urgent, suddenDeath, ended?, left: Side, right: Side, mine }
			Side = { side, name, kingdomName, color, tier { name, color }, hp (0..1), hpText ("72%"),
			         stamina (0..1)?, low (hp ≤ LOW), triggers: { { id, name, icon, state = "armed" | "active" |
			         "spent" } } }
		Both duellists' triggers are shown (design §4: "both players see the trigger"); each fires at most once.
]]

local ArenaText = require("./ArenaText")
local Format = require("@game/ReplicatedStorage/Forge/UI/Format")
local HudModel = require("./HudModel")
local LoadoutModel = require("./LoadoutModel")
local Theme = require("@game/ReplicatedStorage/Forge/UI/Theme")

local ArenaHudModel = {}

ArenaHudModel.ACTIVE_SEC = 6 -- a fired trigger glows this long (the longest G12.3 trigger lasts 8 s)
ArenaHudModel.LOW = 0.25
ArenaHudModel.URGENT_SEC = 15

local function fresh(): any
	return { hp = 1, stamina = nil :: number?, fired = {} :: { [string]: number } }
end

function ArenaHudModel.new(): any
	return { key = nil, a = fresh(), b = fresh(), suddenDeath = false, ended = nil :: any }
end

function ArenaHudModel.reset(track: any)
	track.a = fresh()
	track.b = fresh()
	track.suddenDeath = false
	track.ended = nil
end

local function other(side: string): string
	return if side == "a" then "b" else "a"
end

local function share(n: any): number?
	return if type(n) == "number" then math.clamp(n, 0, 1) else nil
end

function ArenaHudModel.apply(track: any, event: any, now: number)
	if type(event) ~= "table" or type(event.kind) ~= "string" then
		return
	end
	local side = if event.side == "a" or event.side == "b" then event.side else nil
	local data = if type(event.data) == "table" then event.data else {}
	if event.kind == "hit" and side then
		local hp = share(data.targetHpShare)
		if hp then
			track[other(side)].hp = hp
		end
	elseif event.kind == "snapshot" then
		for _, id in { "a", "b" } do
			local s = data[id]
			if type(s) == "table" then
				track[id].hp = share(s.hpShare) or track[id].hp
				track[id].stamina = share(s.staminaShare) or track[id].stamina
			end
		end
		track.suddenDeath = data.suddenDeath == true
	elseif event.kind == "staminaOut" and side then
		track[side].stamina = 0
	elseif event.kind == "triggerFired" and side then
		local id = ArenaText.triggerFromSource(data.source)
		if id and track[side].fired[id] == nil then
			track[side].fired[id] = now
		end
	elseif event.kind == "ended" then
		track.ended = { winner = data.winner or event.side, reason = data.reason }
		if type(data.hpA) == "number" and type(data.hpB) == "number" then
			-- hpA / hpB are HP points; the shares already follow from the last hit or snapshot
			track.a.hp = if data.hpA <= 0 then 0 else track.a.hp
			track.b.hp = if data.hpB <= 0 then 0 else track.b.hp
		end
	end
end

local function sideView(track: any, id: string, d: any, lookup: any, now: number): any
	local k = if type(d.kingdom) == "string" and lookup.kingdom then lookup.kingdom(d.kingdom) else nil
	local kingdomName = if k and k.name then k.name else tostring(d.kingdom or "?")
	local name = if d.isAI == true then `{kingdomName}'s champion` else nil
	if name == nil and type(d.userId) == "number" and lookup.name then
		name = lookup.name(d.userId)
	end
	local tier = ArenaText.tier(d.tier)
	local t = track[id]
	local triggers = {}
	for _, trig in if type(d.triggers) == "table" then d.triggers else {} do
		local info = ArenaText.trigger(trig)
		local firedAt = t.fired[trig]
		local state = if firedAt == nil
			then "armed"
			elseif now - firedAt < ArenaHudModel.ACTIVE_SEC then "active"
			else "spent"
		table.insert(triggers, { id = trig, name = info.name, icon = info.icon, state = state })
	end
	return {
		side = id,
		name = name or `{kingdomName}'s champion`,
		kingdomName = kingdomName,
		color = if k then HudModel.color(k) else Theme.tincture(tostring(d.kingdom)),
		emblem = HudModel.EMBLEMS[d.kingdom] or "crest",
		tier = { name = tier.name, color = Theme.color(tier.color) },
		hp = t.hp,
		hpText = `{math.floor(t.hp * 100 + 0.5)}%`,
		stamina = t.stamina,
		low = t.hp <= ArenaHudModel.LOW,
		triggers = triggers,
	}
end

function ArenaHudModel.view(track: any, arena: any, lookup: any, userId: number?, now: number): any
	if type(arena) ~= "table" or arena.stage ~= "duel" then
		return nil
	end
	if type(arena.a) ~= "table" or type(arena.b) ~= "table" then
		return nil
	end
	local key = `{arena.a.userId}|{arena.b.userId}`
	if track.key ~= key then
		ArenaHudModel.reset(track)
		track.key = key
	end
	local mine = LoadoutModel.side(arena, userId)
	local leftSide = mine or "a"
	local rightSide = other(leftSide)
	local secondsLeft = if type(arena.endsAt) == "number" then math.max(0, arena.endsAt - now) else nil
	return {
		mine = mine ~= nil,
		clock = if secondsLeft then Format.clock(secondsLeft) else nil,
		urgent = secondsLeft ~= nil and secondsLeft <= ArenaHudModel.URGENT_SEC,
		suddenDeath = track.suddenDeath,
		ended = track.ended,
		left = sideView(track, leftSide, arena[leftSide], lookup or {}, now),
		right = sideView(track, rightSide, arena[rightSide], lookup or {}, now),
	}
end

return table.freeze(ArenaHudModel)
