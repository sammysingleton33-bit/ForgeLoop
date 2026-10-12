--!strict
--[[
	DebugPresetService — Studio debug presets for the VS-1 v2 playtest (CONTRACTS G13.7, D-030,
	FL-0093). Owned by FORGE-05.

	Registers commands with Debug/DebugCommands in start(). They can only be reached through
	Debug/DebugServer's remotes, which exist only in Studio (RunService:IsStudio()), so live servers
	never run them. Each command acts on the presser's own kingdom or reputation. It finds the owning
	service with registry:find when it runs and fails closed with a clear message when that service,
	or the debug hook it needs, does not exist yet. Arguments are validated fail-closed by
	DebugCommands (Validate.check).

		rep.set <category> <n>                   ReputationService:get / :apply (G13.4); sets the
		                                         presser's <category> to n (0-100)
		citizen.request <entityId> <scenarioId>  ConversationService:debugRequest (hook, FORGE-01);
		                                         entityId 0 / scenarioId "any" = the hook picks
		kingdom.setFed <ratio>                   CitizenService:setFedRatio(kingdom, ratio) (G5); lasts
		                                         until ProductionService's next upkeep tick
		strike.start <occupation>                ConsequenceService:debugStrike(kingdom, occupation, true) (hook)
		population.reseed <seed>                 PopulationService:debugReseed(kingdom, seed) (hook)

	Debug hooks requested from FORGE-01 (handoff 2026-10-12 forge-05-to-forge-01-debug-hooks), each
	`(self, kingdom: KingdomId, ...) -> (ok: boolean, message: string?)`. The service named first is
	tried first; CitizenService is the fallback home for each hook.

	Presets (STUDIO_PLAYTEST rows 4, 5, 8 and 9; the panel can only run commands without arguments,
	so every user step uses a preset):
		vs1.reseed    population from seed 1234     vs1.request  any citizen raises any eligible request
		vs1.repLow    compassion 10, fear 80        vs1.repHigh  compassion 90, honor 90
		vs1.hungry    kingdom fed ratio 0.3         vs1.strike   farmers strike
]]

local DebugCommands = require("@game/ReplicatedStorage/Forge/Debug/DebugCommands")
local Validate = require("@game/ReplicatedStorage/Forge/Core/Validate")

local DebugPresetService = {}
DebugPresetService.__index = DebugPresetService

local Def = { name = "DebugPresetService", dependencies = {} }

Def.CATEGORIES = table.freeze({ "compassion", "honor", "competence", "courage", "authority", "fear" })

-- { command, services to try in order, hook method }
local HOOKS = table.freeze({
	request = { { "ConversationService", "CitizenService" }, "debugRequest" },
	strike = { { "ConsequenceService", "CitizenService" }, "debugStrike" },
	reseed = { { "PopulationService", "CitizenService" }, "debugReseed" },
})

local function fail(message: string): never
	error(message, 0)
end

function Def.new(env: any, registry: any)
	return setmetatable({ _env = env, _registry = registry, registered = {} :: { string } }, DebugPresetService)
end

function DebugPresetService:_kingdomOf(player: any): string
	local kingdoms = self._registry:find("KingdomService")
	if kingdoms == nil then
		fail("KingdomService is not running yet (FORGE-01, G3)")
	end
	local kingdom = kingdoms:getKingdomOf(player)
	if kingdom == nil then
		fail("you are not in a kingdom yet")
	end
	return kingdom
end

-- Runs a FORGE-01 debug hook: the first listed service that has the method wins.
function DebugPresetService:_hook(key: string, ...: any): string
	local spec = HOOKS[key]
	local names, method = spec[1], spec[2]
	for _, name in names do
		local service = self._registry:find(name)
		if service ~= nil and type(service[method]) == "function" then
			local ok, message = service[method](service, ...)
			if ok ~= true then
				fail(`{name}:{method} refused: {tostring(message or "no reason given")}`)
			end
			return if type(message) == "string" then message else `{name}:{method} done`
		end
	end
	fail(`no {method} hook yet (looked in {table.concat(names, ", ")}; requested from FORGE-01)`)
