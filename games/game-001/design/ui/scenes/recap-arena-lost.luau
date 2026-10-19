-- FL-0073 scene "recap-arena-lost": a Restless champion who lost with no perk fired (the stand emptied).
local scene = require("./_recaparena")
return function(ctx)
	return scene(ctx, { page = "arena", tier = "restless", winner = "b", fired = {} })
end
