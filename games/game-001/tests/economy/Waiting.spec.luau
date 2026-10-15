-- "Waiting" on the rail (FL-0115, the user's first playtest: citizen requests were hard to notice and
-- act on): the number of citizens with an open request, and a tap goes to the next one. The real
-- KingdomHudController and CitizenCardController with FORGE-04's real CitizenBubbleIndicatorController
-- over doubles of CitizenBubbleController (the requests), RulerCameraController and InputModeController.
local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect, beforeEach, afterEach = T.describe, T.it, T.expect, T.beforeEach, T.afterEach

local CitizenCardDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/CitizenCardController")
local CitizenText = require("@game/StarterPlayer/StarterPlayerScripts/Game/UI/CitizenText")
local Create = require("@game/ReplicatedStorage/Forge/UI/Create")
local IndicatorDef =
	require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/CitizenBubbleIndicatorController")
local KingdomHudDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/KingdomHudController")
local KingdomWorld = require("./doubles/KingdomWorld")
local Signal = require("@game/ReplicatedStorage/Forge/Core/Signal")

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

-- FORGE-04's CitizenBubbleController: requests() lists rigs with an open "!" (oldest first by `since`).
local function bubblesDef(state)
	return {
		name = "CitizenBubbleController",
		new = function()
			return {
				requests = function()
					return table.clone(state.requests)
				end,
			}
		end,
	}
end

local function cameraDef(state)
	return {
		name = "RulerCameraController",
		new = function()
			local c = { mode = "overview" }
			function c.focusOn(_, position)
				table.insert(state.focused, position)
			end
			state.camera = c
			return c
		end,
	}
end

local function inputDef(state)
	return {
		name = "InputModeController",
		new = function()
			local c = { mode = "explore", changed = Signal.new(), selected = Signal.new() }
			function c:accepts(mode)
				return self.mode == mode
			end
			function c:select(kind, id)
				table.insert(state.selected, { kind, id })
			end
			return c
		end,
	}
end

