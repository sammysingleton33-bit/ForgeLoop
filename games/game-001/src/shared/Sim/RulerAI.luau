--!strict
--[[
	Sim/RulerAI — an AI ruler for kingdoms without human rulers.

	Every kingdom always has someone in charge: when no player rules it (empty slot, or every ruler
	left), the AI ruler issues the same validated Commands a player would — it cannot cheat. When a
	player joins that kingdom the AI steps back on its next think. Citizens run themselves either way;
	the ruler (human or AI) only sets direction.

	Behaviour (one action per think, every `interval` seconds, staggered per kingdom):
		defence   ring the alarm while enemies are inside the territory and no army defends it
		housing   build a House when population is within 1 of the cap
		food      build Farms to keep about one farm per 5 citizens; farmer quota follows farm slots
		logistics build a Lumber Camp by the forest and a Quarry by the rocks (shorter carry trips)
		growth    upgrade the Keep from day 3; upgrade Houses when wood and stone are plentiful
		military  build a Barracks from day 4, keep an army of about a quarter of the population,
		          Watchtowers after Keep level 2
		objective with 3+ soldiers and no war, march on the nearest capture point it does not own
		war       after the grace period, an aggressive AI declares war on the weakest neighbour and
		          attacks once its army is large enough; it proposes peace when its army is gone and
		          accepts peace when it is behind on score
	Aggression is seeded per kingdom (0.3..1.0) so AI kingdoms differ but stay deterministic.
	A placement search that finds nothing rests for NO_SPOT_RETRY seconds (a full territory walk is the most
	expensive thing a think can do; the governors of a full-length match spent most of their tick budget on it).
	The AI only issues commands the simulation will accept (checked by specs): it recruits with a
	finished barracks, room for the batch and its full price; accepts only unexpired proposals; and
	declares no war in the grace period or on a kingdom it is in a peace cooldown with.

	API
		RulerAI.install(sim, options?)  -- options: { interval = 6, assistHumans = false, minAggression = 0.3,
		                                   maxAggression = 1.0 } (MatchHost passes config Governor)
		RulerAI.think(sim, kingdom): string?    -- one decision now; returns the command issued (specs)
		RulerAI.findSpot(sim, kingdom, kind, near?): (number?, number?)  -- a valid placement, or nil;
		                                         near = { x, z } searches outward from that point instead of the keep
]]

local Commands = require("./Commands")
local Military = require("./Military")
local Snapshot = require("./Snapshot")

local RulerAI = {}

local function count(sim: any, kingdom: any, kind: string, includeSites: boolean): number
	local n = 0
	for _, bid in kingdom.buildingIds do
		local b = sim.buildings[bid]
		if b.kind == kind and (includeSites or b.level >= 1) then
			n += 1
		end
	end
	return n
end

