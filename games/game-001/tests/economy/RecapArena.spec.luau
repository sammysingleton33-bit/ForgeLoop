-- FL-0073 (f): the "Arena & support" page of the leadership recap at Results. The real KingdomHudController,
-- ReputationPanelController, ArenaHudController, SliceSummaryController and LeadershipRecapController over the FORGE-01
-- doubles for reputation, population, the match end (ArmyDoubles' Match.Ended) and the arena (ArenaDoubles: ArenaState,
-- Arena.Events, Kingdom.Support).
local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect, beforeEach, afterEach = T.describe, T.it, T.expect, T.beforeEach, T.afterEach

local ArenaDoubles = require("./doubles/ArenaDoubles")
local ArenaHudDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/ArenaHudController")
local ArenaRecapModel = require("@game/StarterPlayer/StarterPlayerScripts/Game/UI/ArenaRecapModel")
local ArmyDoubles = require("./doubles/ArmyDoubles")
local Create = require("@game/ReplicatedStorage/Forge/UI/Create")
local KingdomHudDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/KingdomHudController")
local KingdomWorld = require("./doubles/KingdomWorld")
local PopulationDoubles = require("./doubles/PopulationDoubles")
local RecapDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/LeadershipRecapController")
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
local STANDINGS = { { kingdom = "crimson", crownPoints = 30 }, { kingdom = "azure", crownPoints = 22 } }

-- Seven moments over the match; the double's SupportView carries only the latest few at a time.
local MOMENTS = {
	{ t = 10, act = "keepUpgraded", component = "reputation", delta = 2, text = "Raised the keep for all to see" },
	{ t = 20, act = "starvation", component = "conduct", delta = -5, text = "Let the kingdom go hungry" },
	{ t = 30, act = "fedRatioKept", component = "conduct", delta = 4, text = "Kept the kingdom fed through the phase" },
	{ t = 40, act = "objectiveDefended", component = "reputation", delta = 3, text = "Held an objective" },
	{ t = 50, act = "abandonedRegion", component = "conduct", delta = -4, text = "Left a raided region to its fate" },
	{ t = 60, act = "rebuiltRaidDamage", component = "conduct", delta = 2, text = "Rebuilt what the raid broke" },
	{ t = 70, act = "petitionFulfilled", component = "conduct", delta = 3, text = "Heard a citizen's petition" },
}

local function newWorld(opts)
	local o = opts or {}
	local remotes = ArmyDoubles.remotes(Rep.REMOTES, if o.noArena then {} else ArenaDoubles.REMOTES)
	local defs = { KingdomHudDef, ReputationDef, SummaryDef, RecapDef }
	if not o.noArena then
		table.insert(defs, ArenaHudDef)
	end
	local services = { PopulationDoubles.service, Rep.service(START), ArmyDoubles.service }
	if not o.noArena then
		table.insert(services, ArenaDoubles.service)
	end
	local world = KingdomWorld.new({ remotes = remotes, services = services, clientDefinitions = defs })
	world.hud = world.client:get("KingdomHudController")
	world.recapper = world.client:get("LeadershipRecapController")
	world.rep = world.server:get("ReputationService")
	world.pop = world.server:get("PopulationService")
	world.military = world.server:get("MilitaryService")
	world.arena = if o.noArena then nil else world.server:get("ArenaDouble")
	world.hud:setViewport(o.width or 1920, o.height or 1022)
	world.match:setPhase("Founding", world.env.serverTimeNow() + 600)
	world.pop:set("crimson", "farmer", 10)
	world:advance(1.5)
	return world
end

-- Push the moments in three SupportViews (each with only its latest three), as the server would over a match.
local function supportOverMatch(world, tier)
	for _, upTo in { 3, 5, 7 } do
		local view = ArenaDoubles.support(tier, 1, "crimson")
		view.moments = {}
		for i = math.max(1, upTo - 2), upTo do
			table.insert(view.moments, MOMENTS[i])
		end
		world.arena.support[1] = view
		world.arena:sendSupport(world.player)
		world:advance(1.2)
	end
end

local function duel(world, tier, winner, fired)
	local a = ArenaDoubles.duellist(1, "crimson", tier, { triggers = { "reforge", "fieldRemedy", "crowdRally" } })
	local b = ArenaDoubles.duellist(7, "azure", "divided")
	world.arena:setState({ stage = "duel", a = a, b = b })
	world:advance(1.2)
	local batch = {}
	for _, id in fired do
		table.insert(batch, { t = 1, kind = "triggerFired", side = "a", data = { trigger = id } })
	end
	if winner then
		table.insert(batch, { t = 2, kind = "ended", side = winner, data = { winner = winner, reason = "ko" } })
	end
	world.arena:events(batch)
	world:advance(1.2)
	world.arena:setState({ stage = "done", a = a, b = b })
	world:advance(1.2)
