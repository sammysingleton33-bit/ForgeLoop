--!strict
--[[
	Gameplay/Kingdom/RulerAI — an AI ruler for kingdoms without human rulers.

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
	The AI only issues commands the simulation will accept (checked by specs): it recruits with a
	finished barracks, room for the batch and its full price; accepts only unexpired proposals; and
	declares no war in the grace period or on a kingdom it is in a peace cooldown with.

	API
		RulerAI.install(sim, options?)  -- options: { interval = 6, assistHumans = false }
		RulerAI.think(sim, kingdom): string?    -- one decision now; returns the command issued (specs)
		RulerAI.findSpot(sim, kingdom, kind, near?): (number?, number?)  -- a valid placement, or nil;
		                                         near = { x, z } searches outward from that point instead of the keep
]]

local Commands = require("./Commands")
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
		state.aggression[kingdom.id] = 0.3 + 0.7 * sim.rng:NextNumber()
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

local function place(sim: any, kingdom: any, kind: string, near: { x: number, z: number }?): string?
	local price = sim.costs.building(kind, 1)
	if price == nil or not sim:canAfford(kingdom.id, price.cost) then
		return nil
	end
	local x, z = RulerAI.findSpot(sim, kingdom, kind, near)
	if x == nil then
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

-- Neighbours are the kingdoms next to this one around the map (k1-k2-k3-k4-k1), so an AI never
-- marches across the centre while a neighbour stands. Kingdoms already fighting two wars are
-- left alone (no dog-piling a single kingdom, human or AI).
-- The kingdom's nearest node of a resource (by distance from the keep), as a placement anchor.
local function nearestNode(sim: any, kingdom: any, resource: string): { x: number, z: number }?
	local best, bestDistance = nil, math.huge
	for _, nid in kingdom.nearNodes do
		local node = sim.nodes[nid]
		if node.resource == resource then
			local dx, dz = node.x - kingdom.x, node.z - kingdom.z
			local d = dx * dx + dz * dz
			if d < bestDistance then
				best, bestDistance = node, d
			end
		end
	end
	return if best then { x = best.x, z = best.z } else nil
end

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
		if #enemies > 0 and army >= 8 then
			local unit = sim.units[kingdom.unitIds[1]]
			if unit.order.kind ~= "Attack" then
				local target = enemies[1]
				if Commands.executeFor(sim, kingdom, nil, "ArmyOrder", "Attack", target.id) then
					return "ArmyOrder:Attack"
				end
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
			local unit = sim.units[kingdom.unitIds[1]]
			local order = unit.order
			local already = order.kind == "Move" and order.x == best.x and order.z == best.z
			if not already and Commands.executeFor(sim, kingdom, nil, "ArmyOrder", "Move", best.x, best.z) then
				return "ArmyOrder:Objective"
			end
		end
	end

	-- housing
	if pop >= kingdom.popCap - 1 and not hasSite(sim, kingdom, "house") then
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
			-- only what Recruit accepts: a finished barracks, room for the batch (queued units
			-- count, and count toward the army) and its full price
			local training = queuedUnits(sim, kingdom)
			local target = math.max(2, math.floor(pop * (0.15 + 0.2 * aggression)))
			local kind = if army % 2 == 0 then "soldier" else "archer"
			local cost = {}
			for res, amount in sim.catalog.units[kind].cost do
				cost[res] = amount * 2
			end
			if
				count(sim, kingdom, "barracks", false) > 0
				and army + training < target
				and pop + training + 2 <= kingdom.popCap
				and sim:canAfford(kingdom.id, cost)
				and Commands.executeFor(sim, kingdom, nil, "Recruit", kind, 2)
			then
				return "Recruit:" .. kind
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
		interval = opts.interval or 6,
		assistHumans = opts.assistHumans == true,
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
