-- FL-0073 scene "support-hud": the HUD with the support chip under the reputation strip (Adoring, rising).
local scene = require("./_support")
return function(ctx)
	return scene(ctx, {}, nil)
end
