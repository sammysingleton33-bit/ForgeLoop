--!strict
--[[
	Governor (ReplicatedStorage.Forge.Config.Governor) — AI rulers for kingdoms without human rulers.
	Owner: FORGE-01.

	Difficulty for empty kingdoms is a user decision (BRIEF §16.3); these are the provisional defaults.
	aggression is drawn per kingdom from [minAggression, maxAggression] with the match seed.
]]

return {
	enabled = true,
	interval = 6, -- seconds between decisions per kingdom (staggered)
	assistHumans = false, -- true: the governor also manages kingdoms that have human rulers
	minAggression = 0.3,
	maxAggression = 1.0,
}
