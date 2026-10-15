-- Rotation scene "plot-pick-turn" (CONTRACTS G13.5 v0.4-g9h, the user's first Studio feedback): a
-- medium plot, a storehouse turned a quarter ("Faces right"); the Facing row with its dial and Turn.
-- The turn is served by SlotDoubles until FORGE-01's server lands (UI/Turns seam).
local SlotDoubles = require("../../../tests/economy/doubles/SlotDoubles")
local Turns = require("@game/StarterPlayer/StarterPlayerScripts/Game/UI/Turns")
local scene = require("./_plots")
return function(ctx)
	Turns.useSeam({ supported = true, fits = SlotDoubles.fitsTurned })
	return scene(ctx, { turns = true }, function(_, _, picker)
		picker:open("crimson_slot5")
		picker:select("storehouse")
		picker:turn()
	end)
end
