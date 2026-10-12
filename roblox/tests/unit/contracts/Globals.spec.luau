-- The globals the harness gives modules under test (roblox/tests/harness/Globals.luau) and the
-- harness's own path helpers. Keep "Random is the spec file's MockRandom" the FIRST test: it checks
-- the unseeded stream of a fresh spec file.
local T = require("../../harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local MockEnv = require("../../mocks/MockEnv")
local MockRandom = require("../../mocks/MockRandom")
local Path = require("../../harness/Path")

describe("harness globals", function()
	it("Random is the spec file's MockRandom (one identity, fresh unseeded stream per spec file)", function()
		expect(rawequal(Random, MockRandom)).toBe(true)
		local env = MockEnv.new()
		expect(getmetatable(Random.new(1))).toBe(getmetatable(env.random(1)))
		-- unseeded generators count 1, 2, 3, ... from the start of each spec file
		expect(Random.new():NextInteger(1, 1e9)).toBe(MockRandom.new(1):NextInteger(1, 1e9))
	end)

	it("TweenInfo.new applies the documented defaults and is read-only", function()
		local info = TweenInfo.new()
		expect(info.Time).toBe(1)
		expect(info.EasingStyle).toBe(Enum.EasingStyle.Quad)
		expect(info.EasingDirection).toBe(Enum.EasingDirection.Out)
		expect(info.RepeatCount).toBe(0)
		expect(info.Reverses).toBe(false)
		expect(info.DelayTime).toBe(0)
		local custom = TweenInfo.new(0.25, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1, true, 2)
		expect(custom.Time).toBe(0.25)
		expect(custom.RepeatCount).toBe(-1)
		expect(custom.Reverses).toBe(true)
		expect(function()
			(info :: any).Time = 3
		end).toThrow("read-only")
		expect(function()
			return (info :: any).Speed
		end).toThrow("Speed is not a valid member of TweenInfo")
	end)

	it("RaycastParams / OverlapParams are property bags with documented members", function()
		local env = MockEnv.new()
		local part = env.newInstance("Part")
		local ray = RaycastParams.new()
		expect(ray.FilterType).toBe(Enum.RaycastFilterType.Exclude)
		expect(ray.FilterDescendantsInstances).toEqual({})
		expect(ray.IgnoreWater).toBe(false)
		expect(ray.CollisionGroup).toBe("Default")
		ray.FilterType = Enum.RaycastFilterType.Include
		ray:AddToFilter(part)
		expect(ray.FilterDescendantsInstances[1]).toBe(part)
		expect(ray.IncludeInstances).toBeNil()
		expect(function()
			(ray :: any).Range = 5
		end).toThrow("Range is not a valid member of RaycastParams")
		local overlap = OverlapParams.new()
		expect(overlap.MaxParts).toBe(0)
		overlap:AddToFilter({ part })
		expect(#overlap.FilterDescendantsInstances).toBe(1)
	end)

	it("DateTime converts UTC timestamps; now() points at env.now()", function()
		local t = DateTime.fromUnixTimestamp(1700000000)
		expect(t.UnixTimestamp).toBe(1700000000)
		expect(t.UnixTimestampMillis).toBe(1700000000000)
		expect(t:ToIsoDate()).toBe("2023-11-14T22:13:20Z")
		expect(t:ToUniversalTime()).toEqual({
			Year = 2023,
			Month = 11,
			Day = 14,
			Hour = 22,
			Minute = 13,
			Second = 20,
			Millisecond = 0,
		})
		local parsed = DateTime.fromIsoDate("2020-01-02T10:30:45Z")
		expect(parsed:ToIsoDate()).toBe("2020-01-02T10:30:45Z")
		expect(DateTime.fromUniversalTime(2020, 1, 2, 10, 30, 45).UnixTimestamp).toBe(parsed.UnixTimestamp)
		expect(DateTime.fromUniversalTime(2024, 2, 29).UnixTimestamp).toBe(1709164800)
		expect(DateTime.fromUnixTimestampMillis(-1):ToIsoDate()).toBe("1969-12-31T23:59:59.999Z")
		expect(DateTime.fromIsoDate("not a date")).toBeNil()
		expect(function()
			local _ = DateTime.fromUniversalTime(2023, 2, 29)
		end).toThrow("invalid date")
		expect(function()
			local _ = DateTime.now()
		end).toThrow("env.now()")
	end)

	it("game, workspace, script and plugin are blocked with a pointer to the Env", function()
		expect(function()
			return game.Players
		end).toThrow("use the injected Env")
		expect(function()
			return workspace.Gravity
		end).toThrow("use the injected Env")
	end)
end)

describe("harness Path", function()
	it("treats POSIX, drive and backslash drive paths as absolute", function()
		expect(Path.isAbsolute("/home/u/repo")).toBe(true)
		expect(Path.isAbsolute("C:/Users/u/ForgeLoop")).toBe(true)
		expect(Path.isAbsolute("C:\\Users\\u\\ForgeLoop\\roblox/tests/harness/run")).toBe(true)
		expect(Path.isAbsolute("roblox/tests/harness/run")).toBe(false)
	end)

	it("derives the repository root from a Windows-style Lune chunk name", function()
		-- Lune 0.11 names the entry chunk cwd (canonicalised, backslashes) + the relative script path.
		local source = "C:\\Users\\u\\ForgeLoop\\roblox/tests/harness/run"
		local resolved = if Path.isAbsolute(source) then source else Path.join("C:/elsewhere", source)
		expect(Path.normalize(Path.dirname(resolved) .. "/../../..")).toBe("C:/Users/u/ForgeLoop")
	end)
end)
