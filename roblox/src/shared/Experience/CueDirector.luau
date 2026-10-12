--!strict
--[[
	Experience/CueDirector — resolves a gameplay signal into feedback actions for the local player,
	using the matrix in Experience/Cues. Pure apart from the injected clock and settings.

		local director = CueDirector.new({
			now = env.clock,                         -- seconds
			kingdomId = function() return "k1" end,  -- the local player's kingdom (nil before founding)
			setting = function(key) return value end -- SettingsController:get
		})
		director:handle(eventName, info) -> { Action }

	Actions, in play order:
		{ kind = "sound", id, position? }
		{ kind = "vfx", id, position?, tint? }
		{ kind = "float", text, position? }
		{ kind = "react", reaction, position?, kingdomId }
		{ kind = "notify", notification = { title, body?, kind, durationSec?, key?, count } }
		{ kind = "music", input = "combat" | "calm" }
		{ kind = "celebrate", celebration, payload }

	Coalescing (variant.coalesce): the first signal of a window plays everything; repeats inside the
	window keep vfx and float (each at its own position) but drop the sound and the reaction, and
	their notification carries the same `key` with a growing `count`, so NotificationController
	updates one toast ("Farm complete x3") instead of stacking three.
	Settings: notifications = "important" keeps only important toasts; citizenBarks = false drops
	reactions. Reduced motion is applied by VFXController (per preset).

		CueDirector.validate(cues, { sounds = registry, vfx = VfxPresets, reactions = CitizenReactions.REACTIONS })
			-> { string }  -- unknown ids, bad relations/kinds, and sound-only variants (accessibility rule)
		CueDirector.format(template, info) -> string     -- "{field}" from primitive info values, max 60 chars
]]

local Cues = require("./Cues")

local CueDirector = {}
CueDirector.__index = CueDirector

local RELATIONS = { mine = true, against = true, others = true }
local NOTIFY_KINDS = { info = true, reward = true, warning = true, achievement = true }
local MAX_TEXT = 60

export type Options = { now: () -> number, kingdomId: () -> string?, setting: ((key: string) -> any)? }

function CueDirector.format(template: string, info: { [string]: any }): string
	local text = string.gsub(template, "{(%w+)}", function(field: string): string
		local value = info[field]
		local kind = type(value)
		if kind == "string" or kind == "number" or kind == "boolean" then
			return tostring(value)
		end
		return ""
	end)
	text = string.gsub(text, "%s+", " ")
	text = string.match(text, "^%s*(.-)%s*$") or text
	if #text > MAX_TEXT then
		text = string.sub(text, 1, MAX_TEXT - 3) .. "..."
	end
	return text
end

local function bandOf(morale: number): number
	if morale < Cues.MORALE_BANDS.low then
		return 1
	elseif morale > Cues.MORALE_BANDS.high then
		return 3
	end
	return 2
end

local function relationOf(info: { [string]: any }, mine: string?): string
	if mine ~= nil then
		if info.kingdomId == mine then
			return "mine"
		elseif info.defenderKingdomId == mine or info.fromKingdomId == mine then
			return "against"
		end
	end
	return "others"
end

local function outcomeOf(eventName: string, info: { [string]: any }, relation: string, mine: string?): string?
	if eventName == "BattleEnded" and info.winnerKingdomId ~= nil then
		return if info.winnerKingdomId == mine then "won" else "lost"
	elseif eventName == "SiegeEnded" and info.outcome ~= nil then
		local breached = info.outcome == "Breached"
		if relation == "mine" then
			return if breached then "won" else "lost"
		end
		return if breached then "lost" else "won"
	end
	return nil
end

local function moraleBand(info: { [string]: any }): string?
	if type(info.morale) ~= "number" or type(info.previous) ~= "number" then
		return nil
	end
	local before, after = bandOf(info.previous), bandOf(info.morale)
	if after == 3 and before < 3 then
		return "joyful"
	elseif after == 1 and before > 1 then
		return "unhappy"
	elseif before == 1 and after > 1 then
		return "recovered"
	end
	return nil
end

function CueDirector.new(options: Options)
	return setmetatable({ _options = options, _windows = {} }, CueDirector)
end

function CueDirector:_setting(key: string): any
	local getter = self._options.setting
	return if getter then getter(key) else nil
end

function CueDirector:_variant(eventName: string, info: { [string]: any }): (any, string)
	local variants = Cues.CUES[eventName]
	local mine = self._options.kingdomId()
	local relation = relationOf(info, mine)
	if variants == nil then
		return nil, relation
	end
	local outcome = outcomeOf(eventName, info, relation, mine)
	local band = if eventName == "MoraleChanged" then moraleBand(info) else nil
	local eventKind = if eventName == "KingdomEventStarted"
		then (if Cues.GOOD_EVENTS[info.eventId] then "good" else "bad")
		else nil
	for _, variant in variants do
		if
			variant.relation == relation
			and (variant.outcome == nil or variant.outcome == outcome)
			and (variant.band == nil or variant.band == band)
			and (variant.eventKind == nil or variant.eventKind == eventKind)
		then
			return variant, relation
		end
	end
	return nil, relation
