local T = require("../../harness/Test")
local describe, it, expect, beforeEach = T.describe, T.it, T.expect, T.beforeEach

local MockEnv = require("../../mocks/MockEnv")
local Loader = require("@game/ReplicatedStorage/Forge/Contracts/Loader")
local SettingsDef = require("@game/StarterPlayer/StarterPlayerScripts/Forge/Controllers/SettingsController")
local OnboardingDef = require("@game/StarterPlayer/StarterPlayerScripts/Forge/Controllers/OnboardingController")

-- Hint text is game data (config.idleHints); the framework holds none.
local IDLE_HINTS = { Expansion = "Try a building you have not built yet.", Conflict = "Rivals are near." }

describe("OnboardingController (client)", function()
	local env, controller, gui, remotes, notifications, settings

	local function remote(name)
		local root = env.ReplicatedStorage:FindFirstChild("ForgeRemotes")
		if root == nil then
			root = env.newInstance("Folder")
			root.Name = "ForgeRemotes"
			root.Parent = env.ReplicatedStorage
		end
		local area = root:FindFirstChild("Experience")
		if area == nil then
			area = env.newInstance("Folder")
			area.Name = "Experience"
			area.Parent = root
		end
		local instance = env.newInstance("RemoteEvent")
		instance.Name = name
		instance.Parent = area
		return instance
	end

	local function state(fields)
		local base = {
			flowId = "first_session",
			total = 9,
			completed = 1,
			step = 2,
			stepId = "MoveRuler",
			clientAction = "RulerMoved",
			hint = { title = "Walk to the landmark", body = "Move with WASD.", target = nil },
			escalated = false,
			done = false,
			skipped = false,
		}
		for k, v in fields or {} do
			base[k] = v
		end
		return base
	end

	beforeEach(function()
		env = MockEnv.new({ isServer = false, localPlayer = { userId = 1001 }, services = { GuiService = {} } })
		remotes = {
			state = remote("OnboardingState"),
			action = remote("OnboardingAction"),
			skip = remote("OnboardingSkip"),
		}
		gui = env.newInstance("Folder")
		gui.Name = "PlayerGui"
		gui.Parent = env.mock.localPlayer
		notifications = { shown = {} }
		function notifications.show(_, n)
			table.insert(notifications.shown, n)
		end
		notifications.reserved = {}
		function notifications.reserveTop(_, owner, px)
			table.insert(notifications.reserved, `{owner}:{tostring(px)}`)
		end
		notifications.celebrated = {}
		function notifications.celebrate(_, kind, payload)
			table.insert(notifications.celebrated, { kind = kind, payload = payload })
			return true
		end
		local registry = Loader.load(env, {
			SettingsDef,
			{
				name = "OnboardingController",
				dependencies = { "SettingsController" },
				new = function(e, r)
					return OnboardingDef.create(e, r, { playerGui = gui, idleHints = IDLE_HINTS })
				end,
			},
			{
				name = "NotificationController",
				new = function()
					return notifications
				end,
			},
		})
		controller = registry:get("OnboardingController")
		settings = registry:get("SettingsController")
		env.mock:advance(0.1) -- RemoteLink finds the remotes
	end)

	it("renders the server's step as a small non-modal card with a counter and Skip", function()
		remotes.state:FireClient(env.mock.localPlayer, state())
		env.mock:advance(0)
		local screen = gui:FindFirstChild("ForgeOnboarding")
		expect(screen).never.toBeNil()
		expect(screen.DisplayOrder).toBe(60)
		local card = screen:FindFirstChild("Card")
		expect(card:FindFirstChild("Title").Text).toBe("Walk to the landmark")
		expect(card:FindFirstChild("Counter").Text).toBe("2/9")
		local skip = card:FindFirstChild("Skip")
		expect(skip.Size.Y.Offset).toBeGreaterThanOrEqual(44)
		expect(card.Size.Y.Offset).toBeLessThanOrEqual(88)
	end)

	it("marks the nearest tagged world object to the character", function()
		local character = env.newInstance("Model")
		local root = env.newInstance("Part")
		root.Position = Vector3.new(0, 0, 0)
		root.Parent = character
		character.PrimaryPart = root
		env.mock.localPlayer.Character = character
		local far = env.newInstance("Part")
		far.Position = Vector3.new(300, 0, 0)
		far.Parent = env.Workspace
		env.CollectionService:AddTag(far, "ResourceNode")
		local near = env.newInstance("Part")
		near.Position = Vector3.new(20, 0, 0)
		near.Parent = env.Workspace
		env.CollectionService:AddTag(near, "ResourceNode")
		local gather = state({ hint = { title = "Gather", target = { kind = "world", tag = "ResourceNode" } } })
		controller:apply(gather)
		expect(near:FindFirstChild("ForgeOnboardingHighlight")).never.toBeNil()
		expect(far:FindFirstChild("ForgeOnboardingHighlight")).toBeNil()
		root.Position = Vector3.new(290, 0, 0) -- walk over to the other node: the mark follows
		controller:apply(gather)
		expect(far:FindFirstChild("ForgeOnboardingHighlight")).never.toBeNil()
		expect(near:FindFirstChild("ForgeOnboardingHighlight")).toBeNil()
	end)

	it("marks world targets with a highlight and an arrow, UI targets with a stroke; gold when stuck", function()
		local castle = env.newInstance("Part")
		castle.Parent = env.Workspace
		env.CollectionService:AddTag(castle, "Landmark")
		controller:apply(state({ hint = { title = "Go", target = { kind = "world", tag = "Landmark" } } }))
		expect(castle:FindFirstChild("ForgeOnboardingHighlight")).never.toBeNil()
		expect(castle:FindFirstChild("ForgeOnboardingArrow")).never.toBeNil()
		local button = env.newInstance("TextButton")
		button:SetAttribute("OnboardingTarget", "HUD.BuildButton")
		button.Parent = gui
		controller:apply(
			state({ escalated = true, hint = { title = "Build", target = { kind = "ui", name = "HUD.BuildButton" } } })
		)
		expect(castle:FindFirstChild("ForgeOnboardingHighlight")).toBeNil()
		local stroke = button:FindFirstChild("ForgeOnboardingStroke")
		expect(stroke).never.toBeNil()
		expect(stroke.Thickness).toBe(4)
	end)

	it("celebrates when the last step completes, never on skip or on a late snapshot that is already done", function()
		controller:apply(state({ done = true, hint = nil })) -- joined with the tutorial already finished
		expect(#notifications.celebrated).toBe(0)
		controller:apply(state())
		controller:apply(state({ done = true, hint = nil }))
		expect(#notifications.celebrated).toBe(1)
		expect(notifications.celebrated[1].kind).toBe("onboardingComplete")
		controller:apply(state())
		controller:skip()
		expect(#notifications.celebrated).toBe(1)
	end)

	it("keeps the toast stack below the card while it shows, and frees the space when it hides", function()
		controller:apply(state())
		expect(notifications.reserved[#notifications.reserved]).toBe(`onboarding:{OnboardingDef.CARD_RESERVE}`)
		expect(OnboardingDef.CARD_RESERVE).toBe(OnboardingDef.CARD_TOP + OnboardingDef.CARD_HEIGHT + 8)
		controller:skip()
		expect(notifications.reserved[#notifications.reserved]).toBe("onboarding:nil")
	end)

	it("Skip tells the server and hides the card at once", function()
		controller:apply(state())
		controller:skip()
		local sent = env.mock.remotes:sent(remotes.skip, "toServer")
		expect(#sent).toBe(1)
		expect(sent[1].args[1]).toBe("first_session")
		expect(gui:FindFirstChild("ForgeOnboarding").Enabled).toBe(false)
	end)

	it("reports RulerMoved after the character walks MOVE_STUDS, and only then", function()
		local character = env.newInstance("Model")
		local root = env.newInstance("Part")
		root.Name = "HumanoidRootPart"
		root.Position = Vector3.new(0, 3, 0)
		root.Parent = character
		character.PrimaryPart = root
		character.Parent = env.Workspace
		env.mock.localPlayer.Character = character
		controller:apply(state())
		env.mock:advance(1)
		expect(#env.mock.remotes:sent(remotes.action, "toServer")).toBe(0)
		root.Position = Vector3.new(9, 3, 0)
		env.mock:advance(0.5)
		local sent = env.mock.remotes:sent(remotes.action, "toServer")
		expect(#sent).toBe(1)
		expect(sent[1].args[2]).toBe("RulerMoved")
	end)

	it("reports ReachedTarget near the step's tagged world target", function()
		local character = env.newInstance("Model")
		local root = env.newInstance("Part")
		root.Position = Vector3.new(0, 0, 0)
		root.Parent = character
		character.PrimaryPart = root
		env.mock.localPlayer.Character = character
		local castle = env.newInstance("Part")
		castle.Position = Vector3.new(40, 0, 0)
		castle.Parent = env.Workspace
		env.CollectionService:AddTag(castle, "Landmark")
		controller:apply(state({
			step = 3,
			stepId = "FindKingdom",
			clientAction = "ReachedTarget",
			hint = { title = "Go", target = { kind = "world", tag = "Landmark" } },
		}))
		env.mock:advance(1)
		expect(#env.mock.remotes:sent(remotes.action, "toServer")).toBe(0)
		root.Position = Vector3.new(30, 0, 0)
		env.mock:advance(0.5)
		expect(env.mock.remotes:sent(remotes.action, "toServer")[1].args[2]).toBe("ReachedTarget")
	end)

	it("UI code reports actions through report(); nothing is sent once the tutorial is done", function()
		controller:apply(state({ clientAction = "ResourceInspected" }))
		expect(controller:report("RulerMoved")).toBe(false) -- not the current step's action: not sent
		expect(controller:report("ResourceInspected")).toBe(true)
		local sent = env.mock.remotes:sent(remotes.action, "toServer")
		expect(#sent).toBe(1)
		controller:apply(state({ done = true, hint = nil }))
		expect(controller:report("ResourceInspected")).toBe(false)
	end)

	it("shows idle hints only after the tutorial and only with showHints on", function()
		controller:apply(state())
		expect(controller:showIdleHint("Expansion")).toBe(false)
		controller:apply(state({ done = true, hint = nil }))
		expect(controller:showIdleHint("Founding")).toBe(false) -- no text for that phase
		expect(controller:showIdleHint("Expansion")).toBe(true)
		expect(notifications.shown[1].title).toBe(IDLE_HINTS.Expansion)
		settings:set("showHints", false)
		expect(controller:showIdleHint("Conflict")).toBe(false)
	end)

	-- A tip's snapshot (FL-0137): one step, no client action.
	local function tipState(id, fields)
		local base = {
			flowId = id,
			tip = true,
			total = 1,
			completed = 0,
			step = 1,
			stepId = "Tip",
			hint = { title = `tip {id}`, body = "Press G." },
			escalated = false,
			done = false,
			skipped = false,
		}
		for k, v in fields or {} do
			base[k] = v
		end
		return base
	end

	local function card()
		return gui:FindFirstChild("ForgeOnboarding"):FindFirstChild("Card")
	end

	it("a tip waits while the tutorial card shows, then shows with Got it and no counter (FL-0137)", function()
		controller:apply(state())
		controller:apply(tipState("tip_siege"))
		expect(card():FindFirstChild("Title").Text).toBe("Walk to the landmark") -- the tutorial wins
		expect(controller.state.flowId).toBe("first_session") -- the tip never replaces the tutorial's state
		expect(controller.tip).toBeNil()
		controller:apply(state({ done = true, hint = nil }))
		expect(card():FindFirstChild("Title").Text).toBe("tip tip_siege")
		expect(card():FindFirstChild("Skip").Text).toBe("Got it")
		expect(card():FindFirstChild("Counter").Text).toBe("")
		expect(controller.tip.flowId).toBe("tip_siege")
		expect(gui:FindFirstChild("ForgeOnboarding").Enabled).toBe(true)
		expect(notifications.reserved[#notifications.reserved]).toBe(`onboarding:{OnboardingDef.CARD_RESERVE}`)
		expect(controller:showIdleHint("Expansion")).toBe(false) -- the tip is already guiding
		-- the tutorial is back (a new snapshot): its own label and counter return
		controller:apply(state())
		expect(card():FindFirstChild("Skip").Text).toBe("Skip tutorial")
		expect(card():FindFirstChild("Counter").Text).toBe("2/9")
	end)

	it(
		"the newest tip shows; when it ends the older one comes back; a finished tip never celebrates (FL-0137)",
		function()
			controller:apply(tipState("tip_war_open"))
			controller:apply(tipState("tip_war_on_you"))
			expect(card():FindFirstChild("Title").Text).toBe("tip tip_war_on_you")
			controller:apply(tipState("tip_war_on_you", { done = true, completed = 1, step = nil, hint = nil }))
			expect(card():FindFirstChild("Title").Text).toBe("tip tip_war_open")
			controller:apply(tipState("tip_war_open", { done = true, completed = 1, step = nil, hint = nil }))
			expect(gui:FindFirstChild("ForgeOnboarding").Enabled).toBe(false)
			expect(notifications.reserved[#notifications.reserved]).toBe("onboarding:nil")
			expect(#notifications.celebrated).toBe(0)
			expect(controller.state).toBeNil()
		end
	)

	it(
		"Got it dismisses the tip on the server and hides it at once; the button keeps Skip for the tutorial (FL-0137)",
		function()
			controller:apply(tipState("tip_raid"))
			controller:dismissTip()
			local sent = env.mock.remotes:sent(remotes.skip, "toServer")
			expect(#sent).toBe(1)
			expect(sent[1].args[1]).toBe("tip_raid")
			expect(gui:FindFirstChild("ForgeOnboarding").Enabled).toBe(false)
			expect(controller.tip).toBeNil()
			controller:dismissTip() -- nothing shows: nothing sent
			expect(#env.mock.remotes:sent(remotes.skip, "toServer")).toBe(1)
			controller:skip() -- no tutorial: Skip sends nothing either
			expect(#env.mock.remotes:sent(remotes.skip, "toServer")).toBe(1)
			-- the card's button: Got it for a tip, Skip tutorial while the tutorial shows
			controller:apply(tipState("tip_siege"))
			controller:_onButton()
			expect(env.mock.remotes:sent(remotes.skip, "toServer")[2].args[1]).toBe("tip_siege")
			controller:apply(tipState("tip_ram"))
			controller:apply(state())
			controller:_onButton()
			expect(env.mock.remotes:sent(remotes.skip, "toServer")[3].args[1]).toBe("first_session")
			expect(controller.tip.flowId).toBe("tip_ram") -- skipping the tutorial leaves the tip to show
		end
	)

	it("no tip shows while showHints is off (FL-0137)", function()
		settings:set("showHints", false)
		controller:apply(tipState("tip_raid"))
		local screen = gui:FindFirstChild("ForgeOnboarding")
		expect(screen == nil or screen.Enabled == false).toBe(true)
		expect(controller.tip).toBeNil()
		controller:apply(state()) -- the tutorial itself is not a hint: it still shows
		expect(card():FindFirstChild("Title").Text).toBe("Walk to the landmark")
	end)
end)
