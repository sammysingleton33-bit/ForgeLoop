-- FL-0099 cinematic conversations (CONTRACTS G13.8, D-036), headless: the real KingdomHudController,
-- CitizenCardController and ConversationController against the FORGE-01 #108 double (Kingdom.Converse
-- with look / job / position / kingdom, the hold, Kingdom.EndConversation; doubles/CitizenDoubles), a
-- stand-in for FORGE-02's Kit.portrait (#85; doubles/PortraitDoubles) and a recording double of
-- FORGE-04's RulerCameraController (#84), which listens to opened / closed as the real one does.
local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect, beforeEach, afterEach = T.describe, T.it, T.expect, T.beforeEach, T.afterEach

local CitizenCardDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/CitizenCardController")
local CitizenDoubles = require("./doubles/CitizenDoubles")
local CitizenModel = require("@game/StarterPlayer/StarterPlayerScripts/Game/UI/CitizenModel")
local CitizenText = require("@game/StarterPlayer/StarterPlayerScripts/Game/UI/CitizenText")
local ConversationDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/ConversationController")
local Create = require("@game/ReplicatedStorage/Forge/UI/Create")
local KingdomHudDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/KingdomHudController")
local KingdomWorld = require("./doubles/KingdomWorld")
local Layout = require("@game/StarterPlayer/StarterPlayerScripts/Game/UI/Layout")
local PortraitDoubles = require("./doubles/PortraitDoubles")
local PortraitView = require("@game/StarterPlayer/StarterPlayerScripts/Game/UI/PortraitView")
local Signal = require("@game/ReplicatedStorage/Forge/Core/Signal")
local StageModel = require("@game/StarterPlayer/StarterPlayerScripts/Game/UI/StageModel")

local SCENARIOS = CitizenDoubles.SCENARIOS
local POSITIONS = CitizenDoubles.POSITIONS

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
	expect(Create.fire(face, "Activated")).toBeGreaterThan(0)
end

-- FORGE-04 double: G4.1 InputModeController with the G13.6 selection signal.
local function inputModeDef()
	return {
		name = "InputModeController",
		new = function()
			return { mode = "explore", changed = Signal.new(), selected = Signal.new(), set = function() end }
		end,
	}
end

