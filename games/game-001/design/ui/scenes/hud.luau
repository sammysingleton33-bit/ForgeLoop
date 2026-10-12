-- FL-0059 scene "hud": the always-on HUD (prototype scene "hud").
local scene = require("./_world")
return function(ctx)
	return scene(ctx, {}, nil)
end
