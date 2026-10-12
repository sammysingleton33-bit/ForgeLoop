--!strict
--[[
	PacingService (FORGE-04, game-001) — owns AI Kingdoms' phase lengths (CONTRACTS G11).

		PacingService:phaseDurations(mode: "slice" | "match")
			-> { Lobby: number, Founding: number, Expansion: number, Conflict: number, Endgame: number, Results: number }
			Seconds per MatchPhase from config Pacing.luau; math.huge = untimed. Returns a fresh table.
		PacingService:targets() -> { firstGatherSec, firstBuildPlacedSec, ... }   -- VS-1 milestone goals (copy)
		Def.validate(config) -> { string }                                        -- problems; empty = valid
		Def.DEFAULTS                                                              -- used when the config is invalid

	Pull only: MatchService finds PacingService with registry:find in its start() and asks for the
	durations (CONTRACTS G3). PacingService never calls MatchService and has no dependencies, so it
	can never block the match: an invalid config is logged as an error and the built-in DEFAULTS
	(the BRIEF §3 numbers and the G3 slice rules) are served instead.
	Design and targets: games/game-001/design/pacing/PACING.md.
]]

local PacingConfig = require("@game/ReplicatedStorage/Forge/Config/Pacing")

local PacingService = {}
PacingService.__index = PacingService

local Def = { name = "PacingService", dependencies = {} }

Def.PHASES = table.freeze({ "Lobby", "Founding", "Expansion", "Conflict", "Endgame", "Results" })
Def.MODES = table.freeze({ "slice", "match" })
local TIMED = { "Founding", "Expansion", "Conflict", "Endgame" }
local TARGET_ORDER =
	{ "firstGatherSec", "firstBuildPlacedSec", "firstBuildingCompleteSec", "firstRecruitSec", "firstCaptureSec" }

Def.DEFAULTS = table.freeze({
	modes = table.freeze({
		slice = table.freeze({
			Lobby = 0,
			Founding = math.huge,
			Expansion = math.huge,
			Conflict = math.huge,
			Endgame = math.huge,
			Results = math.huge,
		}),
		match = table.freeze({
			Lobby = 20,
			Founding = 480,
			Expansion = 720,
			Conflict = 900,
			Endgame = 600,
			Results = 30,
		}),
	}),
	targets = table.freeze({
		firstGatherSec = 45,
		firstBuildPlacedSec = 90,
		firstBuildingCompleteSec = 150,
		firstRecruitSec = 330,
		firstCaptureSec = 450,
	}),
	limits = table.freeze({ matchMinMinutes = 30, matchMaxMinutes = 45 }),
})

local function seconds(value: any): boolean
	return type(value) == "number" and value == value and value >= 0
end

function Def.validate(config: any): { string }
	local problems: { string } = {}
	if type(config) ~= "table" or type(config.modes) ~= "table" then
		return { "Pacing: config.modes missing" }
	end
	for _, mode in Def.MODES do
		local durations = config.modes[mode]
		if type(durations) ~= "table" then
			table.insert(problems, `Pacing: modes.{mode} missing`)
			continue
		end
		for _, phase in Def.PHASES do
			if not seconds(durations[phase]) then
				table.insert(problems, `Pacing: modes.{mode}.{phase} must be seconds >= 0 (math.huge = untimed)`)
			end
		end
		for key in durations do
			if not table.find(Def.PHASES, key) then
				table.insert(problems, `Pacing: modes.{mode}.{tostring(key)} is not a MatchPhase`)
			end
		end
	end
	local slice, match = config.modes.slice, config.modes.match
	if type(slice) == "table" then
		if slice.Lobby ~= 0 then
			table.insert(problems, "Pacing: slice Lobby must be 0 s (CONTRACTS G3 interim rules)")
		end
		if slice.Founding ~= math.huge then
			table.insert(
				problems,
				"Pacing: slice Founding must be untimed (math.huge); the first capture ends the slice"
			)
		end
	end
	if type(match) == "table" then
		local total = 0
		for _, phase in TIMED do
			local value = match[phase]
			if not seconds(value) or value == math.huge or value <= 0 then
				table.insert(problems, `Pacing: match {phase} must be a positive finite number of seconds`)
			else
				total += value
			end
		end
		local limits = if type(config.limits) == "table" then config.limits else Def.DEFAULTS.limits
		local minutes = total / 60
		if minutes < limits.matchMinMinutes or minutes > limits.matchMaxMinutes then
			table.insert(
				problems,
				`Pacing: match Founding..Endgame lasts {minutes} min; target {limits.matchMinMinutes}-{limits.matchMaxMinutes} min`
			)
		end
		if not seconds(match.Results) or match.Results == math.huge or match.Results <= 0 then
			table.insert(problems, "Pacing: match Results must be a positive finite number of seconds")
		end
		if not seconds(match.Lobby) or match.Lobby == math.huge then
			table.insert(problems, "Pacing: match Lobby (countdown) must be finite")
		end
	end
	if config.targets ~= nil then
		local previous = 0
		for _, key in TARGET_ORDER do
			local value = config.targets[key]
			if type(value) ~= "number" or value <= previous then
				table.insert(problems, `Pacing: targets.{key} must be a number after the previous milestone`)
			else
				previous = value
			end
		end
	end
	return problems
end

function Def.create(env: any, _registry: any, options: { config: any? }?)
	local config = if options and options.config ~= nil then options.config else PacingConfig
	local problems = Def.validate(config)
	if #problems > 0 then
		env.log("error", "Pacing config invalid; using built-in defaults", { problems = table.concat(problems, "; ") })
		config = Def.DEFAULTS
	end
	return setmetatable({ _env = env, _config = config, valid = #problems == 0 }, PacingService)
end

function Def.new(env: any, registry: any)
	return Def.create(env, registry, nil)
end

function PacingService:phaseDurations(mode: string): { [string]: number }
	local durations = self._config.modes[mode]
	if durations == nil or not table.find(Def.MODES, mode) then
		error(`PacingService:phaseDurations: mode must be "slice" or "match", got {tostring(mode)}`, 2)
	end
	local out = {}
	for _, phase in Def.PHASES do
		out[phase] = durations[phase]
	end
	return out
end

function PacingService:targets(): { [string]: number }
	return table.clone(self._config.targets or Def.DEFAULTS.targets)
end

return Def
