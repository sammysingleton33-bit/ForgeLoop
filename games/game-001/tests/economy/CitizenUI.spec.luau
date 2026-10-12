-- FL-0088 end to end, headless: the real KingdomHudController, CitizenCardController and
-- ConversationController talk through the framework RemoteService to FORGE-01 doubles of Sim.Inspect,
-- Kingdom.Converse and Kingdom.Choose (doubles/CitizenDoubles) on the spec world (doubles/KingdomWorld,
-- real TreasuryService). Selection comes from a double of FORGE-04's InputModeController.selected
-- (G13.6); taps fire the Activated handlers of the buttons a player would press (connector below).
local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect, beforeEach, afterEach = T.describe, T.it, T.expect, T.beforeEach, T.afterEach

local CitizenCardDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/CitizenCardController")
local CitizenDoubles = require("./doubles/CitizenDoubles")
local CitizenText = require("@game/StarterPlayer/StarterPlayerScripts/Game/UI/CitizenText")
local ConversationDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/ConversationController")
local Costs = require("@game/ReplicatedStorage/Forge/Config/Costs")
local Create = require("@game/ReplicatedStorage/Forge/UI/Create")
local KingdomHudDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/KingdomHudController")
local KingdomWorld = require("./doubles/KingdomWorld")
local Signal = require("@game/ReplicatedStorage/Forge/Core/Signal")

local SCENARIOS = CitizenDoubles.SCENARIOS

-- Taps. Create.useTestConnector keeps handlers in a weak-keyed table; under Lune a garbage collection
-- can drop an instance's userdata wrapper between render and tap, and the handlers with it (a rare
-- "expected 0 to be greater than 0"; reported to the kit owner). This spec's connector keys handlers
-- strongly, which keeps the wrappers alive, so taps are deterministic here.
local strong = {}

local function useStrongConnector()
	strong = {}
	return Create.setConnector(function(instance, eventName, fn)
		local byEvent = strong[instance]
		if byEvent == nil then
			byEvent = {}
			strong[instance] = byEvent
		end
		local list = byEvent[eventName]
		if list == nil then
			list = {}
			byEvent[eventName] = list
		end
		table.insert(list, fn)
		return {
			Disconnect = function()
				local index = table.find(list, fn)
				if index then
					table.remove(list, index)
				end
			end,
		}
	end)
end

local function fire(instance, eventName, ...)
	local byEvent = strong[instance]
	local list = byEvent and byEvent[eventName]
	if list == nil then
		return 0
	end
	for _, fn in table.clone(list) do
		fn(...)
	end
	return #list
end

local function restoreConnector(previous)
	Create.setConnector(previous)
	strong = {}
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
	o.remotes = CitizenDoubles.REMOTES
	o.services = { CitizenDoubles.service }
	o.clientDefinitions = { KingdomHudDef, CitizenCardDef, ConversationDef, inputModeDef(o.rbxSignal) }
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
		expect(panel.Position.Y.Offset).toBeGreaterThan(m.hud.bottom)
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
		tap(help)
		fire(help, "Activated") -- the second tap of a double tap (same, now replaced, button)
		fire(bread, "Activated")
		world.conversation:choose("work")
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
		local panel = talkTo(world, 41)
		tap(find(panel, "Option_help"))
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
		local panel = talkTo(world, 41)
		tap(find(panel, "Option_bread"))
		world:advance(0.2)
		local refused = convoPanel(world)
		expect(refused:GetAttribute("phase")).toBe("refused")
		expect(find(refused, "Reason").Text).toBe(CitizenText.reason("not_eligible"))
		expect(find(refused, "Reason").Text).never.toContain("not_eligible")
		tap(find(find(refused, "Body").Parent, "Close"))
		expect(world.hud.state.menu).toBeNil()
		world.citizens.refuse = "weird_code"
		tap(find(talkTo(world, 41), "Option_bread"))
		world:advance(0.2)
		expect(find(convoPanel(world), "Reason").Text).toBe(CitizenText.GENERIC)
	end)

	it("a dropped Kingdom.Choose opens the answers again with an error; the retry goes through", function()
		world.citizens.drop = true
		local panel = talkTo(world, 41)
		tap(find(panel, "Option_help"))
		world:advance(0.2)
		local again = convoPanel(world)
		expect(again:GetAttribute("phase")).toBe("asking")
		expect(find(again, "Error").Text).toBe(CitizenText.unreachable())
		for _, button in options(again) do
			expect(button.Active).toBe(true)
		end
		tap(find(again, "Option_help"))
		world:advance(0.2)
		expect(#world.citizens:callsNamed("Choose")).toBe(2)
		expect(convoPanel(world):GetAttribute("phase")).toBe("answered")
	end)

	it("selection 'none' closes the conversation; a late reply does not bring it back", function()
		world.citizens.latency = 0.3
		expect(talkTo(world, 41)).toBeTruthy()
		tap(find(convoPanel(world), "Option_help"))
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
