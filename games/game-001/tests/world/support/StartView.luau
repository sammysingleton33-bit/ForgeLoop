--!strict
--[[
	The ruler's real start view (RulerCameraController, overview), for the specs and the world preview (FORGE-02).

	The ruler spawns seated on the keep's Kit Seat "Throne" (KingdomService); the overview's first focus is
	Def.startFocus(root.CFrame, overview.startAhead = 40): the yard 40 studs in front of the throne, at the root's height, and the
	camera's yaw is the direction Roblox's default camera looks when the overview starts: behind the seated ruler, along the throne's
	facing (the keep's -Z). The camera then stands `zoom` studs from the focus at the pitch for that zoom, so at the start view
	(zoom 70, pitch 42.5) it hangs 47.3 studs up and 51.6 studs back from the focus: above the keep, looking out over its yard.

	  StartView.root(Kit, layout, kingdom) -> CFrame   -- where the seated ruler's root is: the keep's frame * the Throne seat's offset,
	                                                       a little above it (SEATED_LIFT, approximate: the exact root height is Studio's)
	  StartView.camera(root, zoom, pitchDeg, ahead?) -> { focus, position, forward, right, up }   -- forward = the camera's look direction
]]

local StartView = {}

StartView.AHEAD = 40 -- RulerCameraController.DEFAULTS.overview.startAhead
StartView.SEATED_LIFT = 2 -- studs from the seat's centre to a seated R15 root (an estimate; Studio unverified)

function StartView.root(Kit: any, layout: any, kingdom: string): CFrame
	local anchor: CFrame = layout.plots[kingdom].anchors.keep
	local model = Kit.build("keep", 1, "complete", Kit.NEUTRAL_COLOR)
	local seat = model:FindFirstChild("Throne", true)
	local primary = model.PrimaryPart
	local offset = Vector3.new(0, 5.7, -11.8) -- the Kit keep's throne, in the keep's frame, if the seat is ever missing
	local look = CFrame.identity
	if seat and primary then
		local rel = (primary.CFrame * primary.PivotOffset):ToObjectSpace(seat.CFrame)
		offset, look = rel.Position, rel - rel.Position
	end
	model:Destroy()
	return anchor * CFrame.new(offset + Vector3.new(0, StartView.SEATED_LIFT, 0)) * look
end

function StartView.camera(root: CFrame, zoom: number, pitchDeg: number, ahead: number?)
	local flat = Vector3.new(root.LookVector.X, 0, root.LookVector.Z)
	flat = if flat.Magnitude < 1e-3 then Vector3.new(0, 0, -1) else flat.Unit
	local focus = root.Position + flat * (ahead or StartView.AHEAD)
	local pitch = math.rad(pitchDeg)
	local position = focus - flat * (zoom * math.cos(pitch)) + Vector3.new(0, zoom * math.sin(pitch), 0)
	local forward = flat * math.cos(pitch) + Vector3.new(0, -math.sin(pitch), 0)
	local right = flat:Cross(Vector3.yAxis)
	local up = right:Cross(forward)
	return { focus = focus, position = position, forward = forward, right = right, up = up }
end

return StartView
