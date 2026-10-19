--[[
	Shared setup for the FL-0073 (f) Results scenes: the FL-0129 match (_recap.luau's reputation, population and
	match end) plus FORGE-01's arena (tests/economy/doubles/ArenaDoubles: SupportViews with moments over the match, a
	duel with triggers and an end) and the real ArenaHudController. Opens "Your reign" on the given page.

		return scene(ctx, { page = "arena" | "reign", tier = "adoring", winner = "a" | "b", fired = { TriggerId } })
]]
local ArenaDoubles = require("../../../tests/economy/doubles/ArenaDoubles")
local ArenaHudDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/ArenaHudController")
local ArmyDoubles = require("../../../tests/economy/doubles/ArmyDoubles")
local PopulationDoubles = require("../../../tests/economy/doubles/PopulationDoubles")
local RecapDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/LeadershipRecapController")
local Rep = require("../../../tests/economy/doubles/ReputationDoubles")
local ReputationDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/ReputationPanelController")
local SummaryDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/SliceSummaryController")
local Support = require("@game/ReplicatedStorage/Forge/Config/Support")
local scene = require("./_world")

local START = {
	values = { compassion = 50, honor = 50, competence = 50, courage = 50, authority = 50, fear = 10 },
	kingdom = { happiness = 60, stability = 60, morale = 60 },
	history = {},
}

local ACTS = {
	"keepUpgraded",
	"starvation",
	"fedRatioKept",
	"objectiveDefended",
	"abandonedRegion",
	"rebuiltRaidDamage",
	"petitionFulfilled",
	"defendedRaid",
}

return function(ctx, opts)
	return scene(ctx, {
		remotes = ArmyDoubles.remotes(Rep.REMOTES, ArenaDoubles.REMOTES),
		services = { PopulationDoubles.service, Rep.service(START), ArmyDoubles.service, ArenaDoubles.service },
		clientDefinitions = { ReputationDef, SummaryDef, RecapDef, ArenaHudDef },
	}, function(world, _hud)
		local rep = world.server:get("ReputationService")
		local pop = world.server:get("PopulationService")
		local arena = world.server:get("ArenaDouble")
		local tier = opts.tier or "adoring"
		world.match:setPhase("Founding", world.env.serverTimeNow() + 600)
		pop:set("crimson", "farmer", 10)
		world:advance(1.5)
		rep:apply("compassion", 9, "You opened the granary to the hungry villages.")
		rep:apply("honor", -12, "You broke the truce with Frostmere.")
		world:advance(1.2)
		-- support moments, three per push (the server sends only the latest few)
		local moments = {}
		for i, id in ACTS do
			local act = Support.acts[id]
			table.insert(moments, {
				t = i * 60,
				kingdom = "crimson",
				userId = 1,
				act = id,
				component = act.component,
				delta = act.delta,
				text = act.text,
			})
			if i % 3 == 0 or i == #ACTS then
				local view = ArenaDoubles.support(tier, 1, "crimson")
				view.moments = { table.unpack(moments, math.max(1, #moments - 2)) }
				arena.support[1] = view
				arena:sendSupport(world.player)
				world:advance(1.2)
			end
		end
		pop:set("crimson", "farmer", 14)
		local a = ArenaDoubles.duellist(1, "crimson", tier, { triggers = { "reforge", "fieldRemedy", "crowdRally" } })
		local b = ArenaDoubles.duellist(7, "azure", "divided")
		arena:setState({ stage = "duel", a = a, b = b })
		world:advance(1.2)
		local batch = {}
		for _, id in opts.fired or { "reforge", "crowdRally" } do
			table.insert(batch, { t = 1, kind = "triggerFired", side = "a", data = { trigger = id } })
		end
		local winner = opts.winner or "a"
		table.insert(batch, { t = 2, kind = "ended", side = winner, data = { winner = winner, reason = "ko" } })
		arena:events(batch)
		world:advance(1.2)
		arena:setState({ stage = "done", a = a, b = b })
		world:advance(1.2)
		world.match:setPhase("Results", world.env.serverTimeNow() + 30)
		world.server:get("MilitaryService"):endMatch({
			winner = if winner == "a" then "crimson" else "azure",
			standings = {
				{ kingdom = "crimson", crownPoints = 30 },
				{ kingdom = "azure", crownPoints = 22 },
			},
			durationSec = 1830,
		})
		world:advance(1.5)
		local recap = world.client:get("LeadershipRecapController")
		recap:open()
		recap:setPage(opts.page or "arena")
		world:advance(0.2)
	end)
end
