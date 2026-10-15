--[[
	Shared setup for the FL-0099 cinematic conversation scenes (design/ui/render, PROJECT=games/game-001/
	default.project.json): the real KingdomHudController, CitizenCardController and ConversationController
	on the spec world (tests/economy/doubles/KingdomWorld) with FORGE-01's #108 Converse fields
	(CitizenDoubles.cinematic: look, job, position, kingdom; Kingdom.EndConversation) and the reputation
	strip on, as in the game. The portrait is FORGE-02's Kit.portrait when Kit has it (#85), otherwise
	the contract stand-in (tests/economy/doubles/PortraitDoubles); the snapshot's `modules` list shows
	which. `act(world, hud, card, conversation, citizens)` drives the UI with the calls a tap makes.
]]
local CitizenCardDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/CitizenCardController")
local CitizenDoubles = require("../../../tests/economy/doubles/CitizenDoubles")
local ConversationDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/ConversationController")
local Create = require("@game/ReplicatedStorage/Forge/UI/Create")
local KingdomHudDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/KingdomHudController")
local KingdomWorld = require("../../../tests/economy/doubles/KingdomWorld")
local PortraitDoubles = require("../../../tests/economy/doubles/PortraitDoubles")
local PortraitView = require("@game/StarterPlayer/StarterPlayerScripts/Game/UI/PortraitView")
local Rep = require("../../../tests/economy/doubles/ReputationDoubles")
local ReputationDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/ReputationPanelController")

local function remotes()
	local out = {}
	for _, set in { CitizenDoubles.CINEMATIC_REMOTES, Rep.REMOTES } do
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
	-- Kit.portrait itself once #85 is merged; the contract stand-in before that
	if PortraitDoubles.real() == nil then
		PortraitView.useSource(PortraitDoubles.source())
	end
	local world = KingdomWorld.new({
		remotes = remotes(),
		services = {
			CitizenDoubles.cinematic,
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
	return { guis = { g.backdrop, g.hud, g.topbar, g.menus, g.modals, g.notices } }
end
