--!strict
--[[
	UI/KingdomStore — the client's copy of the state the kingdom screens show, fed only by the
	CONTRACTS G8 remotes. Nothing here decides an outcome: the server validates every action and
	these values change only when its replies or pushes arrive.

	KingdomStore.new() -> store
	Feeding (each call fires store.changed(what, ...)):
		store:applyKingdoms(payload)              Kingdom.State / Kingdom.GetState { kingdoms, mine }
		store:applyMatch(phase, endsAt?, startedAt?)   Match.State / Match.GetState
		store:applyTreasury(totals, deltas?)      Treasury.Changed / Treasury.Get (my kingdom's bag)
		store:applyBuildings(list, full)          Build.GetBuildings (full = true) / Build.Buildings (changes)
		store:applyCosts(catalogue)               Treasury.GetCosts (config Costs is the fallback)
		store:applySlots(list)                    Build.Slots / Build.GetSlots: my kingdom's plots (G13.5)
		store:applyPopulation(payload)            Kingdom.Population / Kingdom.GetPopulation: my kingdom's
		                                          CitizenService:getPopulation { total, byJob, cap, quotas? }
		                                          (G13.2; soldiers count as byJob.soldier; quotas proposed)
		store:clearPopulation()                   another kingdom: forget the old counts
	Reading:
		store:mine() -> Kingdom?                  store:kingdoms() -> { Kingdom } (server order)
		store:myBuildings() -> { Building }       mine, by id, destroyed ones dropped
		store:keep() -> Building?                 store:count(type) -> number
		store:balances() -> ResourceBag           ({} until the treasury arrives)
		store:hasTreasury() -> boolean
		store:buildingCost(type, level) -> { cost, buildSeconds }?
		store:slot(id) -> { id, size, occupiedBy? }?   store:slots() -> { slot } (by id)
		store:building(id) -> Building?           any kingdom's building (foreign ones too)
		store:population() -> { total, byJob, cap?, quotas? }?   nil until the server sends it
		store.match = { phase, endsAt?, startedAt? }?
		store.changed: Signal<(what: "kingdoms" | "match" | "treasury" | "buildings" | "costs" | "slots"
			| "population", ...)>
			"treasury" also passes the deltas, so the HUD can float them under the pills.
	Payloads are checked loosely (wrong types are ignored with no error): a bad push must never
	break the HUD.
]]

local Costs = require("@game/ReplicatedStorage/Forge/Config/Costs")
local Signal = require("@game/ReplicatedStorage/Forge/Core/Signal")

local KingdomStore = {}
KingdomStore.__index = KingdomStore

function KingdomStore.new()
	return setmetatable({
		_kingdoms = {} :: { any },
		_byId = {} :: { [string]: any },
		_mine = nil :: string?,
		_treasury = nil :: { [string]: number }?,
		_buildings = {} :: { [number]: any },
		_costs = nil :: any,
		_slots = {} :: { [string]: any },
		match = nil :: any,
		changed = Signal.new(),
	}, KingdomStore)
end

local function isBag(value: any): boolean
	if type(value) ~= "table" then
		return false
	end
	for key, amount in value do
		if type(key) ~= "string" or type(amount) ~= "number" or amount ~= amount then
			return false
		end
	end
	return true
end

function KingdomStore:applyKingdoms(payload: any)
	if type(payload) ~= "table" or type(payload.kingdoms) ~= "table" then
		return
	end
	local list, byId = {}, {}
	for _, kingdom in payload.kingdoms do
		if type(kingdom) == "table" and type(kingdom.id) == "string" then
			table.insert(list, kingdom)
			byId[kingdom.id] = kingdom
		end
	end
	self._kingdoms = list
	self._byId = byId
	self._mine = if type(payload.mine) == "string" then payload.mine else nil
	self.changed:fire("kingdoms")
end

function KingdomStore:applyMatch(phase: any, endsAt: any, startedAt: any)
	if type(phase) ~= "string" then
		return
	end
	self.match = {
		phase = phase,
		endsAt = if type(endsAt) == "number" then endsAt else nil,
		startedAt = if type(startedAt) == "number" then startedAt else nil,
	}
	self.changed:fire("match")
end

function KingdomStore:applyTreasury(totals: any, deltas: any)
	if not isBag(totals) then
		return
	end
	self._treasury = table.clone(totals)
	self.changed:fire("treasury", if isBag(deltas) then deltas else nil)
end

function KingdomStore:applyBuildings(list: any, full: boolean)
	if type(list) ~= "table" then
		return
	end
	if full then
		self._buildings = {}
	end
	for _, building in list do
		if type(building) == "table" and type(building.id) == "number" and type(building.type) == "string" then
			if building.state == "destroyed" then
				self._buildings[building.id] = nil
			else
				self._buildings[building.id] = building
			end
		end
	end
	self.changed:fire("buildings")
end

function KingdomStore:applyCosts(catalogue: any)
	if type(catalogue) ~= "table" or type(catalogue.buildings) ~= "table" then
		return
	end
	self._costs = catalogue
	self.changed:fire("costs")
end

function KingdomStore:applySlots(list: any)
	if type(list) ~= "table" then
		return
	end
	local slots = {}
	for _, slot in list do
		if
			type(slot) == "table"
			and type(slot.id) == "string"
			and (slot.size == "S" or slot.size == "M" or slot.size == "L")
		then
			slots[slot.id] = slot
		end
	end
	self._slots = slots
	self.changed:fire("slots")
end

function KingdomStore:slot(id: any): any
	return if type(id) == "string" then self._slots[id] else nil
end

-- A count the HUD may show: a finite whole number >= 0 (no NaN, no inf, no negatives; L3).
local function count(value: any): number?
	if type(value) ~= "number" or value ~= value or value < 0 or value == math.huge then
		return nil
	end
	return math.floor(value)
end

local function counts(map: any): { [string]: number }?
	if type(map) ~= "table" then
		return nil
	end
	local out = {}
	for key, value in map do
		local n = count(value)
		if type(key) == "string" and n then
			out[key] = n
		end
	end
	return out
end

function KingdomStore:applyPopulation(payload: any)
	local byJob = if type(payload) == "table" then counts(payload.byJob) else nil
	if byJob == nil then
		return
	end
	self._population = {
		total = count(payload.total) or 0,
		cap = count(payload.cap),
		byJob = byJob,
		quotas = counts(payload.quotas),
	}
	self.changed:fire("population")
end

function KingdomStore:clearPopulation()
	if self._population ~= nil then
		self._population = nil
		self.changed:fire("population")
	end
end

function KingdomStore:population(): any
	local p = self._population
	if p == nil then
		return nil
	end
	return {
		total = p.total,
		cap = p.cap,
		byJob = table.clone(p.byJob),
		quotas = if p.quotas then table.clone(p.quotas) else nil,
	}
end

function KingdomStore:slots(): { any }
	local out = {}
	for _, slot in self._slots do
		table.insert(out, slot)
	end
	table.sort(out, function(a, b)
		return a.id < b.id
	end)
	return out
end

-- Ids from a tap arrive from an instance attribute (FORGE-04's InputModeController reads
-- `BuildingId`), which may be a number or its string.
function KingdomStore:building(id: any): any
	local n = if type(id) == "string" then tonumber(id) else id
	return if type(n) == "number" then self._buildings[n] else nil
end

function KingdomStore:mine(): any
	return if self._mine then self._byId[self._mine] else nil
end

function KingdomStore:kingdoms(): { any }
	return table.clone(self._kingdoms)
end

function KingdomStore:myBuildings(): { any }
	local mine = self._mine
	local out = {}
	if mine == nil then
		return out
	end
	for _, building in self._buildings do
		if building.kingdom == mine then
			table.insert(out, building)
		end
	end
	table.sort(out, function(a, b)
		return a.id < b.id
	end)
	return out
end

function KingdomStore:keep(): any
	local kingdom = self:mine()
	if kingdom and type(kingdom.keepBuildingId) == "number" then
		local building = self._buildings[kingdom.keepBuildingId]
		if building then
			return building
		end
	end
	for _, building in self:myBuildings() do
		if building.type == "keep" then
			return building
		end
	end
	return nil
end

function KingdomStore:count(buildingType: string): number
	local n = 0
	for _, building in self:myBuildings() do
		if building.type == buildingType then
			n += 1
		end
	end
	return n
end

function KingdomStore:balances(): { [string]: number }
	return if self._treasury then table.clone(self._treasury) else {}
end

function KingdomStore:hasTreasury(): boolean
	return self._treasury ~= nil
end

function KingdomStore:buildingCost(
	buildingType: string,
	level: number
): { cost: { [string]: number }, buildSeconds: number }?
	local catalogue = self._costs
	if catalogue then
		local levels = catalogue.buildings[buildingType]
		local entry = if type(levels) == "table" then levels[level] else nil
		if type(entry) == "table" and isBag(entry.cost) and type(entry.buildSeconds) == "number" then
			return { cost = table.clone(entry.cost), buildSeconds = entry.buildSeconds }
		end
		return nil
	end
	return Costs.building(buildingType, level)
end

return KingdomStore
