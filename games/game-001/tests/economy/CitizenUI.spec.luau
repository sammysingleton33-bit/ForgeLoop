-- FL-0088 end to end, headless: the real KingdomHudController, CitizenCardController and
-- ConversationController talk through the framework RemoteService to FORGE-01 doubles of Sim.Inspect,
-- Kingdom.Converse and Kingdom.Choose (doubles/CitizenDoubles) on the spec world (doubles/KingdomWorld,
-- real TreasuryService). Selection comes from a double of FORGE-04's InputModeController.selected
-- (G13.6); taps fire the Activated handlers of the buttons a player would press (connector below).
local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect, beforeEach, afterEach = T.describe, T.it, T.expect, T.beforeEach, T.afterEach

local CitizenCardDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/CitizenCardController")
local CitizenDoubles = require("./doubles/CitizenDoubles")
local CitizenModel = require("@game/StarterPlayer/StarterPlayerScripts/Game/UI/CitizenModel")
local CitizenText = require("@game/StarterPlayer/StarterPlayerScripts/Game/UI/CitizenText")
local ConversationDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/ConversationController")
local Costs = require("@game/ReplicatedStorage/Forge/Config/Costs")
local Create = require("@game/ReplicatedStorage/Forge/UI/Create")
local KingdomHudDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/KingdomHudController")
local KingdomWorld = require("./doubles/KingdomWorld")
local Layout = require("@game/StarterPlayer/StarterPlayerScripts/Game/UI/Layout")
local Signal = require("@game/ReplicatedStorage/Forge/Core/Signal")

local SCENARIOS = CitizenDoubles.SCENARIOS

-- Taps fire the handlers registered through the kit's test connector (strong keys since #25, so a
-- garbage collection between render and tap no longer drops them).
local function useStrongConnector()
	return Create.useTestConnector()
end

local function fire(instance, eventName, ...)
	return Create.fire(instance, eventName, ...)
end

local function restoreConnector(previous)
	Create.setConnector(previous)
end

-- An RBXScriptSignal look-alike (:Connect / :Disconnect only), for FORGE-04 controllers that expose one.
local function rbxSignal()
	local handlers = {}
	return {
		Connect = function(_, fn)
			table.insert(handlers, fn)
			return {
				Disconnect = function()
					local i = table.find(handlers, fn)
					if i then
						table.remove(handlers, i)
					end
				end,
			}
		end,
		Fire = function(_, ...)
			for _, fn in table.clone(handlers) do
				fn(...)
			end
		end,
	}
end

-- FORGE-04 double: G4.1 InputModeController with the G13.6 selection signal.
local function inputModeDef(rbx)
	return {
		name = "InputModeController",
		new = function()
			return {
				mode = "explore",
				changed = Signal.new(),
				selected = if rbx then rbxSignal() else Signal.new(),
				set = function() end,
			}
		end,
	}
end

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

