--[[
	KingdomFixtures — shared helpers for the kingdom simulation specs (not a spec itself).

		local F = require("./KingdomFixtures")
		local sim, k = F.kingdom({ seed = 1, nodes = true, tuning = { birthInterval = 9999 } })
		F.events(sim, "BuildingCompleted")     -- drains and filters events
		F.assertInvariants(sim)                -- ledger audit, claim bookkeeping, ids
		F.stock(sim, k)                        -- old Stockpile-style view over the G7 treasury (specs only)
]]

local Catalog = require("@game/ReplicatedStorage/Forge/Gameplay/Kingdom/Catalog")
local Simulation = require("@game/ReplicatedStorage/Forge/Gameplay/Kingdom/Simulation")

local F = {}

local giveSeq = 0

-- Maps a treasury ledger entry to the reason names the specs use.
local function reasonOf(entry: any): string
	local tag = entry.sink or entry.source or "other"
	if entry.kind == "deposit" then
		if string.sub(tag, 1, 8) == "citizen:" or tag == "ruler" then
			return "gathered"
		end
		return tag -- refund, loot, test
	end
	if string.sub(tag, 1, 9) == "building:" then
		local level = tonumber(string.match(entry.txId, ":(%d+)$"))
		return if level and level > 1 then "upgrade" else "construction"
	elseif string.sub(tag, 1, 5) == "unit:" then
		return "recruit"
	elseif tag == "upkeep" then
		return "meal"
	elseif tag == "population" then
		return "birth"
	elseif tag == "plunder" then
		return "plundered"
	end
	return tag
end

-- A Stockpile-shaped view of one kingdom's treasury for specs (add/take/get/snapshot/flows/audit).
function F.stock(sim: any, k: any)
	local view = {}
	function view:get(res: string): number
		return sim:balance(k.id, res)
	end
	function view:snapshot()
		return sim.treasury:get(k.id)
	end
	function view:add(res: string, amount: number): number
		giveSeq += 1
		sim.treasury:deposit(k.id, res, amount, `test:give:{giveSeq}`, "test")
		return amount
	end
	function view:take(res: string, amount: number): number
		local taken = math.min(amount, sim:balance(k.id, res))
		if taken > 0 then
			giveSeq += 1
			sim.treasury:spend(k.id, { [res] = taken }, `test:take:{giveSeq}`, "test")
		end
		return taken
	end
	function view:spend(cost: { [string]: number }): boolean
		giveSeq += 1
		return sim.treasury:spend(k.id, cost, `test:spend:{giveSeq}`, "test")
	end
	function view:canAfford(cost: { [string]: number }): boolean
		return sim.treasury:canAfford(k.id, cost)
	end
	function view:audit()
		return sim.treasury:audit(k.id)
	end
	function view:flows()
		local out = { income = {}, expense = {} }
		for _, entry in sim.treasury:ledger(k.id) do
			local book = if entry.kind == "deposit" then out.income else out.expense
			local reason = reasonOf(entry)
			book[reason] = book[reason] or {}
			for res, amount in entry.bag do
				book[reason][res] = (book[reason][res] or 0) + amount
			end
		end
		return out
	end
	return view
end

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
	local k = sim:addKingdom({ id = "crimson", name = "Test", x = 0, z = 0 })
	if opts.nodes ~= false then
		for i = 1, 8 do
			local a = i * math.pi / 4
			sim:addNode("tree", math.cos(a) * 60, math.sin(a) * 60)
		end
		for i = 1, 3 do
			local a = 0.3 + i * 2.1
			sim:addNode("rock", math.cos(a) * 75, math.sin(a) * 75)
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

function F.jobs(sim: any, k: any): { [string]: number }
	local counts = {}
	for _, c in sim:citizensOf(k) do
		counts[c.job] = (counts[c.job] or 0) + 1
	end
	return counts
end

-- Errors with a description when an invariant is broken.
function F.assertInvariants(sim: any)
	for _, kid in sim.kingdomOrder do
		local k = sim.kingdoms[kid]
		local ok, why = sim.treasury:audit(k.id)
		assert(ok, `{kid} ledger: {why}`)
		for _, res in sim.catalog.resources do
			assert(sim:balance(k.id, res) >= 0, `{kid} {res} negative`)
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
