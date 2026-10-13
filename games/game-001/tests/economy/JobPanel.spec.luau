-- FL-0065 job panel (Kingdom panel "Jobs" tab): the model, and end to end the real
-- KingdomHudController over the framework RemoteService against FORGE-01's population and quota
-- remotes as doubles (doubles/PopulationDoubles) on the spec world (doubles/KingdomWorld).
local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect, beforeEach, afterEach = T.describe, T.it, T.expect, T.beforeEach, T.afterEach

local Create = require("@game/ReplicatedStorage/Forge/UI/Create")
local JobModel = require("@game/StarterPlayer/StarterPlayerScripts/Game/UI/JobModel")
local KingdomHudDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/KingdomHudController")
local KingdomStore = require("@game/StarterPlayer/StarterPlayerScripts/Game/UI/KingdomStore")
local KingdomWorld = require("./doubles/KingdomWorld")
local PopulationDoubles = require("./doubles/PopulationDoubles")

local START = PopulationDoubles.START

local function find(root, name)
	if root == nil then
		return nil
	end
	for _, d in root:GetDescendants() do
		if d.Name == name then
			return d
		end
	end
	return nil
end

local function texts(root)
	local out = {}
	if root == nil then
		return ""
	end
	for _, d in root:GetDescendants() do
		if (d:IsA("TextLabel") or d:IsA("TextButton")) and d.Text ~= "" then
			table.insert(out, d.Text)
		end
	end
	return table.concat(out, " | ")
end

local function newWorld(opts)
	local o = opts or {}
	o.remotes = PopulationDoubles.REMOTES
	o.services = { PopulationDoubles.service }
	o.clientDefinitions = { KingdomHudDef }
	local world = KingdomWorld.new(o)
	world.hud = world.client:get("KingdomHudController")
	world.pop = world.server:get("PopulationService")
	world.hud:setViewport(o.width or 1920, o.height or 1022)
	world:advance(0.2)
	world.hud:setMenu("kingdom")
	world.hud:panelTab("jobs")
	return world
end

local function row(world, id)
	return find(find(world.hud.guis.menus, "KingdomPanel"), "Job_" .. id)
end

local function count(world, id)
	return row(world, id):GetAttribute("count")
end

local function button(world, id, which)
	return find(row(world, id), which)
end

-- IconButton is a TextButton: tap it the way a player would (its own Activated handlers).
local function tap(instance)
	assert(instance, "tap: nothing to tap")
	return Create.fire(instance, "Activated")
end

