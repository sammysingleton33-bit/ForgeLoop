-- FL-0129 scene "hud-phase": the HUD in a full match (D-053), Expansion with 4:32 left: the timer pill
-- with the phase track and "Next: Conflict · war opens" (phones show phase and clock only).
local scene = require("./_world")
return function(ctx)
	return scene(ctx, {}, function(world)
		world.match:setPhase("Expansion", world.env.serverTimeNow() + 272)
		world:advance(0.6)
	end)
end
