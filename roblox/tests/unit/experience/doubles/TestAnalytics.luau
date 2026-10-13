--[[
	TestAnalytics — an analytics config for the framework specs (same schema as
	games/<game>/config/Analytics.luau). It exercises framework events through the default subjects
	and game-style events through `subjects` resolvers, the way a game passes its own attribution rules:

		TestAnalytics.build({ membersOf = fn(kingdomId) -> { Player }, matchId = fn() -> string? })
	BuildingCompleted credits every member of the building's kingdom (game-001 G9 rule);
	UnitsRecruited and ResourceGathered (source "ruler") credit the acting player;
	TestDuel (only with duel = true; FakeBus extra event: (attacker, defender, winner)) credits both
	sides with role/won.
]]

local TestAnalytics = {}

function TestAnalytics.build(hooks: { membersOf: ((string) -> { any })?, matchId: (() -> string?)?, duel: boolean? }?)
	local h = hooks or {}
	local function members(kingdomId)
		return if h.membersOf then h.membersOf(kingdomId) else {}
	end
	local function match()
		return if h.matchId then h.matchId() else nil
	end
	local actor = { role = "actor" }
	local config = {
		events = {
			SessionStart = { description = "join", value = "daysSinceFirstJoin", fields = { "visit" } },
			SessionEnd = { description = "leave", value = "sessionSec", fields = { "lastActivity" } },
			OnboardingCompleted = { description = "done", value = "durationSec", fields = { "flow" } },
			OnboardingSkipped = { description = "skip", value = "lastStep", fields = { "lastStepName", "flow" } },
			OnboardingHintEscalated = { description = "stuck", value = "step", fields = { "stepName" } },
			OnboardingStepPassed = { description = "passed", value = "step", fields = { "stepName", "via" } },
			MatchEnded = { description = "end", value = "durationSec", fields = { "won", "placement", "mode" } },
			BuildingCompleted = { description = "built", value = "level", fields = { "buildingType" } },
			AchievementUnlocked = { description = "ach", fields = { "achievementId" } },
			BattleEnded = { description = "duel", fields = { "role", "won" } },
			SettingChanged = { description = "setting", fields = { "key", "value" } },
		},
		funnels = {
			Onboarding = { description = "tutorial", kind = "onboarding" },
			FirstMatch = {
				description = "first match",
				kind = "once",
				steps = {
					"MatchJoined",
					"FirstConstruction",
					"FirstBuilding",
					"FirstUpgrade",
					"FirstArmy",
					"FirstCombat",
					"MatchFinished",
				},
			},
			MatchProgress = {
				description = "every match",
				kind = "recurring",
				steps = { "Joined", "FirstBuilding", "FirstUpgrade", "FirstArmy", "FirstCombat", "Finished" },
				sessionTtlSec = 3600,
			},
			FirstReward = {
				description = "rewards",
				kind = "once",
				steps = { "FirstHarvest", "FirstCurrency", "FirstItem" },
			},
			Shop = { description = "shop", kind = "recurring", steps = { "Opened", "Purchased" }, sessionTtlSec = 900 },
			Return = { description = "day 2", kind = "once", steps = { "FirstSession", "ReturnNextDay" } },
		},
		track = {
			{ on = "RoundStateChanged", match = { state = "Active" }, funnel = "FirstMatch", step = 1 },
			{ on = "BuildingCompleted", funnel = "FirstMatch", step = 3 },
			{ on = "UnitsRecruited", match = actor, funnel = "FirstMatch", step = 5 },
			{ on = "RoundEnded", funnel = "FirstMatch", step = 7 },
			{
				on = "RoundStateChanged",
				match = { state = "Active" },
				funnel = "MatchProgress",
				step = 1,
				session = "match",
			},
			{ on = "BuildingCompleted", funnel = "MatchProgress", step = 2, session = "match" },
			{ on = "UnitsRecruited", match = actor, funnel = "MatchProgress", step = 4, session = "match" },
			{ on = "RoundEnded", funnel = "MatchProgress", step = 6, session = "match" },
			{ on = "ResourceGathered", match = actor, funnel = "FirstReward", step = 1 },
			{ on = "CurrencyChanged", match = { gained = true }, funnel = "FirstReward", step = 2 },
			{ on = "ItemGranted", funnel = "FirstReward", step = 3 },
			{ on = "ShopViewed", funnel = "Shop", step = 1, session = "start", key = "shop" },
			{ on = "PurchaseCompleted", funnel = "Shop", step = 2, session = "continue", key = "shop" },
			{ on = "RoundEnded", event = "MatchEnded", fields = { "durationSec", "won", "placement", "mode" } },
			{ on = "BuildingCompleted", event = "BuildingCompleted", fields = { "level", "buildingType" } },
		},
		subjects = {
			-- (building, player?): every current member of the building's kingdom
			BuildingCompleted = function(args)
				local building = args[1]
				local out = {}
				for _, player in members(building.kingdom) do
					table.insert(out, {
						player = player,
						info = { buildingType = building.type, level = building.level, matchId = match() },
					})
				end
				return out
			end,
			-- (player, kingdomId, count)
			UnitsRecruited = function(args)
				return { { player = args[1], info = { role = "actor", count = args[3], matchId = match() } } }
			end,
			-- (player?, kingdomId, resourceId, amount, source)
			ResourceGathered = function(args)
				if args[5] ~= "ruler" then
					return {}
				end
				return { { player = args[1], info = { role = "actor", resource = args[3], amount = args[4] } } }
			end,
		},
		session = { startEvent = "SessionStart", endEvent = "SessionEnd", returnFunnel = "Return" },
		limits = { perPlayerPerMinute = 30, safety = 0.8, customReserve = 0.25 },
	}
	if h.duel then
		table.insert(config.track, { on = "TestDuel", event = "BattleEnded", fields = { "role", "won" } })
		-- (attacker, defender, winner)
		config.subjects.TestDuel = function(args)
			return {
				{ player = args[1], info = { role = "actor", won = args[3] == args[1] } },
				{ player = args[2], info = { role = "defender", won = args[3] == args[2] } },
			}
		end
	end
	return config
end

return TestAnalytics
