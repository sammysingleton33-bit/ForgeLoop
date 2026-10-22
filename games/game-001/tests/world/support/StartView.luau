--!strict
--[[
	The ruler's real start view (RulerCameraController, overview), for the specs and the world preview (FORGE-02).

	The ruler spawns seated on the keep's Kit Seat "Throne" (KingdomService); the overview's first view (FL-0147) centres the yard
	`overview.startAhead` (20) studs in front of the throne, at the root's height (Def.startFocus), and looks back across it at the keep:
	the camera's yaw is the throne's facing turned `overview.startTurn` (180) degrees (Def.startYaw). The camera then stands `zoom`
	studs from the focus at the pitch for that zoom (Def.pitchFor), so at the start view (zoom 70, pitch 42.5) it hangs 47.3 studs up
	and 51.6 studs back from the focus: over the yard on the far side from the keep, with the keep standing at the top of the frame.

	The numbers are read from the controller's own DEFAULTS (fallback 40 and 0, the pre-FL-0147 view, when a build lacks them), and the
	focus and yaw come from the controller's own Def.startFocus / Def.startYaw, so a change to the start view moves the specs and the
	preview with it.

	  StartView.START -> { zoom, fov, pitch, ahead, turn }   -- the overview's start numbers (degrees; pitch from Def.pitchFor)
	  StartView.root(Kit, layout, kingdom) -> CFrame   -- where the seated ruler's root is: the keep's frame * the Throne seat's offset,
	                                                       a little above it (SEATED_LIFT, approximate: the exact root height is Studio's)
	  StartView.camera(root, zoom, pitchDeg, ahead?, turn?) -> { focus, position, forward, right, up, yaw }   -- forward = the camera's
	                                                       look direction; ahead and turn default to START's
]]

local CameraDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/RulerCameraController")

local StartView = {}

local overview = CameraDef.DEFAULTS.overview

StartView.AHEAD = overview.startAhead or 40 -- RulerCameraController.DEFAULTS.overview.startAhead
StartView.TURN = overview.startTurn or 0 -- ... .startTurn
StartView.SEATED_LIFT = 2 -- studs from the seat's centre to a seated R15 root (an estimate; Studio unverified)
StartView.START = table.freeze({
	zoom = overview.startZoom,
	fov = overview.fieldOfView,
	pitch = CameraDef.pitchFor(overview.startZoom, overview),
	ahead = StartView.AHEAD,
	turn = StartView.TURN,
})

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

function StartView.camera(root: CFrame, zoom: number, pitchDeg: number, ahead: number?, turn: number?)
	local focus = CameraDef.startFocus(root, ahead or StartView.AHEAD)
	local yaw = CameraDef.startYaw(root, turn or StartView.TURN) or 0
	local forwardFlat = Vector3.new(-math.sin(yaw), 0, -math.cos(yaw))
	local pitch = math.rad(pitchDeg)
	local position = focus - forwardFlat * (zoom * math.cos(pitch)) + Vector3.new(0, zoom * math.sin(pitch), 0)
	local forward = forwardFlat * math.cos(pitch) + Vector3.new(0, -math.sin(pitch), 0)
	local right = forwardFlat:Cross(Vector3.yAxis)
	local up = right:Cross(forward)
	return { focus = focus, position = position, forward = forward, right = right, up = up, yaw = yaw }
end

return StartView