-- The real indicator; every request projects off screen to the left (badges are FORGE-04's, not tested here).
local indicatorDef = {
	name = "CitizenBubbleIndicatorController",
	new = function(env, registry)
		return IndicatorDef.create(env, registry, {
			viewport = Vector2.new(1920, 1022),
			project = function()
				return Vector3.new(-500, 500, 10)
			end,
		})
	end,
}

local function newWorld(opts)
	local o = opts or {}
	local state = { requests = o.requests or {}, focused = {}, selected = {} }
	local defs = { KingdomHudDef, CitizenCardDef, cameraDef(state), inputDef(state) }
	if not o.noIndicator then
		table.insert(defs, bubblesDef(state))
		table.insert(defs, indicatorDef)
	end
	local world = KingdomWorld.new({ clientDefinitions = defs, noPlayerGui = o.noPlayerGui })
	world.state = state
	world.hud = world.client:get("KingdomHudController")
	world.card = world.client:get("CitizenCardController")
	if not o.noPlayerGui then
		world.hud:setViewport(o.width or 1920, o.height or 1022)
	end
	world:advance(0.2)
	return world
end

local function button(world)
	return find(world.hud.guis.hud, "Menu_waiting")
end

local function badge(world)
	local b = find(button(world), "Badge")
	return if b then b.Text else nil
end

local function request(id, since, x)
	return { entityId = id, position = Vector3.new(x or 0, 0, 0), since = since }
end

describe("Waiting on the rail (FL-0115)", function()
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

	it("shows how many citizens wait, only while someone does, and follows the count", function()
		world = newWorld()
		expect(button(world)).toBeTruthy()
		expect(button(world).Visible).toBe(false) -- nobody waits: no button
		world.state.requests = { request(7, 10), request(3, 20) }
		world:advance(0.6)
		expect(button(world).Visible).toBe(true)
		expect(badge(world)).toBe("2")
		world.state.requests = { request(3, 20) }
		world:advance(0.6)
		expect(badge(world)).toBe("1")
		world.state.requests = {}
		world:advance(0.6)
		expect(button(world).Visible).toBe(false)
	end)

	it("a tap goes to the oldest request, the next tap to the next one (camera and card)", function()
		world = newWorld()
		world.state.requests = { request(9, 30, 90), request(4, 10, 40) }
		world:advance(0.6)
		Create.fire(button(world), "Activated")
		world:advance(0.1)
		expect(world.state.selected[1]).toEqual({ "citizen", 4 }) -- the oldest first
		expect(world.state.focused[1]).toBe(Vector3.new(40, 0, 0))
		expect(world.hud.state.menu).toBeNil() -- not a menu: the card opens from the selection
		Create.fire(button(world), "Activated")
		world:advance(0.1)
		expect(world.state.selected[2]).toEqual({ "citizen", 9 })
	end)

	it("hidden while placing and during a conversation; back afterwards", function()
		world = newWorld()
		world.state.requests = { request(5, 1) }
		world:advance(0.6)
		expect(button(world).Visible).toBe(true)
		world.hud:setPlacing(true)
		world:advance(0.6)
		expect(button(world).Visible).toBe(false)
		world.hud:setPlacing(false)
		world:advance(0.6)
		expect(button(world).Visible).toBe(true)
		world.hud.state.menu = "conversation"
		world:advance(0.6)
		expect(button(world).Visible).toBe(false)
		expect(world.card:goToWaiting()).toBeNil()
		world.hud.state.menu = nil
		world:advance(0.6)
		expect(button(world).Visible).toBe(true)
	end)

	it("in the walking view the button hides (active(), #170), or a tap says to switch views", function()
		world = newWorld()
		world.state.requests = { request(5, 1) }
		world:advance(0.6)
		world.state.camera.mode = "walk"
		world:advance(0.6)
		local indicator = world.client:get("CitizenBubbleIndicatorController")
		if indicator.active ~= nil then -- FORGE-04's #170 is on main: hidden where a tap can't go
			expect(button(world).Visible).toBe(false)
			world.state.camera.mode = "overview"
			world:advance(0.6)
			expect(button(world).Visible).toBe(true)
			return
		end
		Create.fire(button(world), "Activated")
		world:advance(0.1)
		expect(#world.state.selected).toBe(0)
		local notices = {}
		for _, d in world.hud.guis.notices:GetDescendants() do
			if d:IsA("TextLabel") then
				table.insert(notices, d.Text)
			end
		end
		expect(table.concat(notices, " | ")).toContain(CitizenText.WAITING_AERIAL)
	end)

	it("a count known before the HUD mounts shows once it does (no change needed to repaint it)", function()
		world = newWorld({ noPlayerGui = true, requests = { request(1, 1), request(2, 2) } })
		world:advance(1)
		expect(world.hud.guis.hud).toBeNil() -- not mounted yet; the count is already 2
		local playerGui = world.env.newInstance("PlayerGui")
		playerGui.Parent = world.player
		world:advance(1)
		world.hud:setViewport(1920, 1022)
		world:advance(0.1)
		expect(button(world).Visible).toBe(true)
		expect(badge(world)).toBe("2")
	end)

	it("an indicator with active() (FORGE-04 #170): hidden while it is false, back when true", function()
		local active = true
		local def = {
			name = "CitizenBubbleIndicatorController",
			new = function()
				return {
					count = function()
						return 2
					end,
					cycleRequests = function()
						return 1
					end,
					active = function()
						return active
					end,
				}
			end,
		}
		world = KingdomWorld.new({ clientDefinitions = { KingdomHudDef, CitizenCardDef, def } })
		world.hud = world.client:get("KingdomHudController")
		world.card = world.client:get("CitizenCardController")
		world.hud:setViewport(1920, 1022)
		world:advance(0.6)
		expect(button(world).Visible).toBe(true)
		expect(badge(world)).toBe("2")
		active = false
		world:advance(0.6)
		expect(button(world).Visible).toBe(false)
		expect(world.card:goToWaiting()).toBeNil()
		active = true
		world:advance(0.6)
		expect(button(world).Visible).toBe(true)
		expect(world.card:goToWaiting()).toBe(1)
	end)

	it("keeps its count across a rail rebuild (another screen size); no indicator, no button", function()
		world = newWorld()
		world.state.requests = { request(1, 1), request(2, 2), request(3, 3) }
		world:advance(0.6)
		expect(badge(world)).toBe("3")
		world.hud:setViewport(844, 390) -- phone: the rail is rebuilt
		world:advance(0.1)
		expect(button(world).Visible).toBe(true)
		expect(badge(world)).toBe("3")
		world:destroy()
		world = newWorld({ noIndicator = true })
		expect(button(world)).toBeNil()
		-- the other rail buttons still open their menus
		Create.fire(find(world.hud.guis.hud, "Menu_build"), "Activated")
		world:advance(0.1)
		expect(world.hud.state.menu).toBe("build")
	end)
end)
