--!strict
--[[
	Experience/Subjects — who a server bus event is about. Turns a GameEvents payload into
	"subjects" ({ player, info }) for AnalyticsService track rules and OnboardingService triggers.

	The framework knows the payloads of framework events (DEFAULTS below). Game events (for example
	game-001's G9 events, appended to the bus by D-024) mean game things: "credit every current member
	of the kingdom" needs the game's KingdomService. So a game passes its own resolvers in config
	(`subjects = { [eventName] = resolver }` in Analytics.luau / Onboarding.luau); a game resolver wins
	over a default. Framework code never requires game code: the game hands the functions in.

		Subjects.resolve(eventName, args, ctx, resolvers?) -> ({ Subject }, error: string?)
			args = table.pack(...) of the event; ctx = { byUserId, all, registry }
			resolver(args, ctx) -> { Subject }; an error is caught and returned (callers log it) with {}
		Subjects.validate(resolvers, knownEvents) -> { string }
		Subjects.missing(eventNames, resolvers?) -> { string }
			the names that neither DEFAULTS nor `resolvers` cover: an event a config listens to without a
			resolver resolves to nobody, so its step or rule would silently never fire (FORGE-00 review M8)
		Subjects.primitives(t) -> table   -- strings, numbers and booleans of t (no Instances, no tables)

	Subject = { player: Player, info: { [string]: string | number | boolean } }. Info keeps only
	primitives, so analytics and onboarding never hold payload objects.
	Default info keys:
		RoundStateChanged  state, roundId, matchId            (every player in the server)
		RoundEnded         matchId, mode, placement, eliminations, survivedSec, won, completed, durationSec
		CurrencyChanged    currency, newBalance, delta, reason, gained (delta > 0)
		PurchaseCompleted  kind, productId, robux            RewardRolled  tableId + RewardResult fields
		ItemGranted        itemId, qty, source               ShopViewed    shopId, itemId
		PlayerEliminated   roundId, matchId, cause           OnboardingStep flow, step, stepName
]]

local Subjects = {}

export type Subject = { player: any, info: { [string]: any } }
export type Context = { byUserId: (userId: number) -> any, all: () -> { any }, registry: any? }
export type Resolver = (args: { any }, ctx: Context) -> { Subject }

function Subjects.primitives(source: any): { [string]: any }
	local out = {}
	if type(source) ~= "table" then
		return out
	end
	for key, value in source do
		local kind = type(value)
		if type(key) == "string" and (kind == "string" or kind == "number" or kind == "boolean") then
			out[key] = value
		end
	end
	return out
end

function Subjects.isPlayer(value: any): boolean
	return typeof(value) == "Instance" and value:IsA("Player")
end

local function single(player: any, info: { [string]: any }): { Subject }
	if not Subjects.isPlayer(player) then
		return {}
	end
	return { { player = player, info = info } }
end
Subjects.single = single

Subjects.DEFAULTS = table.freeze({
	PlayerReady = function(args: { any }): { Subject }
		return single(args[1], {})
	end,
	RoundStateChanged = function(args: { any }, ctx: Context): { Subject }
		local info = Subjects.primitives(args[2])
		info.state = args[1]
		info.matchId = info.roundId
		local out = {}
		for _, player in ctx.all() do
			table.insert(out, { player = player, info = table.clone(info) })
		end
		return out
	end,
	PlayerEliminated = function(args: { any }): { Subject }
		local info = Subjects.primitives(args[2])
		info.matchId = info.roundId
		return single(args[1], info)
	end,
	RoundEnded = function(args: { any }, ctx: Context): { Subject }
		local result = args[1]
		if type(result) ~= "table" or type(result.participants) ~= "table" then
			return {}
		end
		local winners = if type(result.winners) == "table" then result.winners else {}
		local duration = if type(result.endedAt) == "number" and type(result.startedAt) == "number"
			then math.max(0, result.endedAt - result.startedAt)
			else nil
		local out = {}
		for _, participant in result.participants do
			local player = if type(participant) == "table" then ctx.byUserId(participant.userId) else nil
			if player then
				table.insert(out, {
					player = player,
					info = {
						matchId = result.roundId,
						roundId = result.roundId,
						mode = result.mode,
						placement = participant.placement,
						eliminations = participant.eliminations,
						survivedSec = participant.survivedSec,
						won = table.find(winners, participant.userId) ~= nil,
						completed = true,
						durationSec = duration,
					},
				})
			end
		end
		return out
	end,
	CurrencyChanged = function(args: { any }): { Subject }
		local delta = if type(args[4]) == "number" then args[4] else 0
		return single(args[1], {
			currency = args[2],
			newBalance = args[3],
			delta = delta,
			reason = args[5],
			gained = delta > 0,
		})
	end,
	ItemGranted = function(args: { any }): { Subject }
		return single(args[1], { itemId = args[2], qty = args[3], source = args[4] })
	end,
	PurchaseCompleted = function(args: { any }): { Subject }
		return single(args[1], { kind = args[2], productId = args[3], robux = args[4] })
	end,
	RewardRolled = function(args: { any }): { Subject }
		local info = Subjects.primitives(args[3])
		info.tableId = args[2]
		return single(args[1], info)
	end,
	OnboardingStep = function(args: { any }): { Subject }
		return single(args[1], { flow = args[2], step = args[3], stepName = args[4] })
	end,
	ShopViewed = function(args: { any }): { Subject }
		return single(args[1], { shopId = args[2], itemId = args[3] })
	end,
} :: { [string]: Resolver })

function Subjects.resolve(
	eventName: string,
	args: { any },
	ctx: Context,
	resolvers: { [string]: any }?
): ({ Subject }, string?)
	local resolver = (resolvers and resolvers[eventName]) or Subjects.DEFAULTS[eventName]
	if resolver == nil then
		return {}, nil
	end
	local ok, result = pcall(resolver, args, ctx)
	if not ok then
		return {}, tostring(result)
	elseif type(result) ~= "table" then
		return {}, "resolver returned " .. typeof(result)
	end
	local out = {}
	for _, subject in result do
		if type(subject) == "table" and Subjects.isPlayer(subject.player) then
			table.insert(out, { player = subject.player, info = Subjects.primitives(subject.info) })
		end
	end
	return out, nil
end

function Subjects.validate(resolvers: any, knownEvents: { string }): { string }
	local problems: { string } = {}
	if resolvers == nil then
		return problems
	end
	if type(resolvers) ~= "table" then
		return { "subjects must be a table of event name -> resolver function" }
	end
	for name, resolver in resolvers do
		if type(name) ~= "string" or not table.find(knownEvents, name) then
			table.insert(problems, `subjects.{tostring(name)}: not a declared GameEvents event`)
		elseif type(resolver) ~= "function" then
			table.insert(problems, `subjects.{name}: must be a function (args, ctx) -> subjects`)
		end
	end
	return problems
end

function Subjects.missing(eventNames: { string }, resolvers: { [string]: any }?): { string }
	local out = {}
	for _, name in eventNames do
		local covered = Subjects.DEFAULTS[name] ~= nil or (type(resolvers) == "table" and resolvers[name] ~= nil)
		if not covered and not table.find(out, name) then
			table.insert(out, name)
		end
	end
	return out
end

return table.freeze(Subjects)
