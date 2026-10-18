-- The leadership recap of the Results screen (FL-0129, BRIEF §2): the real KingdomHudController,
-- ReputationPanelController, SliceSummaryController and LeadershipRecapController over the FORGE-01
-- doubles for reputation (ReputationDoubles), population (PopulationDoubles) and the match end
-- (ArmyDoubles' Match.Ended).
local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect, beforeEach, afterEach = T.describe, T.it, T.expect, T.beforeEach, T.afterEach

local ArmyDoubles = require("./doubles/ArmyDoubles")
local Create = require("@game/ReplicatedStorage/Forge/UI/Create")
local KingdomHudDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/KingdomHudController")
local KingdomWorld = require("./doubles/KingdomWorld")
local PopulationDoubles = require("./doubles/PopulationDoubles")
local RecapDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/LeadershipRecapController")
local RecapModel = require("@game/StarterPlayer/StarterPlayerScripts/Game/UI/RecapModel")
local Rep = require("./doubles/ReputationDoubles")
local ReputationDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/ReputationPanelController")
local SummaryDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/SliceSummaryController")

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
	for _, d in if root then root:GetDescendants() else {} do
		if (d:IsA("TextLabel") or d:IsA("TextButton")) and d.Text ~= "" then
			table.insert(out, d.Text)
		end
	end
	return table.concat(out, " | ")
end

local function tap(instance)
	assert(instance, "tap: nothing to tap")
	local face = instance:FindFirstChild("Face") or instance
	expect(Create.fire(face, "Activated")).toBeGreaterThan(0)
end

local START = {
	values = { compassion = 50, honor = 50, competence = 50, courage = 50, authority = 50, fear = 10 },
	kingdom = { happiness = 60, stability = 60, morale = 60 },
	history = {},
}
local STANDINGS = {
	{ kingdom = "azure", crownPoints = 30 },
	{ kingdom = "crimson", crownPoints = 22 },
}

local function newWorld(opts)
	local o = opts or {}
	local defs = { KingdomHudDef, ReputationDef, SummaryDef }
	if not o.noRecap then
		table.insert(defs, RecapDef)
	end
	local world = KingdomWorld.new({
		remotes = ArmyDoubles.remotes(Rep.REMOTES),
		services = { PopulationDoubles.service, Rep.service(START), ArmyDoubles.service },
		clientDefinitions = defs,
	})
	world.hud = world.client:get("KingdomHudController")
	world.summary = world.client:get("SliceSummaryController")
	world.recapper = if o.noRecap then nil else world.client:get("LeadershipRecapController")
	world.rep = world.server:get("ReputationService")
	world.pop = world.server:get("PopulationService")
	world.military = world.server:get("MilitaryService")
	world.hud:setViewport(o.width or 1920, o.height or 1022)
	world.match:setPhase("Founding", world.env.serverTimeNow() + 600)
	world.pop:set("crimson", "farmer", 10)
	world:advance(1.5)
	return world
end

-- A match: three decisions, citizens 10 → 14, then the end.
local function play(world)
	world.rep:apply("compassion", 4, "You fed the farmers.")
	world:advance(1.2)
	world.rep:apply("honor", -12, "You broke the truce with Frostmere.")
	world:advance(1.2)
	world.rep:apply("authority", 7, "You raised the tithe and nobody dared complain.")
	world.pop:set("crimson", "farmer", 14)
	world:advance(1.2)
	world.match:setPhase("Results", world.env.serverTimeNow() + 30)
	world.military:endMatch({ winner = "azure", standings = STANDINGS, durationSec = 1800 })
	world:advance(0.5)
end

local function modals(world)
	return world.hud.guis.modals
end

describe("UI/RecapModel (FL-0129)", function()
	it("start → end per value, the biggest decisions first, citizens; a new match starts over", function()
		local track = RecapModel.new()
		local rep = {
			known = true,
			values = { compassion = 50, honor = 50, competence = 50, courage = 50, authority = 50, fear = 10 },
			history = {},
		}
		RecapModel.observe(track, { phase = "Lobby", startedAt = 1 }, rep, { total = 3 })
		expect(RecapModel.build(track)).toBeNil() -- nothing before the match
		RecapModel.observe(track, { phase = "Founding", startedAt = 100 }, rep, { total = 10 })
		rep = {
			known = true,
			values = { compassion = 54, honor = 38, competence = 50, courage = 50, authority = 57, fear = 10 },
			history = {
				{ t = 3, category = "authority", delta = 7, text = "Tithe" },
				{ t = 2, category = "honor", delta = -12, text = "Truce broken" },
				{ t = 1, category = "compassion", delta = 4, text = "Fed the farmers" },
				{ t = 0, category = "courage", delta = 1, text = "Small thing" },
			},
		}
		RecapModel.observe(track, { phase = "Conflict", startedAt = 100 }, rep, { total = 14 })
		local recap = RecapModel.build(track)
		expect(#recap.values).toBe(6)
		expect(recap.values[2].id).toBe("honor")
		expect(recap.values[2].start).toBe(50)
		expect(recap.values[2].finish).toBe(38)
		expect(recap.values[2].deltaText).toBe("-12")
		expect(#recap.decisions).toBe(3)
		expect(recap.decisions[1].text).toBe("Truce broken")
		expect(recap.decisions[2].text).toBe("Tithe")
		expect(recap.decisions[3].text).toBe("Fed the farmers")
		expect(recap.citizens.change).toBe(4)
		expect(recap.citizens.text).toBe("4 more citizens than at the start")
		-- history that scrolled out of the latest 30 still counts: seen entries are kept
		rep.history = { { t = 9, category = "fear", delta = 2, text = "Late" } }
		RecapModel.observe(track, { phase = "Endgame", startedAt = 100 }, rep, { total = 14 })
		expect(RecapModel.build(track).decisions[1].text).toBe("Truce broken")
		-- a new match
		RecapModel.observe(track, { phase = "Lobby", startedAt = 100 }, rep, { total = 14 })
		RecapModel.observe(track, { phase = "Founding", startedAt = 100 }, rep, { total = 2 })
		local fresh = RecapModel.build(track)
		expect(#fresh.decisions).toBe(0) -- what was on screen before the new match is the last match's
		expect(fresh.citizens.start).toBe(2)
	end)
end)

describe("Results: Your reign (FL-0129)", function()
	local world, previous
	beforeEach(function()
		previous = Create.useTestConnector()
	end)
	afterEach(function()
		if world then
			world:destroy()
			world = nil
		end
		Create.setConnector(previous)
	end)

	it(
		"the summary offers Your reign; it shows values start → end, key decisions and citizens; Back returns",
		function()
			world = newWorld()
			play(world)
			local summary = find(modals(world), "SliceSummary")
			expect(summary).toBeTruthy()
			tap(find(summary, "Recap"))
			world:advance(0.1)
			local recap = find(modals(world), "LeadershipRecap")
			expect(recap).toBeTruthy()
			local honor = find(recap, "Value_honor")
			expect(honor:GetAttribute("start")).toBe(50)
			expect(honor:GetAttribute("finish")).toBe(38)
			local all = texts(recap)
			expect(all).toContain("You broke the truce with Frostmere.")
			expect(all).toContain("Honor -12")
			expect(all).toContain("4 more citizens than at the start") -- 10 → 14 farmers (the double has builders too)
			expect(texts(find(recap, "Decision_1"))).toContain("You broke the truce")
			tap(find(recap, "Back"))
			world:advance(0.1)
			expect(find(modals(world), "LeadershipRecap")).toBeNil()
			expect(find(modals(world), "SliceSummary")).toBeTruthy()
		end
	)

	it("Continue closes the summary and the recap; a new match forgets the old one", function()
		world = newWorld()
		play(world)
		world.recapper:open()
		world:advance(0.1)
		world.summary:close()
		world:advance(0.1)
		expect(find(modals(world), "LeadershipRecap")).toBeNil()
		world.match:setPhase("Lobby", world.env.serverTimeNow() + 30)
		world:advance(1.2)
		world.match:setPhase("Founding", world.env.serverTimeNow() + 600)
		world:advance(1.2)
		local recap = world.recapper:recap()
		expect(#recap.decisions).toBe(0)
	end)

	it("without the recap controller (or before any reputation) there is no Your reign button", function()
		world = newWorld({ noRecap = true })
		play(world)
		expect(find(modals(world), "SliceSummary")).toBeTruthy()
		expect(find(modals(world), "Recap")).toBeNil()
	end)

	it("phone 667 × 375: two columns inside the screen; Your reign sits above Continue", function()
		world = newWorld({ width = 667, height = 375 })
		play(world)
		local summary = find(modals(world), "SliceSummary")
		local recapButton = find(summary, "Recap")
		expect(recapButton).toBeTruthy()
		expect(recapButton.Position.Y.Offset).toBe(-52)
		tap(recapButton)
		world:advance(0.1)
		local recap = find(modals(world), "LeadershipRecap")
		expect(find(recap, "Left")).toBeTruthy()
		expect(find(recap, "Right")).toBeTruthy()
		-- the summary's own phone box: clear of the Roblox top bar
		local panel = recap:FindFirstChild("Panel")
		expect(panel.Size.Y.Offset).toBe(262)
	end)
end)
