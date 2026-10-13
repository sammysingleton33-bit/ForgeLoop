-- FORGE-05 M1 on #33 scene "notify-drawer": FORGE-04's real NotificationController (interfaces §8)
-- placed by the HUD (KingdomHudController:_placeNotifications) with the Build drawer open and two
-- toasts showing: on phones the stack sits under the pills, clear of the drawer's tabs and Close and
-- of the rail; elsewhere left of the rail. SettingsController is a stand-in (notifications = "all").
local NotificationDef = require("@game/StarterPlayer/StarterPlayerScripts/Forge/Controllers/NotificationController")
local Signal = require("@game/ReplicatedStorage/Forge/Core/Signal")
local scene = require("./_world")

local settingsDef = {
	name = "SettingsController",
	new = function()
		return {
			changed = Signal.new(),
			get = function(_, key)
				return if key == "notifications" then "all" else nil
			end,
		}
	end,
}

return function(ctx)
	return scene(
		ctx,
		{ clientDefinitions = { settingsDef, NotificationDef }, extraGuis = { "ForgeNotifications" } },
		function(world, hud)
			hud:setMenu("build")
			hud:notify({ kind = "success", title = "Farm placed", body = "Builders are on their way" })
			hud:notify({ kind = "error", title = "Couldn't build here", body = "Not enough resources" })
			world:advance(0.3)
		end
	)
end
