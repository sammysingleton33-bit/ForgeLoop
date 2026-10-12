local T = require("../../harness/Test")
local describe, it, expect, beforeEach = T.describe, T.it, T.expect, T.beforeEach

local MockEnv = require("../../mocks/MockEnv")
local Loader = require("@game/ReplicatedStorage/Forge/Contracts/Loader")
local SettingsDef = require("@game/StarterPlayer/StarterPlayerScripts/Forge/Controllers/SettingsController")
local OnboardingDef = require("@game/StarterPlayer/StarterPlayerScripts/Forge/Controllers/OnboardingController")

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
			hint = { title = "Walk to your castle", body = "Move with WASD.", target = nil },
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
		local registry = Loader.load(env, {
			SettingsDef,
			{
				name = "OnboardingController",
				dependencies = { "SettingsController" },
				new = function(e, r)
					return OnboardingDef.create(e, r, { playerGui = gui })
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
		expect(card:FindFirstChild("Title").Text).toBe("Walk to your castle")
		expect(card:FindFirstChild("Counter").Text).toBe("2/9")
		local skip = card:FindFirstChild("Skip")
		expect(skip.Size.Y.Offset).toBeGreaterThanOrEqual(44)
		expect(card.Size.Y.Offset).toBeLessThanOrEqual(88)
	end)

	it("marks world targets with a highlight and an arrow, UI targets with a stroke; gold when stuck", function()
		local castle = env.newInstance("Part")
		castle.Parent = env.Workspace
		env.CollectionService:AddTag(castle, "OnboardingCastle")
		controller:apply(state({ hint = { title = "Go", target = { kind = "world", tag = "OnboardingCastle" } } }))
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

	it("reports ReachedCastle near the tagged castle", function()
		local character = env.newInstance("Model")
		local root = env.newInstance("Part")
		root.Position = Vector3.new(0, 0, 0)
		root.Parent = character
		character.PrimaryPart = root
		env.mock.localPlayer.Character = character
		local castle = env.newInstance("Part")
		castle.Position = Vector3.new(40, 0, 0)
		castle.Parent = env.Workspace
		env.CollectionService:AddTag(castle, "OnboardingCastle")
		controller:apply(state({ step = 3, stepId = "FindKingdom", clientAction = "ReachedCastle" }))
		env.mock:advance(1)
		expect(#env.mock.remotes:sent(remotes.action, "toServer")).toBe(0)
		root.Position = Vector3.new(30, 0, 0)
		env.mock:advance(0.5)
		expect(env.mock.remotes:sent(remotes.action, "toServer")[1].args[2]).toBe("ReachedCastle")
	end)

	it("UI code reports actions through report(); nothing is sent once the tutorial is done", function()
		controller:apply(state({ clientAction = "ResourceInspected" }))
		expect(controller:report("ResourceInspected")).toBe(true)
		controller:apply(state({ done = true, hint = nil }))
		expect(controller:report("ResourceInspected")).toBe(false)
	end)

	it("shows idle hints only after the tutorial and only with showHints on", function()
		controller:apply(state())
		expect(controller:showIdleHint("Development")).toBe(false)
		controller:apply(state({ done = true, hint = nil }))
		expect(controller:showIdleHint("Development")).toBe(true)
		expect(notifications.shown[1].title).toBe("Upgrade your Town Hall to unlock new buildings.")
		settings:set("showHints", false)
		expect(controller:showIdleHint("Competition")).toBe(false)
	end)
end)
