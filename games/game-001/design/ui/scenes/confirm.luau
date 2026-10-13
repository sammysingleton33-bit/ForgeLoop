-- FL-0059 scene "confirm": the large-spend confirmation before the keep upgrade.
local BuildModel = require("@game/StarterPlayer/StarterPlayerScripts/Game/UI/BuildModel")
local scene = require("./_world")
return function(ctx)
	return scene(ctx, { treasury = { food = 132, wood = 300, stone = 300, gold = 0 } }, function(_, hud)
		hud:setMenu("kingdom")
		hud:openUpgrade(1)
		hud:requestUpgrade(BuildModel.upgradeDetail(hud.store, hud.store:keep()))
	end)
end
