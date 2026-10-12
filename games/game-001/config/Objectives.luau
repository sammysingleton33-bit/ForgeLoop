--!strict
--[[
	Objectives (ReplicatedStorage.Forge.Config.Objectives) — neutral capture points. Owner: FORGE-01.

	VS-1 row 7: the neutral Watchtower. Positions are used by the generated layout; once FORGE-02's
	WorldService tags ObjectiveZone parts (G10: ObjectiveId, Radius), those win.
	Capture rules (G8) live in Sim/Objectives.
]]

return {
	{
		id = "watchtower",
		x = 0,
		z = -60,
		radius = 18,
		captureSeconds = 20,
		crownPoints = 100,
		territoryRadius = 60,
		holdPointsPerMinute = 6,
	},
}
