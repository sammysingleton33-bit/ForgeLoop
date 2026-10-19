-- FL-0073 scene "support-panel": the support breakdown (Adoring): tier, trend, arena line, components, latest moments.
local scene = require("./_support")
return function(ctx)
	return scene(ctx, {}, function(_, _, sup)
		sup:open()
	end)
end
