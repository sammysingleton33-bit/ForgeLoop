--!strict
--[[
	Experience/AnalyticsSchema — documented AnalyticsService caps and validation of a game's
	analytics config (games/<game>/config/Analytics.luau). Pure: no services, no clock.

	Caps (CAPS) come from Roblox creator-docs at commit af5f853 (2026-10-10), paths under
	content/en-us/: production/analytics/event-types.md (ET), reference/engine/classes/AnalyticsService.yaml
	(AS), production/analytics/custom-fields.md. Where the docs disagree we keep the stricter number
	(currencies: AS says 5, ET says 10). HOUSE limits leave headroom for later games and live-ops.
	Full table with quotes: analytics/schemas/events.md, "Budget".

	Config shape (all names PascalCase; see analytics/schemas/events.md for every entry):
		{
			events = { [EventName] = { description: string, value: string?, fields: { string }? } },
			funnels = { [FunnelName] = { description: string, kind: "onboarding" | "once" | "recurring",
			                             steps: { string }? (required unless kind = "onboarding"),
			                             inOrder: boolean? (credit a step only after the previous one),
			                             fields: { string }?, sessionTtlSec: number? } },
			track = { Rule },   -- bus event -> funnel step or custom event (AnalyticsRouter)
			session = { startEvent: string?, endEvent: string?, returnFunnel: string?,
			            startOn: string?,      -- bus event whose first argument is the player (default PlayerReady)
			            leftEvent: string?, leftInfo: ((player, ctx) -> { [string]: any }?)? }?,
			            -- at session end, before endEvent: leftInfo's fields as leftEvent (nil = nothing)
			subjects = { [eventName]: resolver }?,  -- game resolvers for its own events (Experience/Subjects)
			limits = { perPlayerPerMinute: number?, safety: number?, customReserve: number? }?,
		}
		Rule = { on: string, funnel: string?, step: number?, event: string?, session: ("start" | "continue" | "match")?,
		         key: string?, match: { [string]: string | number | boolean }?, fields: { string }?, value: string? }

	API
		AnalyticsSchema.CAPS, AnalyticsSchema.HOUSE, AnalyticsSchema.FIELD_KEYS ("CustomField01".."03")
		AnalyticsSchema.validate(config, knownEvents: { string }) -> { string }   -- list of problems (empty = valid)
		AnalyticsSchema.budget(config) -> { events, funnels, maxSteps, fieldsPerEvent }
]]

local AnalyticsSchema = {}

AnalyticsSchema.CAPS = table.freeze({
	customEventNames = 100, -- ET "eventNames | 100"
	funnels = 10, -- ET "Number of funnels | 10"; AS "Limited to 10 unique funnels per experience."
	stepsPerFunnel = 100, -- AS "All funnels start at step 1. Limited to steps 1-100."
	customFields = 3, -- ET "Number of custom fields | 3"
	customFieldCombinations = 8000, -- AS "Limited to 8,000 unique combinations of values across the three custom fields"
	currencies = 5, -- AS "Limited to 5 unique currency types per experience." (ET says 10; stricter kept)
	transactionTypes = 20, -- AS "Limited to 20 unique types per experience."
	itemSkus = 100, -- AS "Limited to 100 unique SKUs per experience."
	requestsPerMinuteBase = 120, -- ET "Total AnalyticsService requests per minute | 120 + (20 * CCU)"
	requestsPerMinutePerPlayer = 20,
	recentFunnelSessions = 10, -- funnel-events.md: only the 10 most recent funnelSessionId values per user count
})

-- Our own, stricter budget per game (headroom for live-ops and later systems).
AnalyticsSchema.HOUSE = table.freeze({
	customEventNames = 60,
	funnels = 8,
	stepsPerFunnel = 30,
})

AnalyticsSchema.FIELD_KEYS = table.freeze({ "CustomField01", "CustomField02", "CustomField03" })

local KINDS = { onboarding = true, once = true, recurring = true }
local SESSIONS = { start = true, continue = true, match = true }
local NAME_PATTERN = "^[A-Z][A-Za-z0-9]*$"
local KEY_PATTERN = "^[a-z][A-Za-z0-9]*$"

local function sortedKeys(t: { [string]: any }): { string }
	local keys = {}
	for key in t do
		table.insert(keys, key)
	end
	table.sort(keys)
	return keys
end

local function isList(t: any): boolean
	if type(t) ~= "table" then
		return false
	end
	local count = 0
	for _ in t do
		count += 1
	end
	return count == #t
end

