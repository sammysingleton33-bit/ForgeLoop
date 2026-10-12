--!strict
--[[
	Sandbox onboarding — owner FORGE-04. Genre-agnostic round game; uses only events declared in
	Contracts/GameEvents today, so the integration place can run the whole flow. Engine and fields:
	roblox/src/shared/Experience/Onboarding.luau.
]]

return table.freeze({
	clientActions = { "CharacterMoved", "GoalAcknowledged" },
	limits = { firstInteractionSec = 30, firstRewardSec = 300 },
	flows = {
		{
			id = "first_session",
			version = 1,
			funnel = true,
			startOn = "PlayerReady",
			steps = {
				{ id = "Arrive", trigger = { auto = true }, hint = { title = "Welcome!" }, expectSec = 2 },
				{
					id = "Move",
					trigger = { client = "CharacterMoved" },
					hint = { title = "Move around", body = "WASD or the thumbstick." },
					expectSec = 6,
					interactive = true,
					nudgeAfterSec = 10,
				},
				{
					id = "OpenShop",
					trigger = { bus = "ShopViewed" },
					hint = { title = "Open the shop", target = { kind = "ui", name = "HUD.Shop" } },
					expectSec = 15,
					interactive = true,
					nudgeAfterSec = 20,
				},
				{
					id = "JoinRound",
					trigger = { bus = "RoundStateChanged", match = { state = "Active" } },
					hint = { title = "A round is starting: get ready" },
					expectSec = 60,
				},
				{
					id = "FinishRound",
					trigger = { bus = "RoundEnded" },
					hint = { title = "Survive the round" },
					expectSec = 180,
					reward = { currency = "Coins", amount = 25 },
				},
				{
					id = "Done",
					trigger = { client = "GoalAcknowledged" },
					hint = { title = "You're ready. Play again for daily rewards." },
					expectSec = 5,
					autoAdvanceSec = 8,
				},
			},
		},
	},
})
