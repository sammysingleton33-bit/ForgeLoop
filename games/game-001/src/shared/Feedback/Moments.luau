--!strict
--[[
	Feedback/Moments (game-001, FORGE-04, FL-0062): what each G9 event means for each player, and how
	the client presents it. Pure: the server's AnnouncerService and the client controllers share it,
	and specs drive it without Roblox.

	Server side
		Moments.fromEvent(eventName, args, ctx) -> { { player, moment } }
		ctx = {
			members: (kingdomId) -> { Player },   -- current members (KingdomService G3)
			all: () -> { Player },
			kingdomName: (kingdomId) -> string?,  -- Kingdom.name (G2), e.g. "Emberhold"
			displayName: (player) -> string,
			byUserId: (userId) -> Player?,
			buildingKind: ((buildingId) -> string?)?,   -- optional: a building's type (Lines.BUILDING key)
		}
		Audience rules (CONTRACTS G9 attribution, kingdom-scoped announcer of G11):
		| G9 event          | the kingdom's members                      | everyone else                  |
		| KingdomJoined     | the joiner: kingdomFounded; others: memberJoined |                          |
		| BuildingPlaced    | buildingPlaced to the co-rulers, with the placer's name | —                 |
		| BuildingCompleted | buildingCompleted                          | —                              |
		| BuildingUpgraded  | keepUpgraded (keep) / buildingUpgraded     | rivalKeepUpgraded (keep only)  |
		| BuildingDestroyed | buildingDestroyed                          | —                              |
		| UnitsRecruited    | unitsRecruited to the co-rulers            | —                              |
		| ObjectiveCaptured | objectiveCaptured                          | rivalCaptured                  |
		| MatchPhaseChanged | phase, to every player                                                      |
		| MatchEnded        | matchEnded to every player: outcome won / lost / draw (no winner) / watched  |
		|                   | (a spectator), won = outcome == "won"                                      |
		| ConsequenceChanged| consequence (rule, on, occupation?, count?, buildingType?) to the kingdom's  |
		|                   | rulers, per start and per end (FL-0091); a rebellion's end is never shown    |
		The player who placed or recruited is left out: FORGE-03's own toast already answered them
		("House placed", "3 soldiers recruited"), so the announcer never says it twice.
		ResourceGathered is not announced: the client's own gather feedback (FeedbackController) is
		immediate, and citizens' gathering would flood the stack.
	Moment (sent as Feedback.Moment): { kind, kingdom?, kingdomName?, actor?, buildingType?, level?,
		count?, objectiveId?, phase?, won?, winner?, rule?, on?, occupation?, position: Vector3? } —
		primitives and Vector3 only.

	Client side
		Moments.present(moment) -> { toast?: { kind, title, body?, key? }, celebrate?: string,
		                             sound?: string, vfx?: string }
		Text comes from Feedback/Lines (one line, ≤ 60 characters per title).
]]

local Lines = require("./Lines")

local Moments = {}

Moments.KINDS = table.freeze({
	"kingdomFounded",
	"memberJoined",
	"buildingPlaced",
	"buildingCompleted",
	"keepUpgraded",
	"buildingUpgraded",
	"rivalKeepUpgraded",
	"buildingDestroyed",
	"unitsRecruited",
	"objectiveCaptured",
	"rivalCaptured",
	"phase",
	"matchEnded",
	"consequence",
})

Moments.RULES = table.freeze({ strike = true, shortage = true, riot = true, rebellion = true })

type Delivery = { player: any, moment: { [string]: any } }

local function positionOf(building: any): Vector3?
	local ok, position = pcall(function()
		return building.cframe.Position
	end)
	return if ok and typeof(position) == "Vector3" then position else nil
end

local function isMember(list: { any }, player: any): boolean
	return table.find(list, player) ~= nil
end

local function to(out: { Delivery }, players: { any }, moment: { [string]: any })
	for _, player in players do
		table.insert(out, { player = player, moment = table.clone(moment) })
	end
end

-- the members without the player who acted (nil: an unknown or departed actor, so all of them)
local function except(members: { any }, actor: any): { any }
	local out = {}
	for _, member in members do
		if member ~= actor then
			table.insert(out, member)
		end
	end
	return out
end

local function others(ctx: any, members: { any }): { any }
	local out = {}
	for _, player in ctx.all() do
		if not isMember(members, player) then
			table.insert(out, player)
		end
	end
	return out
