-- FL-0087 scene "plot-pick-list": a large plot tapped; the list (phones show it first).
local scene = require("./_plots")
return function(ctx)
	return scene(ctx, {}, function(_, _, picker)
		picker:open("l1")
	end)
end
