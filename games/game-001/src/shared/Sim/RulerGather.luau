--!strict
--[[
	Sim/RulerGather — a ruler harvesting a resource node by hand (CONTRACTS G8
	`Kingdom.Gather(nodeId)`, VS-1 row 5).

	The client only names the node. The server supplies the ruler's position from its own view of the
	character (never from the client) and enforces range and a per-ruler cooldown, so auto-clickers
	and teleport claims gain nothing. Each successful gather deposits into the kingdom treasury with a
	unique txId and fires ResourceGathered (source "ruler") exactly once.

	Two rules keep it a helping hand and not an income (D-050 (3), FL-0122):
	  - Ownership: only nodes on the ruler's own land or on neutral land. A node whose position lies in another
	    kingdom's territory (sim:territoryOwner) answers not_your_node, so a ruler can't strip a rival's plot.
	  - Allowance: at most CONFIG.perMinute[resource] of each resource in any 60 seconds for the whole kingdom, its
	    rulers sharing it (the caps in design/economy.md: 25 % of the slice income budget, so co-rulers don't
	    multiply it). The short cooldown still applies; a harvest that would go over the allowance answers
	    cooldown, with nothing taken from the node.

	API
		RulerGather.gather(sim, userId, nodeId, x, z): (boolean, string?, { resource, amount }?)
			errors: match_not_active, not_ruler, kingdom_eliminated, unknown_node, depleted,
			        too_far, not_your_node, cooldown
		RulerGather.CONFIG = { range = 8, cooldown = 0.8, amounts = { food = 2, wood = 2, stone = 1, gold = 1 },
		                       perMinute = { food = 4, wood = 9, stone = 6, gold = 6 }, window = 60 }
		  range is measured from the node's edge (node footprint + range).
	Simulation API used: sim.active, sim.time, sim.nodes, sim:kingdomOfUser(userId), sim:territoryOwner(x, z),
	sim:deposit(kingdomId, resource, amount, txId, source), sim:emit(name, payload).
]]

local RulerGather = {}

RulerGather.CONFIG = {
	range = 8,
	cooldown = 0.8,
	amounts = { food = 2, wood = 2, stone = 1, gold = 1 },
	-- the most a ruler may take of each resource in any `window` seconds: 25 % of the slice income budget
	-- (design/economy.md, D-050 (3)); the per-harvest amounts above stay as they are
	perMinute = { food = 4, wood = 9, stone = 6, gold = 6 },
	window = 60,
}

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
	local owner = sim:territoryOwner(node.x, node.z)
	if owner ~= nil and owner ~= kingdom.id then
		return false, "not_your_node" -- another kingdom's land: not for this ruler's hands
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
	-- the allowance: what the kingdom's rulers took of this resource in the last `window` seconds, plus this harvest
	sim.gatherAllowance = sim.gatherAllowance or {}
	local ledger = sim.gatherAllowance[kingdom.id]
	if ledger == nil then
		ledger = {}
		sim.gatherAllowance[kingdom.id] = ledger
	end
	local taken = ledger[node.resource]
	if taken == nil then
		taken = {}
		ledger[node.resource] = taken
	end
	while #taken > 0 and sim.time - taken[1].t >= config.window do
		table.remove(taken, 1) -- left the window
	end
	local used = 0
	for _, entry in taken do
		used += entry.amount
	end
	local cap = config.perMinute[node.resource]
	if cap ~= nil and used + amount > cap then
		return false, "cooldown" -- enough of this for now; nothing is taken from the node
	end
	table.insert(taken, { t = sim.time, amount = amount })
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