end

local function buildingMoment(kind: string, building: any, ctx: any): { [string]: any }
	return {
		kind = kind,
		kingdom = building.kingdom,
		kingdomName = ctx.kingdomName(building.kingdom),
		buildingType = building.type,
		level = building.level,
		position = positionOf(building),
	}
end

local function finiteCount(value: any): number?
	if type(value) ~= "number" or value ~= value or value < 0 or value == math.huge then
		return nil
	end
	return math.floor(value)
end

local function consequence(args: { any }, ctx: any): { [string]: any }?
	local kingdom, rule, on, info = args[1], args[2], args[3], args[4]
	if type(kingdom) ~= "string" or not Moments.RULES[rule] or type(on) ~= "boolean" then
		return nil
	end
	if rule == "rebellion" and not on then
		return nil -- a rebellion announces only its start (G9 v0.4-g10d)
	end
	local details = if type(info) == "table" then info else {}
	local occupation = details.occupation
	local buildingType = nil
	if details.buildingId ~= nil and ctx.buildingKind ~= nil then
		local ok, kind = pcall(ctx.buildingKind, details.buildingId)
		buildingType = if ok and type(kind) == "string" then kind else nil
	end
	return {
		kind = "consequence",
		kingdom = kingdom,
		rule = rule,
		on = on,
		-- "riot" marks rioters on the strike channel (G13.3), never a job
		occupation = if type(occupation) == "string" and occupation ~= "riot" then occupation else nil,
		count = finiteCount(details.count),
		buildingType = buildingType,
	}
end

function Moments.fromEvent(eventName: string, args: { any }, ctx: any): { Delivery }
	local out: { Delivery } = {}
	if eventName == "KingdomJoined" then
		local player, kingdom = args[1], args[2]
		if player == nil or type(kingdom) ~= "string" then
			return out
		end
		to(out, { player }, { kind = "kingdomFounded", kingdom = kingdom, kingdomName = ctx.kingdomName(kingdom) })
		local members = ctx.members(kingdom)
		local rest = {}
		for _, member in members do
			if member ~= player then
				table.insert(rest, member)
			end
		end
		to(out, rest, { kind = "memberJoined", kingdom = kingdom, actor = ctx.displayName(player) })
	elseif
		eventName == "BuildingPlaced"
		or eventName == "BuildingCompleted"
		or eventName == "BuildingUpgraded"
		or eventName == "BuildingDestroyed"
	then
		local building = args[1]
		if type(building) ~= "table" or type(building.kingdom) ~= "string" then
			return out
		end
		local members = ctx.members(building.kingdom)
		if eventName == "BuildingPlaced" then
			local moment = buildingMoment("buildingPlaced", building, ctx)
			local placer = if type(building.placedBy) == "number" then ctx.byUserId(building.placedBy) else args[2]
			moment.actor = if placer then ctx.displayName(placer) else nil
			-- the placer already has FORGE-03's own notice ("House placed"): the co-rulers get this one
			to(out, except(members, placer), moment)
		elseif eventName == "BuildingCompleted" then
			to(out, members, buildingMoment("buildingCompleted", building, ctx))
		elseif eventName == "BuildingDestroyed" then
			to(out, members, buildingMoment("buildingDestroyed", building, ctx))
		elseif building.type == "keep" then
			to(out, members, buildingMoment("keepUpgraded", building, ctx))
			local rival = buildingMoment("rivalKeepUpgraded", building, ctx)
			rival.position = nil -- rivals learn the news, not the location
			to(out, others(ctx, members), rival)
		else
			to(out, members, buildingMoment("buildingUpgraded", building, ctx))
		end
	elseif eventName == "UnitsRecruited" then
		local player, kingdom, count = args[1], args[2], args[3]
		if type(kingdom) ~= "string" then
			return out
		end
		-- the recruiter already has FORGE-03's own notice ("3 soldiers recruited"): the co-rulers get this one
		to(out, except(ctx.members(kingdom), player), {
			kind = "unitsRecruited",
			kingdom = kingdom,
			actor = if player then ctx.displayName(player) else nil,
			count = if type(count) == "number" then count else nil,
		})
	elseif eventName == "ObjectiveCaptured" then
		local objectiveId, kingdom = args[1], args[2]
		if type(kingdom) ~= "string" then
			return out
		end
		local members = ctx.members(kingdom)
		local moment = { kind = "objectiveCaptured", kingdom = kingdom, objectiveId = objectiveId }
		to(out, members, moment)
		to(out, others(ctx, members), {
			kind = "rivalCaptured",
			kingdom = kingdom,
			kingdomName = ctx.kingdomName(kingdom),
			objectiveId = objectiveId,
		})
	elseif eventName == "MatchPhaseChanged" then
		local phase = args[1]
		if type(phase) == "string" then
			to(out, ctx.all(), { kind = "phase", phase = phase })
		end
	elseif eventName == "ConsequenceChanged" then
		local moment = consequence(args, ctx)
		if moment ~= nil then
			to(out, ctx.members(moment.kingdom), moment)
		end
	elseif eventName == "MatchEnded" then
		local result = args[1]
		if type(result) ~= "table" then
			return out
		end
		local winner = if type(result.winner) == "string" then result.winner else nil
		for _, player in ctx.all() do
			local mine = ctx.kingdomOf and ctx.kingdomOf(player)
			local outcome = if winner == nil
				then "draw"
				elseif mine == nil then "watched"
				elseif mine == winner then "won"
				else "lost"
			table.insert(out, {
				player = player,
				moment = {
					kind = "matchEnded",
					winner = winner,
					kingdomName = if winner then ctx.kingdomName(winner) else nil,
					outcome = outcome,
					won = outcome == "won",
				},
			})
		end
	end
	return out
