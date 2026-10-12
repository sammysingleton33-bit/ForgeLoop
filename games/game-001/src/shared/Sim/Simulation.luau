--!strict
--[[
	Sim/Simulation — the authoritative, deterministic kingdom simulation.

	Pure Luau: no Roblox services, no wall clock, no global randomness. The server host steps it on
	a fixed tick and turns its events into GameEvents/remotes; Lune specs step it directly. Same seed +
	same commands = same world, so bugs reproduce and balance can be simulated headlessly.

	Construction
		Simulation.new({ catalog: Catalog?, random: RandomLike, bounds: Bounds?, treasury: Treasury?, costs: Costs? })
			random    an object with :NextNumber() and :NextInteger(a, b) (env.random(seed) / Random.new)
			bounds    { minX, maxX, minZ, maxZ } in studs; placement outside is rejected (default ±1024)
			treasury  CONTRACTS G7 TreasuryService (get/canAfford/spend/deposit, txIds); default TreasuryDouble
			costs     CONTRACTS G6 Costs (building(type, level) -> { cost, buildSeconds }, unit(type));
			          default Catalog.costs(catalog), the double of FORGE-03's Costs.luau

	World setup
		sim:addKingdom({ id, name, color: {number}, x, z }): Kingdom   -- keep + start buildings + citizens;
		                                                                  seeds the treasury when it is the double
		sim:addNode(kind, x, z, id?): Node                             -- tree / rock / goldvein / berries
	Time
		sim:advance(seconds)        -- runs whole fixed ticks (catalog.tuning.tickSeconds); remainder carried
		sim:step()                  -- exactly one tick
		sim.time, sim:day(), sim:dayFraction(), sim:isNight()
		sim.active: boolean         -- false = frozen (lobby/results): advance() does nothing
	Rulers (shared ownership: every ruler of a kingdom has the same command rights)
		sim:addRuler(kingdomId, userId): (boolean, string?)   sim:removeRuler(userId)
		sim:kingdomOfUser(userId): Kingdom?
		sim:setRulerPosition(userId, x?, z?)   -- the host mirrors characters (objectives count rulers)
	Treasury, Crown Points, territory
		sim:balance(kingdomId, resource), sim:canAfford(kingdomId, cost), sim:spend(kingdomId, cost, txId, sink),
		sim:deposit(kingdomId, resource, amount, txId, source)          -- thin G7 wrappers
		sim:addCrownPoints(kingdomId, amount, reason)                   -- emits CrownPoints
		sim:claimRegion(kingdomId, regionId, x, z, radius, reason), sim:releaseRegion(regionId)
		sim:territoryOwner(x, z): KingdomId?   -- keep circles first, then claimed regions
	Construction (called by Commands after validation; also usable by AI rulers)
		sim:canPlace(kingdom, kind, x, z): (boolean, string?)
		sim:placeBuilding(kingdom, kind, x, z, byUserId?): (Building?, string?)
		sim:startUpgrade(kingdom, buildingId, byUserId?): (boolean, string?)
		sim:cancelConstruction(kingdom, buildingId, byUserId?): (boolean, string?)
	Views
		sim:buildingView(id) / sim:viewOf(record): CONTRACTS G2 Building (cframe, footprint, state, ...)
	Queries (used by CitizenBrain / CitizenActions / Snapshot)
		sim:hasOpenSite(kingdom), sim:needTarget(kingdom, resource), sim:threatNear(kingdom, x, z, r)
		sim:findWorkTarget(kingdom, kind, citizen): (target?, distance), sim:nearestDropoff(kingdom, x, z)
		sim:citizensOf(kingdom) / sim:buildingsOf(kingdom): arrays in creation order
		sim:population(kingdom), sim:atWar(kingdomIdA, kingdomIdB)
	Events
		sim:drainEvents(): { Event }   -- everything since the last drain, in order; Event = { name, ... }
		  ResourceGathered   { kingdomId, resource, amount, source = "citizen" | "ruler", citizenId?, userId? }
		  BuildingPlaced     { kingdomId, buildingId, kind, x, z, by }
		  UpgradeStarted     { kingdomId, buildingId, kind, level, by }
		  BuildingCompleted  { kingdomId, buildingId, kind, level }
		  ConstructionCancelled { kingdomId, buildingId, kind, refund, by }
		  CitizenBorn        { kingdomId, citizenId, job }
		  CitizenDied        { kingdomId, citizenId, cause }
		  CitizenReassigned  { kingdomId, citizenId, from, to }      CrownPoints { kingdomId, amount, total, reason }
		  RegionClaimed { kingdomId, regionId, reason }              RegionReleased { kingdomId, regionId }
		  NodeDepleted       { nodeId, resource }          NodeRegrown { nodeId, resource }
		  AlarmChanged       { kingdomId, on, by }
		  DayStarted         { day }        NightFell { day }
		  RulerJoined        { kingdomId, userId }   RulerLeft { kingdomId, userId }
		  (Military/Diplomacy add their own; see those modules.)

	Ids: citizens and soldiers share one numeric EntityId space; buildings have their own numeric ids;
	resource nodes keep string ids (they come from map tags). Ids are never reused within a match.
	Invariants (covered by specs): the treasury ledger audits exactly and never goes negative; a claim
	slot is never over-subscribed; iteration order is creation order (deterministic).
]]

local Catalog = require("./Catalog")
local CitizenActions = require("./CitizenActions")
local CitizenBrain = require("./CitizenBrain")
local TreasuryDouble = require("./TreasuryDouble")

type Catalog = Catalog.Catalog

export type Bounds = { minX: number, maxX: number, minZ: number, maxZ: number }
export type Event = { [string]: any }

local Simulation = {}
Simulation.__index = Simulation

Simulation.SITE_BUILDERS = 3
Simulation.QUOTA_INTERVAL = 1
Simulation.CITIZEN_HP = 40

