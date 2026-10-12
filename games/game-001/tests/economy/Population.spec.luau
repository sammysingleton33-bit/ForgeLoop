-- G13.2 population plumbing shared by the job panel (FL-0065) and the army panel (FL-0060): the store
-- keeps my kingdom's { total, byJob, cap } from Kingdom.GetPopulation and Kingdom.Population.
local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect, beforeEach, afterEach = T.describe, T.it, T.expect, T.beforeEach, T.afterEach

local Create = require("@game/ReplicatedStorage/Forge/UI/Create")
local KingdomHudDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/KingdomHudController")
local KingdomStore = require("@game/StarterPlayer/StarterPlayerScripts/Game/UI/KingdomStore")
local KingdomWorld = require("./doubles/KingdomWorld")
local PopulationDoubles = require("./doubles/PopulationDoubles")

describe("Population in the store (G13.2)", function()
	local previous
	beforeEach(function()
		previous = Create.useTestConnector()
	end)
	afterEach(function()
		Create.setConnector(previous)
	end)

	it("keeps a clean copy and ignores malformed payloads", function()
		local store = KingdomStore.new()
		local fired = 0
		store.changed:connect(function(what)
			if what == "population" then
				fired += 1
			end
		end)
		expect(store:population()).toBeNil()
		store:applyPopulation({ total = 9.0, cap = 12, byJob = { farmer = 3, soldier = 2, bad = "x", neg = -1 } })
		local p = store:population()
		expect(p.total).toBe(9)
		expect(p.cap).toBe(12)
		expect(p.byJob.farmer).toBe(3)
		expect(p.byJob.soldier).toBe(2)
		expect(p.byJob.bad).toBeNil()
		expect(p.byJob.neg).toBeNil()
		p.byJob.farmer = 99 -- a copy: callers cannot change the store
		expect(store:population().byJob.farmer).toBe(3)
		store:applyPopulation("nope")
		store:applyPopulation({ total = 1 })
		expect(store:population().total).toBe(9)
		expect(fired).toBe(1)
	end)

	it("the HUD fetches it on start and follows the server's pushes", function()
		local world = KingdomWorld.new({
			remotes = PopulationDoubles.REMOTES,
			services = { PopulationDoubles.service },
			clientDefinitions = { KingdomHudDef },
		})
		local hud = world.client:get("KingdomHudController")
		world:advance(0.2)
		local p = hud.store:population()
		expect(p).toBeTruthy()
		expect(p.byJob.farmer).toBe(PopulationDoubles.START.farmer)
		expect(p.cap).toBe(PopulationDoubles.CAP)
		world.server:get("PopulationService"):set("crimson", "soldier", 4)
		world:advance(0.1)
		expect(hud.store:population().byJob.soldier).toBe(4)
		world:destroy()
	end)
end)
