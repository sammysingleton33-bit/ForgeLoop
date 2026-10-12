--!strict
--[[
	Experience/AnalyticsRouter — rule helpers for the analytics track rules (AnalyticsService).
	Who an event is about comes from Experience/Subjects; this module only matches and extracts.

		Router.matches(rule, info) -> boolean          -- every rule.match entry equals info[key]
		Router.eventFields(rule, info) -> { [string]: any } -- rule.fields copied from info
		Router.knownEvents(bus) -> { string }          -- the bus's declared events (GameEvents.EVENT_NAMES)
]]

local Router = {}

function Router.matches(rule: any, info: { [string]: any }): boolean
	if rule.match == nil then
		return true
	end
	for key, expected in rule.match do
		if info[key] ~= expected then
			return false
		end
	end
	return true
end

function Router.eventFields(rule: any, info: { [string]: any }): { [string]: any }
	local out = {}
	for _, key in rule.fields or {} do
		out[key] = info[key]
	end
	return out
end

function Router.knownEvents(bus: any): { string }
	local names = {}
	for _, name in (if type(bus) == "table" and type(bus.EVENT_NAMES) == "table" then bus.EVENT_NAMES else {}) do
		table.insert(names, name)
	end
	return names
end

return table.freeze(Router)
