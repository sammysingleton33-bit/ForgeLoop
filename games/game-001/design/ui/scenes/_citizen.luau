--[[
	Shared setup for the FL-0088 Luau snapshot scenes (design/ui/render, PROJECT=games/game-001/
	default.project.json): the real KingdomHudController, CitizenCardController and
	ConversationController on the spec world (tests/economy/doubles/KingdomWorld: real RemoteService +
	TreasuryService) with the FORGE-01 citizen doubles (tests/economy/doubles/CitizenDoubles), sized to
	the device's CoreUISafeInsets area. The reputation strip (ReputationPanelController with the
	ReputationDoubles server) is on, as in the game: the phone sheet must cover it cleanly.
	`act(world, hud, card, conversation, citizens)` drives the UI with the same calls a tap makes.
]]
local CitizenCardDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/CitizenCardController")
local CitizenDoubles = require("../../../tests/economy/doubles/CitizenDoubles")
local ConversationDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/ConversationController")
local Create = require("@game/ReplicatedStorage/Forge/UI/Create")
local KingdomHudDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/KingdomHudController")
local KingdomWorld = require("../../../tests/economy/doubles/KingdomWorld")
local Rep = require("../../../tests/economy/doubles/ReputationDoubles")
local ReputationDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/ReputationPanelController")

-- Both doubles add Kingdom remotes: one list per area.
local function remotes()
	local out = {}
	for _, set in { CitizenDoubles.REMOTES, Rep.REMOTES } do
		for area, decls in set do
			out[area] = out[area] or {}
			for _, decl in decls do
				table.insert(out[area], decl)
			end
		end
	end
	return out
end

return function(ctx, act)
	Create.useTestConnector()
	local world = KingdomWorld.new({
		remotes = remotes(),
		services = {
			CitizenDoubles.service,
			Rep.service({
				values = { compassion = 62, honor = 48, competence = 55, courage = 40, authority = 70, fear = 15 },
			}),
		},
		clientDefinitions = { KingdomHudDef, CitizenCardDef, ConversationDef, ReputationDef },
	})
	local hud = world.client:get("KingdomHudController")
	hud:setViewport(ctx.core.width, ctx.core.height)
	world.kingdoms:addCrownPoints("crimson", 12)
	world:advance(0.2)
	if act then
		act(
			world,
			hud,
			world.client:get("CitizenCardController"),
			world.client:get("ConversationController"),
			world.server:get("CitizenService")
		)
	end
	local g = hud.guis
	return { guis = { g.hud, g.topbar, g.menus, g.modals, g.notices } }
end
