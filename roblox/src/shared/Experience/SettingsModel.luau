--!strict
--[[
	Experience/SettingsModel (FORGE-04, FL-0103): what the settings panel shows and what each control
	does. Pure: no instances, no remotes; the panel (Experience/SettingsPanel) draws it and
	SettingsPanelController sends the new value through SettingsController:set.

		SettingsModel.SECTIONS = { { id, title, keys = { settingKey } } }   every Schema.SETTINGS key once
		SettingsModel.LABEL[key], SettingsModel.OPTION_LABEL[option]
		SettingsModel.STEP = 0.1                       one − / + tap on a volume
		SettingsModel.sections(values, opts?) -> { { id, title, rows = { Row } } }
		    Row = { key, label, kind ("volume" | "boolean" | "enum"), value, text, progress?, canDown?,
		            canUp?, note? }
		    opts.platformReducedMotion: the device's Reduce Motion is on, so motion is reduced whatever
		    the toggle says (SettingsController:reducedMotion); the row says so in `note`.
		SettingsModel.next(key, value, action) -> any?
		    action "down" | "up" (volume, ±STEP, clamped 0..1, rounded to the step), "toggle" (boolean),
		    "cycle" (enum: the next option). nil when the action changes nothing or does not fit the key.
	Volumes show as whole percentages; every row is one line (phones fit them at 844×390).
]]

local Schema = require("./Schema")

local SettingsModel = {}

SettingsModel.STEP = 0.1

SettingsModel.SECTIONS = table.freeze({
	table.freeze({
		id = "sound",
		title = "Sound",
		keys = table.freeze({ "masterVolume", "musicVolume", "sfxVolume", "ambienceVolume", "uiVolume" }),
	}),
	table.freeze({
		id = "motion",
		title = "Motion and effects",
		keys = table.freeze({ "reducedMotion", "cameraShake", "effectsQuality" }),
	}),
	table.freeze({
		id = "play",
		title = "Gameplay",
		keys = table.freeze({ "showHints", "citizenBarks", "jobGlyphs", "notifications" }),
	}),
})

SettingsModel.LABEL = table.freeze({
	masterVolume = "Master volume",
	musicVolume = "Music",
	sfxVolume = "Effects",
	ambienceVolume = "Ambience",
	uiVolume = "Interface sounds",
	reducedMotion = "Reduced motion",
	cameraShake = "Camera shake",
	effectsQuality = "Effects quality",
	showHints = "Hints",
	citizenBarks = "Citizen chatter",
	jobGlyphs = "Job icons over citizens",
	notifications = "Notifications",
})

SettingsModel.OPTION_LABEL = table.freeze({
	full = "Full",
	reduced = "Reduced",
	all = "All",
	important = "Important only",
})

local function valueOf(key: string, values: { [string]: any }?): any
	local ok, value = Schema.checkSetting(key, if values then values[key] else nil)
	return if ok then value else Schema.SETTINGS[key].default
end

local function round(x: number): number
	local perUnit = math.floor(1 / SettingsModel.STEP + 0.5) -- 10: 0.7 stays 7 / 10, not 7 × 0.1
	return math.clamp(math.floor(x * perUnit + 0.5) / perUnit, 0, 1)
end

local function row(key: string, value: any, opts: { [string]: any }): { [string]: any }
	local spec = Schema.SETTINGS[key]
	local out: { [string]: any } =
		{ key = key, label = SettingsModel.LABEL[key] or key, kind = spec.kind, value = value }
	if spec.kind == "volume" then
		out.progress = value
		out.text = `{math.floor(value * 100 + 0.5)}%`
		out.canDown = value > 0
		out.canUp = value < 1
	elseif spec.kind == "boolean" then
		out.text = if value then "On" else "Off"
		if key == "reducedMotion" and opts.platformReducedMotion and not value then
			out.note = "On in your device settings"
		end
	else
		out.text = SettingsModel.OPTION_LABEL[value] or tostring(value)
	end
	return out
end

function SettingsModel.sections(values: { [string]: any }?, opts: { [string]: any }?): { { [string]: any } }
	local out = {}
	for _, section in SettingsModel.SECTIONS do
		local rows = {}
		for _, key in section.keys do
			if Schema.SETTINGS[key] then
				table.insert(rows, row(key, valueOf(key, values), opts or {}))
			end
		end
		table.insert(out, { id = section.id, title = section.title, rows = rows })
	end
	return out
end

function SettingsModel.next(key: string, value: any, action: string): any
	local spec = Schema.SETTINGS[key]
	if spec == nil then
		return nil
	end
	local ok, current = Schema.checkSetting(key, value)
	if not ok then
		current = spec.default
	end
	local nextValue
	if spec.kind == "volume" and (action == "down" or action == "up") then
		nextValue = round(current + (if action == "up" then SettingsModel.STEP else -SettingsModel.STEP))
	elseif spec.kind == "boolean" and action == "toggle" then
		nextValue = not current
	elseif spec.kind == "enum" and action == "cycle" then
		local options = spec.options or {}
		local index = table.find(options, current) or 0
		nextValue = options[index % #options + 1]
	end
	if nextValue == nil or nextValue == current then
		return nil
	end
	return nextValue
end

return table.freeze(SettingsModel)