-- Seeds a kingdom's aggression and think schedule the first time it is needed (the system's first
-- tick, or a direct think() before that).
local function aggressionOf(sim: any, state: any, kingdom: any): number
	if state.aggression[kingdom.id] == nil then
		state.aggression[kingdom.id] = state.minAggression
			+ (state.maxAggression - state.minAggression) * sim.rng:NextNumber()
		state.nextThink[kingdom.id] = kingdom.index * state.interval / math.max(1, #sim.kingdomOrder)
	end
	return state.aggression[kingdom.id]
end

local function queuedUnits(sim: any, kingdom: any): number
	local n = 0
	for _, bid in kingdom.buildingIds do
		local b = sim.buildings[bid]
		if b.kind == "barracks" then
			n += #b.queue
		end
	end
	return n
end

local function hasSite(sim: any, kingdom: any, kind: string?): boolean
	for _, bid in kingdom.buildingIds do
		local b = sim.buildings[bid]
		if b.pendingLevel ~= nil and (kind == nil or b.kind == kind) then
			return true
		end
	end
	return false
end

function RulerAI.findSpot(sim: any, kingdom: any, kind: string, near: { x: number, z: number }?): (number?, number?)
	local def = sim.catalog.buildings[kind]
	local keep = sim.buildings[kingdom.keepId]
	if def == nil or keep == nil then
		return nil, nil
	end
	local offset = sim.rng:NextNumber() * math.pi * 2
	local cx, cz = kingdom.x, kingdom.z
	local radius = keep.footprint + def.footprint + 6
	if near then
		cx, cz = near.x, near.z
		radius = def.footprint + 6
	end
	-- search rings outward until they leave the territory entirely
	while radius <= kingdom.territory * 2 do
		local steps = math.max(8, math.floor(radius / 6))
		for i = 0, steps - 1 do
			local angle = offset + i / steps * math.pi * 2
			local x, z = cx + math.cos(angle) * radius, cz + math.sin(angle) * radius
			if sim:canPlace(kingdom, kind, x, z) then
				return x, z
			end
		end
		radius += 8
	end
	return nil, nil
end

-- A search that finds no valid spot walks every ring of the territory (a few milliseconds of canPlace each), so a
-- kingdom with no room for a farm would repeat it at every think. It rests for this long after an empty search.
local NO_SPOT_RETRY = 60 -- seconds

local function place(sim: any, kingdom: any, kind: string, near: { x: number, z: number }?): string?
	local price = sim.costs.building(kind, 1)
	if price == nil or not sim:canAfford(kingdom.id, price.cost) then
		return nil
	end
	local resting = sim.rulerAI.noSpotUntil
	local key = `{kingdom.id}:{kind}`
	if resting[key] ~= nil and sim.time < resting[key] then
		return nil
	end
	local x, z = RulerAI.findSpot(sim, kingdom, kind, near)
	if x == nil then
		resting[key] = sim.time + NO_SPOT_RETRY
		return nil
	end
	local ok = Commands.executeFor(sim, kingdom, nil, "PlaceBuilding", kind, x, z)
	return if ok then "PlaceBuilding:" .. kind else nil
end

local function tryUpgrade(sim: any, kingdom: any, kind: string, maxLevel: number): string?
	for _, bid in kingdom.buildingIds do
		local b = sim.buildings[bid]
		if b.kind == kind and b.level >= 1 and b.level < maxLevel and b.pendingLevel == nil then
			local price = sim.costs.building(kind, b.level + 1)
			if price and sim:canAfford(kingdom.id, price.cost) then
				local ok = Commands.executeFor(sim, kingdom, nil, "UpgradeBuilding", bid)
				return if ok then "UpgradeBuilding:" .. kind else nil
			end
		end
	end
	return nil
end

local function warsOf(sim: any, kingdom: any): number
	local n = 0
	for _, kid in sim.kingdomOrder do
		if kid ~= kingdom.id and sim.kingdoms[kid].alive and sim:atWar(kingdom.id, kid) then
			n += 1
		end
	end
	return n
end

-- The kingdom's nearest node of a resource (by distance from the keep), as a placement anchor.
local function nearestNode(sim: any, kingdom: any, resource: string): { x: number, z: number }?
	local best, bestDistance = nil, math.huge
	for _, nid in kingdom.nearNodes do
		local node = sim.nodes[nid]
		if node.resource == resource and node.amount > 0 then
			local dx, dz = node.x - kingdom.x, node.z - kingdom.z
			local d = dx * dx + dz * dz
			if d < bestDistance then
				best, bestDistance = node, d
			end
		end
	end
	return if best then { x = best.x, z = best.z } else nil
end

-- Neighbours are the kingdoms next to this one around the map (adjacent in kingdom order, which
-- runs clockwise), so an AI never marches across the centre while a neighbour stands. Kingdoms
-- already fighting two wars are left alone (no dog-piling a single kingdom, human or AI).
local function weakestEnemy(sim: any, kingdom: any): any?
	local n = #sim.kingdomOrder
	local neighbours = {}
	for _, kid in sim.kingdomOrder do
		local other = sim.kingdoms[kid]
		local gap = math.abs(other.index - kingdom.index)
		if other.alive and kid ~= kingdom.id and (n <= 3 or gap == 1 or gap == n - 1) then
			table.insert(neighbours, other)
		end
	end
	if #neighbours == 0 then
		-- every neighbour has fallen: anyone still standing is fair game
		for _, kid in sim.kingdomOrder do
			if kid ~= kingdom.id and sim.kingdoms[kid].alive then
				table.insert(neighbours, sim.kingdoms[kid])
			end
		end
	end
	local diplomacy = sim.diplomacy
	local best, bestScore = nil, math.huge
	for _, other in neighbours do
		local madePeace = diplomacy.peaceAt[sim:relationKey(kingdom.id, other.id)]
		local cooling = madePeace ~= nil and sim.time - madePeace < diplomacy.peaceCooldown
		if warsOf(sim, other) < 2 and not cooling then
			local score = Snapshot.score(sim, other)
			if score < bestScore then
				best, bestScore = other, score
			end
		end
	end
	return best
end

local function enemiesAtWar(sim: any, kingdom: any): { any }
	local out = {}
	for _, kid in sim.kingdomOrder do
		if kid ~= kingdom.id and sim.kingdoms[kid].alive and sim:atWar(kingdom.id, kid) then
			table.insert(out, sim.kingdoms[kid])
		end
	end
	return out
end

-- ---------------------------------------------------------------- assaults (FL-0126, siege viability)
-- A governor attacks as one body, with a ram: soldiers barely scratch a keep (config Military `siege`), so a trickle of
-- eight dies to the defenders and the keep never falls. It launches when its fighters number at least ASSAULT_MIN (or
-- 1.3 times the target's units, never more than the army cap allows) and a ram stands with them, keeps every new
-- unit marching while it holds, and pulls back when fewer than ASSAULT_BREAK fighters are left.
local ASSAULT_MIN = 8
local ASSAULT_OUTNUMBER = 1.3
local ASSAULT_BREAK = 4
local ASSAULT_IMPATIENCE = 1500 -- seconds of possible war that remove the whole 0.4 of margin
local RAMS_WANTED = 2 -- rams a governor keeps (bunks are reserved for them from day 5)

local function ramsOf(sim: any, kingdom: any): number
	local n = 0
	for _, uid in kingdom.unitIds do
		if sim.units[uid].kind == "ram" then
			n += 1
		end
	end
	return n
end

local function assault(sim: any, kingdom: any, target: any): string?
	local army = #kingdom.unitIds
	if army == 0 then
		return nil
	end
	local rams = ramsOf(sim, kingdom)
	local fighters = army - rams
	local marching = 0
	for _, uid in kingdom.unitIds do
		if sim.units[uid].order.kind == "Attack" then
			marching += 1
		end
	end
	-- how many fighters it wants before going: ASSAULT_MIN at least, and a margin over the target's army that shrinks
	-- with the governor's aggression and with the time the war has been possible, so a stalemate between equal
	-- armies ends in an attack instead of two armies watching each other for ever
	local margin = ASSAULT_OUTNUMBER
		- 0.5 * aggressionOf(sim, sim.rulerAI, kingdom)
		- math.min(0.4, math.max(0, sim.time - sim.diplomacy.graceSeconds) / ASSAULT_IMPATIENCE)
	local needed =
		math.min(math.max(ASSAULT_MIN, math.ceil(#target.unitIds * margin)), Military.armyCap(sim) - RAMS_WANTED)
	if marching == 0 then
		if
			fighters >= needed
			and rams >= 1
			and Commands.executeFor(sim, kingdom, nil, "ArmyOrder", "Attack", target.id)
		then
			return "ArmyOrder:Attack"
		end
		-- still gathering: a march on a capture point (begun at peace) is called off, the army waits at home
		for _, uid in kingdom.unitIds do
			if sim.units[uid].order.kind == "Move" then
				if Commands.executeFor(sim, kingdom, nil, "ArmyOrder", "Defend") then
					return "ArmyOrder:Defend"
				end
				break
			end
		end
	elseif fighters < ASSAULT_BREAK then
		if Commands.executeFor(sim, kingdom, nil, "ArmyOrder", "Defend") then
			return "ArmyOrder:Defend" -- too few left: pull back and rebuild
		end
	elseif marching < army and fighters >= ASSAULT_BREAK then
		if Commands.executeFor(sim, kingdom, nil, "ArmyOrder", "Attack", target.id) then
			return "ArmyOrder:Attack" -- fresh recruits join the assault
		end
	end
	return nil
end

function RulerAI.think(sim: any, kingdom: any): string?
	if not kingdom.alive then
		return nil
	end
	local ai = sim.rulerAI
	local aggression = aggressionOf(sim, ai, kingdom)
	local day = sim:day()
	local pop = sim:population(kingdom)
	local army = #kingdom.unitIds

	-- defence
	local threatened = #kingdom.threats > 0
	if threatened ~= kingdom.alarm and (not threatened or army < 2) then
		Commands.executeFor(sim, kingdom, nil, "SetAlarm", threatened)
		return "SetAlarm"
	end

	-- war and peace (only when diplomacy is installed)
	local enemies = enemiesAtWar(sim, kingdom)
	if sim.diplomacy then
		for _, enemy in enemies do
			local proposedAt = sim.diplomacy.proposals[enemy.id .. ">" .. kingdom.id]
			local open = proposedAt ~= nil and sim.time - proposedAt <= sim.diplomacy.proposalSeconds
			if open and Snapshot.score(sim, kingdom) < Snapshot.score(sim, enemy) then
				if Commands.executeFor(sim, kingdom, nil, "AcceptPeace", enemy.id) then
					return "AcceptPeace"
				end
			end
		end
		if #enemies > 0 and army == 0 then
			-- one open proposal at a time: wait for it to expire before proposing again
			local enemy = enemies[1]
			local mine = sim.diplomacy.proposals[kingdom.id .. ">" .. enemy.id]
			if mine == nil or sim.time - mine > sim.diplomacy.proposalSeconds then
				if Commands.executeFor(sim, kingdom, nil, "ProposePeace", enemy.id) then
					return "ProposePeace"
				end
			end
		end
		local warDay = 9 - math.floor(aggression * 4) -- day 5 (aggressive) .. day 8 (cautious)
		if #enemies == 0 and day >= warDay and army >= 6 and sim.time >= sim.diplomacy.graceSeconds then
			local target = weakestEnemy(sim, kingdom)
			if target and Commands.executeFor(sim, kingdom, nil, "DeclareWar", target.id) then
				return "DeclareWar"
			end
		end
		if #enemies > 0 then
			local issued = assault(sim, kingdom, enemies[1])
			if issued then
				return issued
			end
		end
	end

	-- objectives: a standing army at peace marches on the nearest capture point it does not own
	if sim.objectives and #enemies == 0 and army >= 3 then
		local best, bestDistance = nil, math.huge
		for _, o in sim.objectives.list do
			if o.owner ~= kingdom.id then
				local dx, dz = o.x - kingdom.x, o.z - kingdom.z
				local d = dx * dx + dz * dz
				if d < bestDistance then
					best, bestDistance = o, d
				end
			end
		end
		if best then
			-- re-issue only when some soldier (e.g. a fresh recruit) is not marching there yet
			local already = true
			for _, uid in kingdom.unitIds do
				local order = sim.units[uid].order
				if not (order.kind == "Move" and order.x == best.x and order.z == best.z) then
					already = false
					break
				end
			end
			if not already and Commands.executeFor(sim, kingdom, nil, "ArmyOrder", "Move", best.x, best.z) then
				return "ArmyOrder:Objective"
			end
		end
	end

	-- housing: beds are for citizens only, soldiers sleep in barracks bunks (D-041)
	if #kingdom.citizenIds >= kingdom.popCap - 1 and not hasSite(sim, kingdom, "house") then
		local issued = place(sim, kingdom, "house")
		if issued then
			return issued
		end
	end
	-- food
	local farms = count(sim, kingdom, "farm", true)
	if farms < math.ceil(#kingdom.citizenIds / 5) and not hasSite(sim, kingdom, "farm") then
		local issued = place(sim, kingdom, "farm")
		if issued then
			return issued
		end
	end
	local slots = 0
	for _, bid in kingdom.buildingIds do
		local b = sim.buildings[bid]
		if b.kind == "farm" and b.level >= 1 then
			slots += sim.catalog.buildings.farm.levels[b.level].workers or 0
		end
	end
	if slots > 0 and kingdom.quotas.farmer ~= slots then
		Commands.executeFor(sim, kingdom, nil, "SetJobQuota", "farmer", slots)
		return "SetJobQuota:farmer"
	end
	-- logistics: drop-offs next to the forest and the rocks shorten every carry trip
	if day >= 2 and not hasSite(sim, kingdom) then
		for _, entry in { { kind = "lumbercamp", resource = "wood" }, { kind = "quarry", resource = "stone" } } do
			if count(sim, kingdom, entry.kind, true) == 0 then
				local spot = nearestNode(sim, kingdom, entry.resource)
				local issued = spot and place(sim, kingdom, entry.kind, spot)
				if issued then
					return issued
				end
			end
		end
	end
	-- growth
	if day >= 3 and not hasSite(sim, kingdom) then
		local issued = tryUpgrade(sim, kingdom, "keep", 3)
		if issued then
			return issued
		end
	end
	-- military
	if day >= 4 then
		if count(sim, kingdom, "barracks", true) == 0 then
			local issued = place(sim, kingdom, "barracks")
			if issued then
				return issued
			end
		else
			-- only what Recruit accepts: a finished barracks, bunks for the batch (queued units
			-- count, and count toward the army) and its full price
			local training = queuedUnits(sim, kingdom)
			-- (and never above the army this server can carry, D-055)
			local target = math.min(math.max(2, math.floor(pop * (0.15 + 0.2 * aggression))), Military.armyCap(sim))
			-- alternate soldiers and archers (archers only where Costs lists them)
			local kind = if army % 2 == 0 or sim.costs.unit("archer") == nil then "soldier" else "archer"
			-- from day 5 the last bunks are kept for the rams (FL-0126): the soldiers alone cannot take a keep
			local ramRoom = if day >= 5 then math.max(0, RAMS_WANTED - ramsOf(sim, kingdom)) else 0
			local price = sim.costs.unit(kind) :: any
			local cost = {}
			for res, amount in price.cost do
				cost[res] = amount * 2
			end
			if
				count(sim, kingdom, "barracks", false) > 0
				and army + training + 2 <= math.min(Military.recruitCap(sim, kingdom), Military.armyCap(sim)) - ramRoom
				and army + training < target
				and sim:canAfford(kingdom.id, cost)
				and Commands.executeFor(sim, kingdom, nil, "Recruit", kind, 2)
			then
				return "Recruit:" .. kind
			end
			-- a barracks that can train rams (level 2), then one ram that waits at home for the war (FL-0126)
			if army >= 4 and day >= 5 then
				if ramsOf(sim, kingdom) < RAMS_WANTED and training == 0 then
					local ram = sim.costs.unit("ram")
					if
						ram ~= nil
						and count(sim, kingdom, "barracks", false) > 0
						and army + 1 <= math.min(Military.recruitCap(sim, kingdom), Military.armyCap(sim))
						and sim:canAfford(kingdom.id, ram.cost)
						and Commands.executeFor(sim, kingdom, nil, "Recruit", "ram", 1)
					then
						return "Recruit:ram"
					end
				end
				if not hasSite(sim, kingdom, "barracks") then
					local issued = tryUpgrade(sim, kingdom, "barracks", 2)
					if issued then
						return issued
					end
				end
			end
			-- the bunks cap the army, and war needs one (army >= 6): when they are all that holds it back, build
			-- more room (a barracks upgrade adds four bunks per level)
			if
				army + training < target
				and army + training + 2 > Military.recruitCap(sim, kingdom)
				and not hasSite(sim, kingdom, "barracks")
			then
				local issued = tryUpgrade(sim, kingdom, "barracks", 4)
				if issued then
					return issued
				end
			end
		end
		if sim:keepLevel(kingdom) >= 2 and count(sim, kingdom, "watchtower", true) < 2 then
			local issued = place(sim, kingdom, "watchtower")
			if issued then
				return issued
			end
		end
	end
	if sim:balance(kingdom.id, "wood") > 150 and sim:balance(kingdom.id, "stone") > 120 then
		local issued = tryUpgrade(sim, kingdom, "house", 3)
		if issued then
			return issued
		end
	end
	return nil
end

function RulerAI.install(sim: any, options: { [string]: any }?)
	assert(sim.rulerAI == nil, "RulerAI.install: already installed")
	local opts = options or {}
	local state = {
		minAggression = opts.minAggression or 0.3,
		maxAggression = opts.maxAggression or 1.0,
		interval = opts.interval or 6,
		assistHumans = opts.assistHumans == true,
		noSpotUntil = {} :: { [string]: number }, -- "kingdom:kind" -> sim time before which no new search is made
		nextThink = {} :: { [string]: number },
		aggression = {} :: { [string]: number },
		lastAction = {} :: { [string]: string? },
	}
	sim.rulerAI = state
	sim:addSystem({
		afterCitizens = function(s: any, _dt: number)
			for _, kid in s.kingdomOrder do
				local kingdom = s.kingdoms[kid]
				aggressionOf(s, state, kingdom)
				if
					kingdom.alive
					and (#kingdom.rulers == 0 or state.assistHumans)
					and s.time >= state.nextThink[kid]
				then
					state.nextThink[kid] = s.time + state.interval
					state.lastAction[kid] = RulerAI.think(s, kingdom)
				end
			end
		end,
	})
end

return RulerAI