local function checkFieldList(fields: any, where: string, problems: { string })
	if fields == nil then
		return
	end
	if not isList(fields) then
		table.insert(problems, `{where}: fields must be a list of names`)
		return
	end
	if #fields > AnalyticsSchema.CAPS.customFields then
		table.insert(problems, `{where}: {#fields} fields; Roblox allows {AnalyticsSchema.CAPS.customFields}`)
	end
	local seen = {}
	for _, field in fields do
		if type(field) ~= "string" or not string.match(field, KEY_PATTERN) then
			table.insert(problems, `{where}: field '{tostring(field)}' must be a camelCase name`)
		elseif seen[field] then
			table.insert(problems, `{where}: field '{field}' listed twice`)
		end
		seen[field] = true
	end
end

local function checkEvents(config: any, problems: { string })
	local events = config.events
	if type(events) ~= "table" then
		table.insert(problems, "events: missing table")
		return
	end
	local names = sortedKeys(events)
	if #names > AnalyticsSchema.HOUSE.customEventNames then
		table.insert(
			problems,
			`events: {#names} custom events exceeds the house budget {AnalyticsSchema.HOUSE.customEventNames} (Roblox cap {AnalyticsSchema.CAPS.customEventNames})`
		)
	end
	for _, name in names do
		local decl = events[name]
		local where = `events.{name}`
		if not string.match(name, NAME_PATTERN) then
			table.insert(problems, `{where}: event names are PascalCase`)
		end
		if type(decl) ~= "table" then
			table.insert(problems, `{where}: must be a table`)
			continue
		end
		if type(decl.description) ~= "string" or decl.description == "" then
			table.insert(problems, `{where}: description required`)
		end
		if decl.value ~= nil and (type(decl.value) ~= "string" or not string.match(decl.value, KEY_PATTERN)) then
			table.insert(problems, `{where}: value must name a camelCase field`)
		end
		checkFieldList(decl.fields, where, problems)
		if decl.value ~= nil and type(decl.fields) == "table" and table.find(decl.fields, decl.value) then
			table.insert(problems, `{where}: '{decl.value}' cannot be both the value and a custom field`)
		end
	end
end

local function checkFunnels(config: any, problems: { string })
	local funnels = config.funnels
	if type(funnels) ~= "table" then
		table.insert(problems, "funnels: missing table")
		return
	end
	local names = sortedKeys(funnels)
	if #names > AnalyticsSchema.HOUSE.funnels then
		table.insert(
			problems,
			`funnels: {#names} funnels exceeds the house budget {AnalyticsSchema.HOUSE.funnels} (Roblox cap {AnalyticsSchema.CAPS.funnels})`
		)
	end
	local onboarding = 0
	for _, name in names do
		local decl = funnels[name]
		local where = `funnels.{name}`
		if not string.match(name, NAME_PATTERN) then
			table.insert(problems, `{where}: funnel names are PascalCase`)
		end
		if type(decl) ~= "table" then
			table.insert(problems, `{where}: must be a table`)
			continue
		end
		if type(decl.description) ~= "string" or decl.description == "" then
			table.insert(problems, `{where}: description required`)
		end
		if not KINDS[decl.kind] then
			table.insert(problems, `{where}: kind must be onboarding | once | recurring`)
		end
		if decl.kind == "onboarding" then
			onboarding += 1
		elseif not isList(decl.steps) or #decl.steps == 0 then
			table.insert(problems, `{where}: steps must be a non-empty list`)
		end
		if isList(decl.steps) then
			if #decl.steps > AnalyticsSchema.HOUSE.stepsPerFunnel then
				table.insert(problems, `{where}: {#decl.steps} steps exceeds {AnalyticsSchema.HOUSE.stepsPerFunnel}`)
			end
			local seen = {}
			for i, step in decl.steps do
				if type(step) ~= "string" or not string.match(step, NAME_PATTERN) then
					table.insert(problems, `{where}: step {i} name must be PascalCase`)
				elseif seen[step] then
					table.insert(problems, `{where}: step '{step}' listed twice`)
				end
				seen[step] = true
			end
		end
		checkFieldList(decl.fields, where, problems)
		if decl.inOrder ~= nil and (type(decl.inOrder) ~= "boolean" or decl.kind == "onboarding") then
			table.insert(problems, `{where}: inOrder must be a boolean, and not on the onboarding funnel`)
		end
		if decl.sessionTtlSec ~= nil and (type(decl.sessionTtlSec) ~= "number" or decl.sessionTtlSec <= 0) then
			table.insert(problems, `{where}: sessionTtlSec must be a positive number`)
		end
	end
	if onboarding > 1 then
		table.insert(
			problems,
			"funnels: at most one onboarding funnel (LogOnboardingFunnelStepEvent has no funnel name)"
		)
	end
end

