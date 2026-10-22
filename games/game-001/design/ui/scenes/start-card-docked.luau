-- D-059 proposal for FORGE-04: the start frame with the onboarding card docked bottom centre (see _start).
return function(ctx)
	return require("./_start")(ctx, { dockCard = true })
end
