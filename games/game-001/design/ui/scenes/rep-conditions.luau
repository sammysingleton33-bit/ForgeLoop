-- FL-0089 scene "rep-conditions": the Kingdom tab (happiness, stability, army morale).
local scene = require("./_reputation")
return function(ctx)
	return scene(ctx, {}, function(_, _, rep)
		rep:open()
		rep:selectTab("kingdom")
	end)
end
