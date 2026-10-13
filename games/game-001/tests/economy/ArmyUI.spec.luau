-- FL-0060 end to end: the army drawer, the objective tracker and the slice summary. The real
-- KingdomHudController, UpgradePanelController, ObjectivePanelController, ArmyPanelController and
-- SliceSummaryController over the framework RemoteService, against the real TreasuryService, the
-- FORGE-01 doubles (doubles/KingdomWorld + PopulationDoubles + ArmyDoubles) and a FORGE-04 selection
-- double. The client only sends intents: every number on screen comes from a server reply or push.
local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect, beforeEach, afterEach = T.describe, T.it, T.expect, T.beforeEach, T.afterEach

local ArmyDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/ArmyPanelController")
local ArmyDoubles = require("./doubles/ArmyDoubles")
local ArmyText = require("@game/StarterPlayer/StarterPlayerScripts/Game/UI/ArmyText")
local Create = require("@game/ReplicatedStorage/Forge/UI/Create")
local KingdomHudDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/KingdomHudController")
local KingdomWorld = require("./doubles/KingdomWorld")
local Layout = require("@game/StarterPlayer/StarterPlayerScripts/Game/UI/Layout")
local ObjectiveDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/ObjectivePanelController")
local PopulationDoubles = require("./doubles/PopulationDoubles")
local Signal = require("@game/ReplicatedStorage/Forge/Core/Signal")
local SummaryDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/SliceSummaryController")
local UpgradePanelDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/UpgradePanelController")

-- FORGE-04's selection signal (G13.6) as a double.
local function inputModeDef()
	return {
		name = "InputModeController",
		new = function()
			local c = { mode = "explore", changed = Signal.new(), selected = Signal.new() }
			function c:set(mode)
				self.mode = mode
				self.changed:fire(mode)
			end
			return c
		end,
	}
end

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
	local all = root:GetDescendants()
	table.insert(all, 1, root)
	for _, d in all do
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

local function newWorld(opts)
	local o = opts or {}
	o.remotes = ArmyDoubles.remotes()
	o.services = { PopulationDoubles.service, ArmyDoubles.service }
	o.clientDefinitions = { KingdomHudDef, UpgradePanelDef, ObjectiveDef, ArmyDef, SummaryDef, inputModeDef() }
	local world = KingdomWorld.new(o)
	world.hud = world.client:get("KingdomHudController")
	world.army = world.client:get("ArmyPanelController")
	world.objectives = world.client:get("ObjectivePanelController")
	world.summary = world.client:get("SliceSummaryController")
	world.upgrade = world.client:get("UpgradePanelController")
	world.input = world.client:get("InputModeController")
	world.military = world.server:get("MilitaryService")
	world.population = world.server:get("PopulationService")
	world.hud:setViewport(o.width or 1920, o.height or 1022)
	world:advance(0.2)
	if o.barracks ~= false then
		world.barracksId =
			world.build:add("crimson", "barracks", 1, o.barracksState or "complete", Vector3.new(150, 0, 150))
		world.build:push(world.barracksId)
	end
	if o.soldiers then
		world.population:set("crimson", "soldier", o.soldiers)
	end
	world:advance(0.1)
	return world
end

local function panel(world)
	return find(world.hud.guis.menus, "ArmyPanel")
end

local function face(world, name)
	return find(find(panel(world), name), "Face")
end

local function openArmy(world)
	tap(find(world.hud.guis.hud, "Menu_army"))
	world:advance(0.1)
	expect(world.hud.state.menu).toBe("army")
	return panel(world)
end

-- Another kingdom builds far away: nothing on this player's screen changes.
local function foreignPush(world)
	local id = world.build:add("azure", "house", 1, "planned", Vector3.new(900, 0, 900))
	world.build:push(id)
	world:advance(0.1)
	world.build:progress(id, 0.4, "constructing")
	world:advance(0.1)
end

local function tracker(world)
	return find(world.hud.guis.hud, "ObjectiveTracker")
end

local function summaryRoot(world)
	return find(world.hud.guis.modals, "SliceSummary")
end

local STANDINGS = {
	{ kingdom = "crimson", crownPoints = 112 },
	{ kingdom = "azure", crownPoints = 120 },
	{ kingdom = "emerald", crownPoints = 40 },
	{ kingdom = "gold", crownPoints = 0 },
}

