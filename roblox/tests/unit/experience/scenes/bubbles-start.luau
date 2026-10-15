-- Citizen bubbles over a kingdom at the overview's start zoom (120 studs). See _bubbles.luau.
local build = require("./_bubbles")

return function(ctx)
	return build(ctx, 120)
end
