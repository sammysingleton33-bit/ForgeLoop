-- FL-0089 end to end, headless: the real KingdomHudController and ReputationPanelController talk
-- through the framework RemoteService to a FORGE-01 ReputationService double (doubles/
-- ReputationDoubles, plugged into doubles/KingdomWorld with its `remotes` and `services` options).
-- Taps are simulated with Create.fire on what a player would press.
local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect, beforeEach, afterEach = T.describe, T.it, T.expect, T.beforeEach, T.afterEach

local Create = require("@game/ReplicatedStorage/Forge/UI/Create")
local KingdomHudDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/KingdomHudController")
local KingdomWorld = require("./doubles/KingdomWorld")
local Layout = require("@game/StarterPlayer/StarterPlayerScripts/Game/UI/Layout")
local Rep = require("./doubles/ReputationDoubles")
local ReputationDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/ReputationPanelController")

local START = {
	values = { compassion = 62, honor = 48, competence = 55, courage = 40, authority = 70, fear = 15 },
	kingdom = { happiness = 68, stability = 54, morale = 41 },
	-- oldest first, as the double sends it: the client must put the newest on top
	history = {
		{ ago = 700, category = "competence", delta = 2, text = "The new farm feeds twelve families." },
		{ ago = 420, category = "honor", delta = -5, text = "You broke your promise to the miners." },
		{ ago = 40, category = "compassion", delta = 4, text = "You gave grain to the hungry farmers." },
	},
}

local function find(root, name)
	if root == nil then
		return nil
	end
	if root.Name == name then
		return root
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
	for _, d in root:GetDescendants() do
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
	local world = KingdomWorld.new({
		kingdom = o.kingdom,
		noPlayerGui = o.noPlayerGui,
		remotes = Rep.REMOTES,
		services = { Rep.service(o.reputation or START) },
		clientDefinitions = { KingdomHudDef, ReputationDef },
	})
	world.hud = world.client:get("KingdomHudController")
	world.rep = world.client:get("ReputationPanelController")
	world.server_rep = world.server:get("ReputationService")
	if not o.noPlayerGui then
		world.hud:setViewport(o.width or 1920, o.height or 1022)
	end
	world:advance(0.2)
	return world
end

local function strip(world)
	return world.rep.strip.instance
end

local function item(world, id)
	return find(strip(world), "Rep_" .. id)
end

local function value(world, id)
	return find(item(world, id), "Value").Text
end

local function bar(world, id)
	return find(item(world, id), "Bar"):GetAttribute("progress")
end

local function panel(world)
	return find(world.hud.guis.menus, "ReputationPanel")
end

