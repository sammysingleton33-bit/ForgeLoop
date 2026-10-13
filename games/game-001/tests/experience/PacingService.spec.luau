local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local MockEnv = require("../../../../roblox/tests/mocks/MockEnv")
local Loader = require("@game/ReplicatedStorage/Forge/Contracts/Loader")
local PacingConfig = require("@game/ReplicatedStorage/Forge/Config/Pacing")
local Def = require("@game/ServerScriptService/Game/Services/PacingService")

local function deepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local out = {}
	for k, v in value do
		out[k] = deepCopy(v)
	end
	return out
end

local function problemsOf(mutate)
	local config = deepCopy(PacingConfig)
	mutate(config)
	return table.concat(Def.validate(config), "\n")
end

local function boot(env, config)
	local registry = Loader.load(env, {
		{
			name = "PacingService",
			new = function(e, r)
				return Def.create(e, r, if config then { config = config } else nil)
			end,
		},
	})
	return registry:get("PacingService")
end

describe("PacingService (CONTRACTS G11)", function()
	it("ships a valid config", function()
		expect(Def.validate(PacingConfig)).toEqual({})
		expect(Def.validate(Def.DEFAULTS)).toEqual({})
	end)

	it("returns seconds for every MatchPhase in both modes", function()
		local pacing = boot(MockEnv.new())
		for _, mode in { "slice", "match" } do
			local durations = pacing:phaseDurations(mode)
			for _, phase in Def.PHASES do
				expect(type(durations[phase])).toBe("number")
			end
		end
	end)

	it("slice mode follows the interim VS-1 rules: Lobby 0 s, Founding untimed", function()
		local slice = boot(MockEnv.new()):phaseDurations("slice")
		expect(slice.Lobby).toBe(0)
		expect(slice.Founding).toBe(math.huge)
	end)

	it("match mode lasts 30-45 minutes from Founding to the end of Endgame (BRIEF §3)", function()
		local match = boot(MockEnv.new()):phaseDurations("match")
		local total = match.Founding + match.Expansion + match.Conflict + match.Endgame
		expect(total).toBeGreaterThanOrEqual(30 * 60)
		expect(total).toBeLessThanOrEqual(45 * 60)
		expect(match.Founding).toBe(8 * 60)
		expect(match.Founding + match.Expansion).toBe(20 * 60)
		expect(match.Founding + match.Expansion + match.Conflict).toBe(35 * 60)
	end)

	it("match30 is the ≈ 30-minute evaluation profile with the VS-2 Arena phase, and not the default", function()
		local pacing = boot(MockEnv.new())
		local d = pacing:phaseDurations("match30")
		expect(d.Lobby).toBe(20)
		expect(d.Founding + d.Expansion + d.Conflict + d.Endgame).toBe(25 * 60) -- kingdom play
		expect(d.Arena).toBe(270)
		expect(d.Results).toBe(30)
		local total = 0
		for _, seconds in d do
			total += seconds
		end
		expect(total).toBe(1820) -- 30 min 20 s with the countdown and results
		expect(pacing:phaseDurations("match").Arena).toBeNil() -- match has no Arena until VS-2
		expect(pacing:phaseDurations("slice").Arena).toBeNil()
	end)

	it("returns a fresh table each call (callers may change it)", function()
		local pacing = boot(MockEnv.new())
		local a = pacing:phaseDurations("match")
		a.Founding = 1
		expect(pacing:phaseDurations("match").Founding).toBe(8 * 60)
	end)

	it("rejects an unknown mode with a clear error", function()
		local pacing = boot(MockEnv.new())
		expect(function()
			pacing:phaseDurations("ranked")
		end).toThrow("mode must be one of slice, match, match30, got ranked")
	end)

	it("an invalid config never breaks the match: it logs an error and serves the defaults", function()
		local env = MockEnv.new()
		local broken = deepCopy(PacingConfig)
		broken.modes.match.Founding = -5
		local pacing = boot(env, broken)
		expect(env.mock:hasLog("error", "Pacing config invalid")).toBe(true)
		expect(pacing.valid).toBe(false)
		expect(pacing:phaseDurations("match").Founding).toBe(Def.DEFAULTS.modes.match.Founding)
	end)

	it("is pull-only: it has no dependencies and never touches the registry", function()
		expect(Def.dependencies).toEqual({})
		local touched = {}
		local spy = setmetatable({}, {
			__index = function(_, key)
				table.insert(touched, key)
				return function()
					return nil
				end
			end,
		})
		local pacing = Def.create(MockEnv.new(), spy, nil)
		pacing:phaseDurations("slice")
		pacing:targets()
		expect(touched).toEqual({})
	end)

	it("orders the VS-1 milestone targets: gather < build placed < complete < recruit < capture", function()
		local targets = boot(MockEnv.new()):targets()
		expect(targets.firstGatherSec).toBeLessThan(targets.firstBuildPlacedSec)
		expect(targets.firstBuildingCompleteSec).toBeLessThan(targets.firstRecruitSec)
		expect(targets.firstRecruitSec).toBeLessThan(targets.firstCaptureSec)
		expect(targets.firstCaptureSec).toBeLessThanOrEqual(10 * 60)
	end)

	it("validation catches each broken rule", function()
		expect(problemsOf(function(c)
			c.modes.slice.Lobby = 30
		end)).toContain("slice Lobby must be 0 s")
		expect(problemsOf(function(c)
			c.modes.slice.Founding = 600
		end)).toContain("slice Founding must be untimed")
		expect(problemsOf(function(c)
			c.modes.match.Endgame = 3600
		end)).toContain("target 30-45 min")
		expect(problemsOf(function(c)
			c.modes.match.Results = math.huge
		end)).toContain("match Results must be a positive finite")
		expect(problemsOf(function(c)
			c.modes.match.Siege = 10
		end)).toContain("modes.match.Siege is not a MatchPhase")
		expect(problemsOf(function(c)
			c.modes.match.Conflict = 0 / 0
		end)).toContain("modes.match.Conflict must be seconds")
		expect(problemsOf(function(c)
			c.targets.firstRecruitSec = 60
		end)).toContain("targets.firstRecruitSec must be a number after the previous milestone")
		expect(problemsOf(function(c)
			c.modes.slice = nil
		end)).toContain("modes.slice missing")
		expect(problemsOf(function(c)
			c.modes.match30.Arena = 40 * 60
		end)).toContain("match30 Founding..Arena lasts")
		expect(problemsOf(function(c)
			c.modes.match30.Arena = nil
		end)).toContain("match30 Arena must be a positive finite")
		expect(problemsOf(function(c)
			c.modes.match.Arena = 120
		end)).toContain("modes.match.Arena: later phases only in match30") -- Match.new would reject it
		expect(problemsOf(function(c)
			c.modes.slice.Arena = 0
		end)).toContain("modes.slice.Arena: later phases only in match30")
		expect(problemsOf(function(c)
			c.modes.match30.Arena = -1
		end)).toContain("modes.match30.Arena must be seconds")
	end)
end)
