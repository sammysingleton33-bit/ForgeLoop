-- FL-0060 scene "summary-lost": the slice summary on Match.Ended, Frostmere wins (prototype scene "summary").
local summary = require("./_summary")
return function(ctx)
	return summary(ctx, "azure")
end
