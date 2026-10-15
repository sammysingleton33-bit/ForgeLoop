-- Citizen bubbles over a kingdom at the overview's max zoom (220 studs). See _bubbles.luau.
local build = require("./_bubbles")

return function(ctx)
	return build(ctx, 220)
end