describe("Army drawer (FL-0060)", function()
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

	it("opens from the rail for my barracks; the cost follows the count against the treasury", function()
		world = newWorld({ soldiers = 2 })
		local p = openArmy(world)
		expect(find(world.hud.guis.hud, "Menu_army"):GetAttribute("OnboardingTarget")).toBe("HUD.ArmyButton")
		expect(texts(find(p, "Tab_building"))).toContain("Barracks · Lv 1")
		expect(find(p, "Count").Text).toBe("1")
		expect(find(find(p, "Cost_food"), "Amount").Text).toBe("30")
		expect(find(find(p, "Cost_food"), "Have").Text).toBe("✓ 120")
		tap(find(p, "More"))
		tap(find(p, "More"))
		expect(find(p, "Count").Text).toBe("3")
		expect(find(find(p, "Cost_food"), "Amount").Text).toBe("90")
		expect(find(find(p, "Cost_wood"), "Amount").Text).toBe("30")
		expect(face(world, "Recruit"):GetAttribute("cta")).toBe("ready")
		expect(texts(find(p, "Recruit"))).toContain("Recruit 3 soldiers")
		for _ = 1, 5 do
			tap(find(p, "Less"))
		end
		expect(find(p, "Count").Text).toBe("1")
		expect(find(p, "Less").Active).toBe(false)
		for _ = 1, 12 do
			tap(find(p, "More"))
		end
		expect(find(p, "Count").Text).toBe("10")
		expect(find(p, "More").Active).toBe(false)
		expect(world.army.state.count).toBe(10)
		-- the rail button again closes it
		tap(find(world.hud.guis.hud, "Menu_army"))
		world:advance(0.1)
		expect(panel(world)).toBeNil()
	end)

	it("recruits through the server: the treasury is spent, the soldiers counted, a toast", function()
		world = newWorld({ soldiers = 2 })
		local p = openArmy(world)
		expect(find(p, "Soldiers").Text).toBe("2")
		world.army:setCount(3)
		tap(face(world, "Recruit"))
		world:advance(0.2)
		local calls = world:callsNamed("Recruit")
		expect(#calls).toBe(1)
		expect(calls[1].args[1]).toBe(world.barracksId)
		expect(calls[1].args[2]).toBe("soldier")
		expect(calls[1].args[3]).toBe(3)
		expect(world.treasury:get("crimson").food).toBe(120 - 90)
		expect(world.treasury:get("crimson").wood).toBe(100 - 30)
		expect(find(p, "Soldiers").Text).toBe("5") -- Kingdom.Population pushed by the server
		expect(find(find(p, "Cost_food"), "Have").Text).toBe("have 30") -- Treasury.Changed pushed
		expect(texts(world.hud.guis.notices)).toContain("3 soldiers recruited")
	end)

	it("short of resources: disabled with the reason, no request", function()
		world = newWorld({ treasury = { food = 40, wood = 100, stone = 0, gold = 0 } })
		local p = openArmy(world)
		world.army:setCount(2)
		expect(face(world, "Recruit"):GetAttribute("cta")).toBe("disabled")
		expect(texts(find(p, "Recruit"))).toContain("Need 20 Food")
		expect(find(p, "Cost_food"):GetAttribute("short")).toBe(true)
		expect(find(find(p, "Cost_food"), "Have").Text).toBe("have 40")
		tap(face(world, "Recruit"))
		world.army:recruit()
		world:advance(0.2)
		expect(#world:callsNamed("Recruit")).toBe(0)
	end)

	it("refusals: the server's reason as a sentence; unknown reasons a generic one, never the raw code", function()
		world = newWorld()
		openArmy(world)
		world.military.refuse = "population_cap"
		tap(face(world, "Recruit"))
		world:advance(0.2)
		local notices = texts(world.hud.guis.notices)
		expect(notices).toContain(ArmyText.RECRUIT_FAILED)
		expect(notices).toContain("No room for more people. Build houses first")
		expect(notices).never.toContain("population_cap")
		world:advance(4) -- let the toasts expire
		world.military.refuse = "weird_code_42"
		tap(face(world, "Recruit"))
		world:advance(0.2)
		notices = texts(world.hud.guis.notices)
		expect(notices).toContain(ArmyText.GENERIC)
		expect(notices).never.toContain("weird_code_42")
		expect(world.treasury:get("crimson").food).toBe(120) -- nothing was spent
	end)

	it("one request in flight", function()
		world = newWorld({ latency = 1 })
		openArmy(world)
		tap(face(world, "Recruit"))
		world:advance(0.1)
		expect(face(world, "Recruit"):GetAttribute("cta")).toBe("loading")
		expect(texts(find(panel(world), "Recruit"))).toContain(ArmyText.RECRUITING)
		tap(face(world, "Recruit"))
		world.army:recruit()
		world:advance(1.5)
		expect(#world:callsNamed("Recruit")).toBe(1)
		expect(face(world, "Recruit"):GetAttribute("cta")).toBe("ready")
	end)

	it("an unfinished barracks or none: disabled with the reason", function()
		world = newWorld({ barracksState = "constructing" })
		openArmy(world)
		expect(face(world, "Recruit"):GetAttribute("cta")).toBe("disabled")
		expect(texts(find(panel(world), "Recruit"))).toContain(ArmyText.UNFINISHED_CTA)
		world:destroy()
		world = newWorld({ barracks = false })
		local p = openArmy(world)
		expect(texts(find(p, "Recruit"))).toContain(ArmyText.NO_BARRACKS_CTA)
		expect(texts(find(p, "Notice"))).toContain(ArmyText.NO_BARRACKS)
		expect(find(p, "Tab_building")).toBeNil()
	end)

	it("Send to capture: Army.Command({}, 'capture') once, local feedback, then a cooldown", function()
		world = newWorld({ soldiers = 4 })
		openArmy(world)
		expect(face(world, "Send"):GetAttribute("cta")).toBe("ready")
		tap(face(world, "Send"))
		world:advance(0.1)
		local calls = world:callsNamed("Command")
		expect(#calls).toBe(1)
		expect(type(calls[1].args[1])).toBe("table")
		expect(#calls[1].args[1]).toBe(0) -- no unit ids: all my idle soldiers (VS-1 command)
		expect(calls[1].args[2]).toBe("capture")
		expect(calls[1].args[3]).toBeNil()
		expect(calls[1].args[4]).toBeNil()
		expect(face(world, "Send"):GetAttribute("cta")).toBe("done")
		expect(texts(find(panel(world), "Send"))).toContain(ArmyText.SENT)
		expect(texts(find(panel(world), "Status"))).toContain(ArmyText.SENT_STATUS)
		expect(texts(world.hud.guis.notices)).toContain(ArmyText.SENT_TOAST)
		tap(face(world, "Send"))
		world.army:send()
		world:advance(1)
		expect(#world:callsNamed("Command")).toBe(1)
		world:advance(world.army.COOLDOWN_SEC)
		expect(face(world, "Send"):GetAttribute("cta")).toBe("ready")
		tap(face(world, "Send"))
		world:advance(0.1)
		expect(#world:callsNamed("Command")).toBe(2)
	end)

	it("Send is disabled with a reason without soldiers and when every tower is mine", function()
		world = newWorld({ soldiers = 0 })
		local p = openArmy(world)
		expect(find(p, "Soldiers").Text).toBe("0")
		expect(face(world, "Send"):GetAttribute("cta")).toBe("disabled")
		expect(texts(find(p, "Send"))).toContain(ArmyText.NO_SOLDIERS)
		tap(face(world, "Send"))
		world.army:send()
		world:advance(0.2)
		expect(#world:callsNamed("Command")).toBe(0)
		world.population:set("crimson", "soldier", 3)
		world:advance(0.1)
		expect(face(world, "Send"):GetAttribute("cta")).toBe("ready")
		world.military:setOwner("watchtower", "crimson")
		world:advance(0.1)
		expect(face(world, "Send"):GetAttribute("cta")).toBe("disabled")
		expect(texts(find(p, "Send"))).toContain(ArmyText.ALL_MINE)
	end)

	it("my barracks' upgrade panel gets an Army tab that opens this drawer, and back", function()
		world = newWorld({ soldiers = 1 })
		world.input.selected:fire("building", world.barracksId)
		world:advance(0.1)
		expect(world.hud.state.menu).toBe("upgrade")
		local upgrade = find(world.hud.guis.menus, "UpgradePanel")
		tap(find(upgrade, "Tab_army"))
		world:advance(0.1)
		expect(world.hud.state.menu).toBe("army")
		expect(world.army.state.barracksId).toBe(world.barracksId)
		tap(find(panel(world), "Tab_building"))
		world:advance(0.1)
		expect(world.hud.state.menu).toBe("upgrade")
		-- the keep and another kingdom's barracks get no Army tab
		world.input.selected:fire("building", 1)
		world:advance(0.1)
		expect(find(find(world.hud.guis.menus, "UpgradePanel"), "Tab_army")).toBeNil()
		local theirs = world.build:add("azure", "barracks", 2, "complete", Vector3.new(900, 0, 0))
		world.build:push(theirs)
		world:advance(0.1)
		world.input.selected:fire("building", theirs)
		world:advance(0.1)
		expect(find(find(world.hud.guis.menus, "UpgradePanel"), "Tab_army")).toBeNil()
		-- tapping the ground closes the army drawer
		world.army:open()
		world:advance(0.1)
		world.input.selected:fire("none", "")
		world:advance(0.1)
		expect(world.hud.state.menu).toBeNil()
	end)
end)

describe("Objective tracker (FL-0060)", function()
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

	it("shows Army.GetObjectives and follows Army.Objectives in place", function()
		world = newWorld()
		local t = tracker(world)
		expect(t).toBeTruthy()
		expect(t.Visible).toBe(true)
		local row = find(t, "Objective_watchtower")
		expect(find(row, "ObjectiveName").Text).toBe("Watchtower")
		expect(row:GetAttribute("owner")).toBe("Neutral")
		expect(find(row, "Status").Text).toBe(ArmyText.STATUS_NEUTRAL)
		world.military:setProgress("watchtower", "crimson", 0.4)
		world:advance(0.1)
		local mine = find(row, "Bar_crimson")
		expect(mine.Visible).toBe(true)
		expect(find(mine, "Label").Text).toBe("You")
		expect(find(mine, "Pct").Text).toBe("40%")
		expect(mine:GetAttribute("progress")).toBe(0.4)
		expect(find(row, "Status").Visible).toBe(false)
		world.military:setProgress("watchtower", "crimson", 0.64)
		world.military:setProgress("watchtower", "azure", 0.2)
		world:advance(0.1)
		expect(tracker(world)).toBe(t)
		expect(find(t, "Objective_watchtower")).toBe(row)
		expect(find(row, "Bar_crimson")).toBe(mine)
		expect(find(mine, "Pct").Text).toBe("64%")
		expect(find(mine, "Bar"):GetAttribute("progress")).toBe(0.64)
		local theirs = find(row, "Bar_azure")
		expect(find(theirs, "Label").Text).toBe("Frostmere")
		expect(find(theirs, "Pct").Text).toBe("20%")
		expect(mine.Position.Y.Offset).toBeLessThan(theirs.Position.Y.Offset) -- mine first
		world.military:setOwner("watchtower", "azure")
		world:advance(0.1)
		expect(row:GetAttribute("owner")).toBe("Frostmere")
		expect(mine.Visible).toBe(false)
		expect(find(row, "Status").Text).toBe(ArmyText.STATUS_FOREIGN)
		-- malformed pushes never wipe it or error; bad entries are dropped
		world.remotes:fireAll("Army.Objectives", "nope")
		world:advance(0.1)
		expect(find(tracker(world), "Objective_watchtower")).toBe(row)
		expect(row.Visible).toBe(true)
		world.remotes:fireAll("Army.Objectives", { { id = 5 }, { id = "hill", progress = { crimson = "a" } } })
		world:advance(0.1)
		expect(row.Visible).toBe(false)
		expect(find(t, "Objective_hill").Visible).toBe(true)
	end)

	it("sits under the top-left stack and moves down when the reputation strip appears (#58 strip room)", function()
		world = newWorld({ width = 1024, height = 690 })
		local without = Layout.compute(1024, 690, { reputation = false }).hud.objectives
		expect(tracker(world).Position.Y.Offset).toBe(without.y)
		-- the strip shows for the first time (ReputationPanelController sets the flag)
		world.hud.state.reputation = true
		world.hud:render()
		local with = Layout.compute(1024, 690, { reputation = true }).hud.objectives
		expect(with.y).toBeGreaterThan(without.y)
		expect(tracker(world).Position.Y.Offset).toBe(with.y)
		expect(find(tracker(world), "Objective_watchtower")).toBeTruthy()
	end)

	it("a tap expands the list; phone toasts with an open drawer start below the tracker", function()
		world = newWorld({ width = 750, height = 311, soldiers = 3 })
		world.military:setProgress("watchtower", "crimson", 0.5)
		world.military:add({
			id = "old_ford",
			kind = "capture",
			position = Vector3.zero,
			radius = 20,
			owner = "azure",
			progress = { azure = 1 },
		})
		world:advance(0.1)
		local t = tracker(world)
		expect(t:GetAttribute("expanded")).toBe(false)
		expect(find(t, "Objective_old_ford")).toBeNil()
		expect(find(t, "More").Text).toContain("+1 more")
		expect(find(t, "Toggle").Size.Y.Scale).toBe(1)
		expect(t.Size.Y.Offset).toBeGreaterThanOrEqual(44)
		tap(find(t, "Toggle"))
		expect(t:GetAttribute("expanded")).toBe(true)
		expect(find(t, "Objective_old_ford").Visible).toBe(true)
		expect(find(t, "Objective_watchtower").Visible).toBe(true)
		tap(find(t, "Toggle"))
		expect(t:GetAttribute("expanded")).toBe(false)
		expect(find(t, "Objective_old_ford").Visible).toBe(false)
		-- the phone drawer sits right of the tracker; a toast starts below it
		local p = openArmy(world)
		expect(t.Position.X.Offset + t.Size.X.Offset).toBeLessThan(p.Position.X.Offset)
		tap(face(world, "Send"))
		world:advance(0.1)
		local toasts = world.hud.toasts.instance
		expect(toasts.Position.Y.Offset).toBeGreaterThanOrEqual(t.Position.Y.Offset + t.Size.Y.Offset)
		-- FORGE-04's NotificationController (#74) goes to the same spot, below the tracker too
		local placed = {}
		world.hud._notifications = {
			place = function(_, position)
				table.insert(placed, position)
			end,
		}
		world.hud._notificationsAt = nil
		world.hud:render()
		local m = world.hud:metrics()
		expect(#placed).toBe(1)
		expect(placed[1].Y.Offset).toBeGreaterThanOrEqual(math.floor((t.Position.Y.Offset + t.Size.Y.Offset) * m.scale))
	end)
end)

describe("Slice summary (FL-0060)", function()
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

	it("Match.Ended shows the winner, the standings with Crown Points and the duration; Continue closes it", function()
		world = newWorld()
		expect(summaryRoot(world)).toBeNil()
		world.military:endMatch({ winner = "azure", standings = STANDINGS, durationSec = 754 })
		world:advance(0.1)
		local s = summaryRoot(world)
		expect(s).toBeTruthy()
		expect(s.Parent).toBe(world.hud.roots.modals)
		local all = texts(s)
		expect(all).toContain("Frostmere")
		expect(all).toContain(ArmyText.WINS)
		expect(all).toContain("Lasted 12:34")
		local first = find(s, "Standing_azure")
		expect(first:GetAttribute("rank")).toBe(1)
		expect(first:GetAttribute("winner")).toBe(true)
		expect(find(first, "Points").Text).toBe("120")
		local mine = find(s, "Standing_crimson")
		expect(mine:GetAttribute("rank")).toBe(2)
		expect(mine:GetAttribute("mine")).toBe(true)
		expect(find(mine, "YouTag")).toBeTruthy()
		expect(find(mine, "AiTag")).toBeNil()
		expect(find(find(s, "Standing_emerald"), "AiTag")).toBeTruthy()
		expect(find(find(s, "Standing_gold"), "Points").Text).toBe("0")
		-- a stray tap on the scrim does not close it; Continue does
		Create.fire(find(s, "Scrim"), "Activated")
		expect(summaryRoot(world)).toBe(s)
		tap(find(s, "Continue"))
		expect(summaryRoot(world)).toBeNil()
		expect(world.summary.isOpen).toBe(false)
	end)

	it("a win of mine, no winner, and malformed payloads", function()
		world = newWorld()
		world.military:endMatch({ standings = STANDINGS, durationSec = 60 })
		world:advance(0.1)
		expect(texts(summaryRoot(world))).toContain(ArmyText.NO_WINNER)
		expect(find(summaryRoot(world), "Standing_azure"):GetAttribute("winner")).toBe(false)
		world.military:endMatch({ winner = "crimson", standings = STANDINGS, durationSec = 60 })
		world:advance(0.1)
		local all = texts(summaryRoot(world))
		expect(all).toContain(string.upper(ArmyText.VICTORY))
		expect(all).toContain(ArmyText.YOU_WIN)
		local before = summaryRoot(world)
		world.remotes:fireAll("Match.Ended", 42)
		world:advance(0.1)
		expect(summaryRoot(world)).toBe(before) -- ignored
		world.military:endMatch({ winner = "azure", standings = { "x", { kingdom = "azure", crownPoints = 5 } } })
		world:advance(0.1)
		local s = summaryRoot(world)
		expect(find(s, "Standing_azure")).toBeTruthy()
		expect(find(s, "Standing_crimson")).toBeNil()
		expect(texts(s)).never.toContain("Lasted")
	end)
end)

describe("FL-0060 on a phone (750 × 311 safe area)", function()
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

	local function height(instance)
		return instance.Size.Y.Offset + instance.Size.Y.Scale * 0
	end

	it("every control is at least 44 px tall and the drawer fits the screen", function()
		world = newWorld({ width = 750, height = 311, soldiers = 2 })
		local p = openArmy(world)
		local m = world.hud:metrics()
		expect(p.Position.X.Offset + p.Size.X.Offset).toBeLessThanOrEqual(m.width)
		expect(p.Position.Y.Offset + p.Size.Y.Offset).toBeLessThanOrEqual(m.height)
		for _, name in { "Recruit", "Send" } do
			expect(height(find(p, name))).toBeGreaterThanOrEqual(44)
		end
		for _, name in { "Less", "More", "Close" } do
			expect(find(p, name).Size.Y.Offset).toBeGreaterThanOrEqual(44)
		end
		for _, name in { "Tab_building", "Tab_army" } do
			expect(find(find(p, name), "Hit").Size.Y.Offset).toBeGreaterThanOrEqual(44)
		end
		-- the Recruit CTA ends inside the drawer's content area
		local content = find(p, "Content")
		local recruit = find(p, "Recruit")
		expect(recruit.Position.Y.Offset + 44).toBeLessThanOrEqual(content.Size.Y.Offset + p.Size.Y.Offset)
		local t = tracker(world)
		expect(t.Size.Y.Offset).toBeGreaterThanOrEqual(44)
		expect(find(world.hud.guis.hud, "Menu_army").Size.Y.Offset).toBeGreaterThanOrEqual(44)
		world.military:endMatch({ winner = "azure", standings = STANDINGS, durationSec = 754 })
		world:advance(0.1)
		local s = summaryRoot(world)
		expect(find(s, "Continue").Size.Y.Offset).toBeGreaterThanOrEqual(44)
		local summaryPanel = find(s, "Panel")
		-- clear of the 58 px top bar on a 390 px tall phone when centred
		expect(summaryPanel.Size.Y.Offset).toBeLessThanOrEqual(390 - 2 * 58)
		-- the upgrade panel's Army tab is a 44 px target too
		tap(find(s, "Continue"))
		world.input.selected:fire("building", world.barracksId)
		world:advance(0.1)
		local upgrade = find(world.hud.guis.menus, "UpgradePanel")
		expect(find(find(upgrade, "Tab_army"), "Hit").Size.Y.Offset).toBeGreaterThanOrEqual(44)
		tap(find(find(upgrade, "Tab_army"), "Hit"))
		world:advance(0.1)
		expect(world.hud.state.menu).toBe("army")
	end)
end)

describe("FL-0060 views survive pushes (FORGE-05 M1)", function()
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

	it("Recruit, Send, tracker rows and the summary keep their instances; the kept buttons still work", function()
		world = newWorld({ soldiers = 2, treasury = { food = 20, wood = 100, stone = 0, gold = 0 } })
		world.military:setProgress("watchtower", "crimson", 0.3)
		world:advance(0.1)
		local p = openArmy(world)
		local recruit, send = face(world, "Recruit"), face(world, "Send")
		local count = find(p, "Count")
		local t = tracker(world)
		local row = find(t, "Objective_watchtower")
		local bar = find(row, "Bar_crimson")
		expect(recruit:GetAttribute("cta")).toBe("disabled")

		-- a treasury push that covers the cost, then another kingdom's building push
		world.treasury:deposit("crimson", "food", 100, "m1:food", "test")
		world:advance(0.1)
		foreignPush(world)
		expect(panel(world)).toBe(p)
		expect(face(world, "Recruit")).toBe(recruit)
		expect(face(world, "Send")).toBe(send)
		expect(find(p, "Count")).toBe(count)
		expect(recruit:GetAttribute("cta")).toBe("ready")
		expect(find(find(p, "Cost_food"), "Have").Text).toBe("✓ 120")
		expect(tracker(world)).toBe(t)
		expect(find(t, "Objective_watchtower")).toBe(row)
		expect(find(row, "Bar_crimson")).toBe(bar)

		-- a population push and an objective push patch the same instances too
		world.population:set("crimson", "soldier", 5)
		world.military:setProgress("watchtower", "crimson", 0.7)
		world:advance(0.1)
		expect(face(world, "Send")).toBe(send)
		expect(find(p, "Soldiers").Text).toBe("5")
		expect(find(row, "Bar_crimson")).toBe(bar)
		expect(find(bar, "Pct").Text).toBe("70%")

		-- the kept buttons act on the newest state
		tap(recruit)
		world:advance(0.2)
		expect(#world:callsNamed("Recruit")).toBe(1)
		tap(send)
		world:advance(0.1)
		expect(#world:callsNamed("Command")).toBe(1)

		-- the match ends: the drawer closes (no live buttons under the summary, FORGE-05 low 6), and
		-- the summary keeps its instances across pushes until Continue
		world.military:endMatch({ winner = "azure", standings = STANDINGS, durationSec = 754 })
		world:advance(0.1)
		expect(world.hud.state.menu).toBeNil()
		local s = summaryRoot(world)
		local continue = find(find(s, "Continue"), "Face")
		world.treasury:deposit("crimson", "food", 5, "m1:food2", "test")
		world.military:setProgress("watchtower", "crimson", 0.8)
		world:advance(0.1)
		expect(summaryRoot(world)).toBe(s)
		expect(find(find(s, "Continue"), "Face")).toBe(continue)
		tap(continue)
		expect(summaryRoot(world)).toBeNil()
	end)
end)

describe("FL-0060 destroy paths and match end (FORGE-05 review of #63)", function()
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

	it("M1: a recruit reply and the Send cooldown that land after destroy draw nothing", function()
		world = newWorld({ soldiers = 2, latency = 0.5, treasury = { food = 200, wood = 100, stone = 0, gold = 0 } })
		world:advance(1) -- the first fetches have the same round trip
		openArmy(world)
		expect(face(world, "Recruit"):GetAttribute("cta")).toBe("ready")
		tap(face(world, "Recruit"))
		tap(face(world, "Send"))
		world:advance(0.1)
		local spoken = 0
		local notify = world.hud.notify
		world.hud.notify = function(hud, spec)
			spoken += 1
			return notify(hud, spec)
		end
		world.army:destroy()
		expect(world.hud.state.menu).toBeNil() -- the drawer closed with its controller
		expect(world.army.view).toBeNil()
		expect(find(world.hud.guis.hud, "Menu_army")).toBeNil() -- the rail button went too
		world:advance(world.army.COOLDOWN_SEC + 1) -- the reply and the cooldown both land now
		expect(panel(world)).toBeNil()
		expect(spoken).toBe(0) -- the recruit reply that landed after destroy said nothing
		expect(#world:callsNamed("Recruit")).toBe(1)
		-- the HUD opens "army" again (a stale rail tap): the destroyed controller draws nothing
		world.hud:setMenu("army")
		world.army:render()
		world:advance(0.1)
		expect(panel(world)).toBeNil()
	end)

	it("M2: Army.Objectives replicating only after destroy: no fetch, no tracker", function()
		local release
		local fetched, placed = 0, 0
		local hudDouble = {
			rendered = Signal.new(),
			roots = {},
			hasRemote = function()
				return true -- the army remotes are served; Army.Objectives replicates late
			end,
			setStackBottom = function()
				placed += 1
			end,
			remotes = {
				on = function()
					release = coroutine.running()
					coroutine.yield()
					return { Disconnect = function() end }
				end,
				invoke = function()
					fetched += 1
					return {}
				end,
			},
		}
		local env = {
			spawn = function(fn)
				coroutine.wrap(fn)()
			end,
			log = function() end,
		}
		local objectives = ObjectiveDef.new(env, {
			get = function()
				return hudDouble
			end,
		})
		local changes = 0
		objectives.changed:connect(function()
			changes += 1
		end)
		objectives:start()
		expect(release).toBeTruthy()
		objectives:destroy()
		assert(coroutine.resume(release))
		expect(fetched).toBe(0)
		objectives:apply({ { id = "watchtower" } }, true) -- a reply already on its way
		expect(changes).toBe(0)
		expect(objectives.tracker).toBeNil()
	end)

	it("after destroy the tracker and the summary draw nothing, whoever calls them", function()
		world = newWorld()
		expect(tracker(world)).toBeTruthy()
		world.objectives:destroy()
		world.summary:destroy()
		expect(tracker(world)).toBeNil()
		world.objectives:render()
		world.summary:show({ winner = "azure", standings = STANDINGS, durationSec = 754 })
		world:advance(0.1)
		expect(tracker(world)).toBeNil()
		expect(summaryRoot(world)).toBeNil()
	end)

	it(
		"D-038 (2): without the server's Army remotes there is no Army button or tab; they appear once served",
		function()
			-- today's main without FORGE-01's #70: no Army area under ForgeRemotes
			world = KingdomWorld.new({
				remotes = { Kingdom = PopulationDoubles.REMOTES.Kingdom },
				services = { PopulationDoubles.service },
				clientDefinitions = { KingdomHudDef, UpgradePanelDef, ArmyDef, inputModeDef() },
			})
			world.hud = world.client:get("KingdomHudController")
			world.army = world.client:get("ArmyPanelController")
			world.upgrade = world.client:get("UpgradePanelController")
			world.hud:setViewport(1920, 1022)
			world:advance(5)
			expect(find(world.hud.guis.hud, "Menu_army")).toBeNil()
			expect(world.army.offered).never.toBe(true)
			local barracks = world.build:add("crimson", "barracks", 1, "complete", Vector3.new(150, 0, 150))
			world.build:push(barracks)
			world:advance(0.1)
			world.upgrade:open(barracks)
			world:advance(0.1)
			expect(find(world.hud.guis.menus, "Tab_army")).toBeNil()
			-- the army remotes replicate later (the server got them): the button and the tab appear
			local root = world.env.ReplicatedStorage:FindFirstChild("ForgeRemotes")
			local area = world.env.newInstance("Folder")
			area.Name = "Army"
			area.Parent = root
			local recruit = world.env.newInstance("RemoteFunction")
			recruit.Name = "Recruit"
			recruit.Parent = area
			world:advance(world.army.SERVED_POLL_SEC + 0.1)
			expect(world.army.offered).toBe(true)
			expect(find(world.hud.guis.hud, "Menu_army")).toBeTruthy()
		end
	)

	it("FORGE-05 L1 on #63: without the Army remotes the tracker neither listens nor asks, and logs nothing", function()
		-- today's main without FORGE-01's #70: no Army area under ForgeRemotes
		world = KingdomWorld.new({
			remotes = { Kingdom = PopulationDoubles.REMOTES.Kingdom },
			services = { PopulationDoubles.service },
			clientDefinitions = { KingdomHudDef, UpgradePanelDef, ObjectiveDef, inputModeDef() },
		})
		world.hud = world.client:get("KingdomHudController")
		world.objectives = world.client:get("ObjectivePanelController")
		world.hud:setViewport(1920, 1022)
		world:advance(25) -- past the remote client's 10 s wait and a GetObjectives timeout
		expect(world.objectives.serving).toBe(false)
		expect(world.env.mock:hasLog("warn", "ObjectivePanelController")).toBe(false)
		local tracker = find(world.hud.guis.hud, "ObjectiveTracker")
		expect(tracker == nil or tracker.Visible == false).toBe(true) -- nothing to show
		-- the server's army remotes replicate later: the tracker starts listening and asking
		local root = world.env.ReplicatedStorage:FindFirstChild("ForgeRemotes")
		local area = world.env.newInstance("Folder")
		area.Name = "Army"
		area.Parent = root
		local push = world.env.newInstance("RemoteEvent")
		push.Name = "Objectives"
		push.Parent = area
		world:advance(world.objectives.SERVED_POLL_SEC + 0.1)
		expect(world.objectives.serving).toBe(false) -- both, or it would wait on the fetch
		local get = world.env.newInstance("RemoteFunction")
		get.Name = "GetObjectives"
		get.Parent = area
		world:advance(world.objectives.SERVED_POLL_SEC + 0.1)
		expect(world.objectives.serving).toBe(true)
	end)

	it("low 4: FORGE-01's recruit refusals read as sentences", function()
		for _, code in { "recruit_cap", "match_not_active", "not_in_match", "not_ruler", "kingdom_eliminated" } do
			local sentence = ArmyText.reason(code)
			expect(sentence).never.toBe(ArmyText.GENERIC)
			expect(sentence).never.toContain(code)
		end
	end)

	it("low 6: the summary closes when the next match begins, not when Results starts", function()
		world = newWorld()
		world.match:setPhase("Endgame")
		world:advance(0.1)
		world.military:endMatch({ winner = "azure", standings = STANDINGS, durationSec = 754 })
		world:advance(0.1)
		expect(summaryRoot(world)).toBeTruthy()
		world.match:setPhase("Results")
		world:advance(0.1)
		expect(summaryRoot(world)).toBeTruthy()
		world.match:setPhase("Lobby")
		world:advance(0.1)
		expect(summaryRoot(world)).toBeNil()
	end)
end)