local NAMES = {
	"Ada",
	"Bram",
	"Cora",
	"Dain",
	"Edda",
	"Finn",
	"Greta",
	"Hal",
	"Ione",
	"Jory",
	"Kael",
	"Lise",
	"Mott",
	"Nell",
	"Osric",
	"Pia",
	"Quill",
	"Rhea",
	"Sven",
	"Tova",
	"Ulf",
	"Vera",
	"Wynn",
	"Yara",
}

local function dist(ax: number, az: number, bx: number, bz: number): number
	local dx, dz = ax - bx, az - bz
	return math.sqrt(dx * dx + dz * dz)
end

function Simulation.new(options: { [string]: any })
	local catalog: Catalog = options.catalog or Catalog.default()
	local ok, errors = Catalog.validate(catalog)
	if not ok then
		error("Simulation: invalid catalog:\n  " .. table.concat(errors, "\n  "), 2)
	end
	assert(options.random ~= nil, "Simulation.new: random is required (env.random(seed))")
	local self = setmetatable({}, Simulation)
	self.catalog = catalog
	self.rng = options.random
	self.treasury = options.treasury or TreasuryDouble.new()
	self.costs = options.costs or Catalog.costs(catalog)
	self.rulerPositions = {} :: { [number]: { x: number, z: number } }
	self.regions = {} :: { [string]: any }
	self.regionOrder = {} :: { string }
	self._nextEntity = 0
	self._nextBuilding = 0
	self.bounds = options.bounds or { minX = -1024, maxX = 1024, minZ = -1024, maxZ = 1024 }
	self.time = 0
	self.tick = 0
	self.active = true
	self.kingdoms = {} :: { [string]: any }
	self.kingdomOrder = {} :: { string }
	self.buildings = {} :: { [number]: any }
	self.buildingOrder = {} :: { number }
	self.citizens = {} :: { [number]: any }
	self.citizenOrder = {} :: { number }
	self.nodes = {} :: { [string]: any }
	self.nodeOrder = {} :: { string }
	self.units = {} :: { [number]: any }
	self.unitOrder = {} :: { number }
	self.rulerOf = {} :: { [number]: string }
	self.relations = {} :: { [string]: string }
	self._ids = {} :: { [string]: number }
	self._events = {} :: { Event }
	self._accum = 0
	self._quotaAccum = 0
	self._systems = {} :: { any } -- extra per-tick systems: { beforeCitizens?(sim, dt), afterCitizens?(sim, dt) }
	self.extraCommands = {} :: { [string]: any } -- installed by Military/Diplomacy (Commands.install)
	return self
end

-- ---------------------------------------------------------------- ids, events, time
function Simulation:_newId(prefix: string): string
	local n = (self._ids[prefix] or 0) + 1
	self._ids[prefix] = n
	return prefix .. tostring(n)
end

-- EntityId (G2/G4): citizens and soldiers share one numeric space, never reused.
function Simulation:newEntityId(): number
	self._nextEntity += 1
	return self._nextEntity
end

function Simulation:emit(name: string, payload: { [string]: any }?)
	local event = payload or {}
	event.name = name
	event.t = self.time
	table.insert(self._events, event)
end

function Simulation:drainEvents(): { Event }
	local events = self._events
	self._events = {}
	return events
end

function Simulation:addSystem(system: any)
	table.insert(self._systems, system)
end

function Simulation:day(): number
	return math.floor(self.time / self.catalog.tuning.dayLength) + 1
end

function Simulation:dayFraction(): number
	local len = self.catalog.tuning.dayLength
	return (self.time % len) / len
end

function Simulation:isNight(): boolean
	return self:dayFraction() >= self.catalog.tuning.nightStart
end

function Simulation:relationKey(a: string, b: string): string
	return if a < b then a .. "|" .. b else b .. "|" .. a
end

function Simulation:atWar(a: string, b: string): boolean
	return a ~= b and self.relations[self:relationKey(a, b)] == "War"
end

-- ---------------------------------------------------------------- setup
function Simulation:addKingdom(def: { [string]: any })
	assert(type(def.id) == "string" and self.kingdoms[def.id] == nil, "addKingdom: unique string id required")
	local tuning = self.catalog.tuning
	local kingdom = {
		id = def.id,
		index = #self.kingdomOrder + 1,
		name = def.name or def.id,
		color = def.color or { 200, 200, 200 },
		x = def.x,
		z = def.z,
		keepId = 0,
		rulers = {} :: { number },
		crownPoints = 0,
		buildingIds = {} :: { number },
		citizenIds = {} :: { number },
		unitIds = {} :: { number },
		quotas = table.clone(tuning.startCitizens),
		priorities = { food = 1, wood = 1, stone = 1, gold = 1 },
		alarm = false,
		alive = true,
		eliminatedAt = nil :: number?,
		eliminatedBy = nil :: string?,
		nextBirthAt = tuning.birthInterval,
		popCap = 0,
		territory = 0,
		threats = {} :: { any },
		nearNodes = {} :: { string },
		stats = {
			gathered = { food = 0, wood = 0, stone = 0, gold = 0 },
			born = 0,
			died = 0,
			built = 0,
			conquered = 0,
			unitsTrained = 0,
			unitsLost = 0,
			unitsKilled = 0,
		},
	}
	self.kingdoms[kingdom.id] = kingdom
	table.insert(self.kingdomOrder, kingdom.id)
	if self.treasury.seed then
		self.treasury:seed(kingdom.id, tuning.startResources) -- the double only; FORGE-03 seeds the real one
	end
	for _, other in self.kingdomOrder do
		if other ~= kingdom.id then
			self.relations[self:relationKey(other, kingdom.id)] = "Peace"
		end
	end

	local keep = self:_createBuilding(kingdom, "keep", def.x, def.z)
	self:_completeInstantly(keep)
	kingdom.keepId = keep.id
	-- starting buildings (a farm), placed relative to the direction toward the map centre
	local toCentre = if def.x == 0 and def.z == 0 then 0 else math.atan2(-def.z, -def.x)
	for _, entry in tuning.startBuildings or {} do
		local angle = toCentre + entry.angle
		local b = self:_createBuilding(
			kingdom,
			entry.kind,
			def.x + math.cos(angle) * entry.distance,
			def.z + math.sin(angle) * entry.distance
		)
		self:_completeInstantly(b)
	end
	self:_recompute(kingdom)

	-- start citizens in a ring around the keep, in job order (deterministic)
	local ring = self.catalog.buildings.keep.footprint + 4
	local total = 0
	for _, occ in self.catalog.jobOrder do
		total += tuning.startCitizens[occ] or 0
	end
	local i = 0
	for _, occ in self.catalog.jobOrder do
		for _ = 1, tuning.startCitizens[occ] or 0 do
			local angle = (i / math.max(1, total)) * math.pi * 2
			self:_spawnCitizen(kingdom, occ, def.x + math.cos(angle) * ring, def.z + math.sin(angle) * ring)
			i += 1
		end
	end
	self:_assignHomes(kingdom)
	return kingdom
