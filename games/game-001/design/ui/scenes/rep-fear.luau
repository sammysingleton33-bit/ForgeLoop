-- FL-0089 scene "rep-fear": a fear-heavy ruler, Fear selected, with the content library's category texts.
local scene = require("./_reputation")
return function(ctx)
	return scene(ctx, { profile = "fear" }, function(_, _, rep)
		rep:open()
		rep:select("fear")
	end)
end