describe("Reputation strip (desktop)", function()
	local world, previous
	beforeEach(function()
		previous = Create.useTestConnector()
		world = newWorld()
	end)
	afterEach(function()
		world:destroy()
		Create.setConnector(previous)
	end)

	it("shows the six values from the server, each with its name and number (never colour alone)", function()
		local s = strip(world)
		expect(s.Visible).toBe(true)
		expect(s.Parent).toBe(world.hud.roots.hud)
		for id, v in START.values do
			expect(value(world, id)).toBe(tostring(v))
			expect(bar(world, id)).toBeNear(v / 100, 1e-6)
			expect(item(world, id):GetAttribute("value")).toBe(v)
			expect(find(item(world, id), "Icon")).toBeTruthy()
			expect(find(item(world, id), "RepName")).toBeTruthy()
		end
		local all = texts(s)
		for _, name in { "Compassion", "Honor", "Competence", "Courage", "Authority", "Fear" } do
			expect(all).toContain(name)
		end
		expect(s:GetAttribute("OnboardingTarget")).toBe("HUD.Reputation")
	end)

	it("sits where Layout puts it and the drawer opens below it", function()
		local m = world.hud:metrics()
		local r = m.hud.reputation
		local s = strip(world)
		expect(s.Position.X.Offset).toBe(r.x)
		expect(s.Position.Y.Offset).toBe(r.y)
		expect(s.Size.X.Offset).toBe(r.width)
		expect(s.Size.Y.Offset).toBe(r.height)
		tap(find(s, "Open"))
		local p = panel(world)
		expect(p).toBeTruthy()
		expect(p.Position.Y.Offset).toBe(m.drawer.y)
		expect(m.drawer.y).toBeGreaterThan(r.y + r.height)
		expect(p.Position.X.Offset + p.Size.X.Offset).toBeLessThan(m.width - m.rail.right - m.rail.button)
	end)

	it("a tap on the strip opens the reputation screen; a second tap closes it", function()
		local hit = find(strip(world), "Open")
		expect(hit:IsA("TextButton")).toBe(true)
		expect(hit.Size.Y.Offset).toBeGreaterThan(43)
		tap(hit)
		expect(world.hud.state.menu).toBe("reputation")
		expect(panel(world)).toBeTruthy()
		expect(find(panel(world), "Category_compassion"):GetAttribute("selected")).toBe(true)
		tap(hit)
		expect(world.hud.state.menu).toBeNil()
		expect(panel(world)).toBeNil()
		-- opening another menu closes this one
		world.rep:open()
		world.hud:setMenu("build")
		expect(panel(world)).toBeNil()
	end)

	it("a pushed change moves the bar, floats the change and puts a history line on top", function()
		world.server_rep:apply("compassion", 4, "You fed the farmers from the royal stores.")
		world:advance(0.1)
		expect(value(world, "compassion")).toBe("66")
		expect(bar(world, "compassion")).toBeNear(0.66, 1e-6)
		local float = find(item(world, "compassion"), "Delta")
		expect(float).toBeTruthy()
		expect(texts(float)).toBe("+4")
		expect(find(item(world, "honor"), "Delta")).toBeNil() -- unchanged values do not float
		world:advance(2) -- the float goes away (PULSE_SEC)
		expect(find(item(world, "compassion"), "Delta")).toBeNil()
		world.rep:open()
		world.rep:selectTab("history")
		local list = find(panel(world), "History")
		local first = find(list, "History_1")
		expect(find(first, "Text").Text).toBe("You fed the farmers from the royal stores.")
		expect(texts(find(first, "Delta"))).toBe("+4")
		expect(texts(first)).toContain("Compassion")
		expect(find(first, "Ago").Text).toContain("just now")
		-- the older lines follow, newest first
		expect(find(find(list, "History_2"), "Text").Text).toBe("You gave grain to the hungry farmers.")
		expect(find(find(list, "History_3"), "Text").Text).toBe("You broke your promise to the miners.")
		expect(texts(find(find(list, "History_3"), "Delta"))).toBe("−5")
		expect(find(find(list, "History_4"), "Text").Text).toBe("The new farm feeds twelve families.")
	end)

	it("a push while the screen is open updates it in place", function()
		world.rep:open()
		world.rep:select("fear")
		local detail = find(panel(world), "CategoryDetail")
		expect(find(detail, "Value").Text).toBe("15")
		world.server_rep:apply("fear", 6, "You burned the rebels' farms.")
		world:advance(0.1)
		detail = find(panel(world), "CategoryDetail")
		expect(find(detail, "Value").Text).toBe("21")
		expect(texts(find(detail, "Recent"))).toContain("You burned the rebels' farms.")
		expect(find(panel(world), "Category_fear"):GetAttribute("value")).toBe(21)
	end)

	it("treasury and other kingdoms' pushes leave the open screen and the strip alone (M1)", function()
		world.rep:open()
		world.rep:select("fear")
		local open, row, hit = panel(world), find(panel(world), "Category_honor"), find(strip(world), "Open")
		world.treasury:deposit("crimson", "food", 5, "rep:food", "test")
		local id = world.build:add("azure", "house", 1, "planned", Vector3.new(900, 0, 900))
		world.build:push(id)
		world:advance(0.2)
		expect(panel(world)).toBe(open)
		expect(find(open, "Category_honor")).toBe(row)
		expect(find(strip(world), "Open")).toBe(hit)
	end)

	it("relative times in the open history move on with the server clock", function()
		world.rep:open()
		world.rep:selectTab("history")
		local ago = find(find(panel(world), "History_1"), "Ago")
		expect(ago.Text).toBe(" · 40 s ago")
		world:advance(120)
		expect(ago.Text).toBe(" · 2 min ago")
	end)

	it("shows the kingdom conditions with bars, numbers and band words", function()
		world.rep:open()
		tap(find(panel(world), "Tab_kingdom"))
		expect(world.rep.state.tab).toBe("kingdom")
		local p = panel(world)
		local happiness = find(p, "Condition_happiness")
		expect(find(happiness, "Value").Text).toBe("68")
		expect(find(happiness, "Band").Text).toBe("High")
		expect(find(happiness, "Bar"):GetAttribute("progress")).toBeNear(0.68, 1e-6)
		expect(find(find(p, "Condition_stability"), "Value").Text).toBe("54")
		expect(texts(find(p, "Condition_morale"))).toContain("Army morale")
		world.server_rep:setCondition("stability", 18)
		world:advance(0.1)
		local stability = find(panel(world), "Condition_stability")
		expect(find(stability, "Value").Text).toBe("18")
		expect(find(stability, "Band").Text).toBe("Low")
		expect(texts(panel(world))).toContain("separate from your reputation")
	end)

	it("shows the content library's prose by default, and invents none without a provider", function()
		local Content = require("@game/ReplicatedStorage/Game/Content/Reputation")
		world.rep:open()
		local withContent = find(panel(world), "CategoryDetail")
		expect(texts(find(withContent, "About"))).toContain(Content.categories.compassion.description)
		world.rep:setCategoryText(nil) -- re-renders the open screen
		local detail = find(panel(world), "CategoryDetail")
		expect(find(detail, "About")).toBeNil()
		expect(find(detail, "Affects")).toBeNil()
		expect(texts(detail)).never.toContain("What affects it")
		-- names, value, band and the category's own history are still there
		expect(texts(detail)).toContain("Compassion")
		expect(find(detail, "Value").Text).toBe("62")
		expect(texts(find(detail, "Recent"))).toContain("You gave grain to the hungry farmers.")
	end)

	it("shows the content library's description and 'what affects it' when a provider is set", function()
		world.rep:setCategoryText(Rep.provider)
		world.rep:open()
		world.rep:select("honor")
		local detail = find(panel(world), "CategoryDetail")
		expect(texts(find(detail, "About"))).toContain(Rep.SAMPLE_TEXT.honor.description)
		expect(texts(find(detail, "Affects"))).toContain("What affects it")
		expect(texts(find(detail, "Affects"))).toContain(Rep.SAMPLE_TEXT.honor.affects)
	end)

	it("ignores a malformed push and keeps what the server said before", function()
		world.remotes:fire("Kingdom.Reputation", world.player, "garbage")
		world:advance(0.1)
		expect(value(world, "authority")).toBe("70")
		expect(strip(world).Visible).toBe(true)
	end)
end)

