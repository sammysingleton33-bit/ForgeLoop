--[[
	MockAnalyticsService — records AnalyticsService calls; can throw or behave like a no-op.

	Imitates: creator-docs content/en-us/reference/engine/classes/AnalyticsService.yaml
	  LogCustomEvent(player, eventName, value?, customFields?)
	  LogEconomyEvent(player, flowType, currencyType, amount, endingBalance, transactionType, itemSku?, customFields?)
	  LogFunnelStepEvent(player, funnelName, funnelSessionId?, step?, stepName?, customFields?)
	  LogOnboardingFunnelStepEvent(player, step, stepName?, customFields?)
	  LogProgressionEvent(player, progressionPathName, status, level?, levelName?, customFields?)
	  LogProgressionStartEvent / LogProgressionCompleteEvent / LogProgressionFailEvent
	    (player, progressionPathName, level?, levelName?, customFields?)
	Every method requires a Player as its first argument (errors otherwise, like the engine would).
	Documented caps (event/field cardinality, custom-field keys) are NOT enforced yet: FORGE-05
	adds them on request (FL-0028); this mock only records.

	Modes (setMode):
		"record" (default)  every call is appended to `calls`
		"throw"             every call errors with `message` (analytics outage) — callers must isolate it
		"noop"              calls are accepted and dropped (e.g. Studio sessions where nothing is sent)
	Control API: MockAnalyticsService.new(), as:setMode(mode, message?), as.calls, as:callsTo(method)
]]

local MockAnalyticsService = {}
MockAnalyticsService.__index = MockAnalyticsService

local METHODS = {
	"LogCustomEvent",
	"LogEconomyEvent",
	"LogFunnelStepEvent",
	"LogOnboardingFunnelStepEvent",
	"LogProgressionEvent",
	"LogProgressionStartEvent",
	"LogProgressionCompleteEvent",
	"LogProgressionFailEvent",
}

function MockAnalyticsService.new()
	return setmetatable(
		{ calls = {}, _mode = "record", _message = "AnalyticsService unavailable [mock]" },
		MockAnalyticsService
	)
end

function MockAnalyticsService:setMode(mode: string, message: string?)
	assert(mode == "record" or mode == "throw" or mode == "noop", "mode must be record | throw | noop")
	self._mode = mode
	if message then
		self._message = message
	end
end

function MockAnalyticsService:callsTo(method: string)
	local out = {}
	for _, call in self.calls do
		if call.method == method then
			table.insert(out, call)
		end
	end
	return out
end

for _, method in METHODS do
	MockAnalyticsService[method] = function(self, player, ...)
		if typeof(player) ~= "Instance" or not player:IsA("Player") then
			error(`AnalyticsService:{method}: argument 1 must be a Player`, 2)
		end
		if self._mode == "throw" then
			error(self._message, 2)
		elseif self._mode == "noop" then
			return
		end
		table.insert(self.calls, { method = method, player = player, userId = player.UserId, args = table.pack(...) })
	end
end

return MockAnalyticsService
