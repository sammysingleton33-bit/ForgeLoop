--[[
	Shared setup for the FL-0142 vote scenes: the arena controllers and ArenaHudVoteController over ArenaDoubles and
	VoteDoubles (Arena.Vote and the proposed ArenaState.vote). Sam (user 1) and Mira (user 2) rule Emberhold;
	`stage(world, voteServer)` opens the vote and casts what the scene needs.
]]
local ArenaDoubles = require("../../../tests/economy/doubles/ArenaDoubles")
local ArenaHudDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/ArenaHudController")
local DuelDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/DuelController")
local VoteDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/ArenaHudVoteController")
local VoteDoubles = require("../../../tests/economy/doubles/VoteDoubles")
local scene = require("./_world")

return function(ctx, stage)
	return scene(ctx, {
		clientDefinitions = { DuelDef, ArenaHudDef, VoteDef },
		remotes = VoteDoubles.REMOTES,
		services = { ArenaDoubles.service, VoteDoubles.service },
	}, function(world, _hud)
		world.match:setPhase("Endgame", world.env.serverTimeNow() + 1)
		stage(world, world.server:get("VoteDouble"), world.client:get("ArenaHudVoteController"))
		world:advance(0.4)
	end)
end
