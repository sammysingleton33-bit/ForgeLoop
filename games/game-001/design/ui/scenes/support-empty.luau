-- FL-0073 scene "support-empty": the breakdown at the start of a match: neutral components, no moments yet.
local scene = require("./_support")
return function(ctx)
	return scene(ctx, { profile = "empty" }, function(_, _, sup)
		sup:open()
	end)
end
