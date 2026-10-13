--!strict
--[[
	Kingdom/Reputation — the pure core of ReputationService and of the kingdom conditions (CONTRACTS G13.4;
	design/living-kingdom.md §3; content/SPEC.md §4, §5.9, §6). FL-0080. No services, no clock, no randomness:
	callers pass `now` (seconds on any match clock), the content tables and a query object, so specs pass
	fixtures and the service passes the generated modules. Tuning comes from config Society (the default for
	every `config?` argument), never from literals here.

	Content  the generated Content/Reputation shape (SPEC §7): categories = { [id] = { start, ... } }.
	Actions (actions.csv) are resolved by ContentQuery (actionFirings, scaleGains, inActionAudience,
	actionLoyalty, the anti-farming histories) in ReputationService; this module keeps the ledger, the
	kingdom conditions and the user rules, so there is one effect path (FORGE-00, SPEC §6.9).

	Reputation ledger (one per ruler)
		Reputation.newLedger(categories, config?) -> Ledger
			values from each category's `start` (clamped 0..100); empty history; keeps config.historyLimit entries.
		Reputation.apply(ledger, source, delta, text, now) -> (applied, ignored)
			Adds each delta[c], clamping the value to 0..100, and appends one history entry per category that
			moved: { t = now, category, delta = the applied (post-clamp) amount, text, source }, in category
			order. Zero (or fully clamped) changes leave no entry. Keeps the newest `limit` entries.
			applied = { [c]: applied amount } (moved categories only). Never errors on a bad key: unknown
			categories and non-finite amounts change nothing and are listed (sorted) in `ignored`, so the
			service can warn about a content/code mismatch.
		Reputation.view(ledger, n?) -> { values, history }
			Copies for the remotes and the screen: history is the latest n entries (all when nil), oldest first.
	Rules
		Reputation.guardRules(event, rep, config?) -> (rep, blocked)
			The user rules below on one event's (already decayed) reputation vector: a copy with the blocked
			categories zeroed, and their names in canonical order.
	Kingdom conditions (one set per kingdom, separate from reputation)
		Reputation.newConditions(config?) -> Conditions                         config.conditionStart
		Reputation.applyConditions(conditions, delta, config?) -> (conditions, applied)
			Each delta component is capped to ±config.maxConditionStep, then the value is clamped 0..100.
			Updates `conditions` in place (it may be the Kingdom record) and returns it. Apply one decision
			or one event as ONE call (kingdomDelta), so the cap bounds the whole decision.
		Reputation.conditionTargets(ctx, config?) -> Conditions?
			f = clamp(fed_ratio, 0, 1); crowd = clamp((housing_ratio − housingComfort) /
			(housingCrowded − housingComfort), 0, 1) (0 when housing_ratio is unknown);
			target[c] = clamp(starved[c] + (fed[c] − starved[c]) × f − crowdingPenalty[c] × crowd, 0, 100).
			nil when the fed ratio is unknown (no drift without data).
		Reputation.driftConditions(conditions, ctx, dt, config?) -> conditions
			Each condition moves toward its target by at most rate[c] × dt and never past it (in place).
			Monotonic: more food or less crowding never lowers a target, so never lowers the result.
	Rules (user, living-kingdom §3), applied by guardRules on top of the content
		- Fighting enemies is not a compassion loss: rows on config.rules.fightEvents cannot lower the
		  categories in config.rules.fightNoLoss (those entries become 0 and are listed in `blocked`).
		- Peacekeeping is not rewarded by itself: reputation moves only through events (drift touches the
		  kingdom conditions, never the ledger), and rows on config.rules.peaceEvents cannot raise reputation.
		- One decision never triggers a kingdom-wide rebellion: applyConditions caps every application at
		  config.maxConditionStep per condition.
	Constants: Reputation.CATEGORIES (the six, canonical order), Reputation.CONDITIONS, Reputation.MIN / MAX.
]]

local SocietyConfig = require("@game/ReplicatedStorage/Forge/Config/Society")

