--!strict
--[[
	Sim/CitizenActions — executes a citizen's current activity for one tick.

	Each activity is a tiny state machine over `citizen.phase`:
		Gather  Go (to node) -> Work (fill carry at the node's rate, faster by the kingdom's best lumber camp
		        or quarry level: kingdom.gatherBonus) -> Return (to nearest drop-off) -> done
		Farm    Go (to farm) -> Work (harvest every harvestTime: +yield food) -> Return -> done
		Build   Go (to site) -> Work (add work; the site completes when work reaches the level's cost) -> done
		Eat     Go (to keep) -> eat a meal; with tuning.mealsChargeTreasury the meal is paid from the
		        treasury (double of FORGE-03 upkeep, G7), otherwise eating only needs food in stock -> done
		Sleep   Go (home or keep) -> Rest until morning -> done
		Flee    Go (keep) -> Rest while the alarm rings or a threat is near -> done
		Idle    wander a short hop near the keep, pause, done
	`citizen.done = true` hands control back to CitizenBrain on the next tick. Movement is straight
	line on the XZ plane at catalog.tuning.citizenSpeed (half speed while starving); the server host
	can swap in pathfinding later without changing activities.
	Work slots (D-059, FORGE-04 under a one-PR exception): citizens working the same node or building
	(Gather, Farm, Build) stand apart instead of on one spot. Each takes a slot on the reach circle it
	stopped at before (the target's radius), on the kingdom's side of the target (towards its centre),
	turned by 0, +1, -1, +2, -2, ... steps of SLOT_SPACING studs of arc (at most SLOT_MAX_TURN a step, on a
	small tree or rock); when the circle is full the next slots stand on a ring SLOT_SPACING further out.
	The worker walks onto its slot (moveTo stops arriveRadius short; the last stretch is walked too). The slot index
	is the lowest one free among the citizens on that target, scanned in sim.citizenOrder when the slot
	is taken: deterministic, no randomness. It is kept while the target stays the same and where it was
	(a gatherer comes back to its own spot; a moved farm or site gives a new slot, FL-0119), and freed on
	the first step with another target (or none). The worker faces
	its target (citizen.faceX/faceZ, read by Sim/Replication). Slots change where a worker stands and its
	walk to get there, never who works or how fast.

	API
		CitizenActions.step(sim, citizen, dt)
		CitizenActions.moveTo(sim, citizen, x, z, radius, dt): boolean  -- true once within radius
		CitizenActions.skill(sim, citizen, kind): number                -- work-rate multiplier
		CitizenActions.workSpot(sim, citizen, x, z, radius): (number, number) -- its work slot (above)
		CitizenActions.SLOT_SPACING, SLOT_MAX_TURN
]]

local Nav = require("./Nav")

local CitizenActions = {}

local function dist(ax: number, az: number, bx: number, bz: number): number
	local dx, dz = ax - bx, az - bz
	return math.sqrt(dx * dx + dz * dz)
end

function CitizenActions.moveTo(sim: any, c: any, x: number, z: number, radius: number, dt: number): boolean
	local tuning = sim.catalog.tuning
	local d = dist(c.x, c.z, x, z)
	local reach = math.max(radius, tuning.arriveRadius)
	if d <= reach then
		return true
	end
	local speed = tuning.citizenSpeed
	if c.hunger >= 1 then
		speed *= 0.5
	end
	local stepLen = speed * dt
	local wx, wz = Nav.waypoint(sim, c, x, z)
	if wx ~= x or wz ~= z then
		-- on a leg of a long route (roads and bridges, Sim/Nav): walk to the waypoint
		local dw = dist(c.x, c.z, wx, wz)
		if dw > 0 then
			local f = math.min(1, stepLen / dw)
			c.x += (wx - c.x) * f
			c.z += (wz - c.z) * f
		end
		return false
	end
	local travel = d - reach
	if stepLen >= travel then
		-- stop at the edge of the target radius, not inside the target
		local f = travel / d
		c.x += (x - c.x) * f
		c.z += (z - c.z) * f
		return true
	end
	c.x += (x - c.x) / d * stepLen
	c.z += (z - c.z) / d * stepLen
	return false
end

-- studs between neighbouring slots: a drawn citizen is 2.4 studs wide x the client's rig scale (EntityController.Def
-- .RIG_SCALE, 1.5; FORGE-00 22 Oct) = 3.6, so 5 leaves 1.4 between neighbours. Not 3.5 x 1.5: at 5.25 FORGE-01's
-- "two builders finish it sooner" test sees the second builder still gathering when the build ends (timing, D-059)
CitizenActions.SLOT_SPACING = 5.0
CitizenActions.SLOT_MAX_TURN = math.rad(70) -- at most this turn a step, on a small target: a tree's two slots 4.6 studs apart

-- 0, 1, -1, 2, -2, ...: the slot's steps from the approach
local function slotSteps(index: number): number
	local k = math.ceil(index / 2)
	return if index % 2 == 1 then k else -k
end

-- The citizen's work slot at its target (citizen.target: a node's id is a string, a building's a number, so the
-- two never mix), centred on x, z, on the circle of `radius`. Taken once per target and target position; see the
-- header.
function CitizenActions.workSpot(sim: any, c: any, x: number, z: number, radius: number): (number, number)
	if c.slotTarget ~= c.target or c.slotX == nil or c.slotAtX ~= x or c.slotAtZ ~= z then
		local used = {}
		for _, id in sim.citizenOrder do
			local o = sim.citizens[id]
			if o ~= nil and o ~= c and o.target == c.target and o.slotTarget == c.target then
				used[o.slot] = true
			end
		end
		local index = 0
		while used[index] do
			index += 1
		end
		-- every slot of a target is measured from one side, the kingdom's centre (+X for the keep itself)
		local kingdom = sim.kingdoms[c.kingdomId]
		local ax, az = 0, 0
		if kingdom ~= nil then
			ax, az = kingdom.x - x, kingdom.z - z
		end
		local side = if ax * ax + az * az > 1e-6 then math.atan2(az, ax) else 0
		local step = math.min(CitizenActions.SLOT_SPACING / radius, CitizenActions.SLOT_MAX_TURN)
		-- the slots that fit round the circle without meeting; the next ones stand on a ring SLOT_SPACING further out
		local perRing = math.max(1, math.floor(2 * math.pi / step + 1e-9))
		local ring = radius + (index // perRing) * CitizenActions.SLOT_SPACING
		local angle = side + slotSteps(index % perRing) * step
		c.slotX, c.slotZ = x + math.cos(angle) * ring, z + math.sin(angle) * ring
		c.slot, c.slotTarget, c.slotAtX, c.slotAtZ = index, c.target, x, z
		c.faceX, c.faceZ = x, z
	end
	return c.slotX, c.slotZ
end

-- The last stretch onto a work slot (moveTo stops arriveRadius short of it): true once standing on it.
local function settle(sim: any, c: any, x: number, z: number, dt: number): boolean
	local d = dist(c.x, c.z, x, z)
	local speed = sim.catalog.tuning.citizenSpeed * (if c.hunger >= 1 then 0.5 else 1)
	if d <= speed * dt then
		c.x, c.z = x, z
		return true
	end
	c.x += (x - c.x) / d * speed * dt
	c.z += (z - c.z) / d * speed * dt
	return false
end

function CitizenActions.skill(sim: any, c: any, kind: string): number
	local job = sim.catalog.jobs[c.job]
	local base = job.affinity[kind] or 0.25
	local multiplier = math.max(0.25, base)
	if c.hunger >= 1 then
		multiplier *= 0.5 -- starving citizens work at half speed
	end
	return multiplier * sim:productivityOf(c) -- decision consequences (G13.3), 1 by default
end

local function finish(c: any)
	c.done = true
end

-- Deposits the citizen's cargo into the kingdom treasury: TreasuryService:deposit with txId
-- "dep:<entityId>:<tripSeq>" (CONTRACTS G5), so a replayed trip can never count twice.
local function deposit(sim: any, c: any)
	local kingdom = sim.kingdoms[c.kingdomId]
	local cargo = c.carrying
	c.carrying = nil
	if cargo and cargo.amount > 0 then
		c.tripSeq += 1
		sim:deposit(kingdom.id, cargo.resource, cargo.amount, `dep:{c.id}:{c.tripSeq}`, `citizen:{c.job}`)
		kingdom.stats.gathered[cargo.resource] += cargo.amount
		sim:emit("ResourceGathered", {
			kingdomId = kingdom.id,
			resource = cargo.resource,
			amount = cargo.amount,
			source = "citizen",
			citizenId = c.id,
		})
	end
end

local function returnCargo(sim: any, c: any, dt: number)
	local kingdom = sim.kingdoms[c.kingdomId]
	local dropoff = sim:nearestDropoff(kingdom, c.x, c.z, c.carrying and c.carrying.resource)
	if dropoff == nil then
		-- nowhere to deliver (keep destroyed): drop the load
		c.carrying = nil
		finish(c)
		return
	end
	if not CitizenActions.moveTo(sim, c, dropoff.x, dropoff.z, dropoff.footprint + 1, dt) then
		return
	end
	deposit(sim, c)
	finish(c)
end

local function gather(sim: any, c: any, dt: number)
	if c.phase == "Return" then
		returnCargo(sim, c, dt)
		return
	end
	local node = c.target and sim.nodes[c.target]
	if node == nil or node.amount <= 0 then
		if c.carrying then
			c.phase = "Return"
			sim:releaseClaim(c)
		else
			finish(c)
		end
		return
	end
	if c.carrying and c.carrying.amount > 0 and c.carrying.resource ~= node.resource then
		-- a load from before (a walk-out stopped the delivery): delivered first, never swapped (#107 M3)
		c.phase = "Return"
		sim:releaseClaim(c)
		returnCargo(sim, c, dt)
		return
	end
	if c.phase == "Go" then
		local sx, sz = CitizenActions.workSpot(sim, c, node.x, node.z, node.footprint + 1)
		if CitizenActions.moveTo(sim, c, sx, sz, 0, dt) and settle(sim, c, sx, sz, dt) then
			c.phase = "Work"
		end
		return
	end
	-- Work
	local tuning = sim.catalog.tuning
	local carry = tuning.carry
	if c.carrying == nil or c.carrying.resource ~= node.resource then
		c.carrying = { resource = node.resource, amount = 0 }
	end
	local cargo = c.carrying :: { resource: string, amount: number }
	local kingdom = sim.kingdoms[c.kingdomId]
	local bonus = 1 + (kingdom and kingdom.gatherBonus and kingdom.gatherBonus[node.resource] or 0)
	c.workTimer += dt * (tuning.gatherRate[node.resource] or 0.5) * CitizenActions.skill(sim, c, node.resource) * bonus
	while c.workTimer >= 1 and cargo.amount < carry and node.amount > 0 do
		c.workTimer -= 1
		cargo.amount += 1
		node.amount -= 1
	end
	if node.amount <= 0 then
		node.depletedAt = sim.time
		sim:remember(c, { kind = "depleted", ref = node.id })
		sim:emit("NodeDepleted", { nodeId = node.id, resource = node.resource })
		sim:releaseClaim(c)
		c.phase = "Return"
	elseif cargo.amount >= carry then
		c.phase = "Return"
	end
end

local function farm(sim: any, c: any, dt: number)
	if c.phase == "Return" then
		returnCargo(sim, c, dt)
		return
	end
	if c.carrying and c.carrying.amount > 0 and c.carrying.resource ~= "food" then
		-- a load from before (a walk-out stopped the delivery): delivered first, never counted as food (#107 M3)
		c.phase = "Return"
		returnCargo(sim, c, dt)
		return
	end
	local b = c.target and sim.buildings[c.target]
	if b == nil or b.destroyed or b.level < 1 then
		if c.carrying then
			c.phase = "Return"
		else
			finish(c)
		end
		return
	end
	if c.phase == "Go" then
		local sx, sz = CitizenActions.workSpot(sim, c, b.x, b.z, b.footprint)
		if CitizenActions.moveTo(sim, c, sx, sz, 0, dt) and settle(sim, c, sx, sz, dt) then
			c.phase = "Work"
		end
		return
	end
	local tuning = sim.catalog.tuning
	local stats = sim.catalog.buildings.farm.levels[b.level]
	local yield = stats.yield or 0
	c.workTimer += dt * CitizenActions.skill(sim, c, "farm")
	if c.workTimer >= tuning.harvestTime then
		c.workTimer -= tuning.harvestTime
		local cargo = if c.carrying and c.carrying.resource == "food"
			then c.carrying
			else { resource = "food", amount = 0 }
		cargo.amount = math.min(tuning.carry, cargo.amount + yield)
		c.carrying = cargo
		if cargo.amount + yield > tuning.carry then
			c.phase = "Return"
		end
	end
end

local function build(sim: any, c: any, dt: number)
	local b = c.target and sim.buildings[c.target]
	if b == nil or b.destroyed or b.pendingLevel == nil then
		finish(c)
		return
	end
	if c.phase == "Go" then
		local sx, sz = CitizenActions.workSpot(sim, c, b.x, b.z, b.footprint + 1)
		if CitizenActions.moveTo(sim, c, sx, sz, 0, dt) and settle(sim, c, sx, sz, dt) then
			c.phase = "Work"
		end
		return
	end
	local rate = sim.catalog.tuning.buildRate * CitizenActions.skill(sim, c, "build")
	if sim:addWork(b, rate * dt) then
		finish(c)
	end
end

local function eat(sim: any, c: any, dt: number)
	local kingdom = sim.kingdoms[c.kingdomId]
	-- meals are taken where food is kept (keep, storehouse), not at a lumber camp or quarry
	local place = sim:nearestDropoff(kingdom, c.x, c.z, "food")
	if place == nil then
		finish(c)
		return
	end
	if not CitizenActions.moveTo(sim, c, place.x, place.z, place.footprint + 1, dt) then
		return
	end
	local tuning = sim.catalog.tuning
	local meal = tuning.mealFood
	local eaten = 0
	if tuning.mealsChargeTreasury then
		-- the double of FORGE-03's upkeep: paid from the treasury, partial meal when short
		c.meals = (c.meals or 0) + 1
		local available = math.min(meal, sim:balance(kingdom.id, "food"))
		if available > 0 and sim:spend(kingdom.id, { food = available }, `meal:{c.id}:{c.meals}`, "upkeep") then
			eaten = available
		end
	elseif sim:balance(kingdom.id, "food") > 0 then
		eaten = meal
	end
	if eaten < meal then
		sim:remember(c, { kind = "no_food" })
	end
	c.hunger = math.max(0, c.hunger - eaten / meal)
	finish(c)
end

local function rest(sim: any, c: any, dt: number, untilDone: () -> boolean)
	local b = c.target and sim.buildings[c.target]
	if b == nil or b.destroyed then
		local kingdom = sim.kingdoms[c.kingdomId]
		b = sim.buildings[kingdom.keepId]
		if b == nil or b.destroyed then
			finish(c)
			return
		end
	end
	if c.phase == "Go" then
		if CitizenActions.moveTo(sim, c, b.x, b.z, b.footprint + 1, dt) then
			c.phase = "Rest"
			-- fled or went home with cargo: unload if this is one of our drop-offs
			if c.carrying and b.kingdomId == c.kingdomId and sim.catalog.buildings[b.kind].dropoff then
				deposit(sim, c)
			end
		end
		return
	end
	if untilDone() then
		finish(c)
	end
end

local function sleep(sim: any, c: any, dt: number)
	rest(sim, c, dt, function()
		return not sim:isNight()
	end)
end

local function flee(sim: any, c: any, dt: number)
	local kingdom = sim.kingdoms[c.kingdomId]
	rest(sim, c, dt, function()
		return not kingdom.alarm and not sim:threatNear(kingdom, c.x, c.z, sim.catalog.tuning.fleeRadius * 2)
	end)
end

local function idle(sim: any, c: any, dt: number)
	local kingdom = sim.kingdoms[c.kingdomId]
	if c.wander == nil then
		local angle = sim.rng:NextNumber() * math.pi * 2
		local radius = 20 + sim.rng:NextNumber() * 15
		c.wander = { x = kingdom.x + math.cos(angle) * radius, z = kingdom.z + math.sin(angle) * radius }
		c.phase = "Go"
	end
	local spot = c.wander :: { x: number, z: number }
	if c.phase == "Go" then
		if CitizenActions.moveTo(sim, c, spot.x, spot.z, 0, dt) then
			c.phase = "Rest"
			c.restUntil = sim.time + 3
		end
		return
	end
	if sim.time >= c.restUntil then
		c.wander = nil
		finish(c)
	end
end

local ACTIONS: { [string]: (any, any, number) -> () } = {
	Gather = gather,
	Farm = farm,
	Build = build,
	Eat = eat,
	Sleep = sleep,
	Flee = flee,
	Idle = idle,
}

function CitizenActions.step(sim: any, c: any, dt: number)
	local action = ACTIONS[c.activity]
	if action == nil then
		error(`CitizenActions: unknown activity '{tostring(c.activity)}'`)
	end
	if c.slotTarget ~= nil and c.slotTarget ~= c.target then
		-- left that work (another target, or none): its slot there is free for the next worker (D-059)
		c.slot, c.slotTarget, c.slotX, c.slotZ, c.faceX, c.faceZ = nil, nil, nil, nil, nil, nil
		c.slotAtX, c.slotAtZ = nil, nil
	end
	action(sim, c, dt)
end

return CitizenActions
