--!strict
--[[
	UI/Kingdom/KingdomPanelModel — kingdom overview, building list and construction queue as data
	(pure). Times use server time (`now` = workspace:GetServerTimeNow()) against the snapshot's
	`completesAt`, so every client shows the same countdown.

	KingdomPanelModel.overview(kingdom, treasury, catalog, currencies) -> {
		name, hall, tiles, rank?, kingdoms?, tincture,
		citizens = { total, housing, working, building, idle },
		production = { { currency, name, perMinute, amount, cap } } }      match currencies, display order
	KingdomPanelModel.buildings(kingdom, treasury, catalog, now) -> { Row }
		Row = { uid, buildingId, name, icon, category, level, state, progress?, timeLeft?, workers,
		        slots, canAdd, canRemove, rate: { { currency, perMinute } }, housing?, storage?,
		        canUpgrade, upgradeText }   ordered: Town Hall first, then construction in progress,
		        then by config order
	KingdomPanelModel.queue(kingdom, catalog, now) -> { { uid, buildingId, name, icon, category,
		progress, timeLeft, upgrade } }   constructions and upgrades in progress, soonest first
]]

local Bundle = require("@game/ReplicatedStorage/Forge/Economy/Bundle")

local KingdomPanelModel = {}

local function order(catalog: any): { [string]: number }
	local out = {}
	for i, def in catalog:buildings() do
		out[def.id] = i
	end
	return out
end

local function progressOf(b: any, now: number): (number?, number?)
	if b.state == "ready" or b.completesAt == nil then
		return nil, nil
	end
	local started = b.startedAt or now
	local total = math.max(0.001, b.completesAt - started)
	local left = math.max(0, b.completesAt - now)
	return math.clamp(1 - left / total, 0, 1), left
end

function KingdomPanelModel.overview(kingdom: any, treasury: any, catalog: any, currencies: any): any
	local production = catalog:production(kingdom)
	local rows = {}
	for _, id in currencies:ids("match") do
		local def = currencies:get(id)
		table.insert(rows, {
			currency = id,
			name = def.name,
			perMinute = production[id] or 0,
			amount = if treasury then treasury.balances[id] or 0 else 0,
			cap = if treasury then treasury.caps[id] or 0 else 0,
		})
	end
	local c = kingdom.citizens or {}
	return {
		name = kingdom.name,
		hall = kingdom.hall or 1,
		tiles = if kingdom.territory then kingdom.territory.tiles else 0,
		rank = kingdom.rank,
		kingdoms = kingdom.kingdoms,
		tincture = kingdom.tincture or "azure",
		citizens = {
			total = c.total or 0,
			housing = c.housing or 0,
			working = c.working or 0,
			building = c.building or 0,
			idle = c.idle or 0,
		},
		production = rows,
	}
end

function KingdomPanelModel.buildings(kingdom: any, treasury: any, catalog: any, now: number): { any }
	local rank = order(catalog)
	local balances = if treasury then treasury.balances else {}
	local idle = if kingdom.citizens then kingdom.citizens.idle or 0 else 0
	local rows = {}
	for _, b in kingdom.buildings do
		local def = catalog:building(b.buildingId)
		if def == nil then
			continue
		end
		local level = if b.level >= 1 then catalog:level(b.buildingId, b.level) else nil
		local slots = if level and level.workers then level.workers else 0
		local workers = b.workers or 0
		local progress, left = progressOf(b, now)
		local rate = {}
		for _, entry in Bundle.ordered(catalog:rate(b.buildingId, math.max(b.level, 1), workers), {}) do
			table.insert(rate, { currency = entry.id, perMinute = entry.amount })
		end
		local check = catalog:check(kingdom, balances, b.buildingId, b.uid)
		table.insert(rows, {
			uid = b.uid,
			buildingId = b.buildingId,
			name = def.name,
			icon = def.icon,
			category = def.building.category,
			level = b.level,
			state = b.state,
			progress = progress,
			timeLeft = left,
			workers = workers,
			slots = slots,
			canAdd = b.state ~= "constructing" and workers < slots and idle > 0,
			canRemove = b.state ~= "constructing" and workers > 0,
			rate = rate,
			housing = if level then level.housing else nil,
			storage = if level then level.storage else nil,
			canUpgrade = b.state == "ready" and check.reason ~= "max_level",
			upgradeText = if check.reason == "max_level" then "Max level" else "Upgrade",
			_rank = rank[b.buildingId] or 999,
		})
	end
	table.sort(rows, function(a, b)
		local ap = if a.state == "ready" then 1 else 0
		local bp = if b.state == "ready" then 1 else 0
		if a.buildingId == "townhall" or b.buildingId == "townhall" then
			return a.buildingId == "townhall" and b.buildingId ~= "townhall"
		end
		if ap ~= bp then
			return ap < bp
		end
		if a._rank ~= b._rank then
			return a._rank < b._rank
		end
		return a.uid < b.uid
	end)
	for _, row in rows do
		row._rank = nil
	end
	return rows
end

function KingdomPanelModel.queue(kingdom: any, catalog: any, now: number): { any }
	local out = {}
	for _, b in kingdom.buildings do
		local progress, left = progressOf(b, now)
		local def = catalog:building(b.buildingId)
		if progress ~= nil and def then
			table.insert(out, {
				uid = b.uid,
				buildingId = b.buildingId,
				name = def.name,
				icon = def.icon,
				category = def.building.category,
				progress = progress,
				timeLeft = left,
				upgrade = b.state == "upgrading",
			})
		end
	end
	table.sort(out, function(a, b)
		if a.timeLeft ~= b.timeLeft then
			return a.timeLeft < b.timeLeft
		end
		return a.uid < b.uid
	end)
	return out
end

return table.freeze(KingdomPanelModel)
