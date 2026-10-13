--!strict
--[[
	Sim/RulerGather — a ruler harvesting a resource node by hand (CONTRACTS G8
	`Kingdom.Gather(nodeId)`, VS-1 row 5).

	The client only names the node. The server supplies the ruler's position from its own view of the
	character (never from the client) and enforces range and a per-ruler cooldown, so auto-clickers
	and teleport claims gain nothing. Each successful gather deposits into the kingdom treasury with a
	unique txId and fires ResourceGathered (source "ruler") exactly once.

	API
		RulerGather.gather(sim, userId, nodeId, x, z): (boolean, string?, { resource, amount }?)
			errors: match_not_active, not_ruler, kingdom_eliminated, unknown_node, depleted,
			        too_far, cooldown
		RulerGather.CONFIG = { range = 8, cooldown = 0.8, amounts = { food = 2, wood = 2, stone = 1, gold = 1 } }
		  range is measured from the node's edge (node footprint + range).
	Simulation API used: sim.active, sim.time, sim.nodes, sim:kingdomOfUser(userId),
	sim:deposit(kingdomId, resource, amount, txId, source), sim:emit(name, payload).
]]

local RulerGather = {}

RulerGather.CONFIG = { range = 8, cooldown = 0.8, amounts = { food = 2, wood = 2, stone = 1, gold = 1 } }

function RulerGather.gather(sim: any, userId: number, nodeId: any, x: number, z: number): (boolean, string?, any?)
	if not sim.active then
		return false, "match_not_active"
	end
	local kingdom = sim:kingdomOfUser(userId)
	if kingdom == nil then
		return false, "not_ruler"
	end
	if not kingdom.alive then
		return false, "kingdom_eliminated"
	end
	local node = if type(nodeId) == "string" then sim.nodes[nodeId] else nil
	if node == nil then
		return false, "unknown_node"
	end
	if node.amount <= 0 then
		return false, "depleted"
	end
	local config = RulerGather.CONFIG
	local dx, dz = node.x - x, node.z - z
	if math.sqrt(dx * dx + dz * dz) > node.footprint + config.range then
		return false, "too_far"
	end
	sim.gatherState = sim.gatherState or {}
	local state = sim.gatherState[userId]
	if state == nil then
		state = { last = -math.huge, seq = 0 }
		sim.gatherState[userId] = state
	end
	if sim.time - state.last < config.cooldown then
		return false, "cooldown"
	end
	local amount = math.min(config.amounts[node.resource] or 1, node.amount)
	node.amount -= amount
	if node.amount <= 0 then
		node.depletedAt = sim.time
		sim:emit("NodeDepleted", { nodeId = node.id, resource = node.resource })
	end
	state.last = sim.time
	state.seq += 1
	sim:deposit(kingdom.id, node.resource, amount, `gather:{userId}:{state.seq}`, "ruler")
	sim:emit("ResourceGathered", {
		kingdomId = kingdom.id,
		resource = node.resource,
		amount = amount,
		source = "ruler",
		userId = userId,
		nodeId = node.id,
	})
	return true, nil, { resource = node.resource, amount = amount }
end

return RulerGather
