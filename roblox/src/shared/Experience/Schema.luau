--!strict
--[[
	Experience/Schema — the composite `experience` profile namespace (interfaces §5, §8).

	SettingsService is the ONLY registrant of this namespace (DataService:registerNamespace in its
	new()). Onboarding, Quest and DailyReward services depend on SettingsService and change only
	their own sub-table through SettingsService:update(player, section, fn).

		experience = {
			settings     = { [key]: value }                  -- SETTINGS below
			onboarding   = { flows = { [flowId] = OnboardingProgress } }
			quests       = { progress = { [questId] = number }, completed = { [questId] = number (unix) } }
			achievements = { unlocked = { [achievementId] = number (unix) }, stats = { [statName] = number } }
			daily        = { streak = 0, lastClaimDay = -1, claimedTotal = 0, graceUsedDay = -1 }
		}
		OnboardingProgress = { version: number, completed: number, skipped: boolean,
		                       startedAt: number?, finishedAt: number?, satisfied: { [stepId]: true },
		                       earned: boolean? }   -- earned: a step was done by its real action (D-052 (3))

	Versioning: VERSION is the namespace version. To change the shape, add MIGRATIONS[k] (data at
	version k -> data at k + 1) and bump VERSION. DataService calls migrate(data, k) for
	k = stored .. VERSION - 1 (step-wise, §5). Unknown keys are preserved; normalize() repairs
	missing sections and invalid setting values with defaults (never throws).

	API
		Schema.NAMESPACE, Schema.VERSION, Schema.SETTINGS, Schema.SETTING_KEYS, Schema.SECTIONS
		Schema.defaults() -> data
		Schema.migrate(data, fromVersion) -> data           -- registered with DataService
		Schema.buildMigrate(migrations) -> migrate fn        -- same step-wise runner over any table
		Schema.normalize(data) -> data                       -- in place; returns data
		Schema.checkSetting(key, value) -> (ok, value?)     -- validated/clamped value
		Schema.spec() -> { version, defaults, migrate }     -- what SettingsService registers
]]

local Schema = {}

Schema.NAMESPACE = "experience"
Schema.VERSION = 1

export type SettingSpec = { kind: "volume" | "boolean" | "enum", default: any, options: { string }? }

Schema.SETTINGS = table.freeze({
	masterVolume = table.freeze({ kind = "volume", default = 1 }),
	musicVolume = table.freeze({ kind = "volume", default = 0.6 }),
	sfxVolume = table.freeze({ kind = "volume", default = 0.8 }),
	ambienceVolume = table.freeze({ kind = "volume", default = 0.7 }),
	uiVolume = table.freeze({ kind = "volume", default = 0.8 }),
	reducedMotion = table.freeze({ kind = "boolean", default = false }),
	cameraShake = table.freeze({ kind = "boolean", default = true }),
	showHints = table.freeze({ kind = "boolean", default = true }),
	citizenBarks = table.freeze({ kind = "boolean", default = true }),
	-- D-059 B22.4 prototype: a job icon over each citizen in the overview (game-001 CitizenGlyphController);
	-- off until the owner chooses between a closer start camera and job icons (FORGE-00, 22 Oct)
	jobGlyphs = table.freeze({ kind = "boolean", default = false }),
	notifications = table.freeze({ kind = "enum", default = "all", options = table.freeze({ "all", "important" }) }),
	-- FL-0103: "reduced" halves every effect's particles (VFXController), for slower devices
	effectsQuality = table.freeze({ kind = "enum", default = "full", options = table.freeze({ "full", "reduced" }) }),
} :: { [string]: SettingSpec })

local keys = {}
for key in Schema.SETTINGS do
	table.insert(keys, key)
end
table.sort(keys)
Schema.SETTING_KEYS = table.freeze(keys)

Schema.SECTIONS = table.freeze({ "settings", "onboarding", "quests", "achievements", "daily" })

local function settingsDefaults(): { [string]: any }
	local out = {}
	for key, spec in Schema.SETTINGS do
		out[key] = spec.default
	end
	return out
end

local SECTION_DEFAULTS: { [string]: () -> { [string]: any } } = {
	settings = settingsDefaults,
	onboarding = function()
		return { flows = {} }
	end,
	quests = function()
		return { progress = {}, completed = {} }
	end,
	achievements = function()
		return { unlocked = {}, stats = {} }
	end,
	daily = function()
		return { streak = 0, lastClaimDay = -1, claimedTotal = 0, graceUsedDay = -1 }
	end,
}

function Schema.defaults(): { [string]: any }
	local data = {}
	for _, section in Schema.SECTIONS do
		data[section] = SECTION_DEFAULTS[section]()
	end
	return data
end

function Schema.checkSetting(key: string, value: any): (boolean, any)
	local spec = Schema.SETTINGS[key]
	if spec == nil then
		return false, nil
	end
	if spec.kind == "volume" then
		if type(value) ~= "number" or value ~= value then
			return false, nil
		end
		return true, math.clamp(math.floor(value * 100 + 0.5) / 100, 0, 1)
	elseif spec.kind == "boolean" then
		if type(value) ~= "boolean" then
			return false, nil
		end
		return true, value
	end
	if type(value) ~= "string" or not table.find(spec.options or {}, value) then
		return false, nil
	end
	return true, value
end

function Schema.normalize(data: any): any
	if type(data) ~= "table" then
		return Schema.defaults()
	end
	for _, section in Schema.SECTIONS do
		local defaults = SECTION_DEFAULTS[section]()
		if type(data[section]) ~= "table" then
			data[section] = defaults
		else
			for key, value in defaults do
				if data[section][key] == nil then
					data[section][key] = value
				end
			end
		end
	end
	for key, spec in Schema.SETTINGS do
		local ok, value = Schema.checkSetting(key, data.settings[key])
		data.settings[key] = if ok then value else spec.default
	end
	return data
end

-- MIGRATIONS[k] takes data at version k and returns it at version k + 1. Version 1 is the first
-- shipped shape, so there is nothing to migrate yet; add entries here when the shape changes.
Schema.MIGRATIONS = table.freeze({} :: { [number]: (any) -> any })

function Schema.buildMigrate(migrations: { [number]: (any) -> any }): (any, number) -> any
	return function(data: any, fromVersion: number): any
		local step = migrations[fromVersion]
		if step == nil then
			error(`experience: no migration from version {fromVersion} to {fromVersion + 1}`, 2)
		end
		return step(data)
	end
end

Schema.migrate = Schema.buildMigrate(Schema.MIGRATIONS)

function Schema.spec(): { [string]: any }
	return {
		version = Schema.VERSION,
		defaults = Schema.defaults,
		migrate = Schema.migrate,
	}
end

return table.freeze(Schema)