local function checkRules(config: any, knownEvents: { string }, problems: { string })
	local track = config.track
	if track == nil then
		return
	end
	if not isList(track) then
		table.insert(problems, "track: must be a list of rules")
		return
	end
	local events = if type(config.events) == "table" then config.events else {}
	local funnels = if type(config.funnels) == "table" then config.funnels else {}
	for i, rule in track do
		local where = `track[{i}]`
		if type(rule) ~= "table" then
			table.insert(problems, `{where}: must be a table`)
			continue
		end
		where = `track[{i}] ({tostring(rule.on)})`
		if type(rule.on) ~= "string" or not table.find(knownEvents, rule.on) then
			table.insert(problems, `{where}: 'on' must name a declared GameEvents event`)
		end
		if (rule.funnel == nil) == (rule.event == nil) then
			table.insert(problems, `{where}: set exactly one of funnel or event`)
			continue
		end
		if rule.match ~= nil then
			if type(rule.match) ~= "table" then
				table.insert(problems, `{where}: match must be a table`)
			else
				for key, value in rule.match do
					local kind = type(value)
					if type(key) ~= "string" or (kind ~= "string" and kind ~= "number" and kind ~= "boolean") then
						table.insert(problems, `{where}: match entries are name = string | number | boolean`)
					end
				end
			end
		end
		if rule.funnel ~= nil then
			local decl = funnels[rule.funnel]
			if decl == nil then
				table.insert(problems, `{where}: unknown funnel '{tostring(rule.funnel)}'`)
				continue
			end
			if decl.kind == "onboarding" then
				table.insert(problems, `{where}: the onboarding funnel is logged by OnboardingService only`)
				continue
			end
			local steps = if isList(decl.steps) then #decl.steps else 0
			if type(rule.step) ~= "number" or rule.step % 1 ~= 0 or rule.step < 1 or rule.step > steps then
				table.insert(problems, `{where}: step must be an integer in 1..{steps}`)
			end
			if decl.kind == "recurring" and not SESSIONS[rule.session] then
				table.insert(
					problems,
					`{where}: recurring funnel '{rule.funnel}' needs session = start | continue | match`
				)
			elseif decl.kind == "once" and rule.session ~= nil then
				table.insert(problems, `{where}: once funnel '{rule.funnel}' takes no session`)
			end
		else
			local decl = events[rule.event]
			if decl == nil then
				table.insert(problems, `{where}: unknown event '{tostring(rule.event)}'`)
				continue
			end
			if rule.fields ~= nil then
				if not isList(rule.fields) then
					table.insert(problems, `{where}: fields must be a list`)
				else
					for _, field in rule.fields do
						local allowed = field == decl.value
							or (type(decl.fields) == "table" and table.find(decl.fields, field))
						if not allowed then
							table.insert(
								problems,
								`{where}: field '{tostring(field)}' is not declared by events.{rule.event}`
							)
						end
					end
				end
			end
		end
	end
end

local function checkSession(config: any, knownEvents: { string }, problems: { string })
	local session = config.session
	if session == nil then
		return
	end
	local events = if type(config.events) == "table" then config.events else {}
	local funnels = if type(config.funnels) == "table" then config.funnels else {}
	if
		session.startOn ~= nil and (type(session.startOn) ~= "string" or not table.find(knownEvents, session.startOn))
	then
		table.insert(problems, `session.startOn: '{tostring(session.startOn)}' must name a declared GameEvents event`)
	end
	if (session.leftEvent == nil) ~= (session.leftInfo == nil) then
		table.insert(problems, "session.leftEvent and session.leftInfo go together")
	elseif session.leftInfo ~= nil and type(session.leftInfo) ~= "function" then
		table.insert(problems, "session.leftInfo: must be a function (player, ctx) -> fields?")
	end
	for _, key in { "startEvent", "endEvent", "leftEvent" } do
		if session[key] ~= nil and events[session[key]] == nil then
			table.insert(problems, `session.{key}: unknown event '{tostring(session[key])}'`)
		end
	end
	if session.returnFunnel ~= nil then
		local decl = funnels[session.returnFunnel]
		if decl == nil or decl.kind ~= "once" or not isList(decl.steps) or #decl.steps < 2 then
			table.insert(problems, "session.returnFunnel: must name a once funnel with at least 2 steps")
		end
	end
end

function AnalyticsSchema.validate(config: any, knownEvents: { string }): { string }
	local problems: { string } = {}
	if type(config) ~= "table" then
		return { "config must be a table" }
	end
	checkEvents(config, problems)
	checkFunnels(config, problems)
	checkRules(config, knownEvents, problems)
	checkSession(config, knownEvents, problems)
	return problems
end

function AnalyticsSchema.budget(config: any): { [string]: number }
	local events, funnels, maxSteps, maxFields = 0, 0, 0, 0
	for _, decl in config.events or {} do
		events += 1
		maxFields = math.max(maxFields, #(decl.fields or {}))
	end
	for _, decl in config.funnels or {} do
		funnels += 1
		maxSteps = math.max(maxSteps, #(decl.steps or {}))
	end
	return { events = events, funnels = funnels, maxSteps = maxSteps, fieldsPerEvent = maxFields }
end

return table.freeze(AnalyticsSchema)
