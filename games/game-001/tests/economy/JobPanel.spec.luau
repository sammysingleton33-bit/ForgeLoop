-- FL-0065 job panel (Kingdom panel "Jobs" tab): the model, and end to end the real
-- KingdomHudController over the framework RemoteService against FORGE-01's population and quota
-- remotes as doubles (doubles/PopulationDoubles) on the spec world (doubles/KingdomWorld).
local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect, beforeEach, afterEach = T.describe, T.it, T.expect, T.beforeEach, T.afterEach

local Create = require("@game/ReplicatedStorage/Forge/UI/Create")
local JobModel = require("@game/StarterPlayer/StarterPlayerScripts/Game/UI/JobModel")
local KingdomHudDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/KingdomHudController")
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
		local full = JobModel.view({ total = 10, cap = 10, byJob = { farmer = 4, hauler = 0 } }, nil, 0)
		for _, r in full.rows do
			expect(r.canAdd).toBe(false)
		end
		expect(full.pool.text).toContain("None free")
		-- nothing known yet: no buttons
		local unknown = JobModel.view(nil, nil, 0)
		expect(unknown.known).toBe(false)
		expect(unknown.rows[1].canAdd).toBe(false)
		expect(unknown.rows[1].canRemove).toBe(false)
	end)

	it("says 'Asking…' while a request is on its way and 'Moving…' until the count arrives", function()
		local pop = { total = 10, cap = 12, byJob = { farmer = 3, hauler = 2 } }
		local asking = JobModel.view(pop, { pending = { farmer = 4 }, requested = {} }, 0)
		expect(asking.rows[1].note).toBe("Asking… 3 → 4")
		expect(asking.rows[1].busy).toBe(true)
		expect(asking.rows[1].canAdd).toBe(false)
		local moving = JobModel.view(pop, { pending = {}, requested = { farmer = { target = 4, at = 10 } } }, 12)
		expect(moving.rows[1].note).toBe("Moving… 3 → 4")
		expect(moving.rows[1].canAdd).toBe(true) -- moving is not busy: the next request may follow
		local late = JobModel.view(pop, { pending = {}, requested = { farmer = { target = 4, at = 10 } } }, 16)
		expect(late.rows[1].note).toBeNil()
		local arrived = { total = 10, cap = 12, byJob = { farmer = 4, hauler = 1 } }
		expect(
			JobModel.view(arrived, { pending = {}, requested = { farmer = { target = 4, at = 10 } } }, 11).rows[1].note
		).toBeNil()
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

	it("phone: every − and + is a 44 px target", function()
		local world = newWorld({ width = 844, height = 390 })
		for _, job in JobModel.JOBS do
			for _, which in { "Minus", "Plus" } do
				local b = button(world, job.id, which)
				expect(b.Size.X.Offset).toBeGreaterThan(43)
				expect(b.Size.Y.Offset).toBeGreaterThan(43)
			end
		end
		world:destroy()
	end)
end)
