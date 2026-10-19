-- FL-0073 scene "recap-arena": Results, Your reign → Arena & support: an Adoring champion who won (crowned).
local scene = require("./_recaparena")
return function(ctx)
	return scene(ctx, { page = "arena", tier = "adoring", winner = "a" })
end
