-- FL-0073 scene "recap-arena-reign": the reign page of the same recap, with the Arena & support switch beside Back.
local scene = require("./_recaparena")
return function(ctx)
	return scene(ctx, { page = "reign" })
end
