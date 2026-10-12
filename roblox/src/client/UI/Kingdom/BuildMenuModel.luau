--!strict
--[[
	UI/Kingdom/BuildMenuModel — the construction menu as data (pure, no instances). The verdict for
	every building comes from Economy/Construction:check, the same function FORGE-01's
	KingdomService runs before spending, so what the menu promises is what the server does.

	BuildMenuModel.build(input) -> View
		input = {
			catalog, currencies,           Construction catalog, Currencies registry
			kingdom: KingdomSnapshot?,     nil until the first Gameplay.KingdomState
			treasury: TreasurySnapshot?,   nil until the first Economy.Treasury
			category: string,              "economy" | "civic" | "military"
			selected: string?,             building id (nil = first in the category)
			pending: string?,              building id whose request is in flight
			done: string?,                 building id that was just started (success flash)
		}
		View = {
			loading: boolean,
			tabs: { { id, label, icon } },
			rows: { Row },  detail: Detail?
		}
		Row = { id, name, icon, category, selected, ok, locked, lockText?, count, maxCount,
		        costs: { { currency, amount, short } } }
		Detail = { id, name, icon, category, categoryLabel, level, uid?, action ("build"|"upgrade"),
		           description, meta, buildSec, workers?, rate: { { currency, perMinute } }, housing?,
		           storage?, requirements: { { text, met } },
		           costs: { { currency, name, amount, have, short, need } },
		           cta: { state ("ready"|"disabled"|"loading"|"done"), text, icon?, variant },
		           needsConfirm: boolean, check }
	BuildMenuModel.detail(input, buildingId, uid?) -> Detail     also used for upgrades
	BuildMenuModel.isLargeSpend(cost, balances) -> boolean
		true when the total cost is at least LARGE_SPEND_MIN_TOTAL and takes at least
		LARGE_SPEND_SHARE of some balance: then the UI asks for confirmation first.
]]

local Bundle = require("@game/ReplicatedStorage/Forge/Economy/Bundle")
local Text = require("./Text")

local BuildMenuModel = {}

BuildMenuModel.LARGE_SPEND_MIN_TOTAL = 150
BuildMenuModel.LARGE_SPEND_SHARE = 0.5
BuildMenuModel.CATEGORIES = table.freeze({
	{ id = "economy", label = "Economy", icon = "food" },
	{ id = "civic", label = "Civic", icon = "house" },
	{ id = "military", label = "Military", icon = "army" },
})

local EMPTY_KINGDOM = { buildings = {}, builders = { busy = 0, total = 0 } }

local function names(catalog: any): { [string]: string }
	local out = {}
	for _, def in catalog:buildings() do
		out[def.id] = def.name
	end
	return out
end

function BuildMenuModel.isLargeSpend(cost: { [string]: number }, balances: { [string]: number }): boolean
	local total = 0
	for _, amount in cost do
		total += amount
	end
	if total < BuildMenuModel.LARGE_SPEND_MIN_TOTAL then
		return false
	end
	for currency, amount in cost do
		local have = balances[currency] or 0
		if have > 0 and amount / have >= BuildMenuModel.LARGE_SPEND_SHARE then
			return true
		end
	end
	return false
end

local function categoryLabel(id: string): string
	for _, c in BuildMenuModel.CATEGORIES do
		if c.id == id then
			return c.label
		end
	end
	return id
end