describe("Reputation UI edge cases", function()
	local previous
	beforeEach(function()
		previous = Create.useTestConnector()
	end)
	afterEach(function()
		Create.setConnector(previous)
	end)

	it("hides the strip without a kingdom and fills it after a late join", function()
		local world = newWorld({ kingdom = false })
		expect(world.hud.guis.hud.Enabled).toBe(false)
		expect(strip(world).Visible).toBe(false)
		expect(world.rep.data.known).toBe(false) -- GetReputation answered nil
		world.kingdoms:join(world.player, "azure", nil, true)
		world:advance(0.2)
		expect(world.hud.guis.hud.Enabled).toBe(true)
		expect(strip(world).Visible).toBe(true)
		expect(value(world, "fear")).toBe("15")
		world:destroy()
	end)

	it("does not yield in start(): the strip appears once the PlayerGui does", function()
		local world = newWorld({ noPlayerGui = true })
		expect(world.rep.strip).toBeNil()
		local playerGui = world.env.newInstance("PlayerGui")
		playerGui.Parent = world.player
		world:advance(0.3)
		expect(strip(world)).toBeTruthy()
		expect(value(world, "honor")).toBe("48")
		world:destroy()
	end)

	it("empty history says so in words", function()
		local world = newWorld({ reputation = { values = START.values, kingdom = START.kingdom, history = {} } })
		world.rep:open()
		world.rep:selectTab("history")
		local empty = find(panel(world), "Empty")
		expect(empty).toBeTruthy()
		expect(empty.Text).toContain("Nothing has changed yet")
		world:destroy()
	end)

	it("phone: one row of icons and numbers, 44 px targets, grid → detail → back", function()
		local world = newWorld({ width = 750, height = 311 })
		local m = world.hud:metrics()
		expect(m.breakpoint).toBe("phone")
		local s = strip(world)
		expect(s.Position.Y.Offset).toBe(m.hud.reputation.y)
		expect(s.Position.X.Offset + s.Size.X.Offset).toBeLessThan(m.drawer.x) -- side by side with the drawer
		expect(find(item(world, "compassion"), "RepName")).toBeNil() -- compact: icon + number
		expect(value(world, "compassion")).toBe("62")
		expect(find(s, "Open").Size.Y.Offset).toBeGreaterThan(43)
		tap(find(s, "Open"))
		local p = panel(world)
		expect(p.Position.X.Offset).toBe(m.drawer.x)
		expect(find(p, "Close").Size.Y.Offset).toBeGreaterThan(43)
		for _, id in { "values", "history", "kingdom" } do
			local tab = find(p, "Tab_" .. id)
			expect(find(tab, "Hit").Size.Y.Offset).toBeGreaterThan(43)
		end
		local cell = find(p, "Category_courage")
		expect(cell.Size.Y.Offset).toBeGreaterThan(43)
		expect(find(p, "CategoryDetail")).toBeNil()
		tap(cell)
		local detail = find(panel(world), "CategoryDetail")
		expect(detail).toBeTruthy()
		expect(find(detail, "Value").Text).toBe("40")
		local back = find(detail, "Back")
		expect(find(back, "Hit").Size.Y.Offset).toBeGreaterThan(43)
		tap(back)
		expect(find(panel(world), "CategoryDetail")).toBeNil()
		expect(find(panel(world), "Category_courage")).toBeTruthy()
		-- a phone tab through its 44 px hit area
		tap(find(find(panel(world), "Tab_history"), "Hit"))
		expect(world.rep.state.tab).toBe("history")
		world:destroy()
	end)

	it("tablet: the strip is 3 × 2 under the rulers and every drawer starts below it", function()
		local world = newWorld({ width = 1024, height = 690 })
		local m = world.hud:metrics()
		expect(m.breakpoint).toBe("tablet")
		local r = m.hud.reputation
		expect(r.columns).toBe(3)
		expect(item(world, "courage").Position.Y.Offset).toBeGreaterThan(item(world, "compassion").Position.Y.Offset)
		-- the Kingdom panel (FL-0059) uses the same drawer zone
		world.hud:setMenu("kingdom")
		local kp = find(world.hud.guis.menus, "KingdomPanel")
		expect(kp.Position.Y.Offset).toBe(m.drawer.y)
		expect(kp.Position.Y.Offset).toBeGreaterThan(r.y + r.height)
		-- the strip is outside the drawer's box
		local s = strip(world)
		local right, bottom = s.Position.X.Offset + s.Size.X.Offset, s.Position.Y.Offset + s.Size.Y.Offset
		expect(right <= m.drawer.x or bottom <= m.drawer.y).toBe(true)
		world:destroy()
		expect(Layout.compute(1024, 690).drawer.y).toBe(m.drawer.y)
	end)
end)

