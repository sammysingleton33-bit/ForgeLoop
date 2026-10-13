-- FL-0060 scene "summary-win": the slice summary on Match.Ended, my kingdom wins (prototype scene "summary-win").
local summary = require("./_summary")
return function(ctx)
	return summary(ctx, "crimson")
end
