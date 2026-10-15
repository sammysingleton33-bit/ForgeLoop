-- Rotation scene "plot-pick-turn" (CONTRACTS G13.5 v0.4-g9h, the user's first Studio feedback): a
-- medium plot, a storehouse turned a quarter ("Faces right"); the Facing row with its dial and Turn.
-- Live on this build (FORGE-01 #132): no seam; SlotDoubles serves the same PlaceSlot declaration.
local scene = require("./_plots")
return function(ctx)
	return scene(ctx, { turns = true }, function(_, _, picker)
		picker:open("crimson_slot5")
		picker:select("storehouse")
		picker:turn()
	end)
end