local function findAll(root, pattern)
	local out = {}
	for _, d in root:GetDescendants() do
		if string.match(d.Name, pattern) then
			table.insert(out, d)
		end
	end
	table.sort(out, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	return out
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
	expect(fire(face, "Activated")).toBeGreaterThan(0)
end

local function newWorld(opts)
	local o = opts or {}
	-- inspectOnly: today's main (Sim.Inspect, no Kingdom.Converse / Kingdom.Choose on the server)
	o.remotes = if o.inspectOnly then CitizenDoubles.INSPECT_ONLY else CitizenDoubles.REMOTES
	o.services = { if o.inspectOnly then CitizenDoubles.inspectOnly else CitizenDoubles.service }
	o.clientDefinitions = { KingdomHudDef, CitizenCardDef, ConversationDef, inputModeDef(o.rbxSignal) }
	if o.places then
		-- FORGE-04's NotificationController (#33) as a recording double: show and place
		table.insert(o.clientDefinitions, {
			name = "NotificationController",
			new = function()
				return {
					show = function() end,
					place = function(_, position, anchor, width)
						table.insert(o.places, { position = position, anchor = anchor, width = width })
					end,
				}
			end,
		})
	end
	if o.onboarding then
		-- FORGE-04's OnboardingController (#45) as a recording double: report(action)
		table.insert(o.clientDefinitions, {
			name = "OnboardingController",
			new = function()
				return {
					report = function(_, action)
						table.insert(o.onboarding, action)
					end,
				}
			end,
		})
	end
	local world = KingdomWorld.new(o)
	world.hud = world.client:get("KingdomHudController")
	world.card = world.client:get("CitizenCardController")
	world.conversation = world.client:get("ConversationController")
	world.input = world.client:get("InputModeController")
	world.citizens = world.server:get("CitizenService")
	world.hud:setViewport(o.width or 1920, o.height or 1022)
	world:advance(0.1)
	return world
end

local function pickSelection(world, kind, id)
	local signal = world.input.selected
	if signal.fire then
		signal:fire(kind, id)
	else
		signal:Fire(kind, id)
	end
	world:advance(0.1)
end

local function cardPanel(world)
	return find(world.hud.guis.menus, "CitizenCard")
end

local function convoPanel(world)
	return find(world.hud.guis.menus, "Conversation")
end

-- Opens the conversation of `entityId` through the card's Talk button, as a player would.
local function talkTo(world, entityId)
	pickSelection(world, "citizen", entityId)
	tap(find(cardPanel(world), "Talk"))
	world:advance(0.1 + world.citizens.latency)
	return convoPanel(world)
end

local function options(panel)
	return findAll(panel, "^Option_")
end

-- Answers as a player does: a tap on the answer and, for an answer with a cost or a risk, Choose in
-- the confirm step once its short guard has passed (FORGE-05 B1 on #66).
local function answer(world, id)
	tap(find(convoPanel(world), "Option_" .. id))
	local panel = convoPanel(world)
	if panel and panel:GetAttribute("phase") == "confirming" then
		world:advance(world.conversation.CONFIRM_DELAY + 0.05)
		tap(find(convoPanel(world), "Confirm"))
	end
end

local function amountOf(hud, id)
	return find(hud.view.pills[id].instance, "Amount").Text
end

describe("Citizen card v2 (G13.2)", function()
	local world, previous
	beforeEach(function()
		previous = useStrongConnector()
		world = newWorld()
	end)
	afterEach(function()
		world:destroy()
		restoreConnector(previous)
	end)

	it("selecting a citizen inspects it and opens the card with every CitizenView field", function()
		pickSelection(world, "citizen", 41)
		local inspects = world.citizens:callsNamed("Inspect")
		expect(#inspects).toBe(1)
		expect(inspects[1].args[1]).toBe(41)
		expect(world.hud.state.menu).toBe("citizen")
		local card = cardPanel(world)
		expect(card).toBeTruthy()
		expect(card:GetAttribute("entityId")).toBe(41)
		expect(find(card, "CitizenName").Text).toBe("Edda Thornbury")
		expect(find(card, "CitizenSub").Text).toBe("Farmer")
		expect(find(find(card, "Stat_loyalty"), "Value").Text).toBe("72")
		expect(find(find(card, "Stat_loyalty"), "Bar"):GetAttribute("progress")).toBeNear(0.72, 1e-6)
		expect(find(find(card, "Stat_mood"), "Value").Text).toBe("64")
		expect(find(find(card, "Stat_mood"), "Band").Text).toBe("Content")
		expect(find(find(card, "Stat_obedience"), "Value").Text).toBe("48")
		expect(find(card, "IntentText").Text).toBe("Carrying wheat to the storehouse")
		local traits = findAll(find(card, "Traits"), "^Trait_")
		expect(#traits).toBe(3)
		expect(texts(find(card, "Traits"))).toBe("Hard-working | Generous | Stubborn")
		expect(find(find(card, "Relation_family"), "Names").Text).toBe("Bran Thornbury, Lise Thornbury")
		expect(find(find(card, "Relation_friends"), "Names").Text).toBe("Osric Vale, Mara Quill")
		expect(find(find(card, "Relation_rivals"), "Key").Text).toBe("Rival")
		expect(find(find(card, "Relation_rivals"), "Names").Text).toBe("Tomas Reed")
		expect(find(find(card, "LastMemory"), "MemoryText").Text).toBe("You visited the farms at dawn")
		local memories = texts(find(card, "Memories"))
		expect(memories).toContain("The harvest came in early")
		expect(memories).toContain("Soldiers marched through the east field")
		-- Something to say: the avatar's "!" and a primary Talk button.
		expect(find(card, "Request")).toBeTruthy()
		local talk = find(card, "Talk")
		expect(find(talk, "Face"):GetAttribute("talk")).toBe("request")
		expect(texts(talk)).toContain("Talk")
	end)

	it("a citizen without a request offers Ask (no badge)", function()
		pickSelection(world, "citizen", 44)
		local card = cardPanel(world)
		expect(find(card, "CitizenName").Text).toBe("Osric Vale")
		expect(find(card, "Request")).toBeNil()
		local talk = find(card, "Talk")
		expect(find(talk, "Face"):GetAttribute("talk")).toBe("ask")
		expect(texts(talk)).toContain("Ask")
		expect(find(card, "Relation_rivals")).toBeNil() -- no rival: no empty row
	end)

	it("selection 'none' (or a building) closes the card", function()
		pickSelection(world, "citizen", 41)
		expect(world.hud.state.menu).toBe("citizen")
		pickSelection(world, "none", 0)
		expect(world.hud.state.menu).toBeNil()
		expect(cardPanel(world)).toBeNil()
		pickSelection(world, "citizen", 42)
		expect(world.hud.state.menu).toBe("citizen")
		pickSelection(world, "building", 3)
		expect(world.hud.state.menu).toBeNil()
		-- the X closes it as well
		pickSelection(world, "citizen", 42)
		tap(find(cardPanel(world), "Close"))
		expect(world.hud.state.menu).toBeNil()
	end)

	it("someone else's citizen: a notice and no card", function()
		pickSelection(world, "citizen", 51)
		expect(world.hud.state.menu).toBeNil()
		expect(texts(world.hud.guis.notices)).toContain(CitizenText.CANT_INSPECT)
	end)

	it("a slow reply for an earlier tap never replaces the card of the citizen tapped last", function()
		world.citizens.inspectDelay[41] = 0.3
		world.input.selected:fire("citizen", 41)
		world:advance(0.05)
		pickSelection(world, "citizen", 44)
		expect(find(cardPanel(world), "CitizenName").Text).toBe("Osric Vale")
		world:advance(0.5)
		expect(find(cardPanel(world), "CitizenName").Text).toBe("Osric Vale")
		expect(#world.citizens:callsNamed("Inspect")).toBe(2)
	end)

	it("refreshes while open (loyalty, requests) and closes when the citizen is gone", function()
		pickSelection(world, "citizen", 44)
		world.citizens.citizens[44].loyalty = 91
		world.citizens:setScenario(44, SCENARIOS.two)
		world:advance(world.card.REFRESH_SEC + 0.1)
		local card = cardPanel(world)
		expect(find(find(card, "Stat_loyalty"), "Value").Text).toBe("91")
		expect(find(find(card, "Talk"), "Face"):GetAttribute("talk")).toBe("request")
		world.citizens.citizens[44] = nil
		world:advance(world.card.REFRESH_SEC + 0.1)
		expect(world.hud.state.menu).toBeNil()
	end)

	it("opening another menu replaces the card", function()
		pickSelection(world, "citizen", 41)
		world.hud:setMenu("kingdom")
		expect(cardPanel(world)).toBeNil()
		expect(find(world.hud.guis.menus, "KingdomPanel")).toBeTruthy()
	end)
end)

describe("Citizen card selection signal shapes", function()
	local previous
	beforeEach(function()
		previous = useStrongConnector()
	end)
	afterEach(function()
		restoreConnector(previous)
	end)

	it("works with an RBXScriptSignal-style selected (:Connect)", function()
		local world = newWorld({ rbxSignal = true })
		pickSelection(world, "citizen", 41)
		expect(world.hud.state.menu).toBe("citizen")
		pickSelection(world, "none", 0)
		expect(world.hud.state.menu).toBeNil()
		world:destroy()
	end)

	it("phone: the card fills the drawer and Talk is a 44 px button", function()
		local world = newWorld({ width = 750, height = 311 })
		pickSelection(world, "citizen", 41)
		local m = world.hud:metrics()
		expect(m.breakpoint).toBe("phone")
		local card = cardPanel(world)
		expect(card.Size).toBe(UDim2.fromOffset(m.drawer.width, m.drawer.height))
		expect(find(card, "Talk").Size.Y.Offset).toBe(44)
		expect(find(card, "Body"):IsA("ScrollingFrame")).toBe(true)
		world:destroy()
	end)
end)

describe("Conversation panel (G13.3)", function()
	local world, previous
	beforeEach(function()
		previous = useStrongConnector()
		world = newWorld()
	end)
	afterEach(function()
		world:destroy()
		restoreConnector(previous)
	end)

	it("Talk asks Kingdom.Converse and shows the server's question and its 3 answers in order", function()
		local panel = talkTo(world, 41)
		local converse = world.citizens:callsNamed("Converse")
		expect(#converse).toBe(1)
		expect(converse[1].args[1]).toBe(41)
		expect(world.hud.state.menu).toBe("conversation")
		expect(cardPanel(world)).toBeNil()
		expect(panel:GetAttribute("scenarioId")).toBe("flooded_field")
		expect(find(panel, "CitizenName").Text).toBe("Edda Thornbury")
		expect(find(panel, "CitizenSub").Text).toBe("Farmer")
		expect(find(panel, "Question").Text).toBe(SCENARIOS.three.question)
		local buttons = options(panel)
		expect(#buttons).toBe(3)
		for i, button in buttons do
			local response = SCENARIOS.three.responses[i]
			expect(button.Name).toBe("Option_" .. response.id)
			expect(find(button, "Label").Text).toBe(response.text)
			expect(button.Size.Y.Offset).toBeGreaterThanOrEqual(44)
			expect(button.Size.X.Scale).toBe(1) -- full width on desktop
		end
	end)

	it("renders exactly the 2 or 4 answers the server sent", function()
		expect(#options(talkTo(world, 42))).toBe(2)
		world.conversation:close()
		local four = talkTo(world, 43)
		local buttons = options(four)
		expect(#buttons).toBe(4)
		for i, button in buttons do
			expect(find(button, "Label").Text).toBe(SCENARIOS.four.responses[i].text)
		end
	end)

	it("long text wraps and grows instead of overflowing", function()
		local panel = talkTo(world, 45)
		local question = find(panel, "Question")
		expect(question.Text).toBe(SCENARIOS.long.question)
		expect(question.TextWrapped).toBe(true)
		expect(question.AutomaticSize).toBe(Enum.AutomaticSize.Y)
		for _, button in options(panel) do
			local label = find(button, "Label")
			expect(label.TextWrapped).toBe(true)
			expect(label.AutomaticSize).toBe(Enum.AutomaticSize.Y)
			expect(button.AutomaticSize).toBe(Enum.AutomaticSize.Y) -- the button grows with its label
		end
		expect(find(panel, "Body"):IsA("ScrollingFrame")).toBe(true)
		expect(find(panel, "Body").AutomaticCanvasSize).toBe(Enum.AutomaticSize.Y)
		-- The fitted panel is taller than the one for a short question, within the drawer.
		local longHeight = panel.Size.Y.Offset
		world.conversation:close()
		local short = talkTo(world, 42)
		expect(longHeight).toBeGreaterThan(short.Size.Y.Offset)
		expect(longHeight).toBeLessThanOrEqual(world.hud:metrics().drawer.height)
	end)

	it("phone: a wide sheet below the pills, answers two per row, each at least 44 px", function()
		world:destroy()
		world = newWorld({ width = 750, height = 311 })
		local m = world.hud:metrics()
		local panel = talkTo(world, 43)
		expect(panel.Position.X.Offset).toBe(m.margin)
		expect(panel.Position.Y.Offset).toBeGreaterThan(m.hud.pills.y + 34) -- below the pills
		expect(panel.Position.Y.Offset + panel.Size.Y.Offset).toBeLessThanOrEqual(m.height - m.margin)
		expect(panel.Size.X.Offset).toBeGreaterThan(m.drawer.width) -- wider than the phone drawer
		local rows = findAll(panel, "^Row_")
		expect(#rows).toBe(2)
		for _, button in options(panel) do
			expect(button.Size.X.Scale).toBe(0.5)
			expect(button.Size.Y.Offset).toBeGreaterThanOrEqual(44)
		end
	end)

	it("answer once: a double tap and a second answer send exactly one Kingdom.Choose", function()
		world.citizens.latency = 0.3
		local panel = talkTo(world, 41)
		local help = find(panel, "Option_help")
		local bread = find(panel, "Option_bread")
		tap(help) -- 20 Wood: the confirm step first (FORGE-05 B1)
		fire(help, "Activated") -- the second tap of a double tap (the old, replaced, button)
		fire(bread, "Activated")
		world.conversation:choose("work")
		local confirming = convoPanel(world)
		expect(confirming:GetAttribute("phase")).toBe("confirming")
		expect(#options(confirming)).toBe(1) -- only the picked answer, whole
		-- the double tap that opened the step does not confirm it
		tap(find(confirming, "Confirm"))
		world.conversation:confirm()
		expect(convoPanel(world):GetAttribute("phase")).toBe("confirming")
		world:advance(world.conversation.CONFIRM_DELAY + 0.05)
		local confirm = find(convoPanel(world), "Confirm")
		local face = find(confirm, "Face")
		tap(confirm)
		fire(face, "Activated") -- a double tap on Choose (that button is gone by now)
		world.conversation:confirm()
		world.conversation:choose("bread")
		-- While waiting: the pick is marked and every answer is disabled.
		local waiting = convoPanel(world)
		expect(waiting:GetAttribute("phase")).toBe("choosing")
		for _, button in options(waiting) do
			expect(button.Active).toBe(false)
			expect(button:GetAttribute("state")).toBe(if button.Name == "Option_help" then "picked" else "off")
		end
		world:advance(0.5)
		local chooses = world.citizens:callsNamed("Choose")
		expect(#chooses).toBe(1)
		expect(chooses[1].args).toEqual({ 41, "flooded_field", "help" })
		expect(convoPanel(world):GetAttribute("phase")).toBe("answered")
	end)

	it("shows the server's reaction and its effect chips, then Done closes", function()
		talkTo(world, 41)
		answer(world, "help")
		world:advance(0.2)
		local done = convoPanel(world)
		local response = SCENARIOS.three.responses[1]
		expect(find(done, "Reaction").Text).toBe(response.reaction)
		expect(find(find(done, "Echo"), "Answer").Text).toBe(response.text)
		local chips = findAll(find(done, "Effects"), "^Effect_")
		expect(#chips).toBe(#response.effects)
		for i, chip in chips do
			expect(find(chip, "Label").Text).toBe(response.effects[i].text)
			expect(chip:GetAttribute("kind")).toBe(response.effects[i].kind)
		end
		expect(chips[1]:GetAttribute("tone")).toBe("down") -- "−20 Wood"
		expect(chips[2]:GetAttribute("tone")).toBe("up") -- "+8 Loyalty: ..."
		expect(chips[4]:GetAttribute("tone")).toBe("neutral") -- "Farmers work faster for 60 s"
		expect(find(chips[5], "Icon").Text).toBe("ℹ") -- unknown kind "rumour": the neutral chip
		-- The spend arrives through Treasury.Changed: the Wood pill shows it.
		expect(amountOf(world.hud, "wood")).toBe(tostring(Costs.starting.wood - 20))
		tap(find(done, "Done"))
		expect(world.hud.state.menu).toBeNil()
		expect(world.conversation.state).toBeNil()
	end)

	it("nothing to say (nil from Kingdom.Converse): a notice, the card stays", function()
		pickSelection(world, "citizen", 44)
		tap(find(cardPanel(world), "Talk"))
		world:advance(0.1)
		expect(#world.citizens:callsNamed("Converse")).toBe(1)
		expect(world.hud.state.menu).toBe("citizen")
		expect(convoPanel(world)).toBeNil()
		local notices = texts(world.hud.guis.notices)
		expect(notices).toContain(CitizenText.NOTHING)
		expect(notices).toContain("Osric Vale")
	end)

	it("a refusal shows the reason as a sentence and Close; unknown codes get the generic one", function()
		world.citizens.refuse = "not_eligible"
		talkTo(world, 41)
		answer(world, "bread")
		world:advance(0.2)
		local refused = convoPanel(world)
		expect(refused:GetAttribute("phase")).toBe("refused")
		expect(find(refused, "Reason").Text).toBe(CitizenText.reason("not_eligible"))
		expect(find(refused, "Reason").Text).never.toContain("not_eligible")
		tap(find(find(refused, "Body").Parent, "Close"))
		expect(world.hud.state.menu).toBeNil()
		world.citizens.refuse = "weird_code"
		talkTo(world, 41)
		answer(world, "bread")
		world:advance(0.2)
		expect(find(convoPanel(world), "Reason").Text).toBe(CitizenText.GENERIC)
	end)

	it("a dropped Kingdom.Choose opens the answers again with an error; the retry goes through", function()
		world.citizens.drop = true
		talkTo(world, 41)
		answer(world, "help")
		world:advance(0.2)
		local again = convoPanel(world)
		expect(again:GetAttribute("phase")).toBe("asking")
		expect(find(again, "Error").Text).toBe(CitizenText.unreachable())
		for _, button in options(again) do
			expect(button.Active).toBe(true)
		end
		answer(world, "help")
		world:advance(0.2)
		expect(#world.citizens:callsNamed("Choose")).toBe(2)
		expect(convoPanel(world):GetAttribute("phase")).toBe("answered")
	end)

	it("selection 'none' closes the conversation; a late reply does not bring it back", function()
		world.citizens.latency = 0.3
		expect(talkTo(world, 41)).toBeTruthy()
		answer(world, "help")
		pickSelection(world, "none", 0)
		expect(world.hud.state.menu).toBeNil()
		expect(world.conversation.state).toBeNil()
		world:advance(0.5)
		expect(convoPanel(world)).toBeNil()
		expect(world.hud.state.menu).toBeNil()
	end)

	it("Talk while the question loads asks once and shows a busy button", function()
		world.citizens.latency = 0.3
		pickSelection(world, "citizen", 41)
		local face = find(find(cardPanel(world), "Talk"), "Face")
		tap(face)
		fire(face, "Activated") -- a double tap on the (now replaced) button
		world.conversation:open(41)
		expect(find(find(cardPanel(world), "Talk"), "Face"):GetAttribute("talk")).toBe("loading")
		world:advance(0.5)
		expect(#world.citizens:callsNamed("Converse")).toBe(1)
		expect(world.hud.state.menu).toBe("conversation")
	end)

	it("another menu replaces the conversation", function()
		talkTo(world, 41)
		world.hud:setMenu("build")
		expect(world.conversation.state).toBeNil()
		expect(convoPanel(world)).toBeNil()
	end)
end)

describe("Citizen card and conversation survive pushes (FORGE-05 M1)", function()
	local previous
	beforeEach(function()
		previous = useStrongConnector()
	end)
	afterEach(function()
		restoreConnector(previous)
	end)

	it("treasury and other kingdoms' pushes keep the Talk button and the answers in place", function()
		local world = newWorld()
		local function pushes(tag)
			world.treasury:deposit("crimson", "food", 5, "m1:" .. tag, "test")
			local id = world.build:add("azure", "house", 1, "planned", Vector3.new(900, 0, 900))
			world.build:push(id)
			world:advance(0.2)
		end
		pickSelection(world, "citizen", 41)
		local card = cardPanel(world)
		local talk = find(card, "Talk")
		pushes("card")
		expect(cardPanel(world)).toBe(card)
		expect(find(card, "Talk")).toBe(talk)
		tap(talk)
		world:advance(0.1 + world.citizens.latency)
		local panel = convoPanel(world)
		local first = options(panel)[1]
		pushes("conversation")
		expect(convoPanel(world)).toBe(panel)
		expect(options(panel)[1]).toBe(first)
		tap(first) -- the kept button still works: it opens the confirm step (it costs 20 Wood)
		expect(convoPanel(world):GetAttribute("phase")).toBe("confirming")
		world:advance(world.conversation.CONFIRM_DELAY + 0.05)
		tap(find(convoPanel(world), "Confirm"))
		world:advance(0.1 + world.citizens.latency)
		expect(#world.citizens:callsNamed("Choose")).toBe(1)
		world:destroy()
	end)
end)

describe("Answer costs and risks before choosing (G13.3, FORGE-05 M1)", function()
	local world, previous
	beforeEach(function()
		previous = useStrongConnector()
		world = newWorld()
	end)
	afterEach(function()
		world:destroy()
		restoreConnector(previous)
	end)

	local function checkRisky(panel)
		local shore, dig = find(panel, "Option_shore"), find(panel, "Option_dig")
		-- What it costs, against the treasury: 20 Wood (have 100), 25 Gold (have 0).
		local wood, gold = find(shore, "Cost_wood"), find(shore, "Cost_gold")
		expect(find(wood, "Amount").Text).toBe("20")
		expect(wood:GetAttribute("short")).toBe(false)
		expect(find(gold, "Amount").Text).toBe("25")
		expect(gold:GetAttribute("short")).toBe(true)
		expect(find(shore, "Need").Text).toBe("Need 25 Gold") -- a word, not colour alone
		expect(shore:GetAttribute("affordable")).toBe(false)
		expect(shore.Active).toBe(false)
		-- Every risk, with its chance, in the server's words, wrapping (never truncated).
		local sent = SCENARIOS.risky.responses[2].risks
		local risks = findAll(dig, "^Risk_")
		expect(#risks).toBe(#sent)
		for i, risk in risks do
			local riskText = find(risk, "RiskText")
			expect(riskText.Text).toBe(sent[i].text)
			expect(riskText.TextWrapped).toBe(true)
			expect(riskText.TextTruncate).toBe(Enum.TextTruncate.None)
			expect(find(risk, "Chance").Text).toBe(`{math.floor(sent[i].chance * 100 + 0.5)} %`)
			expect(risk:GetAttribute("percent")).toBe(math.floor(sent[i].chance * 100 + 0.5))
		end
		expect(find(dig, "Cost")).toBeNil() -- no cost: no row
		expect(find(shore, "Risk_1")).toBeNil() -- no risk: nothing
		expect(dig:GetAttribute("affordable")).toBe(true)
		expect(dig.Active).toBe(true)
	end

	it("desktop: each answer shows its cost and every risk; an answer the treasury can't pay is disabled", function()
		local panel = talkTo(world, 46)
		checkRisky(panel)
		-- The disabled answer sends nothing, by tap or by call.
		fire(find(panel, "Option_shore"), "Activated")
		world.conversation:choose("shore")
		world:advance(0.2)
		expect(#world.citizens:callsNamed("Choose")).toBe(0)
		expect(convoPanel(world):GetAttribute("phase")).toBe("asking")
		-- The risky one goes through.
		answer(world, "dig")
		world:advance(0.2)
		expect(world.citizens:callsNamed("Choose")[1].args).toEqual({ 46, "cracked_face", "dig" })
	end)

	it("phone 750 × 311: the 2-answer question with costs and risks shows whole, without scrolling", function()
		world:destroy()
		world = newWorld({ width = 750, height = 311 })
		local m = world.hud:metrics()
		local panel = talkTo(world, 46)
		checkRisky(panel)
		expect(find(panel, "Kicker").Text).toBe("YOUR ANSWER") -- no scroll cue: it all fits
		expect(panel.Position.Y.Offset + panel.Size.Y.Offset).toBeLessThanOrEqual(m.height - m.margin)
		for _, button in options(panel) do
			expect(button.Size.Y.Offset).toBeGreaterThanOrEqual(44)
		end
		-- the cue stays honest where it does scroll
		world.conversation:close()
		expect(find(talkTo(world, 45), "Kicker").Text).toBe("YOUR ANSWER · SCROLL FOR ALL 3")
	end)

	it("costs in the 3-answer question too (talk-3): 20 Wood and 15 Food, covered", function()
		local panel = talkTo(world, 41)
		expect(find(find(find(panel, "Option_help"), "Cost_wood"), "Amount").Text).toBe("20")
		expect(find(find(find(panel, "Option_bread"), "Cost_food"), "Amount").Text).toBe("15")
		expect(find(find(panel, "Option_help"), "Need")).toBeNil()
		expect(find(find(panel, "Option_work"), "RiskText").Text).toBe(SCENARIOS.three.responses[3].risks[1].text)
		expect(find(find(panel, "Option_work"), "Chance").Text).toBe("20 %")
	end)

	it("a treasury push re-checks costs in place: only an answer whose affordability changed is rebuilt", function()
		local panel = talkTo(world, 46)
		local shore, dig = find(panel, "Option_shore"), find(panel, "Option_dig")
		world.treasury:deposit("crimson", "food", 5, "spec:food", "test")
		world:advance(0.2)
		expect(convoPanel(world)).toBe(panel)
		expect(find(panel, "Option_shore")).toBe(shore) -- nothing changed for it
		world.treasury:deposit("crimson", "gold", 30, "spec:gold", "test")
		world:advance(0.2)
		expect(convoPanel(world)).toBe(panel)
		expect(find(panel, "Option_dig")).toBe(dig) -- untouched
		local now = find(panel, "Option_shore")
		expect(now).toBe(shore) -- repainted inside the same button (FORGE-05 L5 on #66)
		expect(now:GetAttribute("affordable")).toBe(true)
		expect(now.Active).toBe(true)
		expect(find(now, "Need")).toBeNil()
		expect(find(now, "Cost_gold"):GetAttribute("short")).toBe(false)
		answer(world, "shore")
		world:advance(0.2)
		expect(world.citizens:callsNamed("Choose")[1].args).toEqual({ 46, "cracked_face", "shore" })
		expect(amountOf(world.hud, "gold")).toBe(tostring(30 - 25))
	end)
end)

describe("Late replies never take the drawer back (FORGE-05 M2)", function()
	local world, previous
	beforeEach(function()
		previous = useStrongConnector()
		world = newWorld()
	end)
	afterEach(function()
		world:destroy()
		restoreConnector(previous)
	end)

	it("Talk, then close the card: the late Converse reply does not open the conversation", function()
		world.citizens.latency = 0.3
		pickSelection(world, "citizen", 41)
		tap(find(cardPanel(world), "Talk"))
		tap(find(cardPanel(world), "Close"))
		expect(world.hud.state.menu).toBeNil()
		world:advance(0.5)
		expect(world.hud.state.menu).toBeNil()
		expect(convoPanel(world)).toBeNil()
		-- and Talk works again afterwards
		pickSelection(world, "citizen", 41)
		expect(find(find(cardPanel(world), "Talk"), "Face"):GetAttribute("talk")).toBe("request")
		tap(find(cardPanel(world), "Talk"))
		world:advance(0.5)
		expect(world.hud.state.menu).toBe("conversation")
	end)

	it("Talk, then Build: the late Converse reply does not replace the Build drawer", function()
		world.citizens.latency = 0.3
		pickSelection(world, "citizen", 41)
		tap(find(cardPanel(world), "Talk"))
		world.hud:setMenu("build")
		world:advance(0.5)
		expect(world.hud.state.menu).toBe("build")
		expect(convoPanel(world)).toBeNil()
		expect(world.conversation.state).toBeNil()
	end)

	it("tap a citizen, then Build: the late Sim.Inspect reply does not replace the Build drawer", function()
		world.citizens.inspectDelay[41] = 0.3
		world.input.selected:fire("citizen", 41)
		world:advance(0.05)
		world.hud:setMenu("build")
		world:advance(0.5)
		expect(world.hud.state.menu).toBe("build")
		expect(cardPanel(world)).toBeNil()
	end)
end)

describe("Kingdom.Choose in flight is guarded per showing (FORGE-05 M3)", function()
	local world, previous
	beforeEach(function()
		previous = useStrongConnector()
		world = newWorld()
	end)
	afterEach(function()
		world:destroy()
		restoreConnector(previous)
	end)

	it("close and reopen while Choose is in flight: one Choose, and the reply lands on the reopened panel", function()
		world.citizens.chooseLatency = 1
		talkTo(world, 41)
		answer(world, "help")
		world.conversation:close()
		expect(world.hud.state.menu).toBeNil()
		local again = talkTo(world, 41) -- the server still offers the same showing
		expect(again:GetAttribute("scenarioId")).toBe("flooded_field")
		expect(again:GetAttribute("phase")).toBe("choosing")
		expect(find(again, "Option_help"):GetAttribute("state")).toBe("picked")
		fire(find(again, "Option_bread"), "Activated")
		world.conversation:choose("bread")
		world.conversation:choose("help")
		world:advance(1.1)
		expect(#world.citizens:callsNamed("Choose")).toBe(1)
		local done = convoPanel(world)
		expect(done:GetAttribute("phase")).toBe("answered")
		expect(find(done, "Reaction").Text).toBe(SCENARIOS.three.responses[1].reaction)
		expect(amountOf(world.hud, "wood")).toBe(tostring(Costs.starting.wood - 20))
	end)

	it("a reply that lands after the panel closed becomes a notice; nothing is sent again", function()
		world.citizens.chooseLatency = 0.5
		talkTo(world, 41)
		answer(world, "help")
		world.conversation:close()
		world:advance(0.6)
		local notices = texts(world.hud.guis.notices)
		expect(notices).toContain(SCENARIOS.three.responses[1].reaction)
		expect(notices).toContain("Edda Thornbury")
		expect(amountOf(world.hud, "wood")).toBe(tostring(Costs.starting.wood - 20))
		pickSelection(world, "citizen", 41)
		tap(find(cardPanel(world), "Talk"))
		world:advance(0.1)
		expect(#world.citizens:callsNamed("Choose")).toBe(1)
		expect(texts(world.hud.guis.notices)).toContain(CitizenText.NOTHING) -- answered: nothing left to ask
	end)
end)

describe("Onboarding step AnswerCitizen (FORGE-04 #45)", function()
	local previous
	beforeEach(function()
		previous = useStrongConnector()
	end)
	afterEach(function()
		restoreConnector(previous)
	end)

	it("reports CitizenAnswered once per accepted Choose, never for a refusal or a dropped call", function()
		local reported = {}
		local world = newWorld({ onboarding = reported })
		world.citizens.refuse = "not_eligible"
		talkTo(world, 41)
		answer(world, "help")
		world:advance(0.2)
		expect(#reported).toBe(0) -- refused
		world.conversation:close()
		world.citizens.drop = true
		talkTo(world, 41)
		answer(world, "help")
		world:advance(0.2)
		expect(#reported).toBe(0) -- dropped: the answers open again
		answer(world, "help")
		world:advance(0.2)
		expect(convoPanel(world):GetAttribute("phase")).toBe("answered")
		expect(#reported).toBe(1)
		expect(reported[1]).toBe("CitizenAnswered")
		world:destroy()
	end)

	it("a reply that lands after the panel closed still counts", function()
		local reported = {}
		local world = newWorld({ onboarding = reported })
		world.citizens.chooseLatency = 0.5
		talkTo(world, 41)
		answer(world, "help")
		world.conversation:close()
		world:advance(0.6)
		expect(table.concat(reported, ",")).toBe("CitizenAnswered")
		world:destroy()
	end)
end)

describe("Citizen card and conversation lows (FORGE-05 L4-L8)", function()
	local world, previous
	beforeEach(function()
		previous = useStrongConnector()
		world = newWorld()
	end)
	afterEach(function()
		world:destroy()
		restoreConnector(previous)
	end)

	it("L4 phone: toasts sit above the conversation sheet, one at a time, and go back after", function()
		world:destroy()
		world = newWorld({ width = 750, height = 311 })
		local m = world.hud:metrics()
		local panel = talkTo(world, 42)
		world.hud:notify({ title = "First" })
		world.hud:notify({ title = "Second", body = "One line of body" })
		local stack = world.hud.toasts
		expect(stack:count()).toBe(1)
		local band = Layout.sheetToast(m)
		expect(stack.instance.Position).toBe(UDim2.fromOffset(band.right, band.y))
		expect(stack.instance.Size.X.Offset).toBe(band.width)
		expect(band.y + 48).toBeLessThanOrEqual(panel.Position.Y.Offset)
		world.conversation:close()
		expect(stack.instance.Position.Y.Offset).toBe(Layout.toastTop(m, false))
		world.hud:notify({ title = "Third" })
		expect(stack:count()).toBe(2)
	end)

	it("L4 with NotificationController (#33): its stack goes to the same band above the sheet, and back", function()
		world:destroy()
		local places = {}
		world = newWorld({ width = 750, height = 311, places = places })
		local m = world.hud:metrics()
		talkTo(world, 42)
		local band = Layout.sheetToast(m)
		local at = places[#places]
		expect(at.position).toBe(
			UDim2.fromOffset(math.floor(band.right * m.scale + 0.5), math.floor(band.y * m.scale + 0.5))
		)
		expect(at.width).toBe(math.floor(band.width * m.scale + 0.5))
		world.conversation:close()
		expect(places[#places].position.Y.Offset).toBe(math.floor(Layout.toastTop(m, false) * m.scale + 0.5))
	end)

	it("L5 no Kingdom.Converse on the server (today's main): Talk says so at once", function()
		world:destroy()
		world = newWorld({ inspectOnly = true })
		pickSelection(world, "citizen", 41)
		tap(find(cardPanel(world), "Talk"))
		world:advance(0.1)
		expect(texts(world.hud.guis.notices)).toContain(CitizenText.UNAVAILABLE)
		expect(world.hud.state.menu).toBe("citizen")
		expect(find(find(cardPanel(world), "Talk"), "Face"):GetAttribute("talk")).toBe("request")
	end)

	it("L6 destroying a controller closes its menu", function()
		talkTo(world, 41)
		world.conversation:destroy()
		expect(world.hud.state.menu).toBeNil()
		pickSelection(world, "citizen", 42)
		expect(world.hud.state.menu).toBe("citizen")
		world.card:destroy()
		expect(world.hud.state.menu).toBeNil()
	end)

	it("L7 a tap on someone else's citizen closes the open card, with a notice", function()
		pickSelection(world, "citizen", 41)
		expect(world.hud.state.menu).toBe("citizen")
		pickSelection(world, "citizen", 51)
		expect(world.hud.state.menu).toBeNil()
		expect(cardPanel(world)).toBeNil()
		expect(texts(world.hud.guis.notices)).toContain(CitizenText.CANT_INSPECT)
	end)

	it("L8 the conversation closes when its citizen is gone", function()
		talkTo(world, 42)
		world:advance(world.conversation.CHECK_SEC + 0.1)
		expect(world.hud.state.menu).toBe("conversation") -- still there: stays open
		world.citizens.citizens[42] = nil
		world:advance(world.conversation.CHECK_SEC + 0.1)
		expect(world.hud.state.menu).toBeNil()
		expect(world.conversation.state).toBeNil()
		local notices = texts(world.hud.guis.notices)
		expect(notices).toContain(CitizenText.GONE)
		expect(notices).toContain("Bran Thornbury")
	end)
end)

describe("FORGE-05 review of #66: risks never below the fold (B1), L1-L5", function()
	local world, previous
	beforeEach(function()
		previous = useStrongConnector()
	end)
	afterEach(function()
		if world then
			world:destroy()
			world = nil
		end
		restoreConnector(previous)
	end)

	local PUSH_ON = "builder_overworked_push_on"

	it("B1 phone (844 × 390, safe area 750 × 311), builder_overworked: a risky answer is confirmed whole", function()
		-- the layout works in the safe area, as the renderer and Roblox's CoreUISafeInsets do
		world = newWorld({ width = 750, height = 311 })
		local asking = talkTo(world, 47)
		expect(asking:GetAttribute("scenarioId")).toBe("builder_overworked")
		expect(#options(asking)).toBe(3)
		-- the bug: the three answers scroll, so the third answer's risk can sit below the fold
		local rect = CitizenModel.conversationRect(world.hud:metrics())
		expect(CitizenModel.conversationOverflows(world.conversation.state, rect, true, nil)).toBe(true)
		tap(find(asking, "Option_" .. PUSH_ON))
		local confirming = convoPanel(world)
		expect(confirming:GetAttribute("phase")).toBe("confirming")
		expect(#world.citizens:callsNamed("Choose")).toBe(0) -- nothing sent yet
		local card = find(confirming, "Option_" .. PUSH_ON)
		local risk = find(card, "Risk_1")
		expect(find(risk, "Chance").Text).toBe("50 %")
		expect(find(risk, "RiskText").Text).toBe("Bran may lay down tools for 45 s.")
		expect(find(confirming, "Back")).toBeTruthy()
		expect(find(confirming, "Confirm")).toBeTruthy()
		-- the step fits the sheet without scrolling: nothing of the answer is below the fold
		local state = world.conversation.state
		expect(CitizenModel.conversationOverflows(state, rect, true, nil)).toBe(false)
		expect(confirming.Size.Y.Offset).toBeLessThanOrEqual(rect.height)
		-- Back: the answers again, nothing sent; Choose (after its guard) sends exactly this answer
		tap(find(confirming, "Back"))
		expect(convoPanel(world):GetAttribute("phase")).toBe("asking")
		answer(world, PUSH_ON)
		world:advance(0.2)
		expect(world.citizens:callsNamed("Choose")[1].args).toEqual({ 47, "builder_overworked", PUSH_ON })
	end)

	it("B1: an answer with neither a cost nor a risk is sent at once; the smallest phone fits two risks", function()
		world = newWorld({ width = 750, height = 311 })
		talkTo(world, 47)
		tap(find(convoPanel(world), "Option_builder_overworked_rest"))
		world:advance(0.2)
		expect(#world.citizens:callsNamed("Choose")).toBe(1)
		world:destroy()
		-- 750 × 311 (the smallest safe area), the answer with two risks
		world = newWorld({ width = 750, height = 311 })
		talkTo(world, 46)
		tap(find(convoPanel(world), "Option_dig"))
		local m = world.hud:metrics()
		expect(world.conversation.state.phase).toBe("confirming")
		expect(
			CitizenModel.conversationOverflows(world.conversation.state, CitizenModel.conversationRect(m), true, nil)
		).toBe(false)
		expect(#findAll(convoPanel(world), "^Risk_")).toBe(2)
	end)

	it("L1: an answered result stays when its citizen leaves; only a deciding panel closes", function()
		world = newWorld()
		talkTo(world, 42)
		answer(world, SCENARIOS.two.responses[1].id)
		world:advance(0.2)
		expect(convoPanel(world):GetAttribute("phase")).toBe("answered")
		world.citizens.citizens[42] = nil -- gone
		world:advance(world.conversation.CHECK_SEC * 2 + 0.5)
		expect(convoPanel(world):GetAttribute("phase")).toBe("answered")
		expect(#world.citizens:callsNamed("Inspect")).toBe(1) -- only the card's tap, no presence checks
	end)

	it("L2: a Converse or Inspect still on its way when its controller is destroyed opens no menu", function()
		world = newWorld()
		world.citizens.latency = 0.5
		pickSelection(world, "citizen", 41)
		tap(find(cardPanel(world), "Talk"))
		world.conversation:destroy()
		world:advance(0.8)
		expect(world.hud.state.menu).never.toBe("conversation")
		world.hud:setMenu(nil)
		world.citizens.inspectDelay[41] = 0.5
		pickSelection(world, "citizen", 41)
		world.card:destroy()
		world:advance(0.8)
		expect(world.hud.state.menu).never.toBe("citizen")
	end)

	it("L3: once the choice is on its way, a treasury change never marks the picked answer short", function()
		world = newWorld({ treasury = { food = 120, wood = 100, stone = 50, gold = 30 } })
		world.citizens.chooseLatency = 1
		talkTo(world, 46)
		answer(world, "shore") -- 20 Wood, 25 Gold
		local waiting = convoPanel(world)
		expect(waiting:GetAttribute("phase")).toBe("choosing")
		world.treasury:spend("crimson", { gold = 30 }, "spec:gold", "test")
		world:advance(0.2)
		local picked = find(convoPanel(world), "Option_shore")
		expect(picked:GetAttribute("state")).toBe("picked")
		expect(find(picked, "Need")).toBeNil()
	end)

	it("L4: an answer whose cost can't be shown is disabled and says so; it is never sent", function()
		world = newWorld()
		world.citizens:setScenario(42, {
			scenarioId = "odd_cost",
			question = "Shall we?",
			responses = {
				{
					id = "yes",
					text = "Yes.",
					cost = { wood = 5, iron = 3 },
					loyalty = 0,
					reaction = "Yes!",
					effects = {},
				},
				{ id = "no", text = "No.", loyalty = 0, reaction = "No.", effects = {} },
			},
		})
		local panel = talkTo(world, 42)
		local yes = find(panel, "Option_yes")
		expect(yes.Active).toBe(false)
		expect(find(yes, "Need").Text).toBe(CitizenText.COST_UNKNOWN)
		fire(yes, "Activated")
		world.conversation:choose("yes")
		world:advance(0.5)
		expect(#world.citizens:callsNamed("Choose")).toBe(0)
	end)
end)
