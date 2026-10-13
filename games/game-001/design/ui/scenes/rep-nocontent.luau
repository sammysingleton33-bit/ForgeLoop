-- FL-0089 scene "rep-nocontent": the fallback without a text provider (no category prose).
local scene = require("./_reputation")
return function(ctx)
	return scene(ctx, { content = false }, function(_, _, rep)
		rep:open()
		rep:select("compassion")
	end)
end
