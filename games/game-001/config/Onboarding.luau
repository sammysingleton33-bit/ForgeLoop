--!strict
--[[
	AI Kingdoms (game-001) first-session onboarding — owner FORGE-04. Engine: Experience/Onboarding.
	Design notes: production/handoffs/2026-10-12-forge-04-to-forge-00-ai-kingdoms-experience.md §4.

	Teach by doing: every step is something the player does (move, look, tap, order, build) or sees
	happen because of what they did; hints are one line. The tutorial never blocks play: hints are a
	small card plus an arrow, Skip is always visible, and steps the player already did complete at
	once. Expected time (expectSec): first interaction at ~3 s, first reward (the first harvest,
	+25 Crowns) at ~100 s, whole flow ~3.5 min.

	Needs from others: bus events CitizenTaskChanged / ConstructionStarted / ResourceProduced /
	BuildingUpgraded (FORGE-01, proposed), the "OnboardingCastle" and "Citizen" tags (FORGE-01 / map),
	UI targets "HUD.Resources", "HUD.BuildButton" and the "ResourceInspected" / "GoalAcknowledged"
	reports from FORGE-03's HUD, and the "Crowns" currency (FORGE-03).
]]

return table.freeze({
	clientActions = { "RulerMoved", "ReachedCastle", "ResourceInspected", "GoalAcknowledged" },
	limits = { firstInteractionSec = 30, firstRewardSec = 180 },
	flows = {
		{
			id = "first_session",
			version = 1,
			funnel = true,
			startOn = "PlayerReady",
			completeReward = { currency = "Crowns", amount = 50 },
			steps = {
				{
					id = "Arrive",
					trigger = { auto = true },
					hint = { title = "Welcome, ruler. This land is yours." },
					expectSec = 3,
				},
				{
					id = "MoveRuler",
					trigger = { client = "RulerMoved" },
					hint = {
						title = "Walk to your castle",
						body = "Move with WASD or the thumbstick.",
						target = { kind = "world", tag = "OnboardingCastle" },
					},
					expectSec = 8,
					interactive = true,
					nudgeAfterSec = 12,
				},
				{
					id = "FindKingdom",
					trigger = { client = "ReachedCastle" },
					hint = {
						title = "Your banner marks your kingdom",
						body = "Everything inside your coloured border is yours to build on.",
						target = { kind = "world", tag = "OnboardingCastle" },
					},
					expectSec = 10,
					interactive = true,
					nudgeAfterSec = 20,
				},
				{
					id = "CheckResources",
					trigger = { client = "ResourceInspected" },
					hint = {
						title = "Tap your Food",
						body = "Food feeds citizens. Wood and Stone build. Gold pays soldiers.",
						target = { kind = "ui", name = "HUD.Resources" },
					},
					expectSec = 8,
					interactive = true,
					nudgeAfterSec = 10,
					autoAdvanceSec = 20,
				},
				{
					id = "AssignCitizen",
					trigger = { bus = "CitizenTaskChanged", match = { role = "actor" } },
					hint = {
						title = "Put a citizen to work",
						body = "Tap an idle citizen, then tap the fields.",
						target = { kind = "world", tag = "Citizen" },
					},
					expectSec = 15,
					interactive = true,
					nudgeAfterSec = 20,
				},
				{
					id = "PlaceFarm",
					trigger = { bus = "ConstructionStarted", match = { role = "actor", buildingType = "Farm" } },
					hint = {
						title = "Build a farm",
						body = "Open Build, choose Farm, place it on green land.",
						target = { kind = "ui", name = "HUD.BuildButton" },
					},
					expectSec = 25,
					interactive = true,
					nudgeAfterSec = 25,
				},
				{
					id = "FirstHarvest",
					trigger = { bus = "ResourceProduced", match = { role = "actor", resource = "Food" } },
					hint = {
						title = "Your citizens are working",
						body = "Watch the farm: your first harvest is coming.",
					},
					expectSec = 30,
					reward = { currency = "Crowns", amount = 25 },
				},
				{
					id = "UpgradeHall",
					trigger = { bus = "BuildingUpgraded", match = { role = "actor", buildingType = "TownHall" } },
					hint = {
						title = "Upgrade your Town Hall",
						body = "A bigger hall unlocks new buildings and more citizens.",
						target = { kind = "world", tag = "OnboardingTownHall" },
					},
					expectSec = 90,
					interactive = true,
					nudgeAfterSec = 45,
				},
				{
					id = "NextGoal",
					trigger = { client = "GoalAcknowledged" },
					hint = {
						title = "Your kingdom grows",
						body = "Next: train soldiers before your rivals come.",
					},
					expectSec = 6,
					autoAdvanceSec = 10,
				},
			},
		},
	},
})
