-- FL-0089 scene "rep-nocontent": the screen as it ships before FL-0083 (no category prose).
local scene = require("./_reputation")
return function(ctx)
	return scene(ctx, {}, function(_, _, rep)
		rep:open()
		rep:select("compassion")
	end)
end
