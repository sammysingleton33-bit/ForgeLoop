-- FL-0089 scene "rep-hud": the HUD with the reputation strip (prototype scene "hud").
local scene = require("./_reputation")
return function(ctx)
	return scene(ctx, {}, nil)
end
