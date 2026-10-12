--[[
	TestOnboarding — an onboarding config for the framework specs (same schema as
	games/<game>/config/Onboarding.luau): a nine-step first session with auto, client and bus steps.
	Its bus steps wait for test events that only the spec's FakeBus declares (FakeBus.new({ extra =
	TestOnboarding.EXTRA_EVENTS })), resolved by `subjects` like a game's own events. Specs fire them
	as (player, info).
]]

local function actorOf(args)
	-- test events carry (player, info); the acting player is credited
	local info = table.clone(args[2] or {})
	info.role = "actor"
	return { { player = args[1], info = info } }
end

local config = {
	subjects = {
		CitizenTaskChanged = actorOf,
		ConstructionStarted = actorOf,
		ResourceProduced = actorOf,
		BuildingUpgraded = actorOf,
	},
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
}

return table.freeze({
	config = config,
	EXTRA_EVENTS = { "CitizenTaskChanged", "ConstructionStarted", "ResourceProduced" },
})