-- FORGE-04 double: RulerCameraController (#84) finds ConversationController and records what it hears.
local function cameraDef(events)
	return {
		name = "RulerCameraController",
		new = function(_, registry)
			return {
				start = function()
					local conversations = registry:find("ConversationController")
					conversations.opened:connect(function(entityId, position)
						table.insert(events, { "opened", entityId, position })
					end)
					conversations.closed:connect(function(entityId)
						table.insert(events, { "closed", entityId })
					end)
				end,
			}
		end,
	}
end

-- FORGE-04 framework double: SettingsController:reducedMotion().
local function settingsDef(settings)
	return {
		name = "SettingsController",
		new = function()
			return {
				reducedMotion = function()
					return settings.reduced == true
				end,
				get = function(_, key)
					return settings[key]
				end,
			}
		end,
	}
end

-- A TweenService double: records each tween and applies nothing (the rise stays at its start).
local function tweenService(tweens)
	return {
		Create = function(_, instance, info, props)
			return {
				Play = function()
					table.insert(tweens, { instance = instance, time = info.Time, props = props })
				end,
			}
		end,
	}
end

local function newWorld(opts)
	local o = opts or {}
	o.events = {}
	o.settings = o.settings or { reduced = false }
	if o.noEnd then
		o.remotes, o.services = CitizenDoubles.REMOTES, { CitizenDoubles.cinematicNoEnd }
	else
		o.remotes, o.services = CitizenDoubles.CINEMATIC_REMOTES, { CitizenDoubles.cinematic }
	end
	o.clientDefinitions = {
		KingdomHudDef,
		CitizenCardDef,
		ConversationDef,
		inputModeDef(),
		cameraDef(o.events),
		settingsDef(o.settings),
	}
	if o.tweens then
		o.envServices = { TweenService = tweenService(o.tweens) }
	end
	local world = KingdomWorld.new(o)
	world.events = o.events
	world.settings = o.settings
	world.hud = world.client:get("KingdomHudController")
	world.card = world.client:get("CitizenCardController")
	world.conversation = world.client:get("ConversationController")
	world.input = world.client:get("InputModeController")
	world.citizens = world.server:get("CitizenService")
	world.hud:setViewport(o.width or 1920, o.height or 1022)
	world:advance(0.1)
	return world
end

local function stageOf(world)
	return find(world.hud.guis.menus, "ConversationStage")
end

local function panelOf(world)
	return find(world.hud.guis.menus, "Conversation")
end

local function pickSelection(world, kind, id)
	world.input.selected:fire(kind, id)
	world:advance(0.1)
end

-- Opens the conversation of `entityId` through the card's Talk button, as a player would.
local function talkTo(world, entityId)
	pickSelection(world, "citizen", entityId)
	tap(find(find(world.hud.guis.menus, "CitizenCard"), "Talk"))
	world:advance(0.1 + world.citizens.latency)
	return stageOf(world)
end

-- Answers as a player does (the confirm step for an answer with a cost or a risk).
local function answer(world, id)
	tap(find(stageOf(world), "Option_" .. id))
	local stage = stageOf(world)
	if stage and stage:GetAttribute("phase") == "confirming" then
		world:advance(world.conversation.CONFIRM_DELAY + 0.05)
		tap(find(stageOf(world), "Confirm"))
	end
	world:advance(0.1)
end

local function named(events, kind)
	local out = {}
	for _, e in events do
		if e[1] == kind then
			table.insert(out, e)
		end
	end
	return out
end

local function ends(world)
	local out = {}
	for _, call in world.citizens:callsNamed("End") do
		table.insert(out, call.args[1])
	end
	return out
end

local CRIMSON = Color3.fromRGB(190, 40, 50)

describe("FL-0099 StageModel (G13.8 geometry)", function()
	it("keeps the stage below the HUD stack, left of the rail, with two answer columns on every size", function()
		for _, size in { { 750, 311 }, { 934, 629 }, { 1596, 850 }, { 1024, 690 } } do
			local m = Layout.compute(size[1], size[2])
			local r = StageModel.rects(m)
			local railLeft = m.width - m.rail.right - m.rail.button
			expect(r.x).toBeGreaterThan(m.margin - 1)
			expect(r.x + r.width).toBeLessThan(railLeft)
			expect(r.bottom).toBe(m.height - m.margin)
			expect(r.bottom - r.maxHeight).toBeGreaterThan(m.hud.bottom) -- never above the HUD stack
			expect(r.column.x).toBeGreaterThan(r.x + r.portrait) -- the column is right of the portrait
			expect(r.column.x + r.column.width).toBe(r.x + r.width)
			expect(r.columns).toBe(2)
			expect(2 * r.answerWidth + StageModel.GEO.answerGap).toBeLessThan(r.column.width + 1)
		end
	end)

	it("phone 844 × 390: four answers fit two per row without scrolling, clear of the HUD stack", function()
		local m = Layout.compute(750, 311) -- 844 × 390 minus the insets and the top bar
		local r = StageModel.rects(m)
		local convo = CitizenModel.conversation({
			scenarioId = SCENARIOS.four.scenarioId,
			question = SCENARIOS.four.question,
			options = SCENARIOS.four.responses,
		})
		local state = { phase = "asking", conversation = convo }
		expect(StageModel.overflows(state, r)).toBe(false)
		local height = StageModel.height(state, r)
		expect(r.bottom - height).toBeGreaterThan(m.hud.bottom)
		-- with costs and risks too (Edda's three answers) it still fits
		local three = CitizenModel.conversation({
			scenarioId = SCENARIOS.three.scenarioId,
			question = SCENARIOS.three.question,
			options = SCENARIOS.three.responses,
		})
		expect(StageModel.overflows({ phase = "asking", conversation = three }, r, { food = 0, wood = 0 })).toBe(false)
	end)

	it("dims at most 20 % and reads for 6-12 s by the length of the reaction and chips", function()
		expect(StageModel.GEO.dimOpacity <= 0.2).toBe(true)
		expect(StageModel.readSeconds({ reaction = "Hmph.", effects = {} })).toBe(StageModel.READ_MIN)
		expect(StageModel.readSeconds({ reaction = string.rep("a", 2000), effects = {} })).toBe(StageModel.READ_MAX)
		local mid = StageModel.readSeconds({ reaction = string.rep("a", 60), effects = { { text = "+8 Loyalty" } } })
		expect(mid).toBeNear(StageModel.READ_BASE + 70 * StageModel.READ_PER_CHAR, 1e-9)
	end)

	it("phones hide the question in the confirm step; a reaction-less answer shows no bubble", function()
		local convo = { question = "Q?" }
		expect(StageModel.showsBubble({ phase = "confirming", conversation = convo }, true)).toBe(false)
		expect(StageModel.showsBubble({ phase = "confirming", conversation = convo }, false)).toBe(true)
		expect(StageModel.showsBubble({ phase = "answered", outcome = { effects = {} } }, false)).toBe(false)
		expect(StageModel.showsBubble({ phase = "answered", outcome = { reaction = "Yes", effects = {} } }, true)).toBe(
			true
		)
		expect(StageModel.showsBubble({ phase = "asking", conversation = convo }, true)).toBe(true)
	end)
end)

describe("FL-0099 cinematic conversation (G13.8)", function()
	local world, previous, source
	beforeEach(function()
		previous = Create.useTestConnector()
		source = PortraitDoubles.source()
		PortraitView.useSource(source)
	end)
	afterEach(function()
		if world then
			world:destroy()
			world = nil
		end
		PortraitView.useSource(nil)
		Create.setConnector(previous)
	end)

	it(
		"opens the stage: the portrait is the citizen's look, job and kingdom colour; opened carries the position",
		function()
			world = newWorld()
			local stage = talkTo(world, 41)
			expect(stage).toBeTruthy()
			expect(panelOf(world)).toBeNil() -- not the drawer panel
			expect(stage:GetAttribute("phase")).toBe("asking")
			expect(#source.calls).toBe(1)
			local call = source.calls[1]
			expect(call.kind).toBe("citizen")
			expect(call.job).toBe("farmer")
			expect(call.kingdom).toBe("crimson")
			expect(call.kingdomColor).toBe(CRIMSON) -- the world rig's colour (config Kingdoms)
			expect(call.look.skin).toBe(2)
			local viewport = find(stage, "Viewport")
			expect(viewport:IsA("ViewportFrame")).toBe(true)
			-- (Lune cannot read ViewportFrame.CurrentCamera back; the view keeps the camera it set)
			local camera = world.conversation.stage.portrait.camera
			expect(camera.Parent).toBe(viewport)
			expect(camera.FieldOfView).toBe(30)
			local model = viewport:FindFirstChildWhichIsA("Model")
			expect(model:GetAttribute("KitPortrait")).toBe(true)
			local focus = model.PrimaryPart:FindFirstChild("PortraitFocus")
			expect(camera.CFrame).toBe(model.PrimaryPart.CFrame * focus.CFrame)
			expect(find(stage, "CitizenName").Text).toBe("Edda Thornbury")
			expect(find(stage, "CitizenSub").Text).toBe("Farmer")
			expect(find(stage, "Question").Text).toBe(SCENARIOS.three.question)
			expect(#findAll(stage, "^Option_")).toBe(3)
			-- the camera heard where she stands; the server holds her
			expect(#world.events).toBe(1)
			expect(world.events[1][1]).toBe("opened")
			expect(world.events[1][2]).toBe(41)
			expect(world.events[1][3]).toBe(POSITIONS[41])
			expect(world.citizens.held[41]).toBe(true)
		end
	)

	it("never covers the world: one dim band at most 20 % dark, the stage itself transparent", function()
		world = newWorld()
		local stage = talkTo(world, 41)
		expect(stage.BackgroundTransparency).toBe(1)
		local dim = find(world.hud.guis.backdrop, "StageDim")
		expect(find(world.hud.guis.menus, "StageDim")).toBeNil()
		-- the whole device, not clipped to the safe area, just under the menus
		expect(world.hud.guis.backdrop.ScreenInsets).toBe(Enum.ScreenInsets.None)
		expect(world.hud.guis.backdrop.ClipToDeviceSafeArea).toBe(false)
		expect(world.hud.guis.backdrop.DisplayOrder < world.hud.guis.menus.DisplayOrder).toBe(true)
		local lowest = 1
		for _, k in dim:FindFirstChildWhichIsA("UIGradient").Transparency.Keypoints do
			lowest = math.min(lowest, k.Value)
		end
		expect(lowest >= 0.8).toBe(true)
		expect(dim.BackgroundTransparency).toBe(0)
		local m = world.hud:metrics()
		-- the band covers the bottom of the screen up to a little above the stage, never more
		expect(dim.AnchorPoint).toBe(Vector2.new(0, 1))
		expect(dim.Size.Y.Offset < m.height * 2 / 3).toBe(true)
		expect(dim.Size.Y.Offset).toBeGreaterThan(stage.Size.Y.Offset)
	end)

	it(
		"answering: Choose, the reaction and the consequence chips, then it closes by itself (closed and EndConversation once)",
		function()
			world = newWorld()
			talkTo(world, 43)
			answer(world, "thornbury")
			local choose = world.citizens:callsNamed("Choose")
			expect(#choose).toBe(1)
			expect(choose[1].args[3]).toBe("thornbury")
			local stage = stageOf(world)
			expect(stage:GetAttribute("phase")).toBe("answered")
			expect(find(stage, "Reaction").Text).toBe("A fair ruling.")
			expect(texts(find(stage, "Effects"))).toContain("+2 Honor")
			expect(find(stage, "Done")).toBeTruthy()
			expect(#named(world.events, "closed")).toBe(0)
			world:advance(
				StageModel.readSeconds({ reaction = "A fair ruling.", effects = { { text = "+2 Honor" } } }) + 0.1
			)
			expect(world.hud.state.menu).toBeNil()
			expect(stageOf(world)).toBeNil()
			expect(#named(world.events, "closed")).toBe(1)
			expect(named(world.events, "closed")[1][2]).toBe(43)
			expect(ends(world)).toEqual({ 43 })
			expect(world.citizens.held[43]).toBeNil()
		end
	)

	it("Done closes at once; the auto-close that follows does nothing more", function()
		world = newWorld()
		talkTo(world, 43)
		answer(world, "split")
		tap(find(stageOf(world), "Done"))
		world:advance(0.1)
		expect(world.hud.state.menu).toBeNil()
		world:advance(StageModel.READ_MAX + 1)
		expect(#named(world.events, "closed")).toBe(1)
		expect(ends(world)).toEqual({ 43 })
	end)

	it("the auto-close of an answered stage never closes the conversation that followed it", function()
		world = newWorld()
		talkTo(world, 43)
		answer(world, "split")
		tap(find(stageOf(world), "Done"))
		world:advance(0.1)
		talkTo(world, 41) -- a new conversation before the first one's reading time ran out
		world:advance(StageModel.READ_MAX + 1)
		expect(stageOf(world)).toBeTruthy()
		expect(find(stageOf(world), "CitizenName").Text).toBe("Edda Thornbury")
	end)

	it("once the choice is on its way a treasury push repaints nothing (the server has charged)", function()
		world = newWorld()
		world.citizens.chooseLatency = 1
		talkTo(world, 41)
		answer(world, "help") -- 20 Wood, confirmed
		local stage = stageOf(world)
		expect(stage:GetAttribute("phase")).toBe("choosing")
		local picked = find(stage, "Option_help")
		world.treasury:spend("crimson", { wood = 95 }, "spec:charged", "test")
		world:advance(0.2)
		expect(find(stageOf(world), "Option_help")).toBe(picked)
		expect(texts(picked)).never.toContain("Need")
	end)

	it("phone: the bubble spans the stage above the portrait, its tail down, the close button beside it", function()
		world = newWorld({ width = 750, height = 311 })
		local stage = talkTo(world, 45) -- the long question and answers
		local r = StageModel.rects(world.hud:metrics())
		expect(r.bubbleAbove).toBe(true)
		local speech = find(stage, "Speech")
		expect(speech.Parent).toBe(stage) -- above the column, not in its scrolling body
		expect(speech.Size.X.Offset).toBe(r.width - r.close - StageModel.GEO.closeGap)
		expect(find(stage, "Close").Parent).toBe(stage)
		local column = find(stage, "Column")
		expect(column.Position.Y.Offset).toBeGreaterThan(0) -- below the bubble
		expect(find(column, "Speech")).toBeNil()
		local tail = find(speech, "Tail")
		expect(tail.Position.Y.Scale).toBe(1) -- on its bottom edge,
		expect(tail.Position.X.Offset).toBe(math.floor(r.portrait / 2)) -- over the portrait
	end)

	it("phone: FORGE-06's longest lines fit (160-character question, four 70-character answers)", function()
		local m = Layout.compute(750, 311) -- with the reputation strip, as in the game
		local question = string.sub(string.rep("Wordy ", 30), 1, 160)
		local answer = string.sub(string.rep("Words ", 15), 1, 70)
		local options = {}
		for i = 1, 4 do
			table.insert(options, { id = `a{i}`, text = answer })
		end
		local convo = CitizenModel.conversation({ scenarioId = "budget", question = question, options = options })
		local state = { phase = "asking", conversation = convo }
		local r = StageModel.rects(m, state)
		expect(r.bubbleAbove).toBe(true)
		expect(StageModel.overflows(state, r)).toBe(false) -- (beside the portrait: 228 of 215 px, it scrolled)
	end)

	it("phone: a bubble too tall for the band goes back beside the portrait and the column scrolls", function()
		world = newWorld({ width = 750, height = 311 })
		local long = {
			scenarioId = "very_long",
			question = string.rep("My lord, the river has risen again and the mill is under water. ", 9),
			responses = SCENARIOS.long.responses,
		}
		world.citizens:setScenario(44, long)
		local stage = talkTo(world, 44)
		local m = world.hud:metrics()
		local r = StageModel.rects(m, world.conversation.state)
		expect(r.bubbleAbove).toBe(false)
		expect(find(find(stage, "Column"), "Speech")).toBeTruthy() -- in the column again
		expect(stage.Size.Y.Offset).toBe(r.maxHeight)
		expect(stage.Position.Y.Offset).toBe(m.hud.bottom + StageModel.GEO.hudGap)
		expect(find(stage, "Kicker").Text).toContain("SCROLL FOR ALL 3")
	end)

	it("closing unanswered (X) ends the hold; reopening shows the same question and opens again", function()
		world = newWorld()
		local stage = talkTo(world, 41)
		tap(find(find(stage, "Column"), "Close"))
		world:advance(0.1)
		expect(world.hud.state.menu).toBeNil()
		expect(ends(world)).toEqual({ 41 })
		expect(world.citizens.held[41]).toBeNil()
		expect(#named(world.events, "closed")).toBe(1)
		expect(#world.citizens:callsNamed("Choose")).toBe(0)
		stage = talkTo(world, 41)
		expect(find(stage, "Question").Text).toBe(SCENARIOS.three.question)
		expect(#named(world.events, "opened")).toBe(2)
		expect(world.citizens.held[41]).toBe(true)
	end)

	it("a selection, another menu or the citizen leaving each end the conversation once", function()
		world = newWorld()
		talkTo(world, 41)
		pickSelection(world, "none", 0)
		expect(ends(world)).toEqual({ 41 })
		talkTo(world, 42)
		world.hud:setMenu("build")
		world:advance(0.1)
		expect(ends(world)).toEqual({ 41, 42 })
		talkTo(world, 45)
		world.citizens.citizens[45].kingdom = "azure" -- no longer ours: Sim.Inspect answers nil
		world:advance(world.conversation.CHECK_SEC + 0.2)
		expect(world.hud.state.menu).toBeNil()
		expect(texts(world.hud.guis.notices)).toContain(CitizenText.GONE)
		expect(#ends(world)).toBe(3)
		expect(ends(world)[3]).toBe(45)
		expect(#named(world.events, "opened")).toBe(3)
		expect(#named(world.events, "closed")).toBe(3)
	end)

	it("a Converse reply that arrives after the player moved on lets the citizen go and opens nothing", function()
		world = newWorld()
		world.citizens.latency = 0.3
		pickSelection(world, "citizen", 41)
		tap(find(find(world.hud.guis.menus, "CitizenCard"), "Talk"))
		world:advance(0.05)
		pickSelection(world, "none", 0)
		world:advance(0.5)
		expect(world.hud.state.menu).toBeNil()
		expect(#world.events).toBe(0)
		expect(ends(world)).toEqual({ 41 })
		expect(world.citizens.held[41]).toBeNil()
	end)

	it("another citizen's conversation replacing this one: closed for the first, then opened for the second", function()
		world = newWorld()
		talkTo(world, 41)
		world.conversation:open(42)
		world:advance(0.2)
		expect(find(stageOf(world), "CitizenName").Text).toBe("Bran Thornbury")
		expect(#world.events).toBe(3)
		expect(world.events[2][1]).toBe("closed")
		expect(world.events[2][2]).toBe(41)
		expect(world.events[3][1]).toBe("opened")
		expect(world.events[3][2]).toBe(42)
		expect(ends(world)).toEqual({ 41 })
		expect(world.citizens.held[42]).toBe(true)
	end)

	it("the same citizen reopened while it shows keeps its opened and its hold", function()
		world = newWorld()
		talkTo(world, 41)
		world.conversation:open(41)
		world:advance(0.2)
		expect(#world.events).toBe(1)
		expect(#ends(world)).toBe(0)
		expect(world.citizens.held[41]).toBe(true)
		expect(stageOf(world)).toBeTruthy()
	end)

	it("the portrait is built once per showing: answering keeps it (no second rise)", function()
		world = newWorld()
		local stage = talkTo(world, 43)
		local model = find(stage, "Viewport"):FindFirstChildWhichIsA("Model")
		answer(world, "reed")
		stage = stageOf(world)
		expect(stage:GetAttribute("phase")).toBe("answered")
		expect(find(stage, "Viewport"):FindFirstChildWhichIsA("Model")).toBe(model)
		expect(#source.calls).toBe(1)
		-- no reaction bubble without effects is still a reaction ("Hmph."), and no chips row
		expect(find(stage, "Reaction").Text).toBe("Hmph.")
		expect(find(stage, "Effects")).toBeNil()
	end)

	it("an answer with a cost or a risk goes through the confirm step with every risk in full", function()
		world = newWorld()
		talkTo(world, 41)
		local stage = stageOf(world)
		-- in the list: chips only (what it costs, each risk's chance)
		local work = find(stage, "Option_work")
		expect(find(work, "Risk_1"):GetAttribute("percent")).toBe(20)
		expect(find(find(work, "Risk_1"), "Amount").Text).toBe("20 %")
		expect(find(find(find(stage, "Option_help"), "Cost_wood"), "Amount").Text).toBe("20")
		tap(work)
		world:advance(0.05)
		stage = stageOf(world)
		expect(stage:GetAttribute("phase")).toBe("confirming")
		expect(texts(find(stage, "Option_work"))).toContain("Edda's family may lay down their tools for 60 s.")
		expect(find(stage, "Question")).toBeTruthy() -- desktop keeps the question
		tap(find(stage, "Back"))
		world:advance(0.05)
		expect(stageOf(world):GetAttribute("phase")).toBe("asking")
		answer(world, "work")
		expect(stageOf(world):GetAttribute("phase")).toBe("answered")
		expect(world.citizens:callsNamed("Choose")[1].args[3]).toBe("work")
	end)

	it("a refusal shows the reason and Close, and waits for the player", function()
		world = newWorld()
		talkTo(world, 43)
		world.citizens.refuse = "not_eligible"
		answer(world, "thornbury")
		local stage = stageOf(world)
		expect(stage:GetAttribute("phase")).toBe("refused")
		expect(texts(find(stage, "Refusal"))).toContain(CitizenText.reason("not_eligible"))
		world:advance(StageModel.READ_MAX + 1)
		expect(stageOf(world)).toBeTruthy()
		tap(find(find(stage, "Column"), "Close"))
		world:advance(0.1)
		expect(world.hud.state.menu).toBeNil()
		expect(ends(world)).toEqual({ 43 })
	end)

	it("a treasury push repaints in place only the answers whose need changed", function()
		world = newWorld()
		world.treasury:spend("crimson", { wood = 90 }, "spec:wood", "test") -- 10 wood left: help needs 20
		world:advance(0.1)
		local stage = talkTo(world, 41)
		local help, bread = find(stage, "Option_help"), find(stage, "Option_bread")
		expect(help:GetAttribute("affordable")).toBe(false)
		expect(texts(help)).toContain("Need")
		local breadLabel = find(bread, "Label")
		world.treasury:deposit("crimson", "wood", 30, "spec:wood2", "test")
		world:advance(0.2)
		expect(find(stageOf(world), "Option_help")).toBe(help) -- the same button
		expect(help:GetAttribute("affordable")).toBe(true)
		expect(texts(help)).never.toContain("Need")
		expect(find(bread, "Label")).toBe(breadLabel) -- untouched
	end)

	it("phone: without the question bubble a head row beside the close button comes first", function()
		world = newWorld({ width = 750, height = 311 })
		talkTo(world, 41)
		tap(find(stageOf(world), "Option_work"))
		world:advance(0.05)
		local stage = stageOf(world)
		expect(stage:GetAttribute("phase")).toBe("confirming")
		expect(find(stage, "Question")).toBeNil()
		local head = find(stage, "Head")
		local r = StageModel.rects(world.hud:metrics())
		expect(head.LayoutOrder).toBe(0) -- first in the body
		expect(head.Size.Y.Offset).toBe(r.close) -- as tall as the close button
		expect(head.Size.X.Offset).toBe(r.bubbleWidth) -- and left of it
		expect(find(head, "Kicker").Text).toBe(CitizenText.CONFIRM_KICKER)
		-- desktop answers start with the "You: ..." echo in the head row
		world:destroy()
		world = newWorld()
		talkTo(world, 43)
		answer(world, "thornbury")
		head = find(stageOf(world), "Head")
		expect(texts(head)).toContain("The Thornburys. They were here first.")
		expect(StageModel.hasHead({ phase = "asking" }, true)).toBe(false)
		expect(StageModel.hasHead({ phase = "refused", outcome = {} }, true)).toBe(true)
		expect(StageModel.hasHead({ phase = "refused", outcome = {} }, false)).toBe(false)
	end)

	it("phone 844 × 390: four answers in two rows of two, the stage below the HUD stack", function()
		world = newWorld({ width = 750, height = 311 })
		local stage = talkTo(world, 43)
		local rows = findAll(stage, "^Row_")
		expect(#rows).toBe(2)
		for _, row in rows do
			expect(#findAll(row, "^Option_")).toBe(2)
		end
		local m = world.hud:metrics()
		expect(stage.Position.Y.Offset).toBeGreaterThan(m.hud.bottom)
		expect(stage.Position.Y.Offset + stage.Size.Y.Offset).toBe(m.height - m.margin)
		expect(find(stage, "Kicker")).toBeNil() -- no scroll cue needed: it fits
	end)
end)

describe("FL-0099 fallbacks and motion", function()
	local world, previous
	beforeEach(function()
		previous = Create.useTestConnector()
	end)
	afterEach(function()
		if world then
			world:destroy()
			world = nil
		end
		PortraitView.useSource(nil)
		Create.setConnector(previous)
	end)

	it(
		"no portrait source: the drawer panel shows the same conversation; opened, closed and EndConversation still apply",
		function()
			PortraitView.useSource(false)
			world = newWorld()
			talkTo(world, 41)
			expect(stageOf(world)).toBeNil()
			local panel = panelOf(world)
			expect(panel).toBeTruthy()
			expect(find(panel, "Question").Text).toBe(SCENARIOS.three.question)
			expect(world.events[1][1]).toBe("opened")
			tap(find(panel, "Close"))
			world:advance(0.1)
			expect(ends(world)).toEqual({ 41 })
			expect(#named(world.events, "closed")).toBe(1)
		end
	)

	it("a result without a look (today's server) keeps the panel even with a portrait source", function()
		PortraitView.useSource(PortraitDoubles.source())
		local o = {}
		o.remotes, o.services = CitizenDoubles.REMOTES, { CitizenDoubles.service }
		o.clientDefinitions = { KingdomHudDef, CitizenCardDef, ConversationDef, inputModeDef() }
		world = KingdomWorld.new(o)
		world.hud = world.client:get("KingdomHudController")
		world.input = world.client:get("InputModeController")
		world.citizens = world.server:get("CitizenService")
		world.hud:setViewport(1920, 1022)
		world:advance(0.1)
		talkTo(world, 43)
		expect(stageOf(world)).toBeNil()
		expect(panelOf(world)).toBeTruthy()
		-- the panel waits for Done after an answer (no auto-close)
		tap(find(panelOf(world), "Option_thornbury"))
		world:advance(StageModel.READ_MAX + 1)
		expect(panelOf(world):GetAttribute("phase")).toBe("answered")
	end)

	it("a source without a camera function: the camera is the PortraitFocus attachment", function()
		local src = PortraitDoubles.source()
		src.camera = nil
		PortraitView.useSource(src)
		local view = PortraitView.new({ look = { skin = 1 }, job = "miner", kingdom = "azure" })
		local root = view.model.PrimaryPart
		expect(view.camera.CFrame).toBe(root.CFrame * root:FindFirstChild("PortraitFocus").CFrame)
		expect(view.camera.FieldOfView).toBe(30)
		expect(src.calls[1].kingdomColor).toBe(Color3.fromRGB(40, 110, 210))
		view:destroy()
		expect(view.frame).toBeNil()
		-- the source's camera is used when it has one
		local moved = CFrame.new(1, 2, 3)
		src.camera = function()
			return moved, 24
		end
		local custom = PortraitView.new({ job = "farmer" })
		expect(custom.camera.CFrame).toBe(moved)
		expect(custom.camera.FieldOfView).toBe(24)
		-- a camera that errors falls back the same way; a model without a focus gives no view
		src.camera = function()
			error("no camera")
		end
		expect(PortraitView.new({ job = "farmer" }).camera.FieldOfView).toBe(30)
		src.portrait = function()
			return Instance.new("Model")
		end
		expect(PortraitView.new({ job = "farmer" })).toBeNil()
		expect(PortraitView.colorOf("nowhere")).toBe(PortraitView.colorOf(nil))
	end)

	it("a Converse result the panel can't show still lets the citizen go", function()
		PortraitView.useSource(PortraitDoubles.source())
		world = newWorld()
		world.citizens:setScenario(44, { scenarioId = "empty", question = "Well?", responses = {} })
		talkTo(world, 44)
		expect(world.hud.state.menu).toBe("citizen") -- nothing to show: the card stays
		expect(texts(world.hud.guis.notices)).toContain(CitizenText.NOTHING)
		expect(ends(world)).toEqual({ 44 })
		expect(#world.events).toBe(0)
	end)

	it("destroy while a conversation shows: closed for the camera and the hold ends", function()
		PortraitView.useSource(PortraitDoubles.source())
		world = newWorld()
		talkTo(world, 41)
		world.conversation:destroy()
		world:advance(0.1)
		expect(#named(world.events, "closed")).toBe(1)
		expect(ends(world)).toEqual({ 41 })
		expect(stageOf(world)).toBeNil()
	end)

	it("a portrait that fails to build falls back to the panel for that showing", function()
		local failing = PortraitDoubles.source({ fail = true })
		PortraitView.useSource(failing)
		world = newWorld()
		talkTo(world, 41)
		expect(stageOf(world)).toBeNil()
		expect(panelOf(world)).toBeTruthy()
		expect(world.conversation.state.figure).toBeNil()
		expect(#failing.calls).toBe(1)
		-- a treasury push re-renders the panel, never retries the portrait
		world.treasury:deposit("crimson", "wood", 5, "spec:w", "test")
		world:advance(0.2)
		expect(#failing.calls).toBe(1)
	end)

	it("a stage after a fallback panel replaces it (the panel never stays behind)", function()
		local src = PortraitDoubles.source()
		local build = src.portrait
		local first = true
		src.portrait = function(...)
			if first then
				first = false
				error("first portrait fails (spec)")
			end
			return build(...)
		end
		PortraitView.useSource(src)
		world = newWorld()
		talkTo(world, 41)
		expect(panelOf(world)).toBeTruthy()
		world.conversation:open(42)
		world:advance(0.2)
		expect(stageOf(world)).toBeTruthy()
		expect(panelOf(world)).toBeNil()
	end)

	it("a server without Kingdom.EndConversation: nothing is invoked, closed still fires", function()
		PortraitView.useSource(PortraitDoubles.source())
		world = newWorld({ noEnd = true })
		local stage = talkTo(world, 41)
		expect(stage).toBeTruthy()
		local pending = world.env.mock:pendingThreads()
		tap(find(find(stage, "Column"), "Close"))
		world:advance(0.1)
		expect(#ends(world)).toBe(0)
		expect(#named(world.events, "closed")).toBe(1)
		-- nothing was invoked: no thread waits 10 s for a remote that will never replicate
		expect(world.env.mock:pendingThreads()).toBe(pending)
	end)

	it("a result without a position: no opened or closed, the hold still ends", function()
		PortraitView.useSource(PortraitDoubles.source())
		world = newWorld()
		world.citizens.noPosition = true
		local stage = talkTo(world, 41)
		expect(stage).toBeTruthy()
		tap(find(find(stage, "Column"), "Close"))
		world:advance(0.1)
		expect(#world.events).toBe(0)
		expect(ends(world)).toEqual({ 41 })
	end)

	it("the portrait rises from below the screen in 0.35 s; reduced motion places it at once", function()
		PortraitView.useSource(PortraitDoubles.source())
		local tweens = {}
		world = newWorld({ tweens = tweens })
		local stage = talkTo(world, 41)
		local portrait = find(stage, "Portrait")
		local m = world.hud:metrics()
		local rise = nil
		for _, t in tweens do
			if t.instance == portrait then
				rise = t
			end
		end
		expect(rise).toBeTruthy()
		expect(rise.time).toBe(StageModel.GEO.rise)
		expect(rise.props.Position.Y.Offset).toBe(stage.Size.Y.Offset - portrait.Size.Y.Offset)
		expect(portrait.Position.Y.Offset).toBeGreaterThan(m.height) -- starts below the screen
		expect(portrait:GetAttribute("risen")).toBe(false)
		world:advance(StageModel.GEO.rise + 0.05)
		expect(portrait:GetAttribute("risen")).toBe(true)
		-- an answer re-renders the stage without a second rise
		local before = #tweens
		answer(world, "work")
		for i = before + 1, #tweens do
			expect(tweens[i].instance ~= portrait).toBe(true)
		end
		world.conversation:close()
		world:advance(0.1)
		-- reduced motion: no tween, the portrait is in place at once
		world.settings.reduced = true
		tweens = {}
		local count = #world.events
		stage = talkTo(world, 43)
		portrait = find(stage, "Portrait")
		expect(portrait.Position.Y.Offset).toBe(stage.Size.Y.Offset - portrait.Size.Y.Offset)
		expect(portrait:GetAttribute("risen")).toBe(true)
		expect(#world.events).toBe(count + 1)
	end)
end)