describe("Follow-ups from the #44 review (FORGE-05)", function()
	local previous
	beforeEach(function()
		previous = Create.useTestConnector()
	end)
	afterEach(function()
		Create.setConnector(previous)
	end)

	it("R44-1: an identical push leaves the open screen alone; a real change keeps the scroll", function()
		local world = newWorld()
		world.rep:open()
		world.rep:selectTab("history")
		local open = panel(world)
		local list = find(open, "History")
		list.CanvasPosition = Vector2.new(0, 60)
		world.server_rep:push(world.player) -- the same payload again
		world:advance(0.1)
		expect(panel(world)).toBe(open)
		world.server_rep:apply("honor", 2, "You kept your word to the miners.")
		world:advance(0.1)
		expect(find(panel(world), "History").CanvasPosition).toBe(Vector2.new(0, 60))
		world:destroy()
	end)

	it("R44-2: the History tab shows the latest 30 changes at most", function()
		local world = newWorld()
		-- A server that sends more than the contract's 30 (the double already trims, so feed the
		-- client directly): the History tab still draws 30, newest first.
		local now = world.env.serverTimeNow()
		local history = {}
		for i = 1, 40 do
			table.insert(history, { t = now - 40 + i, category = "competence", delta = 1, text = `Repaired road {i}.` })
		end
		world.rep:apply({ values = { competence = 70 }, history = history, kingdom = {} }, true)
		world:advance(0.1)
		world.rep:open()
		world.rep:selectTab("history")
		local rows = 0
		for _, d in find(panel(world), "History"):GetChildren() do
			if string.match(d.Name, "^History_%d+$") then
				rows += 1
			end
		end
		expect(rows).toBe(30)
		expect(find(find(panel(world), "History_1"), "Text").Text).toBe("Repaired road 40.")
		world:destroy()
	end)

	it("R44-5: after destroy, a push builds no strip again", function()
		local world = newWorld()
		world.rep:destroy()
		local calls = 0
		world.rep.apply = function() -- the push listener calls self:apply: it must not be listening
			calls += 1
		end
		world.server_rep:apply("fear", 3, "You hanged a thief.")
		world:advance(0.1)
		expect(calls).toBe(0)
		expect(find(world.hud.guis.hud, "ReputationStrip")).toBeNil()
		world:destroy()
	end)

	it("reserves the strip's room only while it shows: no empty gap before the server sends any", function()
		local world = KingdomWorld.new({ clientDefinitions = { KingdomHudDef, ReputationDef } })
		local hud = world.client:get("KingdomHudController")
		hud:setViewport(1024, 690)
		world:advance(0.2)
		expect(hud:metrics().drawer.y).toBe(Layout.compute(1024, 690, { reputation = false }).drawer.y)
		expect(hud:metrics().drawer.y).toBeLessThan(Layout.compute(1024, 690).drawer.y)
		world:destroy()
		-- with reputation, the drawer starts below the strip
		local shown = newWorld({ width = 1024, height = 690 })
		expect(shown.hud:metrics().drawer.y).toBe(Layout.compute(1024, 690).drawer.y)
		shown:destroy()
	end)
end)
