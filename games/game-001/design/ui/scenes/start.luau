-- D-059 scene "start": the kingdom HUD at the match's first second (Founding 0:01, the starting treasury, nothing
-- built, no toasts), with FORGE-04's onboarding card as the real client shows it. Rendered with --backdrop=none and
-- laid over FORGE-02's start-frame render (render_world.py, the FL-0147 camera) for the owner's first impression.
local NotificationDef = require("@game/StarterPlayer/StarterPlayerScripts/Forge/Controllers/NotificationController")
local OnboardingDef = require("@game/StarterPlayer/StarterPlayerScripts/Forge/Controllers/OnboardingController")
local SettingsDef = require("@game/StarterPlayer/StarterPlayerScripts/Forge/Controllers/SettingsController")
local scene = require("./_world")
return function(ctx)
	return scene(ctx, {
		bare = true,
		clientDefinitions = { SettingsDef, NotificationDef, OnboardingDef },
		extraGuis = { "ForgeOnboarding", "ForgeNotifications" },
	}, function(world)
		world:advance(1)
	end)
end
