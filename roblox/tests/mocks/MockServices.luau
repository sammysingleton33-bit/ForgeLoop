--[[
	MockServices — small stand-ins used by MockEnv: RunService, HttpService and "unmocked" guards.

	RunService imitates creator-docs content/en-us/reference/engine/classes/RunService.yaml:
		IsServer(), IsClient(), IsStudio(), IsRunning(); Heartbeat/Stepped/PreSimulation/PostSimulation
		signals (fire them from a spec with :Fire(dt)).
	HttpService imitates content/en-us/reference/engine/classes/HttpService.yaml:
		GenerateGUID(wrapInCurlyBraces = true) — deterministic per MockEnv ("{00000000-0000-4000-8000-000000000001}");
		JSONEncode / JSONDecode (via @lune/serde).
	MockServices.unmocked(name): a placeholder whose every member access errors with a clear
		message, so code may hold the reference but a spec fails loudly if it is used.
]]

local serde = require("@lune/serde")

local MockSignal = require("./MockSignal")

local MockServices = {}

function MockServices.runService(options: { isServer: boolean, isStudio: boolean?, spawn: ((...any) -> ())? })
	local spawn = options.spawn
	local rs = {
		Heartbeat = MockSignal.new({ spawn = spawn, name = "RunService.Heartbeat" }),
		Stepped = MockSignal.new({ spawn = spawn, name = "RunService.Stepped" }),
		PreSimulation = MockSignal.new({ spawn = spawn, name = "RunService.PreSimulation" }),
		PostSimulation = MockSignal.new({ spawn = spawn, name = "RunService.PostSimulation" }),
	}
	function rs:IsServer(): boolean
		return options.isServer
	end
	function rs:IsClient(): boolean
		return not options.isServer
	end
	function rs:IsStudio(): boolean
		return options.isStudio == true
	end
	function rs:IsRunning(): boolean
		return true
	end
	return rs
end

function MockServices.httpService()
	local counter = 0
	local hs = {}
	function hs:GenerateGUID(wrapInCurlyBraces: boolean?): string
		counter += 1
		local guid = string.format("00000000-0000-4000-8000-%012x", counter)
		if wrapInCurlyBraces == false then
			return guid
		end
		return "{" .. guid .. "}"
	end
	function hs:JSONEncode(value: any): string
		return serde.encode("json", value)
	end
	function hs:JSONDecode(json: string): any
		return serde.decode("json", json)
	end
	return hs
end

function MockServices.unmocked(name: string)
	return setmetatable({}, {
		__index = function(_, key)
			error(
				`MockEnv: {name} is not mocked (tried {name}.{tostring(key)}); pass `
					.. "MockEnv.new({ services = { "
					.. name
					.. " = ... } }) or request a mock from FORGE-05 by handoff",
				2
			)
		end,
		__tostring = function()
			return `<unmocked {name}>`
		end,
	})
end

return MockServices
