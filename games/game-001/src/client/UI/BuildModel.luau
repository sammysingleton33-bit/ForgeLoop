--!strict
--[[
	UI/BuildModel — the build menu and the upgrade screen as data (pure, no instances). It only
	compares costs with the treasury the server sent; whether a spot is valid, and whether the
	spend really happens, is the server's call (Build.CanPlace / Build.Place / Build.Upgrade).

	BuildModel.menu(store, { category, selected? }) -> View
		View = { loading, category, tabs, rows: { Row }, selected: string?, detail: Detail? }
		Row = { id (BuildingType), name, icon, category, built, ok, costs: { { currency, amount, short } } }
	BuildModel.placeDetail(store, type, { slot?, pending? }?) -> Detail?
		with a slot (G13.5 plot) the CTA reads "Build <name> here" and action is "slot"
	BuildModel.plotMenu(store, { slot, selected?, pending? }) -> View?   the plot picker (FL-0087):
		one tab named after the plot size, the SlotFit types that fit it
	BuildModel.upgradeDetail(store, building, { pending: boolean?, done: boolean? }?) -> Detail?
		Detail = { type, name, icon, category, description, meta, action ("place" | "upgrade"),
		           buildingId?, level, buildSeconds?, footprint: Vector2?,
		           costs: { { currency, name, amount, have, short } },
		           benefits: { { label, text, next: boolean? } },   UI/BuildingLevels lines ("Now", "Lv 2")
		           cta: { state ("ready" | "disabled" | "loading" | "done"), text, icon? },
		           needsConfirm: boolean, slotId? }
	BuildModel.footprint(type, level) -> Vector2?     Kit.footprint (G10), nil for unknown types
	BuildModel.room(type) -> Vector2?                 the ground the server keeps free for it: its
	                                                  largest-level footprint (Build/Fit) grown by
	                                                  Buildings.placementGap on every side (#62)
	BuildModel.isLargeSpend(cost, balances) -> boolean
		true when the total cost is at least LARGE_SPEND_MIN_TOTAL and takes at least
		LARGE_SPEND_SHARE of some balance: the UI then asks for confirmation first.
]]

local Bundle = require("@game/ReplicatedStorage/Forge/Economy/Bundle")
local BuildingLevels = require("./BuildingLevels")
local Buildings = require("./Buildings")
local Kit = require("@game/ReplicatedStorage/Game/Kit/Kit")
local Resources = require("@game/ReplicatedStorage/Forge/Config/Resources")
local BuildingsConfig = require("@game/ReplicatedStorage/Forge/Config/Buildings")
local Fit = require("@game/ReplicatedStorage/Game/Build/Fit")
local SlotFit = require("./SlotFit")
local Text = require("./Text")

local BuildModel = {}

BuildModel.LARGE_SPEND_MIN_TOTAL = 150
BuildModel.LARGE_SPEND_SHARE = 0.5

function BuildModel.isLargeSpend(cost: { [string]: number }, balances: { [string]: number }): boolean
	local total = 0
	for _, amount in cost do
		total += amount
	end
	if total < BuildModel.LARGE_SPEND_MIN_TOTAL then
		return false
	end
	for currency, amount in cost do
		local have = balances[currency] or 0
		if have > 0 and amount / have >= BuildModel.LARGE_SPEND_SHARE then
			return true
		end
	end
	return false
end

function BuildModel.footprint(buildingType: string, level: number): Vector2?
	local ok, size = pcall(Kit.footprint, buildingType, level)
	return if ok and typeof(size) == "Vector2" then size else nil
end

-- What Simulation:canPlace checks (FORGE-01 #62): this building's largest-level rectangle must stay
-- `placementGap` studs clear of other buildings' and of trees and rocks. The ghost draws it as an
-- outer outline so a red verdict near a neighbour is visible (FORGE-05 M-2 on #62).
function BuildModel.room(buildingType: string): Vector2?
	local largest = Fit.largestFootprint(buildingType)
	if largest == nil then
		return nil
	end
	local gap = BuildingsConfig.placementGap or 0
	return largest + Vector2.new(2 * gap, 2 * gap)
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

local function sizeText(size: Vector2?): string?
	return if size then `{math.floor(size.X)} × {math.floor(size.Y)} studs` else nil
end

function BuildModel.placeDetail(store: any, buildingType: string, opts: { slot: any?, pending: boolean? }?): any
	local info = Buildings.get(buildingType)
	if info == nil then
		return nil
	end
	local slot = if opts then opts.slot else nil
	local entry = store:buildingCost(buildingType, 1)
	local have = store:balances()
	local footprint = BuildModel.footprint(buildingType, 1)
	local cta
	if opts and opts.pending then
		cta = { state = "loading", text = "Starting…" }
	elseif not store:hasTreasury() or store:mine() == nil then
		cta = { state = "disabled", text = "Loading your kingdom…" }
	elseif entry == nil then
		cta = { state = "disabled", text = "Not available yet" }
	else
		local short = Text.missing(entry.cost, have)
		cta = if short
			then { state = "disabled", text = short }
			else {
				state = "ready",
				text = if slot then `Build {info.name} here` else `Place {info.name}`,
				icon = "build",
			}
	end
	local meta = { Buildings.categoryLabel(info.category) }
	if slot then
		table.insert(meta, `{SlotFit.NAMES[slot.size] or slot.size} plot`)
	else
		local size = sizeText(footprint)
		if size then
			table.insert(meta, size)
		end
	end
	local gives = BuildingLevels.benefit(buildingType, 1)
	return {
		type = buildingType,
		name = info.name,
		icon = info.icon,
		category = info.category,
		description = info.description,
		meta = table.concat(meta, " · "),
		action = if slot then "slot" else "place",
		slotId = if slot then slot.id else nil,
		level = 1,
		buildSeconds = if entry then entry.buildSeconds else nil,
		footprint = footprint,
		room = BuildModel.room(buildingType),
		costs = if entry then costRows(entry.cost, have) else {},
		benefits = if gives then { { label = "Gives", text = gives } } else {},
		cta = cta,
		needsConfirm = false, -- placing already asks for a spot and a second tap on Place
	}
end

function BuildModel.upgradeDetail(store: any, building: any, flags: { pending: boolean?, done: boolean? }?): any
	local info = Buildings.get(building.type)
	if info == nil then
		return nil
	end
	local nextLevel = building.level + 1
	local entry = store:buildingCost(building.type, nextLevel)
	local have = store:balances()
	local benefits = {}
	local now = BuildingLevels.benefit(building.type, building.level)
	if now then
		table.insert(benefits, { label = "Now", text = now })
	end
	local nextText = if entry then BuildingLevels.benefit(building.type, nextLevel) else nil
	if nextText then
		table.insert(benefits, { label = `Lv {nextLevel}`, text = nextText, next = true })
	end
	local cta
	if flags and flags.done then
		cta = { state = "done", text = "Upgrade started", icon = "check" }
	elseif flags and flags.pending then
		cta = { state = "loading", text = "Starting…" }
	elseif entry == nil then
		cta = { state = "disabled", text = "Highest level reached" }
	elseif building.state ~= "complete" then
		cta = { state = "disabled", text = "Finish building it first" }
	else
		local short = Text.missing(entry.cost, have)
		cta = if short
			then { state = "disabled", text = short }
			else { state = "ready", text = `Upgrade to Lv {nextLevel}`, icon = "build" }
	end
	return {
		type = building.type,
		name = info.name,
		icon = info.icon,
		category = info.category,
		description = info.description,
		meta = if entry
			then `{info.name} · Level {building.level} → {nextLevel}`
			else `{info.name} · Level {building.level}`,
		action = "upgrade",
		buildingId = building.id,
		level = nextLevel,
		buildSeconds = if entry then entry.buildSeconds else nil,
		footprint = BuildModel.footprint(building.type, nextLevel),
		costs = if entry then costRows(entry.cost, have) else {},
		benefits = benefits,
		cta = cta,
		needsConfirm = cta.state == "ready" and entry ~= nil and BuildModel.isLargeSpend(entry.cost, have),
	}
end

local function row(store: any, info: any, have: { [string]: number }): any
	local entry = store:buildingCost(info.type, 1)
	local costs = {}
	if entry then
		for _, c in costRows(entry.cost, have) do
			table.insert(costs, { currency = c.currency, amount = c.amount, short = c.short })
		end
	end
	return {
		id = info.type,
		name = info.name,
		icon = info.icon,
		category = info.category,
		built = store:count(info.type),
		ok = entry ~= nil and Bundle.covers(have, entry.cost),
		costs = costs,
	}
end

local function pick(rows: { any }, selected: string?): string?
	for _, r in rows do
		if r.id == selected then
			return selected
		end
	end
	return if rows[1] then rows[1].id else nil
end

function BuildModel.plotMenu(store: any, input: { slot: any, selected: string?, pending: boolean? }): any
	local slot = input.slot
	if slot == nil then
		return nil
	end
	local have = store:balances()
	local rows = {}
	for _, buildingType in SlotFit.typesFor(slot) do
		local info = Buildings.get(buildingType)
		if info then
			table.insert(rows, row(store, info, have))
		end
	end
	local selected = pick(rows, input.selected)
	local label = `{SlotFit.NAMES[slot.size] or slot.size} plot`
	return {
		empty = if #rows == 0 then "Nothing can be built on this plot yet." else nil,
		loading = not store:hasTreasury() or store:mine() == nil,
		category = "plot",
		tabs = { { id = "plot", label = label, icon = "build" } },
		rows = rows,
		selected = selected,
		detail = if selected
			then BuildModel.placeDetail(store, selected, { slot = slot, pending = input.pending })
			else nil,
	}
end

function BuildModel.menu(store: any, input: { category: string, selected: string? }): any
	local have = store:balances()
	local rows = {}
	for _, info in Buildings.menu(input.category) do
		table.insert(rows, row(store, info, have))
	end
	local selected = pick(rows, input.selected)
	return {
		loading = not store:hasTreasury() or store:mine() == nil,
		category = input.category,
		tabs = Buildings.CATEGORIES,
		rows = rows,
		selected = selected,
		detail = if selected then BuildModel.placeDetail(store, selected) else nil,
	}
end

return table.freeze(BuildModel)
