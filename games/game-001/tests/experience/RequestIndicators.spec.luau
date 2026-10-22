local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect, beforeEach = T.describe, T.it, T.expect, T.beforeEach

-- FL-0115 B16: off-screen request indicators and the cycle key (the user's first Studio playtest:
-- citizen chat bubbles were hard to notice and to act on from the aerial view).
local roblox = require("@lune/roblox")
local MockEnv = require("../../../../roblox/tests/mocks/MockEnv")
local MockSignal = require("../../../../roblox/tests/mocks/MockSignal")
local Loader = require("@game/ReplicatedStorage/Forge/Contracts/Loader")
local Signal = require("@game/ReplicatedStorage/Forge/Core/Signal")
local Create = require("@game/ReplicatedStorage/Forge/UI/Create")
local Bubbles = require("@game/ReplicatedStorage/Game/Feedback/Bubbles")
local Requests = require("@game/ReplicatedStorage/Game/Feedback/Requests")
local IndicatorDef =
	require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/CitizenBubbleIndicatorController")
local BubbleDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/CitizenBubbleController")

local VIEW = Vector2.new(800, 600)
local INSET = IndicatorDef.INSET

local function near(a, b)
	return math.abs(a - b) < 1e-6
end

describe("Feedback/Requests (FL-0115 B16)", function()
	it("edge(): on screen inside the inset; otherwise where the line from the centre leaves it", function()
		expect(Requests.edge(Vector3.new(400, 300, 10), VIEW, INSET).onScreen).toBe(true)
		expect(Requests.edge(Vector3.new(INSET, INSET, 10), VIEW, INSET).onScreen).toBe(true)
		local right = Requests.edge(Vector3.new(1600, 300, 10), VIEW, INSET)
		expect(right.onScreen).toBe(false)
		expect(right.position).toEqual(Vector2.new(800 - INSET, 300))
		expect(near(right.angle, 0)).toBe(true)
		local up = Requests.edge(Vector3.new(400, -900, 10), VIEW, INSET)
		expect(up.position).toEqual(Vector2.new(400, INSET))
		expect(near(up.angle, -90)).toBe(true)
		-- a corner: the shorter way out wins (here the left edge)
		local corner = Requests.edge(Vector3.new(-2000, 0, 10), VIEW, INSET)
		expect(near(corner.position.X, INSET)).toBe(true)
		expect(corner.position.Y > INSET and corner.position.Y < 300).toBe(true)
		-- just inside the screen but within the inset band still counts as off screen
		expect(Requests.edge(Vector3.new(10, 300, 10), VIEW, INSET).onScreen).toBe(false)
	end)

	it("edge(): behind the camera the direction is mirrored; straight behind points down; NaN is off", function()
		local behind = Requests.edge(Vector3.new(500, 300, -5), VIEW, INSET) -- projects to the right
		expect(behind.onScreen).toBe(false)
		expect(behind.position).toEqual(Vector2.new(INSET, 300)) -- so it is really to the left
		local back = Requests.edge(Vector3.new(400, 300, -5), VIEW, INSET)
		expect(back.position).toEqual(Vector2.new(400, 600 - INSET))
		local bad = Requests.edge(Vector3.new(0 / 0, 1, 1), VIEW, INSET)
		expect(bad.onScreen).toBe(false)
		expect(bad.position).toBeNil()
	end)

	it("order() puts the oldest request first; nextAfter() wraps both ways", function()
		local ordered = Requests.order({
			{ entityId = 9, position = Vector3.zero, since = 30 },
			{ entityId = 4, position = Vector3.zero, since = 10 },
			{ entityId = 2, position = Vector3.zero, since = 30 },
		})
		local ids = {}
		for _, r in ordered do
			table.insert(ids, r.entityId)
		end
		expect(ids).toEqual({ 4, 2, 9 })
		expect(Requests.nextAfter(ids, nil)).toBe(4)
		expect(Requests.nextAfter(ids, 4)).toBe(2)
		expect(Requests.nextAfter(ids, 9)).toBe(4) -- wraps
		expect(Requests.nextAfter(ids, 4, -1)).toBe(9)
		expect(Requests.nextAfter(ids, nil, -1)).toBe(9)
		expect(Requests.nextAfter(ids, 77)).toBe(4) -- the last one is gone: start again
		expect(Requests.nextAfter({}, 4)).toBeNil()
	end)

	it("edge(): per-side insets keep badges off the HUD; one in the top-left stack slides out of it", function()
		local insets = { left = 40, right = 90, top = 70, bottom = 80 }
		local right = Requests.edge(Vector3.new(5000, 285, 10), VIEW, insets) -- the centre is (375, 295)
		expect(right.position.X).toBe(800 - 90)
		local up = Requests.edge(Vector3.new(375, -900, 10), VIEW, insets)
		expect(up.position.Y).toBe(70)
		local corner = Vector2.new(400, 200)
		local topLeft = Requests.edge(Vector3.new(200, -4000, 10), VIEW, insets, corner) -- leaves the top at x ~366
		expect(topLeft.position).toEqual(Vector2.new(400, 70)) -- slid right along the top, out of the stack
		local leftHigh = Requests.edge(Vector3.new(-4000, -1000, 10), VIEW, insets, corner) -- the left at y ~196
		expect(leftHigh.position.X).toBe(40)
		expect(leftHigh.position.Y).toBe(200) -- slid down along the left edge
		local leftLow = Requests.edge(Vector3.new(-4000, 400, 10), VIEW, insets, corner)
		expect(leftLow.position.Y > 200).toBe(true) -- below the stack: untouched
	end)

	it("group(): close badges share one led by the first (oldest); at most max", function()
		local groups = Requests.group({
			{ entityId = 1, position = Vector2.new(766, 300), angle = 0 },
			{ entityId = 2, position = Vector2.new(766, 330), angle = 2 }, -- 30 px: joins 1
			{ entityId = 3, position = Vector2.new(766, 500), angle = 20 },
			{ entityId = 4, position = Vector2.new(34, 300), angle = 180 },
		}, 52, 2)
		expect(#groups).toBe(2)
		expect(groups[1].entityId).toBe(1)
		expect(groups[1].count).toBe(2)
		expect(groups[1].ids).toEqual({ 1, 2 })
		expect(groups[2].entityId).toBe(3) -- 4 does not fit (max 2)
	end)
end)

describe("Feedback/Bubbles:requests (FL-0115 B16)", function()
	it("lists live '!' thoughts only; a repeat keeps when the request first showed", function()
		local now = 100
		local bubbles = Bubbles.new({
			now = function()
				return now
			end,
		})
		bubbles:thought(1, { text = "We are hungry", icon = "request", scenarioId = "hungry" })
		bubbles:thought(2, { text = "Hmm", icon = "concern" })
		bubbles:thought(3, { text = "Build a well", icon = "request", scenarioId = "well" })
		now = 110
		bubbles:thought(1, { text = "We are hungry", icon = "request", scenarioId = "hungry" }) -- repeated
		bubbles:thought(3, { text = "A market, then?", icon = "request", scenarioId = "market" }) -- a new one
		local byId = {}
		for _, r in bubbles:requests() do
			byId[r.entityId] = r.since
		end
		expect(byId).toEqual({ [1] = 100, [3] = 110 })
		bubbles:reaction(1, { text = "Thank you", tone = "happy" }) -- answered
		now = 110 + Bubbles.DEFAULTS.thoughtSec + 1 -- 3 expired (no tick yet)
		expect(bubbles:requests()).toEqual({})
	end)
end)

describe("CitizenBubbleIndicatorController (FL-0115 B16)", function()
	it("aims at the bubble where CitizenBubbleController draws it, over the scaled rig (D-059)", function()
		expect(IndicatorDef.HEIGHT).toBe(BubbleDef.HEIGHT)
	end)

	local env, registry, controller, requests, focused, selected, input, talk, userInput, playerGui, keysDown, camera

	local function boot(withBubbles, hud)
		local defs = {
			{
				name = "RulerCameraController",
				new = function()
					return camera
				end,
			},
			{
				name = "InputModeController",
				new = function()
					return input
				end,
			},
			{
				name = "ConversationController",
				new = function()
					return talk
				end,
			},
			{
				name = "CitizenBubbleIndicatorController",
				new = function(e, r)
					return IndicatorDef.create(e, r, {
						playerGui = playerGui,
						viewport = VIEW,
						userInput = userInput,
						-- world X -> screen X, world Z -> screen Y; a negative Y is behind the camera
						project = function(p)
							return Vector3.new(p.X, p.Z, if p.Y < 0 then -1 else 1)
						end,
					})
				end,
			},
		}
		if hud ~= nil then
			table.insert(defs, {
				name = "KingdomHudController",
				new = function()
					return hud
				end,
			})
		end
		if withBubbles ~= false then
			table.insert(defs, {
				name = "CitizenBubbleController",
				new = function()
					return {
						requests = function()
							return requests
						end,
					}
				end,
			})
		end
		registry = Loader.load(env, defs)
		controller = registry:get("CitizenBubbleIndicatorController")
	end

	local function badges()
		local out = {}
		local gui = playerGui:FindFirstChild("ForgeRequestIndicators")
		for _, child in gui:GetChildren() do
			if child:IsA("TextButton") and child.Visible then
				out[child:GetAttribute("EntityId")] = child
			end
		end
		return out
	end

	local function press(key, processed)
		userInput.InputBegan:Fire({ UserInputType = Enum.UserInputType.Keyboard, KeyCode = key }, processed == true)
	end

	beforeEach(function()
		Create.useTestConnector()
		env = MockEnv.new({ seed = 116, isServer = false, localPlayer = { userId = 11601 } })
		focused, selected, keysDown = {}, {}, {}
		playerGui = roblox.Instance.new("Folder")
		userInput = { InputBegan = MockSignal.new({ name = "UserInputService.InputBegan" }) }
		function userInput:IsKeyDown(key)
			return keysDown[key] == true
		end
		input = {
			mode = "explore",
			changed = Signal.new(),
			accepts = function(self, mode)
				return self.mode == mode
			end,
			select = function(_, kind, id)
				table.insert(selected, `{kind}:{id}`)
				return true
			end,
		}
		talk = { opened = Signal.new(), closed = Signal.new() }
		camera = {
			mode = "overview",
			focusOn = function(_, position)
				table.insert(focused, position)
				return true
			end,
		}
		requests = {
			{ entityId = 7, position = Vector3.new(400, 0, 300), since = 5 }, -- on screen
			{ entityId = 8, position = Vector3.new(1600, 0, 300), since = 1 }, -- far to the right
			{ entityId = 9, position = Vector3.new(400, 0, -900), since = 3 }, -- far up
		}
		boot()
	end)

	it("shows a badge at the edge for each off-screen request, pointing at it; none for on-screen ones", function()
		controller:refresh()
		local shown = badges()
		expect(shown[7]).toBeNil()
		local insets, corner = IndicatorDef.insets(VIEW)
		local function expected(position)
			local q = Requests.edge(Vector3.new(position.X, position.Z, 1), VIEW, insets, corner).position
			return UDim2.fromOffset(math.floor(q.X + 0.5), math.floor(q.Y + 0.5))
		end
		expect(shown[8].Position).toEqual(expected(Vector3.new(1600, 0, 300)))
		expect(shown[8]:FindFirstChild("Pointer").Rotation > -5 and shown[8]:FindFirstChild("Pointer").Rotation < 5).toBe(
			true
		)
		expect(shown[9].Position).toEqual(expected(Vector3.new(400, 0, -900)))
		expect(near(shown[9]:FindFirstChild("Pointer").Rotation, -90)).toBe(false) -- pointed from the inset centre
		expect(shown[9]:FindFirstChild("Pointer").Rotation < -80).toBe(true)
		expect(shown[8].Size).toEqual(UDim2.fromOffset(IndicatorDef.SIZE, IndicatorDef.SIZE)) -- 44 px
		-- TIP covers the drawn arrow (a square turned 45° on the rim, plus its stroke at the corner), and the
		-- plain INSET keeps that tip inside the area
		local arrow = shown[8]:FindFirstChild("Pointer"):FindFirstChild("Arrow")
		local stroke = arrow:FindFirstChildOfClass("UIStroke")
		expect(arrow.Rotation).toBe(45)
		expect(arrow.Size.X.Offset / math.sqrt(2) + stroke.Thickness * math.sqrt(2) <= IndicatorDef.TIP).toBe(true)
		expect(IndicatorDef.SIZE / 2 + IndicatorDef.TIP <= IndicatorDef.INSET).toBe(true)
		expect(shown[8]:FindFirstChild("Disc").Text).toBe("!") -- the glyph, never colour alone
		expect(shown[8]:FindFirstChild("Count").Visible).toBe(false)
		expect(controller:count()).toBe(3)
	end)

	it("keeps clear of FORGE-03's HUD: the right-edge rail, the top row and the bottom bar (UI/Layout)", function()
		local Layout = require("@game/StarterPlayer/StarterPlayerScripts/Game/UI/Layout")
		for _, size in { Vector2.new(844, 371), VIEW, Vector2.new(1920, 1022) } do
			local m = Layout.compute(size.X, size.Y)
			local insets, corner = IndicatorDef.insets(size)
			-- the badge plus its arrow's tip (TIP: the arrow points at the edge it sits on)
			local radius = IndicatorDef.SIZE / 2 + IndicatorDef.TIP
			-- the badge's right side stays left of the rail's buttons
			expect(size.X - insets.right + radius <= size.X - (m.rail.right + m.rail.button) * m.scale).toBe(true)
			-- the badge's top stays below the crest row; its bottom above the placement bar and the chips
			expect(insets.top - radius >= (m.hud.y + m.hud.crest) * m.scale).toBe(true)
			expect(size.Y - insets.bottom + radius <= size.Y - (m.place.bottom + m.place.height) * m.scale).toBe(true)
			expect(corner.Y - radius >= m.hud.bottom * m.scale).toBe(true) -- below the top-left stack
			-- with FORGE-03's support chip showing, the corner reaches below and right of the chip too
			local ms = Layout.compute(size.X, size.Y, { support = true })
			local _, withChip = IndicatorDef.insets(size, true)
			local chip = ms.hud.support
			expect(withChip.Y - radius >= (chip.y + chip.height) * ms.scale).toBe(true)
			expect(withChip.X - radius >= (chip.x + chip.width) * ms.scale).toBe(true)
			expect(withChip.Y > corner.Y).toBe(true)
		end
	end)

	it("reads the HUD's support chip when placing badges (dark until Kingdom.Support is served)", function()
		local hud = { state = { support = false } }
		boot(true, hud)
		expect(controller:_supportShown()).toBe(false)
		hud.state.support = true
		expect(controller:_supportShown()).toBe(true)
		-- refresh places the badges with the HUD's chip state
		local seen = {}
		local original = IndicatorDef.insets
		IndicatorDef.insets = function(size, support)
			table.insert(seen, support)
			return original(size, support)
		end
		local ok, err = pcall(function()
			controller:refresh()
			hud.state.support = false
			controller:refresh()
		end)
		IndicatorDef.insets = original
		assert(ok, err)
		expect(seen).toEqual({ true, false })
		boot(true, nil)
		expect(controller:_supportShown()).toBe(false) -- no HUD: no chip
	end)

	it("requests close together share one badge with a count; at most MAX badges", function()
		requests = {}
		for i = 1, 10 do
			table.insert(requests, { entityId = i, position = Vector3.new(2000, 0, 300 + i), since = i })
		end
		controller:refresh()
		local shown = badges()
		expect(shown[1]:FindFirstChild("Count").Visible).toBe(true)
		expect(shown[1]:FindFirstChild("Count").Text).toBe("10")
		local visible = 0
		for _ in shown do
			visible += 1
		end
		expect(visible).toBe(1)
	end)

	it("a tap on a badge centres the camera on the citizen and selects them (FORGE-03's card opens)", function()
		controller:refresh()
		expect(Create.fire(badges()[8], "Activated")).toBe(1)
		expect(focused).toEqual({ Vector3.new(1600, 0, 300) })
		expect(selected).toEqual({ "citizen:8" })
	end)

	it("F / DPadRight go to the next open request, oldest first; Shift+F / DPadLeft go back; wraps", function()
		press(Enum.KeyCode.F)
		press(Enum.KeyCode.DPadRight)
		press(Enum.KeyCode.F)
		press(Enum.KeyCode.F) -- wraps to the oldest again
		expect(selected).toEqual({ "citizen:8", "citizen:9", "citizen:7", "citizen:8" })
		press(Enum.KeyCode.DPadLeft)
		keysDown[Enum.KeyCode.LeftShift] = true
		press(Enum.KeyCode.F)
		expect(selected).toEqual({ "citizen:8", "citizen:9", "citizen:7", "citizen:8", "citizen:7", "citizen:9" })
		expect(#focused).toBe(6)
		keysDown[Enum.KeyCode.LeftShift] = nil
		press(Enum.KeyCode.F, true) -- typing in a TextBox: nothing
		press(Enum.KeyCode.G)
		expect(#selected).toBe(6)
		expect(controller:cycleRequests()).toBe(7) -- the API FORGE-03's control calls
	end)

	it("hides and stops while placing or editing, and during a conversation", function()
		controller:refresh()
		expect(badges()[8]).never.toBeNil()
		expect(controller:active()).toBe(true)
		input.mode = "build"
		input.changed:fire("build", "explore")
		expect(badges()[8]).toBeNil()
		expect(controller:active()).toBe(false)
		press(Enum.KeyCode.F)
		expect(controller:cycleRequests()).toBeNil()
		expect(controller:focusRequest(8)).toBe(false)
		input.mode = "explore"
		input.changed:fire("explore", "build")
		expect(badges()[8]).never.toBeNil()
		talk.opened:fire(8, Vector3.zero)
		expect(badges()[8]).toBeNil()
		expect(controller:active()).toBe(false)
		press(Enum.KeyCode.F)
		expect(selected).toEqual({})
		talk.closed:fire(8)
		expect(badges()[8]).never.toBeNil()
		expect(controller:active()).toBe(true)
	end)

	it("hides while walking (the follow camera): a focus would not move the view", function()
		camera.mode = "follow"
		controller:refresh()
		expect(badges()[8]).toBeNil()
		expect(controller:active()).toBe(false) -- FORGE-03's "citizens waiting" button hides too (#168)
		press(Enum.KeyCode.F)
		expect(selected).toEqual({})
		camera.mode = "overview"
		controller:refresh()
		expect(badges()[8]).never.toBeNil()
	end)

	it("destroy() disconnects everything: Roblox input and the Forge signals (input mode, conversation)", function()
		local held = table.clone(controller._connections)
		expect(#held >= 4).toBe(true) -- InputBegan, input changed, conversation opened and closed
		controller:destroy()
		for index, connection in held do
			local connected = if connection.connected ~= nil then connection.connected else connection.Connected
			expect(`{index}: connected {connected}`).toBe(`{index}: connected false`)
		end
		expect(userInput.InputBegan:connectionCount()).toBe(0)
		expect(playerGui:FindFirstChild("ForgeRequestIndicators")).toBeNil()
	end)

	it("runs inert without CitizenBubbleController (headless boot)", function()
		local bare = MockEnv.new({ seed = 117, isServer = false, localPlayer = { userId = 11602 } })
		local reg = Loader.load(bare, { IndicatorDef })
		bare.mock:advance(1)
		local inert = reg:get("CitizenBubbleIndicatorController")
		expect(inert:count()).toBe(0)
		expect(inert:active()).toBe(false)
		expect(inert:cycleRequests()).toBeNil()
		expect(bare.mock:hasLog("info", "no CitizenBubbleController")).toBe(true)
		expect(bare.mock.threadErrors).toEqual({})
	end)
end)

describe("CitizenBubbleController:requests with the indicators (FL-0115 B16)", function()
	it("an off-screen citizen's request gets a badge; the citizen in the conversation does not", function()
		Create.useTestConnector()
		local env = MockEnv.new({ seed = 118, isServer = false, localPlayer = { userId = 11801 } })
		local signals = { rendered = Signal.new(), released = Signal.new(), event = Signal.new() }
		local talk = { opened = Signal.new(), closed = Signal.new() }
		local playerGui = roblox.Instance.new("Folder")
		local function rig(x, z)
			local model = roblox.Instance.new("Model")
			local part = roblox.Instance.new("Part")
			part.CFrame = roblox.CFrame.new(x, 0, z)
			part.Parent = model
			model.PrimaryPart = part
			return model
		end
		local project = function(p)
			return Vector3.new(p.X, p.Z, if p.Y < 0 then -1 else 1)
		end
		local reg = Loader.load(env, {
			{
				name = "EntityController",
				new = function()
					return signals
				end,
			},
			{
				name = "ConversationController",
				new = function()
					return talk
				end,
			},
			{
				name = "CitizenBubbleController",
				new = function(e, r)
					return BubbleDef.create(e, r, {
						origin = function()
							return Vector3.new(400, 0, 300)
						end,
						playerGui = playerGui,
						project = function(p)
							local q = project(p)
							return if q.Z > 0 then Vector2.new(q.X, q.Y) else nil
						end,
					})
				end,
			},
			{
				name = "CitizenBubbleIndicatorController",
				new = function(e, r)
					return IndicatorDef.create(e, r, { playerGui = playerGui, viewport = VIEW, project = project })
				end,
			},
		})
		local far, close = rig(2400, 300), rig(420, 300)
		signals.rendered:fire(21, far)
		signals.rendered:fire(22, close)
		signals.event:fire(21, "thought", { text = "The granary is empty", icon = "request" }, far)
		signals.event:fire(22, "thought", { text = "Can we talk?", icon = "request" }, close)
		local indicators = reg:get("CitizenBubbleIndicatorController")
		indicators:refresh()
		expect(#reg:get("CitizenBubbleController"):requests()).toBe(2)
		expect(indicators.shown[1].entityId).toBe(21) -- only the off-screen one
		expect(indicators.shown[2]).toBeNil()
		talk.opened:fire(21, Vector3.zero)
		local listed = {}
		for _, r in reg:get("CitizenBubbleController"):requests() do
			table.insert(listed, r.entityId)
		end
		expect(listed).toEqual({ 22 }) -- the citizen being talked to is not listed
		expect(env.mock.threadErrors).toEqual({})
	end)
end)
