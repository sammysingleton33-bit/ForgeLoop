-- FL-0059 scene "upgrade": the keep's upgrade detail with enough stone and wood.
local scene = require("./_world")
return function(ctx)
	return scene(ctx, { treasury = { food = 132, wood = 180, stone = 160, gold = 0 } }, function(_, hud)
		hud:setMenu("kingdom")
		hud:openUpgrade(1)
	end)
end
