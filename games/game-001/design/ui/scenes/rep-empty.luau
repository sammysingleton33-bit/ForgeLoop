-- FL-0089 scene "rep-empty": the History tab of a ruler with no changes yet.
local scene = require("./_reputation")
return function(ctx)
	return scene(ctx, { profile = "empty" }, function(_, _, rep)
		rep:open()
		rep:selectTab("history")
	end)
end