end

local function resolveId(value: string?, table_: { [string]: string }, info: { [string]: any }): string?
	if value == "@resource" then
		return table_[info.resource]
	end
	return value
end

function CueDirector:handle(eventName: string, info: { [string]: any }?): { any }
	local data = info or {}
	local variant, relation = self:_variant(eventName, data)
	if variant == nil then
		return {}
	end
	local now = self._options.now()
	local position = data.position
	local repeatCount = 1
	local coalesceKey: string? = nil
	if variant.coalesce then
		coalesceKey = `{eventName}:{CueDirector.format(variant.coalesce.key, data)}`
		local window = self._windows[coalesceKey]
		if window and now < window.untilAt then
			window.count += 1
			window.untilAt = now + variant.coalesce.windowSec
			repeatCount = window.count
		else
			self._windows[coalesceKey] = { untilAt = now + variant.coalesce.windowSec, count = 1 }
		end
	end
	local first = repeatCount == 1
	local actions = {}
	local sound = resolveId(variant.sound, Cues.RESOURCE_SOUND, data)
	if sound and first then
		table.insert(actions, { kind = "sound", id = sound, position = position })
	end
	local vfx = resolveId(variant.vfx, Cues.RESOURCE_VFX, data)
	if vfx then
		table.insert(actions, { kind = "vfx", id = vfx, position = position, tint = data.kingdomColor })
	end
	if variant.float then
		table.insert(actions, { kind = "float", text = CueDirector.format(variant.float, data), position = position })
	end
	if variant.react and first and relation ~= "others" and self:_setting("citizenBarks") ~= false then
		-- "mine" and "against" are both about the local kingdom: its own citizens react
		table.insert(
			actions,
			{ kind = "react", reaction = variant.react, position = position, kingdomId = self._options.kingdomId() }
		)
	end
	local notify = variant.notify
	if notify and (notify.important or self:_setting("notifications") ~= "important") then
		table.insert(actions, {
			kind = "notify",
			notification = {
				title = CueDirector.format(notify.title, data),
				body = if notify.body then CueDirector.format(notify.body, data) else nil,
				kind = notify.kind,
				key = coalesceKey,
				count = repeatCount,
			},
		})
	end
	if variant.music then
		table.insert(actions, { kind = "music", input = variant.music })
	end
	if variant.celebrate and first then
		table.insert(actions, { kind = "celebrate", celebration = variant.celebrate, payload = data })
	end
	return actions
end

function CueDirector.validate(cues: { [string]: any }, refs: { [string]: any }): { string }
	local problems: { string } = {}
	local names = {}
	for name in cues do
		table.insert(names, name)
	end
	table.sort(names)
	local function soundExists(id: string): boolean
		return refs.sounds:get(id) ~= nil
	end
	local function vfxExists(id: string): boolean
		return refs.vfx.get(id) ~= nil
	end
	for _, name in names do
		for i, variant in cues[name] do
			local where = `{name}[{i}]`
			if not RELATIONS[variant.relation] then
				table.insert(problems, `{where}: relation must be mine | against | others`)
			end
			local sounds = if variant.sound == "@resource" then Cues.RESOURCE_SOUND else { variant.sound }
			for _, id in sounds do
				if not soundExists(id) then
					table.insert(problems, `{where}: unknown sound '{id}'`)
				end
			end
			local vfxIds = if variant.vfx == "@resource" then Cues.RESOURCE_VFX else { variant.vfx }
			for _, id in vfxIds do
				if not vfxExists(id) then
					table.insert(problems, `{where}: unknown vfx preset '{id}'`)
				end
			end
			if variant.react and refs.reactions[variant.react] == nil then
				table.insert(problems, `{where}: unknown citizen reaction '{variant.react}'`)
			end
			if variant.notify then
				if not NOTIFY_KINDS[variant.notify.kind] then
					table.insert(problems, `{where}: notify.kind must be info | reward | warning | achievement`)
				end
				if type(variant.notify.title) ~= "string" or variant.notify.title == "" then
					table.insert(problems, `{where}: notify.title required`)
				end
			end
			if variant.music and variant.music ~= "combat" and variant.music ~= "calm" then
				table.insert(problems, `{where}: music must be combat | calm`)
			end
			if variant.sound and not (variant.vfx or variant.notify or variant.float or variant.react) then
				table.insert(problems, `{where}: sound-only cue; add a visual (accessibility rule)`)
			end
			if
				variant.coalesce and (type(variant.coalesce.windowSec) ~= "number" or variant.coalesce.windowSec <= 0)
			then
				table.insert(problems, `{where}: coalesce.windowSec must be positive`)
			end
		end
	end
	return problems
end

return CueDirector
