-- FL-0129 scene "results-summary": the Results summary with "Your reign" (the leadership recap).
local recap = require("./_recap")
return function(ctx)
	return recap(ctx, { open = false })
end