export type Ctx = { [string]: any }
export type RepVector = { [string]: number }
export type Conditions = { happiness: number, stability: number, morale: number }
export type Entry = { t: number, category: string, delta: number, text: string, source: string }
export type Ledger = { values: RepVector, history: { Entry }, order: { string }, limit: number }
export type Action = { event: string, rep: RepVector } -- what guardRules reads

local Reputation = {}

Reputation.MIN = 0
Reputation.MAX = 100
Reputation.CATEGORIES = table.freeze({ "compassion", "honor", "competence", "courage", "authority", "fear" })
Reputation.CONDITIONS = table.freeze({ "happiness", "stability", "morale" })

local CATEGORIES = Reputation.CATEGORIES
local CONDITIONS = Reputation.CONDITIONS

local function finite(x: any): boolean
	return type(x) == "number" and x == x and x > -math.huge and x < math.huge
end

local function clamp100(x: number): number
	return math.clamp(x, Reputation.MIN, Reputation.MAX)
end

local function setOf(list: { string }?): { [string]: boolean }
	local set = {}
	for _, item in list or {} do
		set[item] = true
	end
	return set
end

-- ---------------------------------------------------------------- ledger

function Reputation.newLedger(categories: { [string]: any }, config: any?): Ledger
	local cfg = config or SocietyConfig
	assert(type(categories) == "table", "Reputation.newLedger: categories table required")
	local limit = cfg.historyLimit
	assert(finite(limit) and limit >= 0, "Reputation.newLedger: config.historyLimit must be a number >= 0")
	local order: { string } = {}
	for _, id in CATEGORIES do
		if categories[id] ~= nil then
			table.insert(order, id)
		end
	end
	local extras: { string } = {}
	for id in categories do
		if not table.find(CATEGORIES, id) then
			table.insert(extras, id)
		end
	end
	table.sort(extras)
	table.move(extras, 1, #extras, #order + 1, order)
	local values: RepVector = {}
	for _, id in order do
		local start = categories[id].start
		assert(finite(start), `Reputation.newLedger: category '{id}' has no numeric start`)
		values[id] = clamp100(start)
	end
	return { values = values, history = {}, order = order, limit = limit }
end

function Reputation.apply(
	ledger: Ledger,
	source: string,
	delta: { [string]: any },
	text: string,
	now: number
): (RepVector, { string })
	assert(type(source) == "string", "Reputation.apply: source must be a string")
	assert(type(text) == "string", "Reputation.apply: text must be a string")
	assert(finite(now), "Reputation.apply: now must be a finite number")
	local applied: RepVector = {}
	for _, category in ledger.order do
		local d = delta[category]
		if not finite(d) or d == 0 then
			continue
		end
		local old = ledger.values[category]
		local new = clamp100(old + d)
		ledger.values[category] = new
		local moved = new - old
		if moved ~= 0 then
			applied[category] = moved
			table.insert(ledger.history, { t = now, category = category, delta = moved, text = text, source = source })
		end
	end
	while #ledger.history > ledger.limit do
		table.remove(ledger.history, 1)
	end
	local ignored: { string } = {}
	for key, d in delta do
		if ledger.values[key] == nil or not finite(d) then
			table.insert(ignored, tostring(key))
		end
	end
	table.sort(ignored)
	return applied, ignored
end

function Reputation.view(ledger: Ledger, n: number?): { values: RepVector, history: { Entry } }
	local history = ledger.history
	local first = if n then math.max(1, #history - n + 1) else 1
	local out: { Entry } = {}
	for i = first, #history do
		table.insert(out, table.clone(history[i]))
	end
	return { values = table.clone(ledger.values), history = out }
end

-- ---------------------------------------------------------------- actions

local function eventNameOf(event: string): string
	return (string.match(event, "^([^:]+)") or event) :: string
end

local function guardedRep(action: Action, rules: any): (RepVector, { string })
	local name = eventNameOf(action.event)
	local isFight = table.find(rules.fightEvents or {}, name) ~= nil
	local isPeace = table.find(rules.peaceEvents or {}, name) ~= nil
	local noLoss = setOf(rules.fightNoLoss)
	local rep: RepVector, blocked: { string } = {}, {}
	local keys: { string } = {}
	for category in action.rep do
		table.insert(keys, category)
	end
	table.sort(keys, function(a: string, b: string): boolean
		local ia, ib = table.find(CATEGORIES, a) or math.huge, table.find(CATEGORIES, b) or math.huge
		if ia ~= ib then
			return ia < ib
		end
		return a < b
	end)
	for _, category in keys do
		local d = action.rep[category]
		if (isFight and noLoss[category] and d < 0) or (isPeace and d > 0) then
			rep[category] = 0
			table.insert(blocked, category)
		else
			rep[category] = d -- already decayed by ContentQuery (one anti-farming point, #67)
		end
	end
	return rep, blocked
end

-- The user rules (see Rules) on one event's reputation vector, already decayed. Returns the guarded
-- vector and the categories a rule zeroed.
function Reputation.guardRules(event: string, rep: RepVector, config: any?): (RepVector, { string })
	local rules = (config or SocietyConfig).rules
	return guardedRep({ event = event, rep = rep } :: any, rules)
end

function Reputation.newConditions(config: any?): Conditions
	local start = (config or SocietyConfig).conditionStart
	assert(type(start) == "table", "Reputation.newConditions: config.conditionStart required")
	local out = {}
	for _, c in CONDITIONS do
		assert(finite(start[c]), `Reputation.newConditions: conditionStart.{c} must be a number`)
		out[c] = clamp100(start[c])
	end
	return (out :: any) :: Conditions
end

function Reputation.applyConditions(
	conditions: Conditions,
	delta: { [string]: any },
	config: any?
): (Conditions, Conditions)
	local step = (config or SocietyConfig).maxConditionStep
	assert(finite(step) and step >= 0, "Reputation.applyConditions: config.maxConditionStep must be a number >= 0")
	local values = conditions :: any
	local applied = { happiness = 0, stability = 0, morale = 0 } :: any
	for _, c in CONDITIONS do
		local d = delta[c]
		if not finite(d) or d == 0 then
			continue
		end
		local old = values[c]
		local new = clamp100(old + math.clamp(d, -step, step))
		values[c] = new
		applied[c] = new - old
	end
	return conditions, applied :: Conditions
end

function Reputation.conditionTargets(ctx: Ctx?, config: any?): Conditions?
	local drift = (config or SocietyConfig).drift
	assert(type(drift) == "table", "Reputation.conditionTargets: config.drift required")
	local c: Ctx = ctx or {}
	local fed = c["kingdom.fed_ratio"]
	if not finite(fed) then
		return nil
	end
	local f = math.clamp(fed, 0, 1)
	local housing = c["kingdom.housing_ratio"]
	local crowd = 0
	if finite(housing) then
		local span = drift.housingCrowded - drift.housingComfort
		if span > 0 then
			crowd = math.clamp((housing - drift.housingComfort) / span, 0, 1)
		elseif housing > drift.housingComfort then
			crowd = 1
		end
	end
	local out = {}
	for _, k in CONDITIONS do
		local low, high = drift.starved[k], drift.fed[k]
		out[k] = clamp100(low + (high - low) * f - (drift.crowdingPenalty[k] or 0) * crowd)
	end
	return (out :: any) :: Conditions
end

function Reputation.driftConditions(conditions: Conditions, ctx: Ctx?, dt: number, config: any?): Conditions
	local cfg = config or SocietyConfig
	if not finite(dt) or dt <= 0 then
		return conditions
	end
	local targets = Reputation.conditionTargets(ctx, cfg) :: any
	if targets == nil then
		return conditions
	end
	local values = conditions :: any
	for _, k in CONDITIONS do
		local limit = cfg.drift.rate[k] * dt
		values[k] = clamp100(values[k] + math.clamp(targets[k] - values[k], -limit, limit))
	end
	return conditions
end

return Reputation