end

local function results(world)
	world.match:setPhase("Results", world.env.serverTimeNow() + 30)
	world.military:endMatch({ winner = "crimson", standings = STANDINGS, durationSec = 1800 })
	world:advance(1.5)
end

local function recapView(world)
	return find(world.hud.guis.modals, "LeadershipRecap")
end

describe("UI/ArenaRecapModel (pure)", function()
	it("nothing seen: no arena recap", function()
		expect(ArenaRecapModel.build(ArenaRecapModel.new())).toBeNil()
	end)

	it("keeps every moment once across views and lists the five biggest by size, the later first on a tie", function()
		local track = ArenaRecapModel.new()
		ArenaRecapModel.observe(track, 1, { moments = { MOMENTS[1], MOMENTS[2], MOMENTS[3] } }, nil, nil, "crimson")
		ArenaRecapModel.observe(track, 1, { moments = { MOMENTS[3], MOMENTS[4], MOMENTS[5] } }, nil, nil, "crimson")
		ArenaRecapModel.observe(track, 1, { moments = { MOMENTS[5], MOMENTS[6], MOMENTS[7] } }, nil, nil, "crimson")
		local r = ArenaRecapModel.build(track)
		expect(#r.moments).toBe(ArenaRecapModel.MOMENTS)
		-- |delta| 5, 4, 4, 3, 3 (ties: the later first): t 20, 50, 30, 70, 40
		local order = {}
		for _, m in r.moments do
			table.insert(order, m.text)
		end
		expect(table.concat(order, "/")).toBe(
			table.concat({ MOMENTS[2].text, MOMENTS[5].text, MOMENTS[3].text, MOMENTS[7].text, MOMENTS[4].text }, "/")
		)
		expect(r.moments[1].deltaText).toBe("−5")
		expect(r.moments[1].positive).toBe(false)
		expect(r.moments[1].component).toBe("Your conduct")
		expect(r.crowd.id).toBe("absent")
		expect(r.perksText).toBe("Your kingdom had no champion")
	end)

	it("a new match key starts over", function()
		local track = ArenaRecapModel.new()
		ArenaRecapModel.observe(track, 1, { moments = { MOMENTS[1] } }, nil, nil, "crimson")
		ArenaRecapModel.observe(track, 2, nil, nil, nil, "crimson")
		expect(ArenaRecapModel.build(track)).toBeNil()
	end)

	it("the crowd follows design §7: win/loss × high/low support, a draw and an undecided duel", function()
		local function outcome(tier, winner)
			local track = ArenaRecapModel.new()
			local arena = { stage = "done", a = { userId = 1, kingdom = "crimson", tier = tier, triggers = {} } }
			ArenaRecapModel.observe(
				track,
				1,
				nil,
				arena,
				if winner then { ended = { winner = winner } } else nil,
				"crimson"
			)
			return ArenaRecapModel.build(track).crowd.id
		end
		expect(outcome("adoring", "a")).toBe("crowned")
		expect(outcome("loyal", "a")).toBe("crowned")
		expect(outcome("divided", "a")).toBe("quiet")
		expect(outcome("adoring", "b")).toBe("saluted")
		expect(outcome("hostile", "b")).toBe("emptied")
		expect(outcome("adoring", "draw")).toBe("draw")
		expect(outcome("adoring", nil)).toBe("pending")
	end)

	it("the result falls back to ArenaState.winner (a userId) once the duel is over", function()
		local track = ArenaRecapModel.new()
		local arena = {
			stage = "crowning",
			winner = 7,
			a = { userId = 1, kingdom = "crimson", tier = "adoring", triggers = {} },
			b = { userId = 7, kingdom = "azure", tier = "divided", triggers = {} },
		}
		ArenaRecapModel.observe(track, 1, nil, arena, nil, "crimson")
		expect(ArenaRecapModel.build(track).crowd.id).toBe("saluted")
	end)
end)

describe("Leadership recap: Arena & support (FL-0073)", function()
	local world, previous
	beforeEach(function()
		previous = Create.useTestConnector()
		world = newWorld()
	end)
	afterEach(function()
		world:destroy()
		Create.setConnector(previous)
	end)

	it("an Adoring champion who won: five biggest moments, 2 of 3 perks fired, crowned by the stand", function()
		world.rep:apply("compassion", 4, "You fed the farmers.")
		supportOverMatch(world, "adoring")
		duel(world, "adoring", "a", { "reforge", "crowdRally" })
		results(world)
		world.recapper:open()
		world:advance(0.1)
		local view = recapView(world)
		local page = find(view, "Page")
		expect(page).toBeTruthy()
		tap(page)
		world:advance(0.1)
		view = recapView(world)
		expect(world.recapper.page).toBe("arena")
		expect(find(view, "Moment_1")).toBeTruthy()
		expect(find(find(view, "Moment_1"), "Text").Text).toBe(MOMENTS[2].text)
		expect(find(view, "Moment_5")).toBeTruthy()
		expect(find(view, "Moment_6")).toBeNil()
		expect(find(view, "Perk_reforge"):GetAttribute("fired")).toBe(true)
		expect(find(view, "Perk_fieldRemedy"):GetAttribute("fired")).toBe(false)
		expect(find(view, "Perk_crowdRally"):GetAttribute("fired")).toBe(true)
		expect(find(view, "PerksText").Text).toBe("2 of 3 perks fired")
		expect(find(view, "Crowd"):GetAttribute("outcome")).toBe("crowned")
		expect(texts(view)).toContain("Adoring support")
		-- and back to the reign page
		tap(find(view, "Page"))
		world:advance(0.1)
		expect(world.recapper.page).toBe("reign")
		expect(find(recapView(world), "Value_compassion")).toBeTruthy()
	end)

	it("a Hostile champion who lost: the stand emptied", function()
		world.rep:apply("compassion", 4, "You fed the farmers.")
		supportOverMatch(world, "hostile")
		duel(world, "hostile", "b", {})
		results(world)
		world.recapper:open()
		world.recapper:setPage("arena")
		world:advance(0.1)
		local view = recapView(world)
		expect(find(view, "Crowd"):GetAttribute("outcome")).toBe("emptied")
		expect(find(view, "PerksText").Text).toBe("0 of 3 perks fired")
	end)

	it("support seen but no champion: the page says so", function()
		world.rep:apply("compassion", 4, "You fed the farmers.")
		supportOverMatch(world, "divided")
		results(world)
		world.recapper:open()
		world.recapper:setPage("arena")
		world:advance(0.1)
		local view = recapView(world)
		expect(find(view, "Crowd"):GetAttribute("outcome")).toBe("absent")
		expect(find(view, "PerksText").Text).toBe("Your kingdom had no champion")
	end)

	it("opening the recap again starts on the reign page", function()
		world.rep:apply("compassion", 4, "You fed the farmers.")
		supportOverMatch(world, "adoring")
		results(world)
		world.recapper:open()
		world.recapper:setPage("arena")
		world.recapper:close()
		world.recapper:open()
		world:advance(0.1)
		expect(world.recapper.page).toBe("reign")
		expect(find(recapView(world), "Value_compassion")).toBeTruthy()
	end)

	it("phone 667 × 375: Back and Page share the bottom row, 44 px each, inside the panel", function()
		world.hud:setViewport(667, 375)
		world.rep:apply("compassion", 4, "You fed the farmers.")
		supportOverMatch(world, "adoring")
		duel(world, "adoring", "a", { "reforge" })
		results(world)
		world.recapper:open()
		world.recapper:setPage("arena")
		world:advance(0.1)
		local view = recapView(world)
		local back, page = find(view, "Back"), find(view, "Page")
		expect(back.Size.Y.Offset).toBe(44)
		expect(page.Size.Y.Offset).toBe(44)
		expect(back.Position.Y.Scale).toBe(1)
		expect(page.Position.Y.Scale).toBe(1)
		expect(find(view, "Left")).toBeTruthy()
		expect(find(view, "Right").Size.Y.Offset).toBe(-52) -- above the bottom row
	end)
end)

describe("Leadership recap without the arena", function()
	local previous
	beforeEach(function()
		previous = Create.useTestConnector()
	end)
	afterEach(function()
		Create.setConnector(previous)
	end)

	it("no ArenaHudController (or nothing seen): one page, no Page button, Back full width", function()
		local world = newWorld({ noArena = true })
		world.rep:apply("compassion", 4, "You fed the farmers.")
		results(world)
		world.recapper:open()
		world:advance(0.1)
		local view = recapView(world)
		expect(view).toBeTruthy()
		expect(find(view, "Page")).toBeNil()
		expect(find(view, "Back").Size.X.Scale).toBe(1)
		world.recapper:setPage("arena") -- nothing to show: stays on the reign
		world:advance(0.1)
		expect(find(recapView(world), "Value_compassion")).toBeTruthy()
		world:destroy()
	end)
end)