end

function Simulation:addNode(kind: string, x: number, z: number, id: string?)
	local def = self.catalog.nodes[kind]
	assert(def ~= nil, `addNode: unknown node kind '{kind}'`)
	local nodeId = id or self:_newId("n")
	assert(self.nodes[nodeId] == nil, `addNode: duplicate node id '{nodeId}'`)
	local node = {
		id = nodeId,
		kind = kind,
		resource = def.resource,
		x = x,
		z = z,
		amount = def.amount,
		footprint = def.footprint,
		slots = def.slots,
		claims = 0,
		capacity = def.amount,
		regrow = def.regrow,
		depletedAt = nil :: number?,
	}
	self.nodes[node.id] = node
	table.insert(self.nodeOrder, node.id)
	for _, kid in self.kingdomOrder do
		self:_refreshNearNodes(self.kingdoms[kid])
	end
	return node
end

function Simulation:_createBuilding(kingdom: any, kind: string, x: number, z: number)
	local def = self.catalog.buildings[kind]
	self._nextBuilding += 1
	local building = {
		id = self._nextBuilding,
		kind = kind,
		kingdomId = kingdom.id,
		x = x,
		z = z,
		footprint = def.footprint,
		level = 0,
		pendingLevel = 1 :: number?,
		pendingCost = nil :: { [string]: number }?,
		progress = 0,
		hp = math.max(1, math.floor(def.levels[1].hp * 0.1)),
		maxHp = def.levels[1].hp,
		destroyed = false,
		workers = {} :: { string },
		builders = {} :: { string },
		cooldown = 0,
		queue = {} :: { any },
	}
	self.buildings[building.id] = building
	table.insert(self.buildingOrder, building.id)
	table.insert(kingdom.buildingIds, building.id)
	return building
end

function Simulation:_completeInstantly(b: any)
	local stats = self.catalog.buildings[b.kind].levels[1]
	b.level = 1
	b.pendingLevel = nil
	b.progress = 0
	b.maxHp = stats.hp
	b.hp = stats.hp
end