describe("Job model (FL-0065)", function()
	it("lists the quota jobs with counts, the free pool and soldiers, and what each button may do", function()
		local v = JobModel.view({
			total = 12,
			cap = 12,
			byJob = { farmer = 3, woodcutter = 0, miner = 2, builder = 2, hauler = 2, soldier = 3 },
		}, nil, 0)
		expect(v.known).toBe(true)
		expect(#v.rows).toBe(4)
		expect(v.rows[1].id).toBe("farmer")
		expect(v.rows[1].name).toBe("Farmers")
		expect(v.rows[1].canAdd).toBe(true)
		expect(v.rows[2].canRemove).toBe(false) -- no woodcutters to take away
		expect(v.pool.count).toBe(2)
		expect(v.soldiers.count).toBe(3)
		expect(v.summary.free).toBe(2)
		-- no free citizens: nobody can be added anywhere, and the pool says why
		local full = JobModel.view({ total = 10, cap = 10, byJob = { farmer = 4, hauler = 0 } }, nil)
		for _, r in full.rows do
			expect(r.canAdd).toBe(false)
		end
		expect(full.pool.text).toContain("None free")
		-- nothing known yet: no buttons
		local unknown = JobModel.view(nil, nil)
		expect(unknown.known).toBe(false)
		expect(unknown.rows[1].canAdd).toBe(false)
		expect(unknown.rows[1].canRemove).toBe(false)
	end)

	it("steps from the newest target and keeps adds within the free citizens not yet promised", function()
		local pop = { total = 10, cap = 12, byJob = { farmer = 3, hauler = 2 } }
		local asking = JobModel.view(pop, { pending = { farmer = 4 }, quota = {} })
		expect(asking.rows[1].note).toBe("Asking… 3 → 4")
		expect(asking.rows[1].busy).toBe(true)
		expect(asking.rows[1].canAdd).toBe(false)
		-- acknowledged but not filled yet: the target is 4, one hauler is promised
		local moving = JobModel.view(pop, { pending = {}, quota = { farmer = 4 } })
		expect(moving.rows[1].note).toBe("Moving… 3 → 4")
		expect(moving.rows[1].target).toBe(4)
		expect(JobModel.freeLeft(pop, { pending = {}, quota = { farmer = 4 } })).toBe(1)
		expect(moving.rows[1].canAdd).toBe(true) -- one hauler is still free
		-- both haulers promised: + stops everywhere, and the pool says why
		local promised = JobModel.view(pop, { pending = {}, quota = { farmer = 5 } })
		for _, r in promised.rows do
			expect(r.canAdd).toBe(false)
		end
		expect(promised.pool.text).toContain("None free")
		-- the count arrived: no note
		local arrived = { total = 10, cap = 12, byJob = { farmer = 4, hauler = 1 } }
		expect(JobModel.view(arrived, { pending = {}, quota = { farmer = 4 } }).rows[1].note).toBeNil()
		-- an acknowledged quota beats the payload's, which can be from before the request (#61 pushes
		-- at most once a second); without an ack the server's quota beats the count
		local server = { total = 10, cap = 12, byJob = { farmer = 3, hauler = 2 }, quotas = { farmer = 3 } }
		expect(JobModel.target(server, { pending = {}, quota = { farmer = 4 } }, "farmer")).toBe(4)
		expect(JobModel.freeLeft(server, { pending = {}, quota = { farmer = 4 } })).toBe(1)
		local moved = { total = 10, cap = 12, byJob = { farmer = 3, hauler = 2 }, quotas = { farmer = 6 } }
		expect(JobModel.target(moved, { pending = {}, quota = {} }, "farmer")).toBe(6)
		-- a quota the pool cannot fill says so
		local dry = { total = 10, cap = 12, byJob = { farmer = 3, hauler = 0 } }
		expect(JobModel.view(dry, { pending = {}, quota = { farmer = 4 } }).rows[1].note).toBe(
			"Waiting for a free citizen · 3 → 4"
		)
	end)

	it("keeps only finite, non-negative counts (L3)", function()
		local store = KingdomStore.new()
		store:applyPopulation({
			total = 0 / 0,
			cap = math.huge,
			byJob = { farmer = -2, miner = 0 / 0, builder = math.huge, woodcutter = 2 },
			quotas = { farmer = -1, woodcutter = 3 },
		})
		local p = store:population()
		expect(p.total).toBe(0)
		expect(p.cap).toBeNil()
		expect(p.byJob.farmer).toBeNil()
		expect(p.byJob.miner).toBeNil()
		expect(p.byJob.builder).toBeNil()
		expect(p.byJob.woodcutter).toBe(2)
		expect(p.quotas.farmer).toBeNil()
		expect(p.quotas.woodcutter).toBe(3)
	end)
end)