end

local function register(self: any, command: any)
	for _, entry in DebugCommands.list() do
		if entry.name == command.name then
			return -- a second boot in the same process (specs) keeps the first registration
		end
	end
	DebugCommands.register(command)
	table.insert(self.registered, command.name)
end

local function registerPreset(preset: any)
	for _, entry in DebugCommands.presets() do
		if entry.name == preset.name then
			return
		end
	end
	DebugCommands.registerPreset(preset)
end

function DebugPresetService:start()
	register(self, {
		name = "rep.set",
		label = "Set one of your reputation values (category, 0-100)",
		args = { Validate.enum(Def.CATEGORIES), Validate.integer(0, 100) },
		run = function(player: any, category: string, value: number)
			local reputation = self._registry:find("ReputationService")
			if reputation == nil then
				fail("ReputationService is not running yet (FORGE-01, G13.4)")
			end
			local before = reputation:get(player.UserId)
			local current = before and before.values and before.values[category]
			if type(current) ~= "number" then
				fail(`ReputationService:get has no '{category}' value for you`)
			end
			reputation:apply(
				player.UserId,
				"debug",
				{ [category] = value - current },
				`Studio debug: {category} set to {value}`
			)
			local after = reputation:get(player.UserId).values[category]
			return `{category} {current} -> {after}`
		end,
	})
	register(self, {
		name = "citizen.request",
		label = "Make a citizen of your kingdom raise a request (entityId, scenarioId)",
		args = { Validate.integer(0, 65535), Validate.string(1, 48) },
		run = function(player: any, entityId: number, scenarioId: string)
			return self:_hook("request", self:_kingdomOf(player), entityId, scenarioId)
		end,
	})
	register(self, {
		name = "kingdom.setFed",
		label = "Set your kingdom's fed ratio (0-1) until the next upkeep tick",
		args = { Validate.number(0, 1) },
		run = function(player: any, ratio: number)
			local kingdom = self:_kingdomOf(player)
			local citizens = self._registry:find("CitizenService")
			if citizens == nil then
				fail("CitizenService is not running yet (FORGE-01, G5)")
			end
			citizens:setFedRatio(kingdom, ratio)
			return `{kingdom} fed ratio {ratio} (ProductionService resets it at its next upkeep tick)`
		end,
	})
	register(self, {
		name = "strike.start",
		label = "Start a strike of one occupation in your kingdom",
		args = { Validate.string(1, 32) },
		run = function(player: any, occupation: string)
			return self:_hook("strike", self:_kingdomOf(player), occupation, true)
		end,
	})
	register(self, {
		name = "population.reseed",
		label = "Regenerate your kingdom's citizens from a seed",
		args = { Validate.integer(0, 2147483647) },
		run = function(player: any, seed: number)
			return self:_hook("reseed", self:_kingdomOf(player), seed)
		end,
	})

	registerPreset({
		name = "vs1.reseed",
		label = "Row 4: regenerate your citizens from seed 1234",
		steps = { { "population.reseed", 1234 } },
	})
	registerPreset({
		name = "vs1.request",
		label = "Row 9: a citizen raises a request now",
		steps = { { "citizen.request", 0, "any" } },
	})
	registerPreset({
		name = "vs1.repLow",
		label = "Row 8: low compassion, high fear",
		steps = {
			{ "rep.set", "compassion", 10 },
			{ "rep.set", "fear", 80 },
		},
	})
	registerPreset({
		name = "vs1.repHigh",
		label = "Row 8: high compassion and honor",
		steps = {
			{ "rep.set", "compassion", 90 },
			{ "rep.set", "honor", 90 },
		},
	})
	registerPreset({
		name = "vs1.hungry",
		label = "Row 9: kingdom fed ratio 0.3",
		steps = { { "kingdom.setFed", 0.3 } },
	})
	registerPreset({
		name = "vs1.strike",
		label = "Row 9: the farmers strike",
		steps = { { "strike.start", "farmer" } },
	})
end

return Def