function Simulation:_spawnCitizen(kingdom: any, job: string, x: number, z: number)
	local id = self:newEntityId()
	local citizen = {
		id = id,
		kind = "citizen",
		kingdomId = kingdom.id,
		name = NAMES[((id - 1) % #NAMES) + 1],
		job = job,
		tripSeq = 0,
		x = x,
		z = z,
		home = nil :: number?,
		activity = "Idle",
		target = nil :: any,
		phase = "Go",
		reason = "spawned",
		carrying = nil :: { resource: string, amount: number }?,
		workTimer = 0,
		restUntil = 0,
		wander = nil :: { x: number, z: number }?,
		hunger = 0,
		thinkAt = self.time + self.rng:NextNumber() * self.catalog.tuning.thinkInterval,
		memory = {} :: { any },
		claim = nil :: { kind: string, id: any }?,
		done = true,
		alive = true,
		hp = Simulation.CITIZEN_HP,
	}
	self.citizens[id] = citizen
	table.insert(self.citizenOrder, id)
	table.insert(kingdom.citizenIds, id)
	return citizen
end

-- ---------------------------------------------------------------- rulers
function Simulation:addRuler(kingdomId: string, userId: number): (boolean, string?)
	local kingdom = self.kingdoms[kingdomId]
	if kingdom == nil then
		return false, "unknown_kingdom"
	end
	if self.rulerOf[userId] ~= nil then
		return false, "already_ruler"
	end
	table.insert(kingdom.rulers, userId)
	self.rulerOf[userId] = kingdomId
	self:emit("RulerJoined", { kingdomId = kingdomId, userId = userId })
	return true, nil
end

function Simulation:removeRuler(userId: number): boolean
	local kingdomId = self.rulerOf[userId]
	if kingdomId == nil then
		return false
	end
	local kingdom = self.kingdoms[kingdomId]
	local index = table.find(kingdom.rulers, userId)
	if index then
		table.remove(kingdom.rulers, index)
	end
	self.rulerOf[userId] = nil
	self.rulerPositions[userId] = nil
	self:emit("RulerLeft", { kingdomId = kingdomId, userId = userId })
	return true
end

function Simulation:kingdomOfUser(userId: number): any?
	local id = self.rulerOf[userId]
	return if id then self.kingdoms[id] else nil
end

-- ---------------------------------------------------------------- derived kingdom stats
function Simulation:_recompute(kingdom: any)
	local popCap, territory = 0, 0
	for _, bid in kingdom.buildingIds do
		local b = self.buildings[bid]
		if b.destroyed or b.level < 1 then
			continue
		end
		local stats = self.catalog.buildings[b.kind].levels[b.level]
		popCap += stats.popCap or 0
		if b.kind == "keep" then
			territory = stats.territory or 0
		end
	end
	kingdom.popCap = popCap
	if territory ~= kingdom.territory then
		kingdom.territory = territory
		self:_refreshNearNodes(kingdom)
	end
end

function Simulation:_refreshNearNodes(kingdom: any)
	local reach = math.max(kingdom.territory, 1) * 2
	local list = {}
	for _, nid in self.nodeOrder do
		local node = self.nodes[nid]
		if dist(node.x, node.z, kingdom.x, kingdom.z) <= reach then
			table.insert(list, nid)
		end
	end
	kingdom.nearNodes = list
end

function Simulation:_assignHomes(kingdom: any)
	-- fill houses first (in creation order), then the keep
	local beds = {}
	local keepBeds = 0
	for _, bid in kingdom.buildingIds do
		local b = self.buildings[bid]
		if b.destroyed or b.level < 1 then
			continue
		end
		local cap = self.catalog.buildings[b.kind].levels[b.level].popCap or 0
		if b.kind == "keep" then
			keepBeds = cap
		elseif cap > 0 then
			table.insert(beds, { id = bid, free = cap })
		end
	end
	local bi = 1
	for _, cid in kingdom.citizenIds do
		local c = self.citizens[cid]
		while beds[bi] and beds[bi].free <= 0 do
			bi += 1
		end
		if beds[bi] then
			c.home = beds[bi].id
			beds[bi].free -= 1
		elseif keepBeds > 0 then
			c.home = kingdom.keepId
			keepBeds -= 1
		else
			c.home = nil
		end
	end
end

function Simulation:population(kingdom: any): number
	return #kingdom.citizenIds + #kingdom.unitIds
end

-- Units paid for and still training in this kingdom's barracks (they will need a bed too).
function Simulation:queuedUnits(kingdom: any): number
	local n = 0
	for _, bid in kingdom.buildingIds do
		local b = self.buildings[bid]
		if b.queue then
			n += #b.queue
		end
	end
	return n
end

-- CitizenService:getPopulation (G5): { total, byJob, cap }; soldiers count as job "soldier".
function Simulation:getPopulation(kingdom: any): { total: number, byJob: { [string]: number }, cap: number }
	local byJob: { [string]: number } = { soldier = #kingdom.unitIds }
	for _, cid in kingdom.citizenIds do
		local job = self.citizens[cid].job
		byJob[job] = (byJob[job] or 0) + 1
	end
	return { total = self:population(kingdom), byJob = byJob, cap = kingdom.popCap }
end

function Simulation:citizensOf(kingdom: any): { any }
	local out = {}
	for _, id in kingdom.citizenIds do
		table.insert(out, self.citizens[id])
	end
	return out
end

function Simulation:buildingsOf(kingdom: any): { any }
	local out = {}
	for _, id in kingdom.buildingIds do
		table.insert(out, self.buildings[id])
	end
	return out
end

-- ---------------------------------------------------------------- queries for the brain
function Simulation:hasOpenSite(kingdom: any): boolean
	for _, bid in kingdom.buildingIds do
		local b = self.buildings[bid]
		if b.pendingLevel ~= nil and not b.destroyed and #b.builders < self:_siteBuilders(b) then
			return true
		end
	end
	return false
end

function Simulation:_siteBuilders(building: any): number
	return if building.kind == "keep" then Simulation.SITE_BUILDERS + 2 else Simulation.SITE_BUILDERS
end

function Simulation:needTarget(kingdom: any, resource: string): number
	local base = self.catalog.tuning.needTargets[resource] or 100
	if resource == "food" then
		-- two days of meals for everyone, at least the base target
		local perDay = #kingdom.citizenIds * self.catalog.tuning.mealFood * self.catalog.tuning.hungerPerDay
		base = math.max(base, perDay * 2)
	end
	return base
end

function Simulation:threatNear(kingdom: any, x: number, z: number, radius: number): boolean
	for _, threat in kingdom.threats do
		if dist(threat.x, threat.z, x, z) <= radius then
			return true
		end
	end
	return false
end

function Simulation:_freeSlot(target: any, kind: string, citizen: any): boolean
	if citizen.claim ~= nil and citizen.claim.id == target.id then
		return true
	end
	if kind == "node" then
		return target.claims < target.slots
	elseif kind == "farm" then
		local stats = self.catalog.buildings.farm.levels[target.level]
		return stats ~= nil and #target.workers < (stats.workers or 0)
	else
		return #target.builders < self:_siteBuilders(target)
	end
end

function Simulation:findWorkTarget(kingdom: any, kind: string, citizen: any): (any?, number)
	local best, bestDistance = nil, math.huge
	if kind == "build" then
		for _, bid in kingdom.buildingIds do
			local b = self.buildings[bid]
			if b.pendingLevel ~= nil and not b.destroyed and self:_freeSlot(b, "site", citizen) then
				local d = dist(citizen.x, citizen.z, b.x, b.z)
				if d < bestDistance then
					best, bestDistance = b, d
				end
			end
		end
	elseif kind == "farm" then
		for _, bid in kingdom.buildingIds do
			local b = self.buildings[bid]
			if b.kind == "farm" and b.level >= 1 and not b.destroyed and self:_freeSlot(b, "farm", citizen) then
				local d = dist(citizen.x, citizen.z, b.x, b.z)
				if d < bestDistance then
					best, bestDistance = b, d
				end
			end
		end
	else
		for _, nid in kingdom.nearNodes do
			local node = self.nodes[nid]
			if node.resource == kind and node.amount > 0 and self:_freeSlot(node, "node", citizen) then
				local d = dist(citizen.x, citizen.z, node.x, node.z)
				if d < bestDistance then
					best, bestDistance = node, d
				end
			end
		end
	end
	return best, bestDistance
end

-- Nearest complete drop-off of the kingdom; with `resource`, only drop-offs that accept it
-- (lumber camps take wood, quarries stone and gold; the keep and storehouses take everything).
function Simulation:nearestDropoff(kingdom: any, x: number, z: number, resource: string?): any?
	local best, bestDistance = nil, math.huge
	for _, bid in kingdom.buildingIds do
		local b = self.buildings[bid]
		local def = self.catalog.buildings[b.kind]
		local accepts = resource == nil or def.accepts == nil or table.find(def.accepts, resource) ~= nil
		if not b.destroyed and b.level >= 1 and def.dropoff and accepts then
			local d = dist(x, z, b.x, b.z)
			if d < bestDistance then
				best, bestDistance = b, d
			end
		end
	end
	return best
end

-- ---------------------------------------------------------------- claims and activity changes
function Simulation:releaseClaim(citizen: any)
	local claim = citizen.claim
	if claim == nil then
		return
	end
	citizen.claim = nil
	if claim.kind == "node" then
		local node = self.nodes[claim.id]
		if node then
			node.claims = math.max(0, node.claims - 1)
		end
	else
		local b = self.buildings[claim.id]
		if b then
			local list = if claim.kind == "farm" then b.workers else b.builders
			local i = table.find(list, citizen.id)
			if i then
				table.remove(list, i)
			end
		end
	end
end

function Simulation:_claim(citizen: any, kind: string, id: string)
	if citizen.claim and citizen.claim.id == id then
		return
	end
	self:releaseClaim(citizen)
	if kind == "node" then
		self.nodes[id].claims += 1
	elseif kind == "farm" then
		table.insert(self.buildings[id].workers, citizen.id)
	else
		table.insert(self.buildings[id].builders, citizen.id)
	end
	citizen.claim = { kind = kind, id = id }
end

-- Switches a citizen to an activity. Continuing the same unfinished activity keeps its phase; a
-- finished activity (citizen.done) restarts from "Go" even when the brain picks the same target.
function Simulation:setActivity(citizen: any, activity: string, target: string?, reason: string?)
	local changed = citizen.activity ~= activity or citizen.target ~= target
	if changed then
		if activity == "Gather" and target then
			self:_claim(citizen, "node", target)
		elseif activity == "Farm" and target then
			self:_claim(citizen, "farm", target)
		elseif activity == "Build" and target then
			self:_claim(citizen, "site", target)
		else
			self:releaseClaim(citizen)
		end
	end
	if changed or citizen.done then
		citizen.activity = activity
		citizen.target = target
		citizen.phase = "Go"
		citizen.workTimer = 0
		citizen.wander = nil
	end
	citizen.reason = reason or citizen.reason
	citizen.done = false
end

function Simulation:remember(citizen: any, entry: { [string]: any })
	entry.t = self.time
	-- replace an entry of the same kind+ref so memory stays compact
	for i, old in citizen.memory do
		if old.kind == entry.kind and old.ref == entry.ref then
			table.remove(citizen.memory, i)
			break
		end
	end
	table.insert(citizen.memory, entry)
	while #citizen.memory > self.catalog.tuning.memorySize do
		table.remove(citizen.memory, 1)
	end
end

function Simulation:killCitizen(citizen: any, cause: string)
	if not citizen.alive then
		return
	end
	citizen.alive = false
	self:releaseClaim(citizen)
	local kingdom = self.kingdoms[citizen.kingdomId]
	local i = table.find(kingdom.citizenIds, citizen.id)
	if i then
		table.remove(kingdom.citizenIds, i)
	end
	local j = table.find(self.citizenOrder, citizen.id)
	if j then
		table.remove(self.citizenOrder, j)
	end
	self.citizens[citizen.id] = nil
	kingdom.stats.died += 1
	self:emit("CitizenDied", { kingdomId = kingdom.id, citizenId = citizen.id, cause = cause })
	self:_assignHomes(kingdom)
end

-- ---------------------------------------------------------------- G2 views
-- CONTRACTS G2 Building for a building record (also for one being destroyed).
function Simulation:viewOf(b: any): { [string]: any }
	local state
	if b.destroyed then
		state = "destroyed"
	elseif b.pendingLevel ~= nil and b.level == 0 and b.progress == 0 then
		state = "planned"
	elseif b.pendingLevel ~= nil then
		state = "constructing"
	elseif b.hp < b.maxHp * 0.5 then
		state = "damaged"
	else
		state = "complete"
	end
	local progress = 1
	if b.pendingLevel ~= nil then
		local work = self:workFor(b.kind, b.pendingLevel)
		progress = if work > 0 then math.clamp(b.progress / work, 0, 1) else 1
	end
	return {
		id = b.id,
		kingdom = b.kingdomId,
		type = b.kind,
		level = b.level,
		cframe = CFrame.new(b.x, 0, b.z),
		footprint = Vector2.new(b.footprint * 2, b.footprint * 2),
		state = state,
		progress = progress,
		hp = b.hp,
		maxHp = b.maxHp,
	}
end

function Simulation:buildingView(id: number): { [string]: any }?
	local b = self.buildings[id]
	return if b then self:viewOf(b) else nil
end

-- ---------------------------------------------------------------- treasury (G7), crown points, territory
function Simulation:balance(kingdomId: string, resource: string): number
	return self.treasury:get(kingdomId)[resource] or 0
end

function Simulation:canAfford(kingdomId: string, cost: { [string]: number }): boolean
	return self.treasury:canAfford(kingdomId, cost)
end

function Simulation:spend(kingdomId: string, cost: { [string]: number }, txId: string, sink: string): boolean
	return self.treasury:spend(kingdomId, cost, txId, sink)
end

function Simulation:deposit(kingdomId: string, resource: string, amount: number, txId: string, source: string): boolean
	if amount <= 0 then
		return true
	end
	return self.treasury:deposit(kingdomId, resource, amount, txId, source)
end

function Simulation:workFor(kind: string, level: number): number
	local price = self.costs.building(kind, level)
	return if price then price.buildSeconds else self.catalog.buildings[kind].levels[level].work
end

function Simulation:addCrownPoints(kingdomId: string, amount: number, reason: string)
	local kingdom = self.kingdoms[kingdomId]
	if kingdom == nil or amount == 0 then
		return
	end
	kingdom.crownPoints += amount
	self:emit("CrownPoints", { kingdomId = kingdomId, amount = amount, total = kingdom.crownPoints, reason = reason })
end

function Simulation:claimRegion(
	kingdomId: string,
	regionId: string,
	x: number,
	z: number,
	radius: number,
	reason: string
)
	if self.regions[regionId] == nil then
		table.insert(self.regionOrder, regionId)
	end
	self.regions[regionId] = { kingdomId = kingdomId, x = x, z = z, radius = radius, reason = reason }
	self:emit("RegionClaimed", { kingdomId = kingdomId, regionId = regionId, reason = reason })
end

function Simulation:releaseRegion(regionId: string)
	local region = self.regions[regionId]
	if region == nil then
		return
	end
	self.regions[regionId] = nil
	table.remove(self.regionOrder, table.find(self.regionOrder, regionId) :: number)
	self:emit("RegionReleased", { kingdomId = region.kingdomId, regionId = regionId })
end

-- A footprint circle at (x, z) lies inside the kingdom's land: its keep circle or a claimed region.
function Simulation:insideTerritory(kingdom: any, x: number, z: number, footprint: number): boolean
	if kingdom.alive and dist(x, z, kingdom.x, kingdom.z) + footprint <= kingdom.territory then
		return true
	end
	for _, regionId in self.regionOrder do
		local region = self.regions[regionId]
		if region.kingdomId == kingdom.id and dist(x, z, region.x, region.z) + footprint <= region.radius then
			return true
		end
	end
	return false
end

-- TerritoryService:owner (G6): keep circles first (in kingdom order), then claimed regions.
function Simulation:territoryOwner(x: number, z: number): string?
	for _, kid in self.kingdomOrder do
		local k = self.kingdoms[kid]
		if k.alive and dist(x, z, k.x, k.z) <= k.territory then
			return kid
		end
	end
	for _, regionId in self.regionOrder do
		local region = self.regions[regionId]
		if self.kingdoms[region.kingdomId].alive and dist(x, z, region.x, region.z) <= region.radius then
			return region.kingdomId
		end
	end
	return nil
end

function Simulation:setRulerPosition(userId: number, x: number?, z: number?)
	if x == nil or z == nil then
		self.rulerPositions[userId] = nil
	else
		self.rulerPositions[userId] = { x = x, z = z }
	end
end

-- ---------------------------------------------------------------- construction
function Simulation:countOf(kingdom: any, kind: string): number
	local n = 0
	for _, bid in kingdom.buildingIds do
		local b = self.buildings[bid]
		if b.kind == kind and not b.destroyed then
			n += 1
		end
	end
	return n
end

function Simulation:keepLevel(kingdom: any): number
	local keep = self.buildings[kingdom.keepId]
	return if keep and not keep.destroyed then keep.level else 0
end

function Simulation:canPlace(kingdom: any, kind: string, x: number, z: number): (boolean, string?)
	local def = self.catalog.buildings[kind]
	if def == nil then
		return false, "unknown_building"
	end
	if not def.placeable then
		return false, "not_placeable"
	end
	if not kingdom.alive then
		return false, "kingdom_eliminated"
	end
	if def.requiresKeepLevel and self:keepLevel(kingdom) < def.requiresKeepLevel then
		return false, "requires_keep_level"
	end
	if def.maxCount and self:countOf(kingdom, kind) >= def.maxCount then
		return false, "limit_reached"
	end
	local bounds = self.bounds
	if x - def.footprint < bounds.minX or x + def.footprint > bounds.maxX then
		return false, "out_of_bounds"
	end
	if z - def.footprint < bounds.minZ or z + def.footprint > bounds.maxZ then
		return false, "out_of_bounds"
	end
	if not self:insideTerritory(kingdom, x, z, def.footprint) then
		return false, "out_of_territory"
	end
	local gap = self.catalog.tuning.placementGap
	for _, bid in self.buildingOrder do
		local b = self.buildings[bid]
		if not b.destroyed and dist(x, z, b.x, b.z) < def.footprint + b.footprint + gap then
			return false, "blocked"
		end
	end
	for _, nid in self.nodeOrder do
		local node = self.nodes[nid]
		-- depleted trees still block: they grow back
		local present = node.amount > 0 or node.regrow ~= nil
		if present and dist(x, z, node.x, node.z) < def.footprint + node.footprint + gap then
			return false, "blocked"
		end
	end
	local price = self.costs.building(kind, 1)
	if price == nil then
		return false, "unknown_building"
	end
	if not self:canAfford(kingdom.id, price.cost) then
		return false, "cannot_afford"
	end
	return true, nil
end

function Simulation:placeBuilding(kingdom: any, kind: string, x: number, z: number, by: number?): (any?, string?)
	local ok, err = self:canPlace(kingdom, kind, x, z)
	if not ok then
		return nil, err
	end
	local cost = (self.costs.building(kind, 1) :: any).cost
	local nextId = self._nextBuilding + 1
	if not self:spend(kingdom.id, cost, `build:{nextId}:1`, `building:{kind}`) then
		return nil, "cannot_afford" -- e.g. another server-side spend raced us
	end
	local building = self:_createBuilding(kingdom, kind, x, z)
	assert(building.id == nextId, "building id changed between spend and create")
	building.pendingCost = table.clone(cost)
	self:emit(
		"BuildingPlaced",
		{ kingdomId = kingdom.id, buildingId = building.id, kind = kind, x = x, z = z, by = by }
	)
	return building, nil
end

function Simulation:_ownedBuilding(kingdom: any, buildingId: string): (any?, string?)
	local b = self.buildings[buildingId]
	if b == nil or b.destroyed then
		return nil, "not_found"
	end
	if b.kingdomId ~= kingdom.id then
		return nil, "not_owner"
	end
	return b, nil
end

function Simulation:startUpgrade(kingdom: any, buildingId: string, by: number?): (boolean, string?)
	local b, err = self:_ownedBuilding(kingdom, buildingId)
	if b == nil then
		return false, err
	end
	if b.pendingLevel ~= nil then
		return false, "busy"
	end
	local def = self.catalog.buildings[b.kind]
	local nextStats = def.levels[b.level + 1]
	local price = self.costs.building(b.kind, b.level + 1)
	if nextStats == nil or price == nil then
		return false, "max_level"
	end
	if b.kind ~= "keep" and def.requiresKeepLevel and self:keepLevel(kingdom) < def.requiresKeepLevel then
		return false, "requires_keep_level"
	end
	if not self:spend(kingdom.id, price.cost, `build:{b.id}:{b.level + 1}`, `building:{b.kind}`) then
		return false, "cannot_afford"
	end
	b.pendingLevel = b.level + 1
	b.pendingCost = table.clone(price.cost)
	b.progress = 0
	self:emit(
		"UpgradeStarted",
		{ kingdomId = kingdom.id, buildingId = b.id, kind = b.kind, level = b.level + 1, by = by }
	)
	return true, nil
end

function Simulation:_releaseAll(list: { string })
	-- copy first: releaseClaim mutates the list
	for _, cid in table.clone(list) do
		local c = self.citizens[cid]
		if c then
			self:releaseClaim(c)
			c.done = true
		end
	end
	table.clear(list)
end

function Simulation:cancelConstruction(kingdom: any, buildingId: string, by: number?): (boolean, string?)
	local b, err = self:_ownedBuilding(kingdom, buildingId)
	if b == nil then
		return false, err
	end
	if b.pendingLevel == nil then
		return false, "nothing_to_cancel"
	end
	local refund = {}
	for _, res in self.catalog.resources do
		local amount = math.floor(((b.pendingCost or {})[res] or 0) * self.catalog.tuning.cancelRefund)
		if amount > 0 then
			self:deposit(kingdom.id, res, amount, `refund:{b.id}:{b.pendingLevel}:{res}`, "refund")
			refund[res] = amount
		end
	end
	self:_releaseAll(b.builders)
	if b.level == 0 then
		self:_removeBuilding(b)
	else
		b.pendingLevel = nil
		b.pendingCost = nil
		b.progress = 0
	end
	self:emit(
		"ConstructionCancelled",
		{ kingdomId = kingdom.id, buildingId = b.id, kind = b.kind, refund = refund, by = by }
	)
	return true, nil
end

function Simulation:_removeBuilding(b: any)
	local kingdom = self.kingdoms[b.kingdomId]
	self:_releaseAll(b.builders)
	self:_releaseAll(b.workers)
	b.destroyed = true
	local i = table.find(kingdom.buildingIds, b.id)
	if i then
		table.remove(kingdom.buildingIds, i)
	end
	local j = table.find(self.buildingOrder, b.id)
	if j then
		table.remove(self.buildingOrder, j)
	end
	self.buildings[b.id] = nil
	self:_recompute(kingdom)
	self:_assignHomes(kingdom)
end

-- Adds builder work to a site; completes the level when enough work is done. Returns true when complete.
function Simulation:addWork(b: any, amount: number): boolean
	if b.pendingLevel == nil or b.destroyed then
		return true
	end
	local stats = self.catalog.buildings[b.kind].levels[b.pendingLevel]
	local work = self:workFor(b.kind, b.pendingLevel :: number)
	b.progress += amount
	if b.level == 0 then
		-- a new site's hit points grow with its progress
		b.hp = math.max(b.hp, math.floor(stats.hp * math.clamp(0.1 + 0.9 * b.progress / work, 0, 1)))
	end
	if b.progress < work then
		return false
	end
	local kingdom = self.kingdoms[b.kingdomId]
	local oldMax = b.maxHp
	b.level = b.pendingLevel :: number
	b.pendingLevel = nil
	b.pendingCost = nil
	b.progress = 0
	b.maxHp = stats.hp
	b.hp = if b.level == 1 then stats.hp else math.min(stats.hp, b.hp + (stats.hp - oldMax))
	kingdom.stats.built += 1
	self:_releaseAll(b.builders)
	self:_recompute(kingdom)
	self:_assignHomes(kingdom)
	self:emit("BuildingCompleted", { kingdomId = kingdom.id, buildingId = b.id, kind = b.kind, level = b.level })
	self:addCrownPoints(kingdom.id, self.catalog.crown.buildingLevel * b.level, `building:{b.kind}`)
	return true
end

-- ---------------------------------------------------------------- population and workforce
function Simulation:_rebalanceQuotas(kingdom: any)
	local catalog = self.catalog
	local counts: { [string]: number } = {}
	for _, cid in kingdom.citizenIds do
		local occ = self.citizens[cid].job
		counts[occ] = (counts[occ] or 0) + 1
	end
	local function reassign(c: any, to: string)
		local from = c.job
		counts[from] -= 1
		counts[to] = (counts[to] or 0) + 1
		c.job = to
		c.done = c.carrying == nil -- rethink now unless mid-delivery
		self:emit("CitizenReassigned", { kingdomId = kingdom.id, citizenId = c.id, from = from, to = to })
	end
	-- over quota -> hauler pool (newest first, preferring citizens not carrying anything)
	for _, occ in catalog.jobOrder do
		if occ == "hauler" then
			continue
		end
		local quota = kingdom.quotas[occ] or 0
		for pass = 1, 2 do
			for i = #kingdom.citizenIds, 1, -1 do
				if (counts[occ] or 0) <= quota then
					break
				end
				local c = self.citizens[kingdom.citizenIds[i]]
				if c.job == occ and (pass == 2 or c.carrying == nil) then
					reassign(c, "hauler")
				end
			end
		end
	end
	-- under quota <- hauler pool (oldest first)
	for _, occ in catalog.jobOrder do
		if occ == "hauler" then
			continue
		end
		local quota = kingdom.quotas[occ] or 0
		for _, cid in kingdom.citizenIds do
			if (counts[occ] or 0) >= quota then
				break
			end
			local c = self.citizens[cid]
			if c.job == "hauler" then
				reassign(c, occ)
			end
		end
	end
end

function Simulation:_neededOccupation(kingdom: any): string
	local counts: { [string]: number } = {}
	for _, cid in kingdom.citizenIds do
		local occ = self.citizens[cid].job
		counts[occ] = (counts[occ] or 0) + 1
	end
	for _, occ in self.catalog.jobOrder do
		if occ ~= "hauler" and (counts[occ] or 0) < (kingdom.quotas[occ] or 0) then
			return occ
		end
	end
	return "hauler"
end

function Simulation:_stepPopulation(kingdom: any)
	if self.time < kingdom.nextBirthAt then
		return
	end
	kingdom.nextBirthAt = self.time + self.catalog.tuning.birthInterval
	local tuning = self.catalog.tuning
	-- recruits still training already hold a bed (found by the spec batch: births overfilled the cap)
	if self:population(kingdom) + self:queuedUnits(kingdom) >= kingdom.popCap then
		return
	end
	-- keep a day of meals in reserve before growing
	local reserve = #kingdom.citizenIds * tuning.mealFood
	if self:balance(kingdom.id, "food") < tuning.birthFood + reserve then
		return
	end
	if
		not self:spend(
			kingdom.id,
			{ food = tuning.birthFood },
			`birth:{kingdom.id}:{kingdom.stats.born + 1}`,
			"population"
		)
	then
		return
	end
	local keep = self.buildings[kingdom.keepId]
	local angle = self.rng:NextNumber() * math.pi * 2
	local ring = keep.footprint + 3
	local occ = self:_neededOccupation(kingdom)
	local c = self:_spawnCitizen(kingdom, occ, keep.x + math.cos(angle) * ring, keep.z + math.sin(angle) * ring)
	kingdom.stats.born += 1
	self:_assignHomes(kingdom)
	self:emit("CitizenBorn", { kingdomId = kingdom.id, citizenId = c.id, job = occ })
end

function Simulation:_regrowNodes()
	for _, nid in self.nodeOrder do
		local node = self.nodes[nid]
		if node.amount <= 0 and node.regrow and node.depletedAt and self.time >= node.depletedAt + node.regrow then
			node.amount = node.capacity
			node.depletedAt = nil
			self:emit("NodeRegrown", { nodeId = node.id, resource = node.resource })
		end
	end
end

-- ---------------------------------------------------------------- tick
function Simulation:_stepCitizen(c: any, dt: number)
	local tuning = self.catalog.tuning
	local kingdom = self.kingdoms[c.kingdomId]
	c.hunger += dt * tuning.hungerPerDay / tuning.dayLength
	if c.hunger >= tuning.starveDeathHunger then
		self:killCitizen(c, "starvation")
		return
	end

	-- interrupts: emergencies preempt anything; night preempts work once cargo is delivered
	local emergency = kingdom.alarm or self:threatNear(kingdom, c.x, c.z, tuning.fleeRadius)
	if emergency and c.activity ~= "Flee" then
		if not kingdom.alarm then
			for _, threat in kingdom.threats do
				if math.abs(threat.x - c.x) + math.abs(threat.z - c.z) <= tuning.fleeRadius * 1.5 then
					self:remember(c, { kind = "threat", x = threat.x, z = threat.z, ref = threat.id })
					break
				end
			end
		end
		c.done = true
	elseif c.carrying == nil and self:isNight() and c.activity ~= "Sleep" and c.activity ~= "Flee" then
		c.done = true
	end

	if c.done or (self.time >= c.thinkAt and c.carrying == nil) then
		local decision = CitizenBrain.decide(self, c)
		self:setActivity(c, decision.activity, decision.target, decision.reason)
		c.thinkAt = self.time + tuning.thinkInterval
	end
	CitizenActions.step(self, c, dt)
end

function Simulation:step()
	local dt = self.catalog.tuning.tickSeconds
	local dayBefore = self:day()
	local nightBefore = self:isNight()
	self.time += dt
	self.tick += 1
	if self:day() ~= dayBefore then
		self:emit("DayStarted", { day = self:day() })
	elseif self:isNight() and not nightBefore then
		self:emit("NightFell", { day = self:day() })
	end

	for _, system in self._systems do
		if system.beforeCitizens then
			system.beforeCitizens(self, dt)
		end
	end

	self._quotaAccum += dt
	local rebalance = self._quotaAccum >= Simulation.QUOTA_INTERVAL
	if rebalance then
		self._quotaAccum -= Simulation.QUOTA_INTERVAL
	end
	if rebalance then
		self:_regrowNodes()
	end
	for _, kid in self.kingdomOrder do
		local kingdom = self.kingdoms[kid]
		if kingdom.alive then
			if rebalance then
				self:_rebalanceQuotas(kingdom)
			end
			self:_stepPopulation(kingdom)
		end
	end

	-- iterate a copy: citizens may die during the step
	for _, cid in table.clone(self.citizenOrder) do
		local c = self.citizens[cid]
		if c and c.alive then
			self:_stepCitizen(c, dt)
		end
	end

	for _, system in self._systems do
		if system.afterCitizens then
			system.afterCitizens(self, dt)
		end
	end
end

function Simulation:advance(seconds: number)
	assert(type(seconds) == "number" and seconds >= 0 and seconds < math.huge, "advance: seconds must be >= 0")
	if not self.active then
		return
	end
	local dt = self.catalog.tuning.tickSeconds
	self._accum += seconds
	-- tolerate float noise so advance(0.25) four times equals advance(1)
	while self._accum >= dt - 1e-9 do
		self._accum -= dt
		self:step()
		if not self.active then
			self._accum = 0
			break
		end
	end
end

return Simulation
