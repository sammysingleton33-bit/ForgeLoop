-- D-059 scenes "start" and "start-card-docked": the kingdom HUD at the match's first second (Founding 0:01, the
-- starting treasury, nothing built, no toasts) with FORGE-04's onboarding card as the server's first "vs1" snapshot
-- puts it. Rendered with --backdrop=none and laid over FORGE-02's start-frame render (render_world.py, the FL-0147
-- camera) for the owner's first impression. opts.dockCard moves the card to the bottom centre: a proposal for
-- FORGE-04 (the card is theirs), not what the game ships.
local OnboardingConfig = require("@game/ReplicatedStorage/Forge/Config/Onboarding")
local NotificationDef = require("@game/StarterPlayer/StarterPlayerScripts/Forge/Controllers/NotificationController")
local OnboardingDef = require("@game/StarterPlayer/StarterPlayerScripts/Forge/Controllers/OnboardingController")
local SettingsDef = require("@game/StarterPlayer/StarterPlayerScripts/Forge/Controllers/SettingsController")
local scene = require("./_world")

local function firstFlow()
	for _, flow in OnboardingConfig.flows do
		if flow.id == "vs1" then
			return flow
		end
	end
	error("_start: no vs1 flow in config/Onboarding")
end

return function(ctx, opts: { dockCard: boolean? }?)
	local o = opts or {}
	return scene(ctx, {
		bare = true,
		clientDefinitions = { SettingsDef, NotificationDef, OnboardingDef },
		extraGuis = { "ForgeOnboarding", "ForgeNotifications" },
	}, function(world)
		local flow = firstFlow()
		local step = flow.steps[1]
		world.client:get("OnboardingController"):apply({
			flowId = flow.id,
			total = #flow.steps,
			completed = {},
			step = 1,
			stepId = step.id,
			hint = step.hint,
			done = false,
			skipped = false,
		})
		if o.dockCard then
			local root = world.client:get("KingdomHudController").roots.hud
			local playerGui = root and root:FindFirstAncestorOfClass("PlayerGui")
			local gui = playerGui and playerGui:FindFirstChild("ForgeOnboarding")
			local card = gui and gui:FindFirstChild("Card")
			assert(card, "_start: the onboarding card was not built")
			card.AnchorPoint = Vector2.new(0.5, 1)
			card.Position = UDim2.new(0.5, 0, 1, -16)
		end
		world:advance(1)
	end)
end
