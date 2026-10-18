-- The spectate screen (FL-0129, D-053 (3)): the real KingdomHudController and
-- KingdomHudSpectateController over a double of FORGE-01's Match.Spectate (FL-0125) and of FORGE-04's
-- RulerSpectateController (#183), as their handoffs describe them.
local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect, beforeEach, afterEach = T.describe, T.it, T.expect, T.beforeEach, T.afterEach

local Create = require("@game/ReplicatedStorage/Forge/UI/Create")
local KingdomHudDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/KingdomHudController")
local KingdomWorld = require("./doubles/KingdomWorld")
local FallenDoubles = require("./doubles/FallenDoubles")
local SpectateDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/KingdomHudSpectateController")
local SpectateModel = require("@game/StarterPlayer/StarterPlayerScripts/Game/UI/SpectateModel")

local function find(root, name)
	if root == nil then
		return nil
	end
	for _, d in root:GetDescendants() do
		if d.Name == name then
			return d
		end
	end
	return nil
end

local function texts(root)
	local out = {}
	for _, d in if root then root:GetDescendants() else {} do
		if (d:IsA("TextLabel") or d:IsA("TextButton")) and d.Text ~= "" then
			table.insert(out, d.Text)
		end
	end
	return table.concat(out, " | ")
end

local function tap(instance)
	assert(instance, "tap: nothing to tap")
	local face = instance:FindFirstChild("Face") or instance
	expect(Create.fire(face, "Activated")).toBeGreaterThan(0)
end

local cameraDef = FallenDoubles.camera
local spectateService = FallenDoubles.service
local REMOTES = FallenDoubles.REMOTES
local keep, battle = FallenDoubles.keep, FallenDoubles.battle

local function newWorld(opts)
	local o = opts or {}
	local state = {
		targets = o.targets
			or { battle("azure", "Frostmere", 10, 6), keep("azure", "Frostmere", 20), keep("emerald", "Thornwood", 30) },
	}
	local defs = { KingdomHudDef, SpectateDef }
	if not o.noCamera then
		table.insert(defs, cameraDef(state))
	end
	local world = KingdomWorld.new({
		clientDefinitions = defs,
		remotes = if o.noRemote then nil else REMOTES,
		services = if o.noRemote then nil else { spectateService },
	})
	world.state = state
	world.hud = world.client:get("KingdomHudController")
	world.spectate = world.client:get("KingdomHudSpectateController")
	world.server_ = if o.noRemote then nil else world.server:get("SpectateDouble")
	world.hud:setViewport(o.width or 1920, o.height or 1022)
	world:advance(0.3)
	return world
end

local function fall(world, info)
	world.server_:send(
		world.player,
		true,
		info or { reason = "eliminated", kingdomId = "crimson", by = "azure", standing = { "azure", "emerald" } }
	)
	world:advance(0.3)
end

-- the modal layer: a spectator has no kingdom, and the HUD turns its other layers off without one
local function menus(world)
	return world.hud.guis.modals
end

describe("UI/SpectateModel (FL-0129)", function()
	local function store()
		return {
			kingdoms = function()
				return {
					{ id = "crimson", name = "Emberhold" },
					{ id = "azure", name = "Frostmere" },
					{ id = "emerald", name = "Thornwood" },
				}
			end,
		}
	end

	it("who fell, who took the keep, how many stand; battles say how many fight", function()
		local view = SpectateModel.view(
			{ reason = "eliminated", kingdomId = "crimson", by = "azure", standing = { "azure", "emerald" } },
			store(),
			{ battle("azure", nil, 1, 4), keep("emerald", "Thornwood", 2) },
			keep("emerald", "Thornwood", 2)
		)
		expect(view.title).toBe("Emberhold has fallen")
		expect(view.subtitle).toBe("Frostmere took your keep")
		expect(view.standing).toBe("2 kingdoms still stand")
		expect(view.rows[1].label).toBe("Battle · Frostmere") -- the name from the store when the target has none
		expect(view.rows[1].detail).toBe("4 fighting")
		expect(view.rows[2].label).toBe("Thornwood")
		expect(view.rows[2].selected).toBe(true)
		expect(view.current).toBe(2)
	end)

	it("without info (the camera alone) and for a full match it still says something true", function()
		local view = SpectateModel.view(nil, store(), {}, nil)
		expect(view.title).toBe("Your kingdom has fallen")
		expect(view.subtitle).toBe("Your keep was taken")
		expect(#view.rows).toBe(0)
		view = SpectateModel.view({ reason = "match_full", standing = { "azure" } }, store(), {}, nil)
		expect(view.title).toBe("This match is full")
		expect(view.standing).toBe("1 kingdom still stands")
	end)
end)

describe("The spectate screen (FL-0129)", function()
	local world, previous
	beforeEach(function()
		previous = Create.useTestConnector()
	end)
	afterEach(function()
		if world then
			world:destroy()
			world = nil
		end
		Create.setConnector(previous)
	end)

	it("Match.Spectate: the fallen card, the camera on, the drawer closed; Stay leaves the target list", function()
		world = newWorld()
		world.hud:setMenu("kingdom")
		world:advance(0.1)
		expect(find(menus(world), "FallenCard")).toBeNil()
		fall(world)
		local fallen = find(menus(world), "FallenCard")
		expect(fallen).toBeTruthy()
		expect(texts(fallen)).toContain("Emberhold has fallen")
		expect(texts(fallen)).toContain("Frostmere took your keep")
		expect(world.state.setActive).toBe(true)
		expect(world.hud.state.menu).toBeNil()
		tap(find(fallen, "Stay"))
		world:advance(0.1)
		expect(find(menus(world), "FallenCard")).toBeNil()
		local panel = find(menus(world), "WatchPanel")
		expect(panel).toBeTruthy()
		expect(find(panel, "Target_1")).toBeTruthy()
		expect(texts(find(panel, "Target_1"))).toContain("Battle · Frostmere")
		expect(texts(find(panel, "Target_3"))).toContain("Thornwood")
	end)

	it("a tap on a target and Next move the camera; the current row follows the camera", function()
		world = newWorld()
		fall(world)
		world.spectate:stay()
		world:advance(0.1)
		tap(find(menus(world), "Target_2"))
		world:advance(0.1)
		expect(world.state.camera.index).toBe(2)
		expect(find(menus(world), "Target_2"):GetAttribute("selected")).toBe(true)
		tap(find(find(menus(world), "WatchPanel"), "Next"))
		world:advance(0.1)
		expect(world.state.camera.index).toBe(3)
		expect(find(menus(world), "Target_3"):GetAttribute("selected")).toBe(true)
		expect(find(menus(world), "Target_2"):GetAttribute("selected")).toBe(false)
		-- the camera's own keys (FORGE-04) move it too: the row follows targetChanged
		world.state.camera:select(1)
		world:advance(0.1)
		expect(find(menus(world), "Target_1"):GetAttribute("selected")).toBe(true)
		-- a new battle appears: the list is re-read without a push, even with the HUD quiet
		world.spectate._renderedConnection:disconnect()
		table.insert(world.state.targets, 1, battle("emerald", "Thornwood", 40, 2))
		world:advance(1.2)
		expect(texts(find(menus(world), "Target_1"))).toContain("Battle · Thornwood")
	end)

	it("Leave asks first; Cancel keeps watching; Leave leaves the server", function()
		world = newWorld()
		fall(world)
		tap(find(find(menus(world), "FallenCard"), "Leave"))
		world:advance(0.1)
		local fallen = find(menus(world), "FallenCard")
		expect(texts(fallen)).toContain("Leave the match?")
		tap(find(fallen, "CancelLeave"))
		world:advance(0.1)
		expect(texts(find(menus(world), "FallenCard"))).never.toContain("Leave the match?")
		expect((world.env.mock.players:wasKicked(world.player))).toBe(false)
		tap(find(find(menus(world), "FallenCard"), "Leave"))
		world:advance(0.1)
		tap(find(find(menus(world), "FallenCard"), "ConfirmLeave"))
		local kicked, message = world.env.mock.players:wasKicked(world.player)
		expect(kicked).toBe(true)
		expect(message).toContain("Thanks for playing")
	end)

	it("Match.Spectate(false) (seated again) ends it and the camera; a camera that stops alone does not", function()
		world = newWorld()
		fall(world)
		world.spectate:stay()
		world.state.camera:setActive(false) -- e.g. the camera's own rule; the server still says spectate
		world:advance(0.1)
		expect(find(menus(world), "WatchPanel")).toBeTruthy()
		world.state.camera:setActive(true)
		world.server_:send(world.player, false, nil)
		world:advance(0.3)
		expect(find(menus(world), "WatchPanel")).toBeNil()
		expect(find(menus(world), "FallenCard")).toBeNil()
		expect(world.state.setActive).toBe(false)
	end)

	it("a real spectator (no kingdom, ours fallen): the HUD steps away but the screen is seen, at the top", function()
		world = newWorld()
		world.kingdoms.kingdoms.crimson.alive = false
		world.kingdoms.members[world.player.UserId] = nil
		world.kingdoms.members[2] = nil
		world.kingdoms:publish()
		fall(world)
		expect(world.hud.guis.menus.Enabled).toBe(false) -- the kingdom HUD is gone (no kingdom)
		expect(world.hud.guis.modals.Enabled).toBe(true)
		expect(world.hud.guis.topbar.Enabled).toBe(true) -- the phase bar stays (FORGE-07 L3)
		expect(find(world.hud.guis.topbar, "Timer").Visible).toBe(true)
		expect(texts(find(menus(world), "FallenCard"))).toContain("Emberhold has fallen")
		world.spectate:stay()
		world:advance(0.1)
		expect(find(menus(world), "WatchPanel").Position.Y.Offset).toBe(72)
	end)

	it("Results and the Lobby hide it; the next active phase brings it back while still spectating", function()
		world = newWorld()
		world.match:setPhase("Conflict", world.env.serverTimeNow() + 300)
		fall(world)
		world.spectate:stay()
		world:advance(0.1)
		expect(find(menus(world), "WatchPanel")).toBeTruthy()
		world.match:setPhase("Results", world.env.serverTimeNow() + 30)
		world:advance(0.3)
		expect(find(menus(world), "WatchPanel")).toBeNil()
		expect(world.spectate.spectating).toBe(true)
		world.match:setPhase("Founding", world.env.serverTimeNow() + 300)
		world:advance(0.3)
		expect(find(menus(world), "WatchPanel")).toBeTruthy()
	end)

	it("the camera alone (no server remote, today's main): the card and list show, and go with the camera", function()
		world = newWorld({ noRemote = true })
		world.state.camera:setActive(true)
		world:advance(0.1)
		expect(texts(find(menus(world), "FallenCard"))).toContain("Your kingdom has fallen")
		world.state.camera:setActive(false)
		world:advance(0.1)
		expect(find(menus(world), "FallenCard")).toBeNil()
	end)

	it("phone 667 × 375: the card first, then the list, never both; a full match says so", function()
		world = newWorld({ width = 667, height = 375 })
		expect(world.hud:metrics().breakpoint).toBe("phone")
		fall(world, { reason = "match_full", standing = { "crimson", "azure", "emerald", "gold" } })
		expect(texts(find(menus(world), "FallenCard"))).toContain("This match is full")
		expect(find(menus(world), "WatchPanel")).toBeNil()
		world.spectate:stay()
		world:advance(0.1)
		local panel = find(menus(world), "WatchPanel")
		expect(panel).toBeTruthy()
		expect(panel.Size.X.Offset).toBe(224)
		expect(find(menus(world), "FallenCard")).toBeNil()
	end)

	it("without FORGE-04's camera the card still shows and the list says there is nothing yet", function()
		world = newWorld({ noCamera = true })
		fall(world)
		world.spectate:stay()
		world:advance(0.1)
		expect(texts(find(menus(world), "WatchPanel"))).toContain("Nothing to watch yet")
	end)
end)