describe("Job panel end to end (FL-0065)", function()
	local previous
	beforeEach(function()
		previous = Create.useTestConnector()
	end)
	afterEach(function()
		Create.setConnector(previous)
	end)

	it("shows the server's counts and moves a worker with + and −", function()
		local world = newWorld({ latency = 0.1 })
		local panel = find(world.hud.guis.menus, "KingdomPanel")
		expect(texts(panel)).toContain("Jobs")
		expect(count(world, "woodcutter")).toBe(START.woodcutter)
		expect(count(world, "free")).toBe(START.hauler)
		expect(count(world, "soldier")).toBe(START.soldier)
		local total = 0
		for _, n in START do
			total += n
		end
		expect(find(panel, "JobSummary").Text).toBe(
			`{total} citizens · homes for {PopulationDoubles.CAP} · {START.hauler} free`
		)
		expect(tap(button(world, "woodcutter", "Plus"))).toBeGreaterThan(0)
		-- on its way: the note says so and the row's buttons wait
		expect(texts(row(world, "woodcutter"))).toContain(`Asking… {START.woodcutter} → {START.woodcutter + 1}`)
		tap(button(world, "woodcutter", "Plus")) -- a second tap before the reply sends nothing
		world.hud:changeJob("woodcutter", 1) -- nor does the controller, whoever calls it
		world:advance(0.3)
		local calls = world:callsNamed("SetJobQuota")
		expect(#calls).toBe(1)
		expect(calls[1].args[1]).toBe("woodcutter")
		expect(calls[1].args[2]).toBe(START.woodcutter + 1)
		expect(count(world, "woodcutter")).toBe(START.woodcutter + 1)
		expect(count(world, "free")).toBe(START.hauler - 1)
		expect(texts(row(world, "woodcutter"))).never.toContain("Asking")
		tap(button(world, "farmer", "Minus"))
		world:advance(0.3)
		expect(world:callsNamed("SetJobQuota")[2].args[2]).toBe(START.farmer - 1)
		expect(count(world, "farmer")).toBe(START.farmer - 1)
		expect(count(world, "free")).toBe(START.hauler)
		world:destroy()
	end)

	it("with no free citizens + does nothing and the pool says why", function()
		local world = newWorld()
		world.pop:set("crimson", "hauler", 0)
		world:advance(0.1)
		expect(texts(row(world, "free"))).toContain("None free")
		for _, job in JobModel.JOBS do
			tap(button(world, job.id, "Plus"))
			world.hud:changeJob(job.id, 1) -- the controller refuses too, not only the button
		end
		world.hud:changeJob("hauler", 1) -- the pool is not a quota job
		world:advance(0.2)
		expect(#world:callsNamed("SetJobQuota")).toBe(0)
		world:destroy()
	end)

	it("explains a refusal with the server's reason, never the code", function()
		local world = newWorld()
		world.pop.refuse = "match_not_active"
		tap(button(world, "miner", "Plus"))
		world:advance(0.2)
		local notices = texts(world.hud.guis.notices)
		expect(notices).toContain("Couldn't change jobs")
		expect(notices).toContain("The match isn't running")
		expect(notices).never.toContain("match_not_active")
		expect(count(world, "miner")).toBe(START.miner)
		world:destroy()
	end)

	it("says 'Moving…' until the server fills the quota, then shows the new count", function()
		local world = newWorld()
		world.pop.immediate = false
		tap(button(world, "builder", "Plus"))
		world:advance(0.2)
		expect(texts(row(world, "builder"))).toContain(`Moving… {START.builder} → {START.builder + 1}`)
		world.pop:rebalance("crimson")
		world:advance(0.1)
		expect(count(world, "builder")).toBe(START.builder + 1)
		expect(texts(row(world, "builder"))).never.toContain("Moving")
		world:destroy()
	end)

	it("keeps its rows and buttons across unrelated pushes (M1) and they still work", function()
		local world = newWorld()
		local plus = button(world, "farmer", "Plus")
		local r = row(world, "farmer")
		world.treasury:deposit("crimson", "food", 5, "jobs:food", "test")
		local id = world.build:add("azure", "house", 1, "planned", Vector3.new(900, 0, 900))
		world.build:push(id)
		world:advance(0.2)
		expect(row(world, "farmer")).toBe(r)
		expect(button(world, "farmer", "Plus")).toBe(plus)
		tap(plus)
		world:advance(0.2)
		expect(#world:callsNamed("SetJobQuota")).toBe(1)
		expect(row(world, "farmer")).toBe(r) -- its own population push patches it in place
		world:destroy()
	end)

	it("M1: each + steps from the last acknowledged target, even before the count moves", function()
		local world = newWorld()
		world.pop.immediate = false -- the real sim fills quotas a second later
		for _ = 1, 3 do
			tap(button(world, "woodcutter", "Plus"))
			world:advance(0.1)
		end
		local sent = {}
		for _, call in world:callsNamed("SetJobQuota") do
			table.insert(sent, call.args[2])
		end
		expect(table.concat(sent, ",")).toBe(`{START.woodcutter + 1},{START.woodcutter + 2},{START.woodcutter + 3}`)
		-- + then −: the − steps down from the newest target, not from the count
		tap(button(world, "woodcutter", "Minus"))
		world:advance(0.1)
		expect(world:callsNamed("SetJobQuota")[4].args[2]).toBe(START.woodcutter + 2)
		world:destroy()
	end)

	it("#61: an ack beats the payload's older quota, and + stops once the free citizens are promised", function()
		local world = newWorld()
		world.pop.immediate = false -- no push until the spec publishes: the payload keeps the old quotas
		local pop = world.hud.store:population()
		expect(pop.quotas.farmer).toBe(START.farmer) -- the server's payload carries quotas (#61)
		-- 3 free citizens: + on three jobs, each after its reply, with no push in between
		for _, job in { "farmer", "miner", "builder" } do
			tap(button(world, job, "Plus"))
			world:advance(0.1)
		end
		expect(#world:callsNamed("SetJobQuota")).toBe(3)
		-- every free citizen is promised: a fourth + anywhere sends nothing, and the pool says why
		tap(button(world, "woodcutter", "Plus"))
		world.hud:changeJob("woodcutter", 1)
		tap(button(world, "farmer", "Plus"))
		world:advance(0.1)
		expect(#world:callsNamed("SetJobQuota")).toBe(3)
		expect(texts(row(world, "free"))).toContain("None free")
		-- + then − on a job whose payload quota is still the old one: − steps from the ack
		tap(button(world, "miner", "Minus"))
		world:advance(0.1)
		local calls = world:callsNamed("SetJobQuota")
		expect(calls[4].args[1]).toBe("miner")
		expect(calls[4].args[2]).toBe(START.miner) -- ack START+1 → START, not the old quota − 1
		world:destroy()
	end)

	it("#61: the ack is forgotten once a push shows it; a co-ruler's later quota wins after the hold", function()
		local world = newWorld()
		world.pop.immediate = false
		tap(button(world, "farmer", "Plus"))
		world:advance(0.1)
		local jobs = world.hud.state.panel.jobs
		expect(jobs.quota.farmer).toBe(START.farmer + 1)
		-- a push that still shows the old quota (sent before the request was handled) keeps the ack
		world.pop.quotas.crimson.farmer = START.farmer -- a push computed before the request was handled
		world.pop:publish("crimson")
		world:advance(0.1)
		expect(jobs.quota.farmer).toBe(START.farmer + 1)
		-- the push that shows it: the ack is forgotten, the server's quota is the target
		world.pop.quotas.crimson.farmer = START.farmer + 1
		world.pop:publish("crimson")
		world:advance(0.1)
		expect(jobs.quota.farmer).toBeNil()
		expect(texts(row(world, "farmer"))).toContain(`Moving… {START.farmer} → {START.farmer + 1}`)
		-- a co-ruler sets farmers to 6 and my next ack is never shown by a push: after the hold the
		-- server's 6 wins over my 5
		tap(button(world, "farmer", "Plus"))
		world:advance(0.1)
		expect(jobs.quota.farmer).toBe(START.farmer + 2)
		world.pop.quotas.crimson.farmer = 6
		world.pop:publish("crimson")
		world:advance(0.1)
		expect(texts(row(world, "farmer"))).toContain(`→ {START.farmer + 2}`)
		world:advance(JobModel.ACK_HOLD_SEC)
		expect(jobs.quota.farmer).toBeNil()
		expect(texts(row(world, "farmer"))).toContain(`Moving… {START.farmer} → 6`)
		world:destroy()
	end)

	it("#61: without quotas in the payload (an older server) the ack stays the target", function()
		local world = newWorld()
		world.pop.sendQuotas = false
		world.pop:publish("crimson")
		world.pop.immediate = false
		world:advance(0.1)
		tap(button(world, "miner", "Plus"))
		world:advance(JobModel.ACK_HOLD_SEC + 0.5)
		expect(world.hud.state.panel.jobs.quota.miner).toBe(START.miner + 1)
		tap(button(world, "miner", "Plus"))
		world:advance(0.1)
		expect(world:callsNamed("SetJobQuota")[2].args[2]).toBe(START.miner + 2)
		world:destroy()
	end)

	it("M2: another kingdom forgets the old counts and quotas and fetches its own", function()
		local world = newWorld()
		world.pop.immediate = false
		tap(button(world, "farmer", "Plus"))
		world:advance(0.1)
		world.pop:set("azure", "farmer", 7)
		world.kingdoms:join(world.player, "azure")
		world:advance(0.2)
		expect(count(world, "farmer")).toBe(7)
		tap(button(world, "farmer", "Minus"))
		world:advance(0.1)
		local calls = world:callsNamed("SetJobQuota")
		expect(calls[#calls].args[2]).toBe(6) -- azure's 7 − 1, not crimson's target
		world:destroy()
	end)

	it("M2: until the new kingdom's counts arrive the tab shows – and sends nothing", function()
		local world = newWorld()
		world.pop.getLatency = 1
		world.pop:set("azure", "farmer", 7)
		world.kingdoms:join(world.player, "azure")
		world:advance(0.2) -- the kingdom changed; its counts are still on the way
		expect(find(row(world, "farmer"), "Count").Text).toBe("–")
		tap(button(world, "farmer", "Minus"))
		world:advance(0.1)
		expect(#world:callsNamed("SetJobQuota")).toBe(0) -- never crimson's count − 1 sent to azure
		world:advance(1)
		expect(count(world, "farmer")).toBe(7)
		world:destroy()
	end)

	it("M2: a refusal that answers the old kingdom's request after a move says nothing", function()
		local world = newWorld({ latency = 0.5 })
		world.pop.refuse = "not_ruler"
		tap(button(world, "farmer", "Plus"))
		world:advance(0.1)
		world.kingdoms:join(world.player, "azure")
		world:advance(0.8) -- the refusal arrives after the move
		expect(#world:callsNamed("SetJobQuota")).toBe(1)
		expect(texts(world.hud.guis.notices)).never.toContain("Couldn't change jobs")
		world:destroy()
	end)

	it("shows – while the server has not sent counts (L2)", function()
		local world = KingdomWorld.new({ clientDefinitions = { KingdomHudDef } }) -- no population remotes
		local hud = world.client:get("KingdomHudController")
		hud:setViewport(1920, 1022)
		world:advance(0.2)
		hud:setMenu("kingdom")
		hud:panelTab("jobs")
		local farmers = find(find(hud.guis.menus, "KingdomPanel"), "Job_farmer")
		expect(find(farmers, "Count").Text).toBe("–")
		expect(farmers:GetAttribute("count")).toBeNil()
		world:destroy()
	end)

	it("− above the remote's 50 brings a server-set quota to 50 (L7)", function()
		local world = newWorld()
		world.pop:set("crimson", "miner", 60)
		world:advance(0.1)
		tap(button(world, "miner", "Minus"))
		world:advance(0.1)
		expect(world:callsNamed("SetJobQuota")[1].args[2]).toBe(50)
		world:destroy()
	end)

	it("not_in_match reads as a sentence (L8)", function()
		local world = newWorld()
		world.pop.refuse = "not_in_match"
		tap(button(world, "miner", "Plus"))
		world:advance(0.2)
		expect(texts(world.hud.guis.notices)).toContain("The match isn't running")
		world:destroy()
	end)

	it("a push that changes no button state leaves the − / + icons alone (L6)", function()
		local world = newWorld()
		local plus = button(world, "farmer", "Plus")
		local body = plus:FindFirstChild("Body")
		world.pop:set("crimson", "soldier", 2) -- a count elsewhere: farmer's buttons keep their state
		world:advance(0.1)
		expect(plus:FindFirstChild("Body")).toBe(body)
		world:destroy()
	end)

	it("phone: every − and + is a 44 px target", function()
		local world = newWorld({ width = 844, height = 390 })
		for _, job in JobModel.JOBS do
			for _, which in { "Minus", "Plus" } do
				local b = button(world, job.id, which)
				expect(b.Size.X.Offset).toBeGreaterThan(43)
				expect(b.Size.Y.Offset).toBeGreaterThan(43)
			end
		end
		-- L1: in every row (the count-only Free citizens and Soldiers too) the text column ends
		-- before the count begins, so the subtitle never runs under the number
		for _, id in { "farmer", "woodcutter", "miner", "builder", "free", "soldier" } do
			local r = row(world, id)
			local mid = r:FindFirstChild("Mid")
			local label = r:FindFirstChild("Count")
			local midRight = mid.Position.X.Offset + mid.Size.X.Offset -- offset from the row's right edge
			local countLeft = label.Position.X.Offset - label.Size.X.Offset * label.AnchorPoint.X
			expect(midRight).toBeLessThanOrEqual(countLeft)
		end
		world:destroy()
	end)
end)
