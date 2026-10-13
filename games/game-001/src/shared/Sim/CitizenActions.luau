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

	API
		CitizenActions.step(sim, citizen, dt)
		CitizenActions.moveTo(sim, citizen, x, z, radius, dt): boolean  -- true once within radius
		CitizenActions.skill(sim, citizen, kind): number                -- work-rate multiplier
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
	if c.phase == "Go" then
		if CitizenActions.moveTo(sim, c, node.x, node.z, node.footprint + 1, dt) then
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
		if CitizenActions.moveTo(sim, c, b.x, b.z, b.footprint, dt) then
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
		local cargo = c.carrying or { resource = "food", amount = 0 }
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
		if CitizenActions.moveTo(sim, c, b.x, b.z, b.footprint + 1, dt) then
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
	action(sim, c, dt)
end

return CitizenActions
