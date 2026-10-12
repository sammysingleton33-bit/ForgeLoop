-- FL-0087 scene "plot-pick": a medium plot tapped, Lumber Camp selected (phones: its detail).
local scene = require("./_plots")
return function(ctx)
	return scene(ctx, {}, function(_, _, picker)
		picker:open("m1")
		picker:select("lumbercamp")
	end)
end
