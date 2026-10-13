--!strict
--[[
	Feedback remotes (game-001, FORGE-04, FL-0062; remote area `Feedback`, CONTRACTS v0.4-g2).
	Created by the framework RemoteService.

	Feedback.Moment   serverEvent to the players a moment is about (Feedback/Moments decides who):
	                  (moment: Moment), primitives and Vector3 only (no CFrame crosses the wire, G8).
	                  AnnouncerService sends it from G9 events; AnnouncerController, FeedbackController
	                  and MusicController react on the client.
]]

return {
	{ name = "Feedback.Moment", kind = "serverEvent" },
}
