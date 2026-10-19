-- The release-checklist L7 phone fit at 667 × 375 (FORGE-03, PR #215; FORGE-07's L1 asked for one spec per
-- behaviour): the wrapped pills, the stage and sheet under them, the strip during a conversation and its change
-- chips, toasts beside a phone drawer and toasts already showing.
local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect, beforeEach, afterEach = T.describe, T.it, T.expect, T.beforeEach, T.afterEach

local CitizenModel = require("@game/StarterPlayer/StarterPlayerScripts/Game/UI/CitizenModel")
local Create = require("@game/ReplicatedStorage/Forge/UI/Create")
local KingdomHudDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/KingdomHudController")
local KingdomWorld = require("./doubles/KingdomWorld")
local Layout = require("@game/StarterPlayer/StarterPlayerScripts/Game/UI/Layout")
local Rep = require("./doubles/ReputationDoubles")
local ReputationDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/ReputationPanelController")
local StageModel = require("@game/StarterPlayer/StarterPlayerScripts/Game/UI/StageModel")
local ToastStack = require("@game/ReplicatedStorage/Forge/UI/ToastStack")

local function find(root, name)
	for _, d in if root then root:GetDescendants() else {} do
		if d.Name == name then
			return d
		end
	end
	return nil
end

local START = {
	values = { compassion = 50, honor = 50, competence = 50, courage = 50, authority = 50, fear = 10 },
	kingdom = { happiness = 60, stability = 60, morale = 60 },
	history = {},
}

describe("Phone fit at 667 × 375 (L7): geometry", function()
	it(
		"the conversation stage and the citizen sheet start under both pill rows; the usual phone is unchanged",
		function()
			local m = Layout.compute(667, 375)
			local pillsBottom = m.hud.pills.y + m.hud.pills.height
			local r = StageModel.rects(m)
			expect(r.bottom - r.maxHeight >= pillsBottom).toBe(true)
			expect(r.bottom - r.maxHeight < m.hud.bottom).toBe(true) -- above the strip it covers
			expect(CitizenModel.conversationRect(m).y >= pillsBottom).toBe(true)
			-- 750 × 311 (one pill row): the stage still starts under the HUD stack
			local usual = Layout.compute(750, 311)
			local u = StageModel.rects(usual)
			expect(u.bottom - u.maxHeight >= usual.hud.bottom).toBe(true)
		end
	)

	it("a toast already showing follows ToastStack:place", function()
		local parent = Instance.new("Frame")
		local stack = ToastStack.new(parent, { after = function() end })
		stack:place(UDim2.fromOffset(0, 0), Vector2.new(1, 0), 300)
		local toast = stack:show({ title = "Built" })
		expect(toast.instance.Size.X.Offset).toBe(300)
		stack:place(UDim2.fromOffset(0, 0), Vector2.new(1, 0), 180)
		expect(toast.instance.Size.X.Offset).toBe(180)
	end)
end)

describe("Phone fit at 667 × 375 (L7): the HUD", function()
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

	local function newWorld()
		world = KingdomWorld.new({
			remotes = Rep.REMOTES,
			services = { Rep.service(START) },
			clientDefinitions = { KingdomHudDef, ReputationDef },
		})
		world.hud = world.client:get("KingdomHudController")
		world.rep = world.server:get("ReputationService")
		world.hud:setViewport(667, 375)
		world.match:setPhase("Founding", world.env.serverTimeNow() + 600)
		world:advance(1.5)
		return world
	end

	it("the pills wrap into a 2 × 2 grid", function()
		newWorld()
		local pills = find(world.hud.guis.hud, "Pills")
		expect(pills:FindFirstChildOfClass("UIGridLayout")).toBeTruthy()
		expect(pills.Size.Y.Offset).toBe(world.hud:metrics().hud.pills.height)
	end)

	it("a change chip floats over its own item on the two-row strip, not under the strip", function()
		newWorld()
		world.rep:apply("courage", 3, "You led the charge.")
		world:advance(1.2)
		local strip = find(world.hud.guis.hud, "ReputationStrip")
		expect(strip).toBeTruthy()
		local delta = find(strip, "Delta")
		expect(delta).toBeTruthy()
		expect(delta.Position.Y.Scale).toBe(0) -- (a one-row strip puts it at 1, under the item)
	end)

	it("the strip hides during a conversation on a narrow phone", function()
		newWorld()
		local strip = find(world.hud.guis.hud, "ReputationStrip")
		expect(strip.Visible).toBe(true)
		world.hud.state.menu = "conversation"
		world.hud:render()
		world:advance(0.1)
		strip = find(world.hud.guis.hud, "ReputationStrip")
		expect(strip == nil or strip.Visible == false).toBe(true)
	end)

	it("a toast beside an open phone drawer fits the free band", function()
		newWorld()
		world.hud:notify({ title = "Frostmere proposes peace", body = "Open Kingdom → Rivals to answer" })
		world.hud:setMenu("kingdom")
		world:advance(0.1)
		local m = world.hud:metrics()
		local free = Layout.freeArea(m, true)
		local toast = find(world.hud.guis.notices, "Toast")
		expect(toast).toBeTruthy()
		expect(toast.Size.X.Offset <= free.width - 10).toBe(true)
	end)
end)
