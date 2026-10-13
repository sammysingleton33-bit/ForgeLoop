--!strict
--[[
	UI/ArmyModel — the army drawer as data (FL-0060; pure, no instances). It only compares costs with
	the treasury the server sent and counts what Kingdom.Population said; whether a recruit happens is
	the server's call (`Army.Recruit`), and `Army.Command` is an intent the server may ignore.

	ArmyModel.UNIT = "soldier"  ArmyModel.MAX_COUNT = 10 (CONTRACTS G8: count integer(1, 10))
	ArmyModel.myBarracks(store) -> { Building }            my barracks, by id
	ArmyModel.barracks(store, preferredId?) -> Building?   the one the drawer recruits at: the preferred
		one when it is my barracks, else my first finished one, else my first one
	ArmyModel.soldiers(store) -> number?                   byJob.soldier; nil until the server sends the
		population (shown as "—"), 0 when the population has no soldiers
	ArmyModel.panel(store, opts) -> Panel
		opts = { barracksId?, count, pending?, cooling?, objectives? (UI/ObjectiveModel list) }
		Panel = { tabs: { { id, label, icon } }, barracks: Building?, notice: string?,
		          unit = { name, icon, description, meta, each, upkeepEach, line, trainSeconds, upkeepFood }?,
		          count, canLess, canMore,
		          costs: { { currency, name, amount, have, short } }   (unit cost × count),
		          recruit = { state ("ready" | "disabled" | "loading"), text, icon? },
		          soldiers: number?, soldiersText ("4" | "—"), soldiersWord, upkeep: string?,
		          send = { state ("ready" | "disabled" | "done"), text, icon? },
		          status = { text, tone ("ok" | "muted"), default: boolean },
		          target = { name, text }? }
		Send to capture is disabled with a reason when the server says there are no soldiers (a
		count it has not sent yet does not block it) or when every objective is already mine; "done"
		while the local cooldown runs.
]]

local Bundle = require("@game/ReplicatedStorage/Forge/Economy/Bundle")
local ArmyText = require("./ArmyText")
local ObjectiveModel = require("./ObjectiveModel")
local Resources = require("@game/ReplicatedStorage/Forge/Config/Resources")
local Text = require("./Text")

local ArmyModel = {}

ArmyModel.UNIT = "soldier"
ArmyModel.MAX_COUNT = 10

function ArmyModel.myBarracks(store: any): { any }
	local out = {}
	for _, building in store:myBuildings() do
		if building.type == "barracks" then
			table.insert(out, building)
		end
	end
	return out
end

function ArmyModel.barracks(store: any, preferredId: number?): any
	local list = ArmyModel.myBarracks(store)
	for _, building in list do
		if building.id == preferredId then
			return building
		end
	end
	for _, building in list do
		if building.state == "complete" then
			return building
		end
	end
	return list[1]
end

function ArmyModel.soldiers(store: any): number?
	local population = store:population()
	if population == nil then
		return nil
	end
	return population.byJob.soldier or 0
end

function ArmyModel.clampCount(n: any): number
	if type(n) ~= "number" or n ~= n then
		return 1
	end
	return math.clamp(math.floor(n), 1, ArmyModel.MAX_COUNT)
end

local function costRows(cost: { [string]: number }, have: { [string]: number }): { any }
	local rows = {}
	for _, entry in Bundle.ordered(cost, Resources.ids) do
		local def = Resources.defs[entry.id]
		local balance = have[entry.id] or 0
		table.insert(rows, {
			currency = entry.id,
			name = if def then def.name else entry.id,
			amount = entry.amount,
			have = balance,
			short = balance < entry.amount,
		})
	end
	return rows
end

function ArmyModel.panel(store: any, opts: { [string]: any }): { [string]: any }
	local count = ArmyModel.clampCount(opts.count)
	local barracks = ArmyModel.barracks(store, opts.barracksId)
	local entry = store:unitCost(ArmyModel.UNIT)
	local have = store:balances()

	local tabs = {}
	if barracks then
		table.insert(tabs, { id = "building", label = `Barracks · Lv {barracks.level}`, icon = "barracks" })
	end
	table.insert(tabs, { id = "army", label = ArmyText.TAB, icon = "army" })

	local unit = nil
	local costs = {}
	if entry then
		local total = {}
		for currency, amount in entry.cost do
			total[currency] = amount * count
		end
		costs = costRows(total, have)
		unit = {
			name = ArmyText.UNIT_NAME,
			icon = "militia",
			description = ArmyText.UNIT_DESCRIPTION,
			meta = if barracks then `Recruit at Barracks Lv {barracks.level}` else ArmyText.RECRUIT_LINE,
			each = ArmyText.each(entry.trainSeconds),
			upkeepEach = `{ArmyText.upkeep(entry.upkeepFood)} each`,
			line = `· {ArmyText.each(entry.trainSeconds)} · {entry.upkeepFood} Food/min`,
			trainSeconds = entry.trainSeconds,
			upkeepFood = entry.upkeepFood,
		}
	end

	local recruit
	if opts.pending then
		recruit = { state = "loading", text = ArmyText.RECRUITING }
	elseif store:mine() == nil or not store:hasTreasury() then
		recruit = { state = "disabled", text = ArmyText.LOADING }
	elseif barracks == nil then
		recruit = { state = "disabled", text = ArmyText.NO_BARRACKS_CTA }
	elseif barracks.state == "planned" or barracks.state == "constructing" then
		recruit = { state = "disabled", text = ArmyText.UNFINISHED_CTA }
	elseif entry == nil then
		recruit = { state = "disabled", text = ArmyText.UNAVAILABLE }
	else
		local total = {}
		for _, c in costs do
			total[c.currency] = c.amount
		end
		local short = Text.missing(total, have)
		recruit = if short
			then { state = "disabled", text = short }
			else { state = "ready", text = ArmyText.recruitCta(count), icon = "militia" }
	end

	local soldiers = ArmyModel.soldiers(store)
	local mine = store:mine()
	local objectives = opts.objectives or {}
	local allMine = ObjectiveModel.allMine(objectives, if mine then mine.id else nil)
	local send, status
	if opts.cooling then
		send = { state = "done", text = ArmyText.SENT, icon = "check" }
		status = { text = ArmyText.SENT_STATUS, tone = "ok", default = false }
	elseif soldiers == 0 then
		send = { state = "disabled", text = ArmyText.NO_SOLDIERS }
		status = { text = ArmyText.NO_SOLDIERS_STATUS, tone = "muted", default = false }
	elseif allMine then
		send = { state = "disabled", text = ArmyText.ALL_MINE }
		status = { text = ArmyText.SEND_DEFAULT, tone = "muted", default = true }
	else
		send = { state = "ready", text = ArmyText.SEND, icon = "banner" }
		status = { text = ArmyText.SEND_DEFAULT, tone = "muted", default = true }
	end

	return {
		tabs = tabs,
		barracks = barracks,
		notice = if barracks == nil then ArmyText.NO_BARRACKS else nil,
		unit = unit,
		count = count,
		canLess = count > 1,
		canMore = count < ArmyModel.MAX_COUNT,
		costs = costs,
		recruit = recruit,
		soldiers = soldiers,
		soldiersText = if soldiers then tostring(soldiers) else ArmyText.UNKNOWN_COUNT,
		soldiersWord = ArmyText.soldiers(soldiers or 0),
		upkeep = if soldiers and entry then ArmyText.upkeep(soldiers * entry.upkeepFood) else nil,
		send = send,
		status = status,
		target = ObjectiveModel.target(objectives, store),
	}
end

return table.freeze(ArmyModel)
