--!strict
--[[
	Debug/DebugCommands — the Studio debug panel's command registry (FL-0068, D-028). Owned by FORGE-05.

	Every owner registers its own commands and presets from its own service, so nobody edits another
	worker's file. Registering is harmless outside Studio: the commands are only reachable through
	the ForgeDebug remotes, which Debug/DebugServer creates only when RunService:IsStudio() is true.

		local DebugCommands = require("@game/ReplicatedStorage/Forge/Debug/DebugCommands")
		local Validate = require("@game/ReplicatedStorage/Forge/Core/Validate")
		-- in your service's start():
		DebugCommands.register({
			name = "economy.grant",                     -- "<area>.<action>", unique
			label = "Grant 500 of each resource",
			args = { Validate.integer(0, 100000) },     -- validators, fail closed (Validate.check)
			run = function(player, amount)              -- server side; return a short message
				treasury:deposit(...)
				return `granted {amount}`
			end,
		})
		DebugCommands.registerPreset({
			name = "vs1.row6",
			label = "Row 6: rich kingdom, plot ready",
			steps = { { "economy.grant", 500 }, { "build.clearPlots" } },
		})

	API
		DebugCommands.register(command)        errors on a bad or duplicate definition (boot-time mistake)
		DebugCommands.registerPreset(preset)   steps name commands; checked when the preset runs
		DebugCommands.list() -> { { name, label, area, argCount } }       sorted by name
		DebugCommands.presets() -> { { name, label, steps: number } }     sorted by name
		DebugCommands.run(player, name, ...) -> (ok: boolean, message: string)
			validates the arguments (Validate.check: at most #args, each validator must return
			exactly true), runs the command under pcall; never throws
		DebugCommands.runPreset(player, name) -> (ok, message)   runs the steps in order, stops at
			the first failure
		DebugCommands.reset()                  tests only: forget every command and preset
]]

local Validate = require("../Core/Validate")

export type Command = {
	name: string,
	label: string?,
	args: { (any) -> (boolean, string?) }?,
	run: (player: any, ...any) -> string?,
}

export type Preset = {
	name: string,
	label: string?,
	steps: { { any } },
}

local NAME_PATTERN = "^[%a][%w]*%.[%a][%w]*$"

local DebugCommands = {}

local commands: { [string]: Command } = {}
local presets: { [string]: Preset } = {}

local function checkName(kind: string, name: any)
	if type(name) ~= "string" or not string.match(name, NAME_PATTERN) then
		error(`DebugCommands.{kind}: name must look like "area.action" (got {tostring(name)})`, 3)
	end
end

function DebugCommands.register(command: Command)
	if type(command) ~= "table" then
		error("DebugCommands.register: expected a command table", 2)
	end
	checkName("register", command.name)
	if commands[command.name] then
		error(`DebugCommands.register: '{command.name}' is already registered`, 2)
	end
	if type(command.run) ~= "function" then
		error(`DebugCommands.register: '{command.name}' needs a run(player, ...) function`, 2)
	end
	if command.args ~= nil then
		if type(command.args) ~= "table" then
			error(`DebugCommands.register: '{command.name}' args must be a list of validators`, 2)
		end
		for _, validator in command.args do
			if type(validator) ~= "function" then
				error(`DebugCommands.register: '{command.name}' args must be a list of validators`, 2)
			end
		end
	end
	commands[command.name] = command
end

function DebugCommands.registerPreset(preset: Preset)
	if type(preset) ~= "table" then
		error("DebugCommands.registerPreset: expected a preset table", 2)
	end
	checkName("registerPreset", preset.name)
	if presets[preset.name] then
		error(`DebugCommands.registerPreset: '{preset.name}' is already registered`, 2)
	end
	if type(preset.steps) ~= "table" or #preset.steps == 0 then
		error(`DebugCommands.registerPreset: '{preset.name}' needs a non-empty list of steps`, 2)
	end
	for i, step in preset.steps do
		if type(step) ~= "table" or type(step[1]) ~= "string" then
			error(`DebugCommands.registerPreset: '{preset.name}' step {i} must be \{ "command.name", args... \}`, 2)
		end
	end
	presets[preset.name] = preset
end

function DebugCommands.list(): { { name: string, label: string, area: string, argCount: number } }
	local out = {}
	for name, command in commands do
		table.insert(out, {
			name = name,
			label = command.label or name,
			area = string.match(name, "^(%a[%w]*)%.") :: string,
			argCount = if command.args then #command.args else 0,
		})
	end
	table.sort(out, function(a, b)
		return a.name < b.name
	end)
	return out
end

function DebugCommands.presets(): { { name: string, label: string, steps: number } }
	local out = {}
	for name, preset in presets do
		table.insert(out, { name = name, label = preset.label or name, steps = #preset.steps })
	end
	table.sort(out, function(a, b)
		return a.name < b.name
	end)
	return out
end

function DebugCommands.run(player: any, name: any, ...: any): (boolean, string)
	if type(name) ~= "string" then
		return false, "command name must be a string"
	end
	local command = commands[name]
	if command == nil then
		return false, `unknown command '{name}'`
	end
	local ok, why = Validate.check(command.args or {}, ...)
	if ok ~= true then
		return false, `{name}: {why or "invalid arguments"}`
	end
	local ran, message = pcall(command.run, player, ...)
	if not ran then
		return false, `{name} failed: {tostring(message)}`
	end
	return true, if type(message) == "string" then message else `{name}: done`
end

function DebugCommands.runPreset(player: any, name: any): (boolean, string)
	if type(name) ~= "string" then
		return false, "preset name must be a string"
	end
	local preset = presets[name]
	if preset == nil then
		return false, `unknown preset '{name}'`
	end
	local messages = {}
	for i, step in preset.steps do
		local ok, message = DebugCommands.run(player, table.unpack(step))
		if not ok then
			return false, `{name} step {i}: {message}`
		end
		table.insert(messages, message)
	end
	return true, `{name}: {table.concat(messages, "; ")}`
end

function DebugCommands.reset()
	table.clear(commands)
	table.clear(presets)
end

return DebugCommands
