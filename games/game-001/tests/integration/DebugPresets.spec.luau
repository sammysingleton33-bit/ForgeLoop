-- G13.7 Studio debug presets (FL-0093, FORGE-05): DebugPresetService registers the commands and
-- presets; each one works against the contract APIs and fails closed when a service, a hook, the
-- presser's kingdom or a valid argument is missing.
local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect, beforeEach = T.describe, T.it, T.expect, T.beforeEach

local MockEnv = require("../../../../roblox/tests/mocks/MockEnv")
local DebugCommands = require("@game/ReplicatedStorage/Forge/Debug/DebugCommands")
local Loader = require("@game/ReplicatedStorage/Forge/Contracts/Loader")
local Def = require("@game/ServerScriptService/Game/Services/DebugPresetService")

local PLAYER = { UserId = 7, Name = "Ruler" }

-- Doubles for FORGE-01's services, shaped as CONTRACTS G3, G5 and G13.4; `calls` records every use.
local function doubles(calls: { any }, withHooks: boolean)
	local values = { compassion = 50, honor = 50, competence = 50, courage = 50, authority = 50, fear = 50 }
	local services = {
		KingdomService = {
			getKingdomOf = function(_, player)
				return if player == PLAYER then "azure" else nil
			end,
		},
		ReputationService = {
			get = function(_, userId)
				assert(userId == 7, "wrong userId")
				return { values = table.clone(values), history = {} }
			end,
			apply = function(_, userId, source, delta, text)
				table.insert(calls, { "apply", userId, source, delta, text })
				for category, d in delta do
					values[category] = math.clamp(values[category] + d, 0, 100)
				end
			end,
		},
		CitizenService = {
			setFedRatio = function(_, kingdom, ratio)
				table.insert(calls, { "setFedRatio", kingdom, ratio })
			end,
		},
	}
	if withHooks then
		services.ConversationService = {
			debugRequest = function(_, kingdom, entityId, scenarioId)
				table.insert(calls, { "debugRequest", kingdom, entityId, scenarioId })
				return true, `citizen {entityId} asks '{scenarioId}'`
			end,
		}
		services.ConsequenceService = {
			debugStrike = function(_, kingdom, occupation, on)
				table.insert(calls, { "debugStrike", kingdom, occupation, on })
				return occupation == "farmer", if occupation == "farmer" then nil else "unknown occupation"
			end,
		}
		services.CitizenService.debugReseed = function(_, kingdom, seed)
			table.insert(calls, { "debugReseed", kingdom, seed })
			return true, `{kingdom} reseeded with {seed}`
		end
	end
	return services
end

local function boot(services: { [string]: any }?)
	local env = MockEnv.new({ studio = true })
	local definitions = { Def }
	for name, double in services or {} do
		table.insert(definitions, {
			name = name,
			new = function()
				return double
			end,
		})
	end
	local registry = Loader.load(env, definitions)
	return registry:get("DebugPresetService"), registry
end

local function run(...)
	return DebugCommands.run(PLAYER, ...)
end

