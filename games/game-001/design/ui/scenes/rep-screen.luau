-- FL-0089 scene "rep-screen": the reputation screen, Compassion selected, with the content library's category texts.
local scene = require("./_reputation")
return function(ctx)
	return scene(ctx, {}, function(_, _, rep)
		rep:open()
	end)
end
