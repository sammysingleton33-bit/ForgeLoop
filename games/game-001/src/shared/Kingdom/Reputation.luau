--!strict
--[[
	Kingdom/Reputation — the pure core of ReputationService and of the kingdom conditions (CONTRACTS G13.4;
	design/living-kingdom.md §3; content/SPEC.md §4, §5.9, §6). FL-0080. No services, no clock, no randomness:
	callers pass `now` (seconds on any match clock), the content tables and a query object, so specs pass
	fixtures and the service passes the generated modules. Tuning comes from config Society (the default for
	every `config?` argument), never from literals here.

	Inputs
		Content  the generated Content/Reputation shape (SPEC §7): categories = { [id] = { start, ... } },
		         actions = { Action } (file order). Action = { id, event ("Name" or "Name:arg"), condition,
		         farm_key, repeat_decay, repeat_window_s, rep = { six }, audience, audience_condition,
		         audience_loyalty, kingdom = { happiness, stability, morale }, notice? }.
		Query    { evaluate(clauses, ctx), repeatMultiplier(history, key, now, decay, window), recordFire(history,
		         key, now) } — Content/ContentQuery satisfies it (SPEC §4 nil/flag rules, model decision 5).
		Ctx      the flat kingdom context of SPEC §4, e.g. ctx["kingdom.fed_ratio"].
		FarmHistory  { [farm_key]: { fireTime } }, one per ruler (ContentQuery.recordFire keeps it bounded).

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
	Actions (events → content rows → effects)
		Reputation.actionsFor(actions, eventName, arg?) -> { Action }
			Rows for an event, in file order: event == eventName (a row without an arg matches every arg),
			or event == "eventName:arg", e.g. ("BuildingCompleted", "house"), ("UnitsRecruited").
		Reputation.resolveEvent(rows, ctx, farmHistory, now, query, config?) -> { Resolved }
			The rows whose `condition` holds for ctx (the need condition: a house counts only while the
			kingdom needs housing). Rows sharing a farm_key are ONE firing: they share the multiplier
			(query.repeatMultiplier before this firing) and the firing is recorded once (query.recordFire),
			only when at least one row applied. Nothing applies → nothing is recorded.
		Reputation.resolveAction(action, ctx, farmHistory, now, query, config?) -> Resolved?
			resolveEvent for one row; nil when its condition does not hold.
			Resolved = { id, event, farmKey, multiplier,
				rep (every category of the row: gains × multiplier, losses never reduced, rule-blocked = 0),
				repRaw (the row's values), blocked = { category } (zeroed by a user rule, see Rules),
				kingdom = { happiness, stability, morale } (the row's values, unscaled: applyConditions caps them),
				audience, audienceCondition, audienceLoyalty (gain × multiplier), audienceLoyaltyRaw, notice? }
		Reputation.audienceMatches(action, listener, query) -> boolean
			action: a row (audience, audience_condition) or a Resolved (audience, audienceCondition).
			listener = { occupation: string?, job: string?, kind: string?, speaker: boolean?, ctx: Ctx? }.
			"soldiers": job or kind is "soldier"; "civilians": everyone else; "occupation:<id>": that
			occupation; "kingdom": everyone; "speaker": the listener the event is about (listener.speaker,
			e.g. the visited citizen). Then the per-listener audience condition must hold for listener.ctx
			(citizen scope, e.g. citizen.hunger). Unknown audience: false.
		Reputation.listenerLoyalty(resolved, traits, traitWeights, reach) -> number
			Interim personality reaction until the service uses ContentQuery.loyaltyDelta (SPEC §6.3 without
			chemistry): (Σ_trait Σ_category traitWeights[trait][c] × repRaw[c]) × reach + audienceLoyaltyRaw,
			then a gain × multiplier (losses unchanged). Unknown traits weigh 0.
		Reputation.kingdomDelta(results) -> { happiness, stability, morale }   the summed kingdom deltas of one event
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
	Rules (user, living-kingdom §3), applied in resolveEvent on top of the content
		- Fighting enemies is not a compassion loss: rows on config.rules.fightEvents cannot lower the
		  categories in config.rules.fightNoLoss (those entries become 0 and are listed in `blocked`).
		- Peacekeeping is not rewarded by itself: reputation moves only through events (drift touches the
		  kingdom conditions, never the ledger), and rows on config.rules.peaceEvents cannot raise reputation.
		- One decision never triggers a kingdom-wide rebellion: applyConditions caps every application at
		  config.maxConditionStep per condition.
	Constants: Reputation.CATEGORIES (the six, canonical order), Reputation.CONDITIONS, Reputation.MIN / MAX.
]]

local SocietyConfig = require("@game/ReplicatedStorage/Forge/Config/Society")

export type Clause = { var: string, op: string, value: any }
export type Ctx = { [string]: any }
export type RepVector = { [string]: number }
export type Conditions = { happiness: number, stability: number, morale: number }
export type FarmHistory = { [string]: { number } }
export type Entry = { t: number, category: string, delta: number, text: string, source: string }
export type Ledger = { values: RepVector, history: { Entry }, order: { string }, limit: number }
export type Query = {
	evaluate: (clauses: { Clause }?, ctx: Ctx?) -> boolean,
	repeatMultiplier: (history: FarmHistory?, farmKey: string, now: number, decay: number?, window: number?) -> number,
	recordFire: (history: FarmHistory, farmKey: string, now: number) -> FarmHistory,
}
export type Action = {
	id: string,
	event: string,
	condition: { Clause }?,
	farm_key: string?,
	repeat_decay: number?,
	repeat_window_s: number?,
	rep: RepVector,
	audience: string,
	audience_condition: { Clause }?,
	audience_loyalty: number?,
	kingdom: Conditions?,
	notice: string?,
}
export type Resolved = {
	id: string,
	event: string,
	farmKey: string,
	multiplier: number,
	rep: RepVector,
	repRaw: RepVector,
	blocked: { string },
	kingdom: Conditions,
	audience: string,
	audienceCondition: { Clause },
	audienceLoyalty: number,
	audienceLoyaltyRaw: number,
	notice: string?,
}
export type Listener = { occupation: string?, job: string?, kind: string?, speaker: boolean?, ctx: Ctx? }

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

local function scaleGain(delta: number, multiplier: number): number
	if delta > 0 then
		return delta * multiplier
	end
	return delta
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
	return string.match(event, "^([^:]*)") or event
end

function Reputation.actionsFor(actions: { Action }, eventName: string, arg: string?): { Action }
	assert(type(eventName) == "string" and eventName ~= "", "Reputation.actionsFor: eventName required")
	local full = if arg ~= nil then `{eventName}:{arg}` else nil
	local out: { Action } = {}
	for _, action in actions do
		if action.event == eventName or (full ~= nil and action.event == full) then
			table.insert(out, action)
		end
	end
	return out
end

-- The rep vector a row may move after the user rules (living-kingdom §3).
local function guardedRep(action: Action, multiplier: number, rules: any): (RepVector, RepVector, { string })
	local name = eventNameOf(action.event)
	local isFight = table.find(rules.fightEvents or {}, name) ~= nil
	local isPeace = table.find(rules.peaceEvents or {}, name) ~= nil
	local noLoss = setOf(rules.fightNoLoss)
	local rep: RepVector, raw: RepVector, blocked: { string } = {}, {}, {}
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
		raw[category] = d
		if (isFight and noLoss[category] and d < 0) or (isPeace and d > 0) then
			rep[category] = 0
			table.insert(blocked, category)
		else
			rep[category] = scaleGain(d, multiplier)
		end
	end
	return rep, raw, blocked
end

local function resolveRow(action: Action, multiplier: number, rules: any): Resolved
	local rep, raw, blocked = guardedRep(action, multiplier, rules)
	local k = action.kingdom or { happiness = 0, stability = 0, morale = 0 }
	local loyalty = action.audience_loyalty or 0
	return {
		id = action.id,
		event = action.event,
		farmKey = action.farm_key or action.id,
		multiplier = multiplier,
		rep = rep,
		repRaw = raw,
		blocked = blocked,
		kingdom = { happiness = k.happiness or 0, stability = k.stability or 0, morale = k.morale or 0 },
		audience = action.audience,
		audienceCondition = action.audience_condition or {},
		audienceLoyalty = scaleGain(loyalty, multiplier),
		audienceLoyaltyRaw = loyalty,
		notice = action.notice,
	}
end

function Reputation.resolveEvent(
	rows: { Action },
	ctx: Ctx?,
	farmHistory: FarmHistory,
	now: number,
	query: Query,
	config: any?
): { Resolved }
	local cfg = config or SocietyConfig
	local rules = cfg.rules or {}
	local c: Ctx = ctx or {}
	local multipliers: { [string]: number } = {}
	local fired: { string } = {}
	local out: { Resolved } = {}
	for _, action in rows do
		if not query.evaluate(action.condition, c) then
			continue
		end
		local key = action.farm_key or action.id
		local multiplier = multipliers[key]
		if multiplier == nil then
			multiplier = query.repeatMultiplier(farmHistory, key, now, action.repeat_decay, action.repeat_window_s)
			multipliers[key] = multiplier
			table.insert(fired, key)
		end
		table.insert(out, resolveRow(action, multiplier :: number, rules))
	end
	for _, key in fired do
		query.recordFire(farmHistory, key, now)
	end
	return out
end

function Reputation.resolveAction(
	action: Action,
	ctx: Ctx?,
	farmHistory: FarmHistory,
	now: number,
	query: Query,
	config: any?
): Resolved?
	return Reputation.resolveEvent({ action }, ctx, farmHistory, now, query, config)[1]
end

function Reputation.audienceMatches(action: any, listener: Listener, query: Query): boolean
	local audience = action.audience
	local isSoldier = listener.job == "soldier" or listener.kind == "soldier"
	local matches
	if audience == "kingdom" then
		matches = true
	elseif audience == "soldiers" then
		matches = isSoldier
	elseif audience == "civilians" then
		matches = not isSoldier
	elseif audience == "speaker" then
		matches = listener.speaker == true
	elseif type(audience) == "string" and string.sub(audience, 1, 11) == "occupation:" then
		matches = listener.occupation ~= nil and listener.occupation == string.sub(audience, 12)
	else
		matches = false
	end
	if not matches then
		return false
	end
	local clauses = action.audienceCondition or action.audience_condition
	return query.evaluate(clauses, listener.ctx or {})
end

function Reputation.listenerLoyalty(
	resolved: Resolved,
	traits: { string },
	traitWeights: { [string]: RepVector },
	reach: number
): number
	local sum = 0
	for _, trait in traits do
		local weights = traitWeights[trait]
		if weights == nil then
			continue
		end
		for _, category in CATEGORIES do
			sum += (weights[category] or 0) * (resolved.repRaw[category] or 0)
		end
	end
	return scaleGain(sum * reach + resolved.audienceLoyaltyRaw, resolved.multiplier)
end

function Reputation.kingdomDelta(results: { Resolved }): Conditions
	local total = { happiness = 0, stability = 0, morale = 0 }
	for _, r in results do
		total.happiness += r.kingdom.happiness
		total.stability += r.kingdom.stability
		total.morale += r.kingdom.morale
	end
	return total
end

-- ---------------------------------------------------------------- kingdom conditions

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
