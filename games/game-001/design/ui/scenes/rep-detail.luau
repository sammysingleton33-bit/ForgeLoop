-- FL-0089 scene "rep-detail": Honor selected (phones: its detail pane with the back link).
local scene = require("./_reputation")
return function(ctx)
	return scene(ctx, { content = true }, function(_, _, rep)
		rep:open()
		rep:select("honor")
	end)
end
