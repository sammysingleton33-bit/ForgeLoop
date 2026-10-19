-- FL-0073 scene "support-moments": the Divided breakdown scrolled down to "What moved it" (newest first, signed deltas).
local scene = require("./_support")
return function(ctx)
	return scene(ctx, { profile = "divided" }, function(_, _, sup, svc)
		svc:act("starvation")
		sup:open()
		local body = sup.panel.instance:FindFirstChild("Body", true)
		body.CanvasPosition = Vector2.new(0, 400)
	end)
end
