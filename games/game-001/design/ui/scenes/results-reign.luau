-- FL-0129 scene "results-reign": "Your reign" open over the Results summary: values start -> end,
-- the key decisions and citizens gained.
local recap = require("./_recap")
return function(ctx)
	return recap(ctx, { open = true })
end
