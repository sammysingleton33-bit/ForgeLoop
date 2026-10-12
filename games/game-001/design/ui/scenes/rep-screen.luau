-- FL-0089 scene "rep-screen": the reputation screen, Compassion selected, with SAMPLE category texts.
local scene = require("./_reputation")
return function(ctx)
	return scene(ctx, { content = true }, function(_, _, rep)
		rep:open()
	end)
end
