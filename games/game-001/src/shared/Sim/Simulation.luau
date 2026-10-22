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
			          default Catalog.costs(catalog), on FORGE-03's Costs.luau

	World setup
		sim:addKingdom({ id, name, color: {number}, x, z, yaw?, startAt?, populate? }): Kingdom   -- keep + start
		                                       buildings (startAt = { { kind, x, z, yaw? } }, else tuning) +
		                                       citizens (populate = false: none until sim:populate(id));
		                                       seeds the treasury when it is the double
		sim:populate(kingdomId): boolean       -- spawns the starting citizens once (slice mode: on first ruler)
		sim:addProductivity(citizen, amount, seconds), sim:productivityOf(citizen): number,
		sim:strike(citizen, seconds), sim:isStriking(citizen)   -- decision consequences (G13.3)
		sim.profiler: { start: (sim, kingdom, citizens), birth: (sim, kingdom, citizen) }?
		                                       -- optional; gives citizens names, traits and families
		                                          (Sim/People, G13.2) right after they spawn
		sim:addNode(kind, x, z, id?): Node                             -- tree / rock / goldvein / berries
		sim:nodeClear(kind, x, z): boolean     -- a `kind` node there keeps placementGap to every standing
		                                       building's placement shape and footprint circle (Layout)
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
		sim:canPlace(kingdom, kind, x, z, yaw?): (boolean, string?)   -- yaw nil: the facing placeBuilding
		                                       would give (towards the keep)
		sim:placeBuilding(kingdom, kind, x, z, byUserId?, yaw?): (Building?, string?)
		sim:shapeOf(kind, x, z, yaw): Footprint.Shape   -- placement shape: catalog placeSize rectangle
		                                       (largest Kit level, turned by yaw), else the footprint circle
		sim:startUpgrade(kingdom, buildingId, byUserId?): (boolean, string?)
		sim:cancelConstruction(kingdom, buildingId, byUserId?): (boolean, string?)
		sim:canMoveBuilding(kingdom, buildingId, x, z, yaw): (boolean, string?)     -- CONTRACTS G13.9
		sim:moveBuilding(kingdom, buildingId, x, z, yaw, byUserId?, slotId?): (boolean, string?)
		                                       -- one atomic, in-place move of an own non-keep building: same id and
		                                       record (level, hp, construction progress, paid cost, placedBy,
		                                       recruit queue, claims kept); nothing is charged, refunded, completed
		                                       or re-placed. Refusals: match_not_active, kingdom_eliminated,
		                                       not_found, not_owner, not_movable (keep), alarm, under_attack,
		                                       cooldown (tuning.moveCooldown), then the placement geometry
		                                       (out_of_bounds, out_of_territory, blocked). The same spot and facing
		                                       is a no-op: true, no event, no cooldown. Citizens working, building
		                                       or resting at it walk to its new place again.
		Overlap (Sim/Footprint): placement shapes keep tuning.placementGap from each other and from
		resource node circles, except two line pieces (wall, gate), which keep tuning.wallGap (0: they join
		end to end); bounds and territory still test the footprint circle.
	Conversations (G13.8)
		sim:holdCitizen(citizen, seconds, faceX?, faceZ?, by?)   -- the citizen stops (activity "Talk", claims
		                                       released) and faces (faceX, faceZ) for at most `seconds`; an
		                                       emergency (alarm, threat near) ends it early
		sim:releaseCitizen(citizen)            -- ends the hold; the citizen decides again on its next tick
		sim:isHeld(citizen): boolean
	Citizens (G5)
		sim:rulerVisit(citizen, userId?): boolean   -- rulerVisited memory + mood lift, once per visitCooldown
		sim:setJob(citizen, job)               -- one citizen to `job`, quotas kept in step (no rebalance back)
	Views
		sim:buildingView(id) / sim:viewOf(record): CONTRACTS G2 Building (cframe, footprint, state, ...)
	Queries (used by CitizenBrain / CitizenActions / Snapshot)
		sim:hasOpenSite(kingdom, citizen?), sim:needTarget(kingdom, resource), sim:threatNear(kingdom, x, z, r)
		sim:findWorkTarget(kingdom, kind, citizen): (target?, distance), sim:nearestDropoff(kingdom, x, z)
		sim:citizensOf(kingdom) / sim:buildingsOf(kingdom): arrays in creation order
		sim:population(kingdom), sim:atWar(kingdomIdA, kingdomIdB)
	Events
		sim:drainEvents(): { Event }   -- everything since the last drain, in order; Event = { name, ... }
		  ResourceGathered   { kingdomId, resource, amount, source = "citizen" | "ruler", citizenId?, userId? }
		  BuildingPlaced     { kingdomId, buildingId, kind, x, z, by }
		  BuildingMoved      { kingdomId, buildingId, kind, from = { x, z, yaw }, to = { x, z, yaw }, slotId?, by }
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

local Authority = require("./Authority")
local Catalog = require("./Catalog")
local CitizenActions = require("./CitizenActions")
local CitizenBrain = require("./CitizenBrain")
local Footprint = require("./Footprint")
local TreasuryDouble = require("./TreasuryDouble")
local SocietyConfig = require("@game/ReplicatedStorage/Forge/Config/Society")

