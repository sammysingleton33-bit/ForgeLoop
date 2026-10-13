-- FL-0060 scene "objectives-open": the tracker expanded after a tap. VS-1 has one objective; a second
-- one (Old Ford, Frostmere's, Sunspire 30 %) shows how the list stacks (prototype scene "hud-open").
local scene = require("./_army")
return function(ctx)
	return scene(ctx, {}, function(_, c)
		c.military:setProgress("watchtower", "crimson", 0.64)
		c.military:setProgress("watchtower", "azure", 0.2)
		c.military:setProgress("watchtower", "emerald", 0.08)
		c.military:add({
			id = "old_ford",
			kind = "capture",
			position = Vector3.new(200, 0, 200),
			radius = 20,
			owner = "azure",
			progress = { azure = 1, gold = 0.3 },
		})
		c.objectives:toggle()
	end)
end