function BuildMenuModel.detail(input: { [string]: any }, buildingId: string, uid: string?): any
	local catalog, currencies = input.catalog, input.currencies
	local def = catalog:building(buildingId)
	if def == nil then
		return nil
	end
	local kingdom = input.kingdom or EMPTY_KINGDOM
	local balances = if input.treasury then input.treasury.balances else {}
	local check = catalog:check(kingdom, balances, buildingId, uid)
	local level = catalog:level(buildingId, check.level) or def.building.levels[1]
	local buildingNames = names(catalog)

	local rate = {}
	if level.produces then
		for _, entry in Bundle.ordered(level.produces, currencies:ids()) do
			table.insert(rate, { currency = entry.id, perMinute = entry.amount * (level.workers or 0) })
		end
	end
	local requirements = {}
	for _, req in level.requires or {} do
		local met = catalog:highestLevel(kingdom, req.building) >= req.level
		table.insert(requirements, { text = Text.requirement(req, buildingNames), met = met })
	end
	local costs = {}
	for _, entry in Bundle.ordered(check.cost, currencies:ids()) do
		local have = balances[entry.id] or 0
		local cdef = currencies:get(entry.id)
		table.insert(costs, {
			currency = entry.id,
			name = if cdef then cdef.name else entry.id,
			amount = entry.amount,
			have = have,
			short = have < entry.amount,
			need = math.max(0, entry.amount - have),
		})
	end

	local upgrade = check.action == "upgrade"
	local verb = if upgrade then `Upgrade to Lv {check.level}` else `Build {def.name}`
	local cta
	if input.done == buildingId and (uid == nil or input.doneUid == uid) then
		cta = {
			state = "done",
			text = if upgrade then "Upgrade started" else "Construction started",
			icon = "check",
			variant = "success",
		}
	elseif input.pending == buildingId and (uid == nil or input.pendingUid == uid) then
		cta = { state = "loading", text = "Starting…", variant = "primary" }
	elseif not input.kingdom or not input.treasury then
		cta = { state = "disabled", text = "Loading your kingdom…", variant = "primary" }
	elseif check.ok then
		cta = { state = "ready", text = verb, icon = "build", variant = "primary" }
	else
		cta = {
			state = "disabled",
			text = Text.reason(check, buildingNames, currencies),
			icon = if check.reason == "requirement" then "lock" else nil,
			variant = "primary",
		}
	end

	local metaParts = { categoryLabel(def.building.category) }
	if upgrade then
		table.insert(metaParts, `Level {check.level - 1} → {check.level}`)
	else
		table.insert(metaParts, `Level 1`)
		table.insert(metaParts, `{check.count}/{check.maxCount} built`)
	end

	return {
		id = buildingId,
		uid = uid,
		action = check.action,
		name = def.name,
		icon = def.icon,
		category = def.building.category,
		categoryLabel = categoryLabel(def.building.category),
		level = check.level,
		description = def.description,
		meta = table.concat(metaParts, " · "),
		buildSec = check.buildSec,
		workers = level.workers,
		rate = rate,
		housing = level.housing,
		storage = level.storage,
		requirements = requirements,
		costs = costs,
		cta = cta,
		needsConfirm = check.ok and BuildMenuModel.isLargeSpend(check.cost, balances),
		check = check,
	}
end

function BuildMenuModel.build(input: { [string]: any }): any
	local catalog, currencies = input.catalog, input.currencies
	local kingdom = input.kingdom or EMPTY_KINGDOM
	local balances = if input.treasury then input.treasury.balances else {}
	local buildingNames = names(catalog)
	local rows = {}
	local selected = input.selected
	for _, def in catalog:buildings(input.category) do
		if def.building.prebuilt then
			continue -- the Town Hall is upgraded from the Kingdom panel, never built
		end
		local check = catalog:check(kingdom, balances, def.id)
		local costs = {}
		for _, entry in Bundle.ordered(check.cost, currencies:ids()) do
			table.insert(costs, {
				currency = entry.id,
				amount = entry.amount,
				short = (balances[entry.id] or 0) < entry.amount,
			})
		end
		local locked = check.reason == "requirement"
		table.insert(rows, {
			id = def.id,
			name = def.name,
			icon = def.icon,
			category = def.building.category,
			ok = check.ok,
			locked = locked,
			lockText = if locked then Text.requirement(check.unmet[1], buildingNames) else nil,
			count = check.count,
			maxCount = check.maxCount,
			costs = costs,
			selected = false,
		})
	end
	if
		selected == nil
		or catalog:building(selected) == nil
		or catalog:building(selected).building.category ~= input.category
	then
		selected = if rows[1] then rows[1].id else nil
	end
	for _, row in rows do
		row.selected = row.id == selected
	end
	return {
		loading = not input.kingdom or not input.treasury,
		tabs = BuildMenuModel.CATEGORIES,
		rows = rows,
		selected = selected,
		detail = if selected then BuildMenuModel.detail(input, selected) else nil,
	}
end

return table.freeze(BuildMenuModel)