describe("DebugPresetService (CONTRACTS G13.7)", function()
	beforeEach(function()
		DebugCommands.reset()
	end)

	it("registers the five G13.7 commands and the six row presets once", function()
		boot()
		boot() -- a second boot in the same process must not error or duplicate
		local names = {}
		for _, command in DebugCommands.list() do
			table.insert(names, command.name)
		end
		expect(names).toEqual({ "citizen.request", "kingdom.setFed", "population.reseed", "rep.set", "strike.start" })
		local presets = {}
		for _, preset in DebugCommands.presets() do
			table.insert(presets, preset.name)
		end
		expect(presets).toEqual({ "vs1.hungry", "vs1.repHigh", "vs1.repLow", "vs1.request", "vs1.reseed", "vs1.strike" })
	end)

	it("runs every command against the contract APIs when the services exist", function()
		local calls = {}
		boot(doubles(calls, true))
		expect({ run("rep.set", "fear", 80) }).toEqual({ true, "fear 50 -> 80" })
		expect({ run("kingdom.setFed", 0.3) }).toEqual({
			true,
			"azure fed ratio 0.3 (ProductionService resets it at its next upkeep tick)",
		})
		expect({ run("citizen.request", 12, "granary_low") }).toEqual({ true, "citizen 12 asks 'granary_low'" })
		expect({ run("strike.start", "farmer") }).toEqual({ true, "ConsequenceService:debugStrike done" })
		expect({ run("population.reseed", 42) }).toEqual({ true, "azure reseeded with 42" })
		expect(calls).toEqual({
			{ "apply", 7, "debug", { fear = 30 }, "Studio debug: fear set to 80" },
			{ "setFedRatio", "azure", 0.3 },
			{ "debugRequest", "azure", 12, "granary_low" },
			{ "debugStrike", "azure", "farmer", true },
			{ "debugReseed", "azure", 42 },
		})
	end)

	it("runs the row presets in order", function()
		local calls = {}
		boot(doubles(calls, true))
		expect({ DebugCommands.runPreset(PLAYER, "vs1.repLow") }).toEqual({
			true,
			"vs1.repLow: compassion 50 -> 10; fear 50 -> 80",
		})
		expect((DebugCommands.runPreset(PLAYER, "vs1.hungry"))).toBe(true)
		expect((DebugCommands.runPreset(PLAYER, "vs1.strike"))).toBe(true)
		expect((DebugCommands.runPreset(PLAYER, "vs1.repHigh"))).toBe(true)
		expect({ DebugCommands.runPreset(PLAYER, "vs1.request") }).toEqual({
			true,
			"vs1.request: citizen 0 asks 'any'",
		})
		expect((DebugCommands.runPreset(PLAYER, "vs1.reseed"))).toBe(true)
	end)

	it("fails closed on bad arguments (negative test per command)", function()
		local calls = {}
		boot(doubles(calls, true))
		local bad = {
			{ "rep.set", "kindness", 50 }, -- unknown category
			{ "rep.set", "fear", 101 }, -- out of range
			{ "rep.set", "fear", 0.5 }, -- not an integer
			{ "citizen.request", -1, "x" }, -- negative entity id
			{ "citizen.request", 12, "" }, -- empty scenario id
			{ "citizen.request", 12, string.rep("s", 49) }, -- scenario id too long
			{ "kingdom.setFed", 1.5 },
			{ "kingdom.setFed", 0 / 0 },
			{ "strike.start", "" },
			{ "strike.start", 5 },
			{ "population.reseed", -1 },
			{ "population.reseed", 1, 2 }, -- extra argument
		}
		for _, args in bad do
			local ok = run(table.unpack(args))
			if ok ~= false then
				error(`accepted bad arguments: {table.concat(args :: any, ", ")}`)
			end
		end
		expect(calls).toEqual({}) -- nothing reached a service
	end)

	it("fails closed when the services or hooks are not there yet", function()
		boot() -- no FORGE-01 services at all (main today)
		local ok, why = run("rep.set", "fear", 80)
		expect(ok).toBe(false)
		expect(why).toContain("ReputationService is not running yet")
		ok, why = run("kingdom.setFed", 0.3)
		expect(ok).toBe(false)
		expect(why).toContain("KingdomService is not running yet")

		DebugCommands.reset()
		local calls = {}
		boot(doubles(calls, false)) -- services exist, debug hooks do not
		ok, why = run("citizen.request", 12, "granary_low")
		expect(ok).toBe(false)
		expect(why).toContain("no debugRequest hook yet")
		ok, why = run("strike.start", "farmer")
		expect(why).toContain("no debugStrike hook yet")
		ok, why = run("population.reseed", 42)
		expect(why).toContain("no debugReseed hook yet")
	end)

	it("refuses a presser without a kingdom and reports a refused hook", function()
		local calls = {}
		boot(doubles(calls, true))
		local ok, why = DebugCommands.run({ UserId = 9 }, "kingdom.setFed", 0.3)
		expect(ok).toBe(false)
		expect(why).toContain("you are not in a kingdom yet")
		ok, why = run("strike.start", "miner")
		expect(ok).toBe(false)
		expect(why).toContain("ConsequenceService:debugStrike refused: unknown occupation")
		expect(#calls).toBe(1) -- only the refused strike reached a service
	end)
end)
