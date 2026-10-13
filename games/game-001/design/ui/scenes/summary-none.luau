-- FL-0060 scene "summary-none": the slice summary on Match.Ended, no winner (prototype scene "summary-none").
local summary = require("./_summary")
return function(ctx)
	return summary(ctx, false)
end