end

local function fill(template: string?, moment: any): string?
	if template == nil then
		return nil
	end
	local text = string.gsub(template, "{(%w+)}", function(field)
		local value = moment[field]
		if field == "building" then
			value = Lines.BUILDING[moment.buildingType] or moment.buildingType
		elseif field == "place" then
			local name = Lines.BUILDING[moment.buildingType] or moment.buildingType
			value = if type(name) == "string" then string.lower(name) else nil
		elseif field == "jobs" then
			value = Lines.JOBS[moment.occupation] or "workers"
		end
		if type(value) == "string" or type(value) == "number" then
			return tostring(value)
		end
		return ""
	end)
	text = string.gsub(text, "%s+", " ")
	text = string.match(text, "^%s*(.-)%s*$") or text
	return if text == "" then nil else text
end

-- A template whose every {field} the moment has (else nil: a consequence line is never shown half empty).
local function fillAll(template: string?, moment: any): string?
	if template == nil then
		return nil
	end
	for field in string.gmatch(template, "{(%w+)}") do
		local present = if field == "place"
			then moment.buildingType ~= nil
			elseif field == "jobs" then true
			else moment[field] ~= nil
		if not present then
			return nil
		end
	end
	return fill(template, moment)
end

-- matchEnded outcome -> its line in Lines.MOMENT
Moments.OUTCOME_LINE = table.freeze({ won = "victory", lost = "defeat", draw = "draw", watched = "watched" })

function Moments.present(moment: any): { [string]: any }
	if type(moment) ~= "table" then
		return {}
	end
	local kind = moment.kind
	if kind == "phase" then
		local line = Lines.PHASE[moment.phase]
		if line == nil then
			return {}
		end
		return {
			toast = { kind = line.kind or "info", title = line.title, body = line.body, key = `phase:{moment.phase}` },
			sound = line.sound,
		}
	end
	if kind == "consequence" then
		local rule = Lines.CONSEQUENCE[moment.rule]
		local line = rule and rule[if moment.on == true then "start" else "stop"]
		if line == nil then
			return {}
		end
		local title = fillAll(line.title, moment) or line.plain
		if title == nil then
			return {}
		end
		return {
			toast = {
				kind = line.kind or "info",
				title = title,
				body = fillAll(if moment.count == 1 and line.bodyOne then line.bodyOne else line.body, moment),
				key = fill(line.key, moment),
			},
			sound = line.sound,
		}
	end
	local line = if kind == "matchEnded"
		then Lines.MOMENT[Moments.OUTCOME_LINE[moment.outcome or (if moment.won then "won" else "lost")]]
		else Lines.MOMENT[kind]
	if line == nil then
		return {}
	end
	local title = fill(line.title, moment)
	return {
		toast = if title
			then {
				kind = line.kind or "info",
				title = title,
				body = fill(line.body, moment),
				key = if line.key then fill(line.key, moment) else nil,
			}
			else nil,
		celebrate = line.celebrate,
		sound = line.sound,
		vfx = line.vfx,
	}
end

return table.freeze(Moments)