type Catalog = Catalog.Catalog

export type Bounds = { minX: number, maxX: number, minZ: number, maxZ: number }
export type Event = { [string]: any }

local Simulation = {}

-- wall and gate pieces form lines: next to each other they keep tuning.wallGap instead of placementGap
local LINE_PIECES: { [string]: boolean } = { wall = true, gate = true }
-- A soldier's body for placement clearance (Military.UNIT_RADIUS)
local UNIT_BODY = 1.5
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
	self._repairing = {} :: { [number]: number } -- building id -> the hit points its passive repair stops at
	self.noBuild = {} :: { Footprint.Shape } -- areas no placement shape may overlap (Kingdom/Layout.reservedAreas)
	self._settling = {} :: { [number]: boolean } -- moved drop-offs still settling (b.settleUntil)
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
	self._decisionBudget = 2 -- per tick; set by step() (staggered decisions)
	self.fedByUpkeep = false -- true: citizens never buy meals; hunger follows kingdom.fedRatio (G7)
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
		quotaRev = 0, -- +1 on every accepted quota change (SetJobQuota, setJob): co-rulers' panels follow it
		priorities = { food = 1, wood = 1, stone = 1, gold = 1 },
		alarm = false,
		alive = true,
		eliminatedAt = nil :: number?,
		eliminatedBy = nil :: string?,
		nextBirthAt = tuning.birthInterval,
		fedRatio = 1, -- 0..1, set by CitizenService:setFedRatio (G7 upkeep) when fedByUpkeep
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

	local keep = self:_createBuilding(kingdom, "keep", def.x, def.z, def.yaw)
	self:_completeInstantly(keep)
	kingdom.keepId = keep.id
	if def.startAt then
		-- starting buildings at given spots (the world Layout's plot anchors, G6)
		for _, spot in def.startAt do
			self:_completeInstantly(self:_createBuilding(kingdom, spot.kind, spot.x, spot.z, spot.yaw))
		end
	else
		-- starting buildings (tuning.startBuildings), placed relative to the direction toward the map centre
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
	end
	self:_recompute(kingdom)
	kingdom.populated = false
	if def.populate ~= false then
		self:populate(kingdom.id)
	end
	return kingdom
end

-- Spawns the kingdom's starting citizens in a ring around the keep, in job order (deterministic).
-- Once per kingdom: later calls do nothing. Returns whether citizens were spawned.
function Simulation:populate(kingdomId: string): boolean
	local kingdom = self.kingdoms[kingdomId]
	if kingdom == nil or kingdom.populated or not kingdom.alive then
		return false
	end
	kingdom.populated = true
	local tuning = self.catalog.tuning
	kingdom.nextBirthAt = self.time + tuning.birthInterval
	local ring = self.catalog.buildings.keep.footprint + 4
	local total = 0
	for _, occ in self.catalog.jobOrder do
		total += tuning.startCitizens[occ] or 0
	end
	local i = 0
	local spawned = {}
	for _, occ in self.catalog.jobOrder do
		for _ = 1, tuning.startCitizens[occ] or 0 do
			local angle = (i / math.max(1, total)) * math.pi * 2
			local c =
				self:_spawnCitizen(kingdom, occ, kingdom.x + math.cos(angle) * ring, kingdom.z + math.sin(angle) * ring)
			table.insert(spawned, c)
			i += 1
		end
	end
	if self.profiler then
		self.profiler.start(self, kingdom, spawned) -- names, traits, families (Sim/People, G13.2)
	end
	self:_assignHomes(kingdom)
	return true
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

-- Node generation (Kingdom/Layout): a `kind` node at (x, z) clears every standing building by
-- placementGap: its placement shape (the canPlace rule, seen from the node) and its footprint circle
-- (where citizens, units and combat reach it).
function Simulation:nodeClear(kind: string, x: number, z: number): boolean
	local radius = self.catalog.nodes[kind].footprint
	local gap = self.catalog.tuning.placementGap
	for _, bid in self.buildingOrder do
		local b = self.buildings[bid]
		if
			not b.destroyed
			and (
				Footprint.overlapsCircle(b.shape, x, z, radius, gap)
				or dist(x, z, b.x, b.z) < b.footprint + radius + gap
			)
		then
			return false
		end
	end
	return true
end

-- yaw: facing in radians (CFrame.Angles(0, yaw, 0); Kit models face -Z). Default: the front towards
-- the kingdom's keep, or for the keep itself towards the map centre.
function Simulation:_facing(kingdom: any, kind: string, x: number, z: number, yaw: number?): number
	if yaw ~= nil then
		return yaw
	end
	local tx, tz = kingdom.x, kingdom.z
	if kind == "keep" or (math.abs(tx - x) < 1e-6 and math.abs(tz - z) < 1e-6) then
		tx, tz = 0, 0
	end
	return if math.abs(tx - x) + math.abs(tz - z) < 1e-6 then 0 else math.atan2(-(tx - x), -(tz - z))
end

function Simulation:shapeOf(kind: string, x: number, z: number, yaw: number): Footprint.Shape
	local def = self.catalog.buildings[kind]
	return if def.placeSize then Footprint.rect(def.placeSize, x, z, yaw) else Footprint.circle(x, z, def.footprint)
end

function Simulation:_createBuilding(kingdom: any, kind: string, x: number, z: number, yaw: number?)
	local def = self.catalog.buildings[kind]
	self._nextBuilding += 1
	local facing = self:_facing(kingdom, kind, x, z, yaw)
	local building = {
		id = self._nextBuilding,
		kind = kind,
		kingdomId = kingdom.id,
		x = x,
		z = z,
		yaw = facing,
		footprint = def.footprint,
		shape = self:shapeOf(kind, x, z, facing), -- placement overlap (never grows; recomputed by a move)
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
	Authority.seated(self, userId)
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
	Authority.left(self, userId)
	self:emit("RulerLeft", { kingdomId = kingdomId, userId = userId })
	return true
end

-- The ruler did something the server saw (a command, gathering, a conversation, walking): they count as active for
-- the senior-ruler rule (Sim/Authority).
function Simulation:touchRuler(userId: number)
	Authority.touch(self, userId)
end

function Simulation:kingdomOfUser(userId: number): any?
	local id = self.rulerOf[userId]
	return if id then self.kingdoms[id] else nil
end

-- ---------------------------------------------------------------- derived kingdom stats
function Simulation:_recompute(kingdom: any)
	local popCap, territory = 0, 0
	local bonus: { [string]: number } = {}
	for _, bid in kingdom.buildingIds do
		local b = self.buildings[bid]
		if b.destroyed or b.level < 1 then
			continue
		end
		local def = self.catalog.buildings[b.kind]
		local stats = def.levels[b.level]
		popCap += stats.popCap or 0
		if b.kind == "keep" then
			territory = stats.territory or 0
		end
		-- the best standing camp's level speeds up gathering what it accepts (FL-0081); a camp on fire gives none,
		-- and a camp that was just moved gives no bonus while it settles (G13.9)
		local settling = b.settleUntil ~= nil and self.time < b.settleUntil
		for _, resource in if stats.gatherBonus and not b.burning and not settling then def.accepts or {} else {} do
			bonus[resource] = math.max(bonus[resource] or 0, stats.gatherBonus)
		end
	end
	kingdom.popCap = popCap
	kingdom.gatherBonus = bonus
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

-- Bunks (D-041): soldiers (living + training) sleep in the kingdom's standing barracks, never in house or
-- keep beds: the sum of their levels' `bunks` (Buildings.luau); a level without one sleeps any number.
function Simulation:bunks(kingdom: any): number
	local n = 0
	for _, bid in kingdom.buildingIds do
		local b = self.buildings[bid]
		if b.kind == "barracks" and not b.destroyed and b.level >= 1 then
			n += self.catalog.buildings.barracks.levels[b.level].bunks or math.huge
		end
	end
	return n
end

-- Sleeping places for the whole population (beds + bunks, D-041): the G5 getPopulation cap. A barracks
-- level without a bunk count (unlimited) shows as exactly full.
function Simulation:sleepCap(kingdom: any): number
	local bunks = self:bunks(kingdom)
	if bunks == math.huge then
		bunks = #kingdom.unitIds + self:queuedUnits(kingdom)
	end
	return kingdom.popCap + bunks
end

-- Units paid for and still training in this kingdom's barracks (they will need a bunk too).
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

-- CitizenService:getPopulation (G5): { total, byJob, cap }; soldiers count as job "soldier" and the cap is
-- beds plus bunks (D-041).
function Simulation:getPopulation(kingdom: any): { total: number, byJob: { [string]: number }, cap: number }
	local byJob: { [string]: number } = { soldier = #kingdom.unitIds }
	for _, cid in kingdom.citizenIds do
		local job = self.citizens[cid].job
		byJob[job] = (byJob[job] or 0) + 1
	end
	return { total = self:population(kingdom), byJob = byJob, cap = self:sleepCap(kingdom) }
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
-- A site with a free builder slot; for `citizen`, also the site it already builds on (full or not).
function Simulation:hasOpenSite(kingdom: any, citizen: any?): boolean
	local claim = if citizen then citizen.claim else nil
	if claim and claim.kind == "site" then
		local site = self.buildings[claim.id]
		if site and site.pendingLevel ~= nil and not site.destroyed then
			return true
		end
	end
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
			if b.pendingLevel ~= nil and not b.destroyed and not b.burning and self:_freeSlot(b, "site", citizen) then
				local d = dist(citizen.x, citizen.z, b.x, b.z)
				if d < bestDistance then
					best, bestDistance = b, d
				end
			end
		end
	elseif kind == "farm" then
		for _, bid in kingdom.buildingIds do
			local b = self.buildings[bid]
			if
				b.kind == "farm"
				and b.level >= 1
				and not b.destroyed
				and not b.burning
				and self:_freeSlot(b, "farm", citizen)
			then
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
		-- a building on fire takes no deliveries (D-050 (1b)); neither does a drop-off that was just moved while it
		-- settles (G13.9)
		local settling = b.settleUntil ~= nil and self.time < b.settleUntil
		if not b.destroyed and not b.burning and b.level >= 1 and def.dropoff and accepts and not settling then
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
	-- the same building can be a farm to work and a site to build (an upgrade): the kind matters
	if citizen.claim and citizen.claim.id == id and citizen.claim.kind == kind then
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

-- ---------------------------------------------------------------- conversations (G13.8)
-- A ruler's conversation holds the citizen still, facing (faceX, faceZ), for at most `seconds`.
function Simulation:holdCitizen(citizen: any, seconds: number, faceX: number?, faceZ: number?, by: number?)
	self:setActivity(citizen, "Talk", nil, "with the ruler")
	citizen.phase = "Talk"
	local yaw = nil
	if faceX and faceZ then
		local dx, dz = faceX - citizen.x, faceZ - citizen.z
		if dx * dx + dz * dz > 1e-6 then
			yaw = math.atan2(-dx, -dz) -- the Replication facing convention
		end
	end
	citizen.hold = { untilTime = self.time + seconds, yaw = yaw, by = by }
end

function Simulation:releaseCitizen(citizen: any)
	if citizen.hold then
		citizen.hold = nil
		citizen.done = true -- decides again on its next tick
	end
end

function Simulation:isHeld(citizen: any): boolean
	return citizen.hold ~= nil and self.time < citizen.hold.untilTime
end

-- A ruler's visit (CONTRACTS G5): a rulerVisited memory and a mood lift of tuning.visitMood for
-- visitMoodSeconds, at most once per citizen per visitCooldown. True when it counted.
function Simulation:rulerVisit(citizen: any, userId: number?): boolean
	local tuning = self.catalog.tuning
	if citizen.visitedAt and self.time - citizen.visitedAt < tuning.visitCooldown then
		return false
	end
	citizen.visitedAt = self.time
	self:remember(citizen, { kind = "rulerVisited", ref = userId })
	citizen.moodLift = { amount = tuning.visitMood, untilTime = self.time + tuning.visitMoodSeconds }
	return true
end

-- Moves one citizen to `job` and keeps the kingdom's quotas in step, so the rebalancer leaves it there
-- (CitizenService:setJob, G5). The hauler pool has no quota.
function Simulation:setJob(citizen: any, job: string)
	local kingdom = self.kingdoms[citizen.kingdomId]
	local from = citizen.job
	if from == job then
		return
	end
	if from ~= "hauler" then
		kingdom.quotas[from] = math.max(0, (kingdom.quotas[from] or 0) - 1)
	end
	if job ~= "hauler" then
		kingdom.quotas[job] = (kingdom.quotas[job] or 0) + 1
	end
	kingdom.quotaRev = (kingdom.quotaRev or 0) + 1
	citizen.job = job
	citizen.done = citizen.carrying == nil -- rethink now unless mid-delivery
	self:emit("CitizenReassigned", { kingdomId = kingdom.id, citizenId = citizen.id, from = from, to = job })
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
		cframe = CFrame.new(b.x, 0, b.z) * CFrame.Angles(0, b.yaw or 0, 0),
		footprint = Vector2.new(b.footprint * 2, b.footprint * 2),
		state = state,
		progress = progress,
		hp = b.hp,
		maxHp = b.maxHp,
		placedBy = b.placedBy,
	}
end

-- Every standing building as a G2 Building view, in id order.
function Simulation:buildingViews(): { { [string]: any } }
	local out = {}
	for _, id in self.buildingOrder do
		local b = self.buildings[id]
		if b and not b.destroyed then
			table.insert(out, self:viewOf(b))
		end
	end
	return out
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

-- ---------------------------------------------------------------- work modifiers (G13.3 consequences)
-- A productivity change of `amount` (−1..+1: −0.2 = 20 % slower) for `seconds`; changes add up.
function Simulation:addProductivity(citizen: any, amount: number, seconds: number)
	citizen.boosts = citizen.boosts or {}
	table.insert(citizen.boosts, { amount = amount, untilTime = self.time + seconds })
end

-- The citizen's work-rate factor: 1 + the active productivity changes, never below 0.
function Simulation:productivityOf(citizen: any): number
	local boosts = citizen.boosts
	if boosts == nil then
		return 1
	end
	local total = 1
	for i = #boosts, 1, -1 do
		local boost = boosts[i]
		if self.time >= boost.untilTime then
			table.remove(boosts, i)
		else
			total += boost.amount
		end
	end
	if #boosts == 0 then
		citizen.boosts = nil
	end
	return math.max(0, total)
end

-- Stops the citizen working for `seconds` (a strike); they idle instead.
function Simulation:strike(citizen: any, seconds: number)
	citizen.strikeUntil = math.max(citizen.strikeUntil or 0, self.time + seconds)
	citizen.done = true -- downs tools at once, even with a load in hand (#77 N2): it re-plans next tick
end

-- Stops the citizen working because they are rioting (the G13.3 riot state, D-050 (1d)): they idle like a
-- striker, but they are a different state to the player (their own placard) and to the sim (isStriking is false).
function Simulation:riot(citizen: any, seconds: number)
	citizen.riotUntil = math.max(citizen.riotUntil or 0, self.time + seconds)
	citizen.done = true
end

function Simulation:isRioting(citizen: any): boolean
	return citizen.riotUntil ~= nil and self.time < citizen.riotUntil
end

-- A building catches fire or the fire goes out (D-050 (1b), (1c)). On fire it stops producing: nobody farms or
-- builds at it, it takes no deliveries and gives no gather bonus; the citizens working there stop at once and
-- choose again. When the fire goes out the building heals slowly on its own back to the hit points it had
-- when it caught fire (`regenPerSecond` of its maximum; no permanent damage); builders may take over the
-- repair later as a work order.
function Simulation:setBurning(b: any, on: boolean, regenPerSecond: number?)
	if (b.burning == true) == on then
		return
	end
	local kingdom = self.kingdoms[b.kingdomId]
	if on then
		b.burning = true
		b.hpBeforeFire = b.hpBeforeFire or b.hp
		self._repairing[b.id] = nil
		for _, cid in kingdom.citizenIds do
			local c = self.citizens[cid]
			if c.target == b.id and (c.activity == "Farm" or c.activity == "Build") then
				c.done = true -- downs tools at once; the building no longer offers work
			end
		end
	else
		b.burning = nil
		local goal = math.min(b.maxHp, b.hpBeforeFire or b.hp)
		b.hpBeforeFire = nil
		if b.hp < goal and (regenPerSecond or 0) > 0 then
			b.regenPerSecond = regenPerSecond
			self._repairing[b.id] = goal
		end
	end
	self:_recompute(kingdom)
end

-- Passive repair of buildings the fire left damaged, one step of `dt` seconds.
function Simulation:_stepRepairs(dt: number)
	for id, goal in self._repairing do
		local b = self.buildings[id]
		if b == nil or b.destroyed or b.burning then
			self._repairing[id] = nil
		else
			b.hp = math.min(goal, b.hp + b.maxHp * (b.regenPerSecond or 0) * dt)
			if b.hp >= goal then
				b.regenPerSecond = nil
				self._repairing[id] = nil
			end
		end
	end
end

-- On strike, or walked out (productivity down to 0: SPEC §5.4 "−1 = one citizen's walk-out").
function Simulation:isStriking(citizen: any): boolean
	return (citizen.strikeUntil ~= nil and self.time < citizen.strikeUntil) or self:productivityOf(citizen) <= 0
end

-- builder-seconds of work for a level (Costs.building(kind, level).buildSeconds, CONTRACTS G13.5)
function Simulation:workFor(kind: string, level: number): number
	local price = self.costs.building(kind, level)
	assert(price, `no Costs.building({kind}, {level})`)
	return price.buildSeconds
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

-- A footprint circle at (x, z) lies inside the kingdom's land: its keep circle or a claimed region
-- (`keepOnly`: the keep circle alone, which is where a building may be moved to).
function Simulation:insideTerritory(kingdom: any, x: number, z: number, footprint: number, keepOnly: boolean?): boolean
	if kingdom.alive and dist(x, z, kingdom.x, kingdom.z) + footprint <= kingdom.territory then
		return true
	end
	if keepOnly then
		return false
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

-- Where a `kind` building may stand (Place, PlaceSlot and Move share it): inside the bounds and the kingdom's
-- territory (a move: the keep's own circle, never a claimed region), its placement shape clear of every standing
-- building except `ignoreId` (a building being moved does not block itself), of every resource node still
-- present and of every objective zone, each with the placement gap (line pieces, walls and gates, join with
-- wallGap), of the no-build areas (sim.noBuild: crop fields, plot roads, spawn pads) and of every soldier and
-- every ruler's character (G13.9 v0.4-g9j). `yaw` is the facing the building will have.
function Simulation:_geometry(
	kingdom: any,
	kind: string,
	x: number,
	z: number,
	yaw: number,
	ignoreId: number?,
	keepOnly: boolean?
): (boolean, string?)
	local def = self.catalog.buildings[kind]
	local bounds = self.bounds
	if x - def.footprint < bounds.minX or x + def.footprint > bounds.maxX then
		return false, "out_of_bounds"
	end
	if z - def.footprint < bounds.minZ or z + def.footprint > bounds.maxZ then
		return false, "out_of_bounds"
	end
	if not self:insideTerritory(kingdom, x, z, def.footprint, keepOnly) then
		return false, "out_of_territory"
	end
	local gap = self.catalog.tuning.placementGap
	local lineGap = self.catalog.tuning.wallGap -- wall / gate pieces may join end to end
	local shape = self:shapeOf(kind, x, z, yaw)
	for _, bid in self.buildingOrder do
		local b = self.buildings[bid]
		if not b.destroyed and b.id ~= ignoreId then
			local between = if LINE_PIECES[kind] and LINE_PIECES[b.kind] then lineGap else gap
			if Footprint.overlaps(shape, b.shape, between) then
				return false, "blocked"
			end
		end
	end
	for _, nid in self.nodeOrder do
		local node = self.nodes[nid]
		-- depleted trees still block: they grow back
		local present = node.amount > 0 or node.regrow ~= nil
		if present and Footprint.overlapsCircle(shape, node.x, node.z, node.footprint, gap) then
			return false, "blocked"
		end
	end
	-- an objective's zone is never built on (G13.9 v0.4-g9i): not within its radius plus the placement gap
	for _, o in (self.objectives and self.objectives.list) or {} do
		if Footprint.overlapsCircle(shape, o.x, o.z, o.radius, gap) then
			return false, "blocked"
		end
	end
	for _, area in self.noBuild do
		if Footprint.overlaps(shape, area, area.gap or 0) then
			return false, "blocked"
		end
	end
	-- nobody is built over: no soldier of any kingdom and no ruler's character inside the shape
	for _, uid in self.unitOrder do
		local u = self.units[uid]
		if Footprint.overlapsCircle(shape, u.x, u.z, UNIT_BODY, 0) then
			return false, "blocked"
		end
	end
	local clearance = self.catalog.tuning.rulerClearance
	for _, pos in self.rulerPositions do
		if Footprint.overlapsCircle(shape, pos.x, pos.z, clearance, 0) then
			return false, "blocked"
		end
	end
	return true, nil
end

function Simulation:canPlace(kingdom: any, kind: string, x: number, z: number, yaw: number?): (boolean, string?)
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
	local fits, why = self:_geometry(kingdom, kind, x, z, self:_facing(kingdom, kind, x, z, yaw), nil)
	if not fits then
		return false, why
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

-- Activities whose `target` is a building a citizen stands at: they must walk again when it moves
local WORKS_AT_BUILDING: { [string]: boolean } = { Farm = true, Build = true, Sleep = true, Flee = true }

local function sameSpot(b: any, x: number, z: number, yaw: number): boolean
	local turn = (yaw - b.yaw) % (2 * math.pi)
	return math.abs(b.x - x) < 1e-6 and math.abs(b.z - z) < 1e-6 and math.min(turn, 2 * math.pi - turn) < 1e-6
end

-- (building, nil, isNoOp) when `buildingId` may move to (x, z) facing `yaw`, else (nil, reason)
function Simulation:_checkMove(
	kingdom: any,
	buildingId: number,
	x: number,
	z: number,
	yaw: number
): (any?, string?, boolean?)
	if not self.active then
		return nil, "match_not_active"
	end
	if not kingdom.alive then
		return nil, "kingdom_eliminated"
	end
	local b, err = self:_ownedBuilding(kingdom, buildingId)
	if b == nil then
		return nil, err
	end
	if b.kind == "keep" then
		return nil, "not_movable" -- the keep anchors territory, births and the throne
	end
	if sameSpot(b, x, z, yaw) then
		return b, nil, true
	end
	if kingdom.alarm then
		return nil, "alarm" -- a UX rule: the bell is ringing
	end
	local tuning = self.catalog.tuning
	if kingdom.moveLockedUntil ~= nil and self.time < kingdom.moveLockedUntil then
		return nil, "under_attack" -- a war was just declared or ended: nothing moves for moveLockout seconds
	end
	local shape = self:shapeOf(b.kind, x, z, yaw)
	if self:_underAttack(b, shape) then
		return nil, "under_attack"
	end
	if b.movedAt ~= nil and self.time - b.movedAt < tuning.moveCooldown then
		return nil, "cooldown"
	end
	local fits, why = self:_geometry(kingdom, b.kind, x, z, yaw, b.id, true)
	if not fits then
		return nil, why
	end
	return b, nil, false
end

-- Whether building `b` is under attack, for the move rules (G13.9 v0.4-g9j): burning, damaged within
-- moveDamageWindow seconds, targeted or focused by an at-war unit, or an at-war unit within its attack range
-- plus moveThreatReach of the building's shape where it stands or where it would stand (`newShape`).
function Simulation:_underAttack(b: any, newShape: Footprint.Shape): boolean
	local tuning = self.catalog.tuning
	if b.burning then
		return true
	end
	if b.damagedAt ~= nil and self.time - b.damagedAt < tuning.moveDamageWindow then
		return true
	end
	for _, uid in self.unitOrder do
		local u = self.units[uid]
		if self:atWar(b.kingdomId, u.kingdomId) then
			local target, focus = u.target, u.order and u.order.focus
			if
				(target and target.kind == "building" and target.id == b.id)
				or (focus and focus.kind == "building" and focus.id == b.id)
			then
				return true
			end
			local reach = self.catalog.units[u.kind].range + tuning.moveThreatReach
			if
				Footprint.overlapsCircle(b.shape, u.x, u.z, reach, 0)
				or Footprint.overlapsCircle(newShape, u.x, u.z, reach, 0)
			then
				return true
			end
		end
	end
	return false
end

-- Ends the settling of moved drop-offs whose time is up: they take deliveries and give their bonus again
function Simulation:_endSettling()
	for bid in table.clone(self._settling) do
		local b = self.buildings[bid]
		if b == nil or b.destroyed or b.settleUntil == nil or self.time >= b.settleUntil then
			self._settling[bid] = nil
			if b ~= nil then
				b.settleUntil = nil
				if not b.destroyed then
					self:_recompute(self.kingdoms[b.kingdomId])
				end
			end
		end
	end
end

function Simulation:canMoveBuilding(
	kingdom: any,
	buildingId: number,
	x: number,
	z: number,
	yaw: number
): (boolean, string?)
	local b, err = self:_checkMove(kingdom, buildingId, x, z, yaw)
	return b ~= nil, err
end

function Simulation:moveBuilding(
	kingdom: any,
	buildingId: number,
	x: number,
	z: number,
	yaw: number,
	by: number?,
	slotId: string?
): (boolean, string?)
	local b, err, noOp = self:_checkMove(kingdom, buildingId, x, z, yaw)
	if b == nil then
		return false, err
	end
	if noOp then
		return true, nil -- already there and facing that way: nothing changes, no event, no cooldown
	end
	-- from here on nothing can fail and nothing yields: the move is applied whole
	local from = { x = b.x, z = b.z, yaw = b.yaw }
	b.x, b.z, b.yaw = x, z, yaw
	b.shape = self:shapeOf(b.kind, x, z, yaw)
	b.slotId = slotId
	b.movedAt = self.time
	if self.catalog.buildings[b.kind].dropoff then
		-- a moved storehouse, lumber camp or quarry takes no deliveries and gives no gather bonus for a while,
		-- so a drop-off can't be dragged along behind the carriers
		b.settleUntil = self.time + self.catalog.tuning.moveSettle
		self._settling[b.id] = true
		self:_recompute(kingdom)
	end
	for _, cid in kingdom.citizenIds do
		local c = self.citizens[cid]
		if c.target == b.id and WORKS_AT_BUILDING[c.activity] then
			-- Farm and Build work, and sleeping or sheltering, never re-check the distance once started:
			-- back to walking to the building's new place (claims stay)
			if c.phase == "Work" or c.phase == "Rest" then
				c.phase = "Go"
			end
			c._route = nil
		end
	end
	self:emit("BuildingMoved", {
		kingdomId = kingdom.id,
		buildingId = b.id,
		kind = b.kind,
		from = from,
		to = { x = x, z = z, yaw = yaw },
		slotId = slotId,
		by = by,
	})
	return true, nil
end

function Simulation:placeBuilding(
	kingdom: any,
	kind: string,
	x: number,
	z: number,
	by: number?,
	yaw: number?
): (any?, string?)
	local ok, err = self:canPlace(kingdom, kind, x, z, yaw)
	if not ok then
		return nil, err
	end
	local cost = (self.costs.building(kind, 1) :: any).cost
	local nextId = self._nextBuilding + 1
	if not self:spend(kingdom.id, cost, `build:{nextId}:1`, `building:{kind}`) then
		return nil, "cannot_afford" -- e.g. another server-side spend raced us
	end
	local building = self:_createBuilding(kingdom, kind, x, z, yaw)
	assert(building.id == nextId, "building id changed between spend and create")
	building.pendingCost = table.clone(cost)
	building.placedBy = by
	self:emit(
		"BuildingPlaced",
		{ kingdomId = kingdom.id, buildingId = building.id, kind = kind, x = x, z = z, by = by }
	)
	return building, nil
end

-- Build.PlaceLine (FL-0126 part 2, CONTRACTS G13.5/G13.9): a straight wall of Kit segments from (fx, fz) to (tx, tz). Both ends
-- snap to tuning.lineGrid; the length is split into round(length / segment) pieces (at least one), laid end to end along the
-- line and each facing it. All or nothing: every segment passes the Place rules and the kingdom affords them all, or nothing is
-- built or charged. Returns the segments' building ids in order from the first end, else (nil, reason).
function Simulation:placeLine(
	kingdom: any,
	kind: string,
	fx: number,
	fz: number,
	tx: number,
	tz: number,
	by: number?
): ({ number }?, string?)
	local def = self.catalog.buildings[kind]
	if def == nil then
		return nil, "unknown_building"
	end
	if kind ~= "wall" or def.placeSize == nil then
		return nil, "not_a_line_piece" -- gates are put in a wall with Build.PlaceGate, not drawn
	end
	if not kingdom.alive then
		return nil, "kingdom_eliminated"
	end
	local tuning = self.catalog.tuning
	local grid = tuning.lineGrid
	local function snap(v: number): number
		return math.floor(v / grid + 0.5) * grid
	end
	fx, fz, tx, tz = snap(fx), snap(fz), snap(tx), snap(tz)
	local dx, dz = tx - fx, tz - fz
	local length = math.sqrt(dx * dx + dz * dz)
	local segment = def.placeSize.X
	local count = math.max(1, math.floor(length / segment + 0.5))
	if length < grid then
		return nil, "too_short"
	end
	if count > tuning.maxLineSegments then
		return nil, "too_long"
	end
	if def.requiresKeepLevel and self:keepLevel(kingdom) < def.requiresKeepLevel then
		return nil, "requires_keep_level"
	end
	if def.maxCount and self:countOf(kingdom, kind) + count > def.maxCount then -- the D-047 part ceiling counts 12 walls
		return nil, "limit_reached"
	end
	local ux, uz = dx / length, dz / length
	local yaw = math.atan2(-uz, ux) -- Footprint.rect: the piece's long axis in the world is (cos yaw, -sin yaw)
	local price = self.costs.building(kind, 1)
	if price == nil then
		return nil, "unknown_building"
	end
	local total = {}
	for res, amount in price.cost do
		total[res] = amount * count
	end
	-- every segment on its own against the world (neighbours of the same line join end to end, so they never overlap)
	local spots = {}
	for i = 1, count do
		local at = (i - 0.5) * segment
		local x, z = fx + ux * at, fz + uz * at
		local fits, why = self:_geometry(kingdom, kind, x, z, yaw, nil)
		if not fits then
			return nil, why
		end
		table.insert(spots, { x = x, z = z })
	end
	if not self:canAfford(kingdom.id, total) then
		return nil, "cannot_afford"
	end
	local placed = {}
	for _, spot in spots do
		local building, err = self:placeBuilding(kingdom, kind, spot.x, spot.z, by, yaw)
		if building == nil then
			-- a race the checks above cannot see: give everything back in full, as if the line was never drawn
			for _, id in placed do
				local b = self.buildings[id]
				for res, amount in b.pendingCost or {} do
					self:deposit(kingdom.id, res, amount, `refund:line:{id}:{res}`, "refund")
				end
				self:_removeBuilding(b)
			end
			return nil, err
		end
		table.insert(placed, building.id)
	end
	return placed, nil
end

function Simulation:_ownedBuilding(kingdom: any, buildingId: any): (any?, string?)
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
	-- a barracks lost with recruits queued or in training refunds each one in full (D-041); the txIds
	-- differ from cancelConstruction's refund:<id>:<level>:<resource>
	for i, entry in b.queue or {} do
		local price = self.costs.unit(entry.unit)
		for resource, amount in if price then price.cost else {} do
			self:deposit(kingdom.id, resource, amount, `recruit_refund:{b.id}:{i}:{resource}`, "refund")
		end
	end
	if b.queue then
		table.clear(b.queue)
	end
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
	if not kingdom.populated or self.time < kingdom.nextBirthAt then
		return -- an unpopulated kingdom (slice mode, no ruler yet) stays empty
	end
	kingdom.nextBirthAt = self.time + self.catalog.tuning.birthInterval
	local tuning = self.catalog.tuning
	-- beds are for citizens only: soldiers sleep in the barracks (D-041); and no more than the server can carry (D-055)
	if #kingdom.citizenIds >= math.min(kingdom.popCap, tuning.maxPerKingdom or math.huge) then
		return
	end
	if self.fedByUpkeep then
		-- D-045: the upkeep is the only food consumer (G7); a well-fed kingdom grows, it pays no food for it
		if (kingdom.fedRatio or 1) < SocietyConfig.food.wellFedAtLeast then
			return
		end
	else
		-- the meal double (no upkeep): keep a day of meals in reserve, then pay for the birth
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
	end
	local keep = self.buildings[kingdom.keepId]
	local angle = self.rng:NextNumber() * math.pi * 2
	local ring = keep.footprint + 3
	local occ = self:_neededOccupation(kingdom)
	local c = self:_spawnCitizen(kingdom, occ, keep.x + math.cos(angle) * ring, keep.z + math.sin(angle) * ring)
	kingdom.stats.born += 1
	if self.profiler then
		self.profiler.birth(self, kingdom, c)
	end
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
	if self.fedByUpkeep then
		-- G7: the kingdom's upkeep feeds its citizens (ProductionService sets fedRatio each interval):
		-- fully fed, hunger falls; half fed, it holds; unfed, it rises at the normal rate
		local rate = tuning.hungerPerDay / tuning.dayLength * (1 - 2 * kingdom.fedRatio)
		c.hunger = math.max(0, c.hunger + dt * rate)
	else
		c.hunger += dt * tuning.hungerPerDay / tuning.dayLength
	end
	if c.hunger >= tuning.starveDeathHunger then
		self:killCitizen(c, "starvation")
		return
	end

	-- interrupts: emergencies preempt anything; night preempts work once cargo is delivered
	local emergency = kingdom.alarm or self:threatNear(kingdom, c.x, c.z, tuning.fleeRadius)
	if c.hold then
		if self.time < c.hold.untilTime and not emergency then
			return -- talking to the ruler (G13.8): no thinking, no moving
		end
		self:releaseCitizen(c) -- the time is up, or safety first
	end
	local urgent = emergency and c.activity ~= "Flee"
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

	-- decisions are staggered (CONTRACTS G4): at most the tick's budget re-plan, threats excepted;
	-- the rest keep their flag and decide on one of the next ticks
	if (c.done or (self.time >= c.thinkAt and c.carrying == nil)) and (urgent or self._decisionBudget > 0) then
		if not urgent then
			self._decisionBudget -= 1
		end
		local decision = CitizenBrain.decide(self, c)
		self:setActivity(c, decision.activity, decision.target, decision.reason)
		c.thinkAt = self.time + tuning.thinkInterval
	elseif self.time >= c.thinkAt and c.activity == "Gather" and c.phase == "Work" and self._decisionBudget > 0 then
		-- a gatherer mid-load still looks up: a site to build sends it home with what it carries (a slow
		-- gatherer, e.g. a builder chopping wood, would otherwise keep a site waiting for a full load);
		-- it decides again once the load is delivered
		self._decisionBudget -= 1
		if CitizenBrain.decide(self, c).activity == "Build" then
			c.phase = "Return"
		end
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
	if next(self._repairing) ~= nil then
		self:_stepRepairs(dt)
	end
	if next(self._settling) ~= nil then
		self:_endSettling()
	end
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

	-- about twice the average re-planning rate per tick (everyone every thinkInterval), at least 2
	local tuning = self.catalog.tuning
	self._decisionBudget = math.max(2, math.ceil(#self.citizenOrder * dt / tuning.thinkInterval * 2))
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
