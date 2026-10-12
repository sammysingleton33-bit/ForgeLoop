--!strict
--[[
	Gameplay/Kingdom/CitizenBrain — utility-based decision making for AI citizens.

	A citizen does not run an expensive planner: every few seconds (or when something interrupts it)
	the brain scores a handful of candidate activities and picks the best. Scores combine:
		- emergencies (flee from threats or the ruler's alarm bell, sleep at night, eat when hungry);
		- skill: the citizen's job affinity for the activity (farmer: farm 1.0, build 0.3 ...);
		- kingdom need: how far the treasury balance of that resource is below its target, scaled by the rulers'
		  priority weight (0 = never, 1 = normal, 3 = urgent); open construction sites are explicit
		  ruler orders and score high;
		- distance to the best target (nearer is better);
		- compact memory: a recent threat near a target lowers its score;
		- commitment: the current activity gets a small bonus so citizens do not flip-flop.

	API
		CitizenBrain.decide(world, citizen): Decision     -- pure: reads world state, never mutates it
		CitizenBrain.WORK_KINDS: { string }               -- "farm", "wood", "stone", "gold", "build"
		CitizenBrain.need(world, kingdom, kind): number   -- 0..3, exposed for specs and the debug view

	Decision = { activity: string, target: string?, score: number, reason: string }
	Activities: "Flee" | "Sleep" | "Eat" | "Farm" | "Gather" | "Build" | "Idle".
	The world passed in is Gameplay/Kingdom/Simulation (duck-typed to avoid a require cycle).
]]

export type Decision = { activity: string, target: string?, score: number, reason: string }

local CitizenBrain = {}

CitizenBrain.WORK_KINDS = table.freeze({ "farm", "wood", "stone", "gold", "build" })

local COMMIT_BONUS = 0.1
local IDLE_SCORE = 0.05
local DISTANCE_SCALE = 150

local function distanceFactor(d: number): number
	return 1 / (1 + d / DISTANCE_SCALE)
end

local function resourceOfKind(kind: string): string
	if kind == "farm" then
		return "food"
	end
	return kind
end

local function nearRememberedThreat(world: any, citizen: any, x: number, z: number): boolean
	local horizon = world.time - world.catalog.tuning.memorySeconds
	local radius = world.catalog.tuning.fleeRadius
	for _, entry in citizen.memory do
		if entry.kind == "threat" and entry.t >= horizon and entry.x ~= nil and entry.z ~= nil then
			local dx, dz = entry.x - x, entry.z - z
			if dx * dx + dz * dz <= radius * radius then
				return true
			end
		end
	end
	return false
end

function CitizenBrain.need(world: any, kingdom: any, kind: string): number
	if kind == "build" then
		return if world:hasOpenSite(kingdom) then 1 else 0
	end
	local resource = resourceOfKind(kind)
	local weight = kingdom.priorities[resource] or 1
	if weight <= 0 then
		return 0
	end
	local stock = world:balance(kingdom.id, resource)
	local target = world:needTarget(kingdom, resource)
	local deficit = math.clamp(1 - stock / math.max(1, target), 0, 1)
	return weight * (0.25 + 0.75 * deficit)
end

function CitizenBrain.decide(world: any, citizen: any): Decision
	local kingdom = world.kingdoms[citizen.kingdomId]
	local tuning = world.catalog.tuning

	if kingdom.alarm then
		return { activity = "Flee", target = kingdom.keepId, score = 10, reason = "alarm" }
	end
	if world:threatNear(kingdom, citizen.x, citizen.z, tuning.fleeRadius) then
		return { activity = "Flee", target = kingdom.keepId, score = 9, reason = "threat" }
	end
	if world:isNight() then
		return { activity = "Sleep", target = citizen.home or kingdom.keepId, score = 5, reason = "night" }
	end
	if citizen.hunger >= tuning.eatThreshold and world:balance(kingdom.id, "food") > 0 then
		return { activity = "Eat", target = kingdom.keepId, score = 1 + citizen.hunger, reason = "hungry" }
	end

	local job = world.catalog.jobs[citizen.job]
	local best: Decision = { activity = "Idle", target = nil, score = IDLE_SCORE, reason = "nothing to do" }
	for _, kind in CitizenBrain.WORK_KINDS do
		local affinity = job.affinity[kind] or 0
		if affinity <= 0 then
			continue
		end
		local need = CitizenBrain.need(world, kingdom, kind)
		if need <= 0 then
			continue
		end
		local target, distance = world:findWorkTarget(kingdom, kind, citizen)
		if target == nil then
			continue
		end
		local score = affinity * need * distanceFactor(distance)
		if nearRememberedThreat(world, citizen, target.x, target.z) then
			score *= 0.2
		end
		if citizen.target == target.id then
			score += COMMIT_BONUS
		end
		if score > best.score then
			local activity = if kind == "farm" then "Farm" elseif kind == "build" then "Build" else "Gather"
			best = { activity = activity, target = target.id, score = score, reason = kind }
		end
	end
	if
		best.activity == "Idle"
		and world:balance(kingdom.id, "food") > 0
		and citizen.hunger >= tuning.eatThreshold * 0.5
	then
		return { activity = "Eat", target = kingdom.keepId, score = IDLE_SCORE, reason = "idle snack" }
	end
	return best
end

return CitizenBrain
