--[[
	KingdomFixtures — shared helpers for the kingdom simulation specs (not a spec itself).

		local F = require("./KingdomFixtures")
		local sim, k = F.kingdom({ seed = 1, nodes = true, tuning = { birthInterval = 9999 } })
		F.events(sim, "BuildingCompleted")     -- drains and filters events
		F.assertInvariants(sim)                -- ledger audit, capacity, claim bookkeeping, ids
]]

local Catalog = require("@game/ReplicatedStorage/Forge/Gameplay/Kingdom/Catalog")
local Simulation = require("@game/ReplicatedStorage/Forge/Gameplay/Kingdom/Simulation")

local F = {}

function F.catalog(tuning: { [string]: any }?)
	local catalog = Catalog.default()
	for key, value in tuning or {} do
		catalog.tuning[key] = value
	end
	return catalog
end

-- One kingdom at the origin. nodes: a ring of 8 trees at 60 studs and 3 rocks at 75 studs.
function F.kingdom(options: { [string]: any }?)
	local opts = options or {}
	local sim = Simulation.new({ random = Random.new(opts.seed or 1), catalog = F.catalog(opts.tuning) })
	local k = sim:addKingdom({ id = "k1", name = "Test", x = 0, z = 0 })
	if opts.nodes ~= false then
		for i = 1, 8 do
			local a = i * math.pi / 4
			sim:addNode("Tree", math.cos(a) * 60, math.sin(a) * 60)
		end
		for i = 1, 3 do
			local a = 0.3 + i * 2.1
			sim:addNode("Rock", math.cos(a) * 75, math.sin(a) * 75)
		end
	end
	return sim, k
end

function F.events(sim: any, name: string?): { any }
	local out = {}
	for _, e in sim:drainEvents() do
		if name == nil or e.name == name then
			table.insert(out, e)
		end
	end
	return out
end

function F.count(list: { any }, predicate: (any) -> boolean): number
	local n = 0
	for _, item in list do
		if predicate(item) then
			n += 1
		end
	end
	return n
end

function F.occupations(sim: any, k: any): { [string]: number }
	local counts = {}
	for _, c in sim:citizensOf(k) do
		counts[c.occupation] = (counts[c.occupation] or 0) + 1
	end
	return counts
end

-- Errors with a description when an invariant is broken.
function F.assertInvariants(sim: any)
	for _, kid in sim.kingdomOrder do
		local k = sim.kingdoms[kid]
		local ok, why = k.stock:audit()
		assert(ok, `{kid} ledger: {why}`)
		for _, res in sim.catalog.resources do
			assert(k.stock:get(res) >= 0, `{kid} {res} negative`)
		end
	end
	local nodeClaims = {}
	local buildingClaims = {}
	local seen = {}
	for _, cid in sim.citizenOrder do
		local c = sim.citizens[cid]
		assert(c and c.alive, `dead or missing citizen {cid} in citizenOrder`)
		assert(not seen[cid], `citizen {cid} listed twice`)
		seen[cid] = true
		if c.claim then
			if c.claim.kind == "node" then
				nodeClaims[c.claim.id] = (nodeClaims[c.claim.id] or 0) + 1
			else
				local b = sim.buildings[c.claim.id]
				assert(b, `{cid} claims missing building {c.claim.id}`)
				local list = if c.claim.kind == "farm" then b.workers else b.builders
				assert(table.find(list, cid), `{cid} claim not in {c.claim.id} {c.claim.kind} list`)
				buildingClaims[c.claim.id] = (buildingClaims[c.claim.id] or 0) + 1
			end
		end
	end
	for _, nid in sim.nodeOrder do
		local node = sim.nodes[nid]
		assert(node.claims == (nodeClaims[nid] or 0), `node {nid} claims {node.claims} ~= {nodeClaims[nid] or 0}`)
		assert(node.claims <= node.slots, `node {nid} over-subscribed`)
		assert(node.amount >= 0, `node {nid} negative amount`)
	end
	for _, bid in sim.buildingOrder do
		local b = sim.buildings[bid]
		assert(not b.destroyed, `destroyed building {bid} still listed`)
		assert(#b.workers + #b.builders == (buildingClaims[bid] or 0), `building {bid} claim lists out of sync`)
		for _, cid in b.workers do
			assert(sim.citizens[cid], `building {bid} lists dead worker {cid}`)
		end
		for _, cid in b.builders do
			assert(sim.citizens[cid], `building {bid} lists dead builder {cid}`)
		end
	end
end

return F
