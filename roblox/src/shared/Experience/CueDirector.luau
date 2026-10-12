--!strict
--[[
	Experience/CueDirector — resolves a gameplay signal into feedback actions for the local player,
	from a game's cue matrix. Generic: the game supplies the matrix, how to classify a signal (whose
	it is, who won, ...) and how to resolve "@placeholder" ids. game-001: games/game-001/src/shared/
	Feedback/Cues.luau, played by its FeedbackController (FL-0062).

		local director = CueDirector.new({
			cues = { [signalName] = { Variant } },
			classify = function(signalName, info) -> { [tag]: any },   -- e.g. { relation = "mine", outcome = "won" }
			ids = { [placeholder] = function(info) -> id? },          -- "@resource" -> ids.resource(info)
			now = env.clock,
			setting = function(key) return SettingsController:get(key) end,
		})
		director:handle(signalName, info) -> { Action }

	Variant: the first whose `when` entries all equal the classify tags is used (no `when` = always).
		sound, vfx: id or "@placeholder"     float: "+{amount} {resource}" (template from info)
		react: reaction id (the game decides who reacts)   notify: { kind, title, body?, important? }
		music: input string for the game's MusicController   celebrate: kind for NotificationController
		coalesce: { key = "{resource}", windowSec } — repeats inside the window keep vfx and float but drop
		the sound and the reaction, and their notification carries the same `key` with a growing
		`count`, so NotificationController updates one toast ("Farm complete x3").
	Actions, in play order: sound, vfx, float, react, notify, music, celebrate.
		{ kind = "sound", id, position? }   { kind = "vfx", id, position?, tint? }   { kind = "float", text, position? }
		{ kind = "react", reaction, position? }   { kind = "notify", notification = { title, body?, kind, key?, count } }
		{ kind = "music", input }   { kind = "celebrate", celebration, payload }
	Settings: notifications = "important" keeps only important toasts; citizenBarks = false drops reactions.

		CueDirector.validate(cues, { sounds = registry, vfx = VfxPresets-like, reactions = table?, expand = fn? })
			-> { string }   -- unknown ids, bad notify kinds, and sound-only variants (accessibility rule:
			                -- creator-docs production/publishing/accessibility.md, players with sound off
			                -- "will be confused by in-game events that are **only** conveyed with sound")
		CueDirector.format(template, info) -> string   -- "{field}" from primitive info values, max 60 chars
]]

local CueDirector = {}
CueDirector.__index = CueDirector

local NOTIFY_KINDS = { info = true, reward = true, warning = true, achievement = true }
local MAX_TEXT = 60

export type Options = {
	cues: { [string]: { any } },
	classify: ((signalName: string, info: { [string]: any }) -> { [string]: any })?,
	ids: { [string]: (info: { [string]: any }) -> string? }?,
	now: () -> number,
	setting: ((key: string) -> any)?,
}

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

function CueDirector.new(options: Options)
	assert(type(options) == "table" and type(options.cues) == "table", "CueDirector.new: options.cues required")
	assert(type(options.now) == "function", "CueDirector.new: options.now required")
	return setmetatable({ _options = options, _windows = {} }, CueDirector)
end

function CueDirector:_setting(key: string): any
	local getter = self._options.setting
	return if getter then getter(key) else nil
end

local function matches(variant: any, tags: { [string]: any }): boolean
	for key, expected in variant.when or {} do
		if tags[key] ~= expected then
			return false
		end
	end
	return true
end

function CueDirector:_resolveId(value: string?, info: { [string]: any }): string?
	if type(value) ~= "string" or string.sub(value, 1, 1) ~= "@" then
		return value
	end
	local resolver = self._options.ids and self._options.ids[string.sub(value, 2)]
	return if resolver then resolver(info) else nil
end

function CueDirector:handle(signalName: string, info: { [string]: any }?): { any }
	local data = info or {}
	local variants = self._options.cues[signalName]
	if variants == nil then
		return {}
	end
	local tags = if self._options.classify then self._options.classify(signalName, data) else {}
	local variant = nil
	for _, candidate in variants do
		if matches(candidate, tags) then
			variant = candidate
			break
		end
	end
	if variant == nil then
		return {}
	end
	local now = self._options.now()
	local position = data.position
	local repeatCount = 1
	local coalesceKey: string? = nil
	if variant.coalesce then
		coalesceKey = `{signalName}:{CueDirector.format(variant.coalesce.key, data)}`
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
	local sound = self:_resolveId(variant.sound, data)
	if sound and first then
		table.insert(actions, { kind = "sound", id = sound, position = position })
	end
	local vfx = self:_resolveId(variant.vfx, data)
	if vfx then
		table.insert(actions, { kind = "vfx", id = vfx, position = position, tint = data.tint })
	end
	if variant.float then
		table.insert(actions, { kind = "float", text = CueDirector.format(variant.float, data), position = position })
	end
	if variant.react and first and self:_setting("citizenBarks") ~= false then
		table.insert(actions, { kind = "react", reaction = variant.react, position = position })
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
	local function idsOf(value: any): { string }
		if type(value) ~= "string" then
			return {}
		end
		if string.sub(value, 1, 1) == "@" then
			return if refs.expand then refs.expand(string.sub(value, 2)) or {} else {}
		end
		return { value }
	end
	for _, name in names do
		for i, variant in cues[name] do
			local where = `{name}[{i}]`
			if variant.when ~= nil and type(variant.when) ~= "table" then
				table.insert(problems, `{where}: when must be a table of tags`)
			end
			for _, id in idsOf(variant.sound) do
				if refs.sounds:get(id) == nil then
					table.insert(problems, `{where}: unknown sound '{id}'`)
				end
			end
			for _, id in idsOf(variant.vfx) do
				if refs.vfx.get(id) == nil then
					table.insert(problems, `{where}: unknown vfx preset '{id}'`)
				end
			end
			if variant.react and refs.reactions and refs.reactions[variant.react] == nil then
				table.insert(problems, `{where}: unknown reaction '{variant.react}'`)
			end
			if variant.notify then
				if not NOTIFY_KINDS[variant.notify.kind] then
					table.insert(problems, `{where}: notify.kind must be info | reward | warning | achievement`)
				end
				if type(variant.notify.title) ~= "string" or variant.notify.title == "" then
					table.insert(problems, `{where}: notify.title required`)
				end
			end
			if variant.music ~= nil and type(variant.music) ~= "string" then
				table.insert(problems, `{where}: music must be an input name`)
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
