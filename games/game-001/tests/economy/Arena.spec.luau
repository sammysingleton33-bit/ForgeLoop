-- The Crown Arena screens (FL-0073, design crown-arena.md §3-§7): the real KingdomHudController, ArenaHudController,
-- LoadoutController and ArenaIntroController over ArenaDoubles (CONTRACTS G12.4, stub support numbers until FORGE-01's
-- FL-0070 / FL-0071 land).
local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect, beforeEach, afterEach = T.describe, T.it, T.expect, T.beforeEach, T.afterEach

local ArenaDoubles = require("./doubles/ArenaDoubles")
local ArenaHud = require("@game/StarterPlayer/StarterPlayerScripts/Game/UI/ArenaHud")
local ArenaHudDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/ArenaHudController")
local ArenaIntroDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/ArenaIntroController")
local Create = require("@game/ReplicatedStorage/Forge/UI/Create")
local KingdomHudDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/KingdomHudController")
local KingdomWorld = require("./doubles/KingdomWorld")
local LoadoutDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/LoadoutController")

local function find(root, name)
	for _, d in if root then root:GetDescendants() else {} do
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

-- FORGE-04's InputModeArenaController, as far as the HUD reads it: controls() (Def.CONTROLS)
local inputDef = {
	name = "InputModeArenaController",
	new = function()
		return {
			controls = function()
				return {
					{ action = "light", keyboard = "Left click", gamepad = "R1", touch = "Light" },
					{ action = "heavy", keyboard = "R", gamepad = "R2", touch = "Heavy" },
					{ action = "block", keyboard = "Hold F", gamepad = "Hold L1", touch = "Hold Block" },
					{ action = "parry", keyboard = "E", gamepad = "L2", touch = "Parry" },
					{ action = "dodge", keyboard = "Q", gamepad = "B", touch = "Dodge" },
				}
			end,
		}
	end,
}

local function newWorld(opts)
	local o = opts or {}
	local defs = { KingdomHudDef, ArenaHudDef, LoadoutDef, ArenaIntroDef }
	if o.input then
		table.insert(defs, inputDef)
	end
	local world = KingdomWorld.new({
		userId = o.userId,
		remotes = ArenaDoubles.REMOTES,
		services = { ArenaDoubles.service },
		clientDefinitions = defs,
		envServices = o.envServices,
	})
	world.hud = world.client:get("KingdomHudController")
	world.arena = world.client:get("ArenaHudController")
	world.loadout = world.client:get("LoadoutController")
	world.intro = world.client:get("ArenaIntroController")
	world.arenaServer = world.server:get("ArenaDouble")
	world.hud:setViewport(o.width or 1920, o.height or 1022)
	world.match:setPhase("Endgame", world.env.serverTimeNow() + 60)
	world:advance(0.3)
	return world
end

local function modals(world)
	return world.hud.guis.modals
end

-- the loadout stage with Sam (user 1, crimson) against Rowan (user 7, azure)
local function loadout(world, tier, seconds)
	world.arenaServer.support[1] = ArenaDoubles.support(tier or "adoring", 1, "crimson")
	world.arenaServer:setState({
		stage = "loadout",
		endsAt = world.env.serverTimeNow() + (seconds or 20),
		a = ArenaDoubles.duellist(1, "crimson", tier or "adoring"),
		b = ArenaDoubles.duellist(7, "azure", "divided"),
	})
	world:advance(0.3)
end

describe("Crown Arena: loadout and perk picker (FL-0073)", function()
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

	it("a champion picks weapon, armour and perks within the slots; Ready sends Arena.Choose", function()
		world = newWorld()
		loadout(world, "adoring")
		local picker = find(modals(world), "LoadoutPicker")
		expect(picker).toBeTruthy()
		expect(find(picker, "Tier"):GetAttribute("tier")).toBe("adoring")
		expect(texts(picker)).toContain("Bram · Blacksmith · loyalty 88")
		expect(texts(picker)).toContain("When: Your HP first drops below 50%")
		expect(texts(picker)).toContain("none is stronger overall")
		-- the first three offers start chosen; the Crowd Rally waits behind a full set
		expect(find(picker, "Offer_reforge"):GetAttribute("selected")).toBe(true)
		expect(find(picker, "Offer_crowdRally"):GetAttribute("locked")).toBe(true)
		tap(find(picker, "Weapon_spear"))
		tap(find(modals(world), "Armour_light"))
		tap(find(modals(world), "Offer_crowdRally")) -- full: nothing changes
		expect(find(modals(world), "Offer_crowdRally"):GetAttribute("selected")).toBe(false)
		tap(find(modals(world), "Offer_heartyRations")) -- drop one
		tap(find(modals(world), "Offer_crowdRally")) -- and take the Rally
		picker = find(modals(world), "LoadoutPicker")
		expect(find(picker, "Weapon_spear"):GetAttribute("selected")).toBe(true)
		expect(find(picker, "Offer_crowdRally"):GetAttribute("selected")).toBe(true)
		expect(texts(picker)).toContain("Perks 3 of 3")
		tap(find(picker, "Ready"))
		world:advance(0.2)
		local choice = world.arenaServer.choices[1]
		expect(choice.weapon).toBe("spear")
		expect(choice.armour).toBe("light")
		expect(table.find(choice.triggers, "crowdRally")).toBeTruthy()
		expect(table.find(choice.triggers, "heartyRations")).toBeNil()
		expect(texts(find(modals(world), "LoadoutPicker"))).toContain("You can still change it")
		-- after Ready a change goes out by itself
		tap(find(modals(world), "Weapon_mace"))
		world:advance(0.2)
		expect(#world.arenaServer.choices).toBe(2)
		expect(world.arenaServer.choices[2].weapon).toBe("mace")
	end)

	it("a change made while Arena.Choose is in flight is sent when it answers, before Ready shows", function()
		world = newWorld()
		loadout(world, "adoring")
		-- a 300 ms round trip for Arena.Choose (FORGE-07 M1's repro)
		local remotes = world.hud.remotes
		local invoke = remotes.invoke
		remotes.invoke = function(self, name, ...)
			if name == "Arena.Choose" then
				world.env.wait(0.3)
			end
			return invoke(self, name, ...)
		end
		tap(find(modals(world), "Weapon_spear"))
		tap(find(modals(world), "Ready"))
		world:advance(0.05)
		tap(find(modals(world), "Weapon_mace")) -- while the first call is in flight
		world:advance(2)
		local choices = world.arenaServer.choices
		expect(#choices).toBe(2)
		expect(choices[#choices].weapon).toBe("mace") -- the server holds what the screen shows
		expect(texts(find(modals(world), "LoadoutPicker"))).toContain("Ready ✓")
		remotes.invoke = invoke
	end)

	it("a new deadline for the same pair keeps the accepted choice (no reseed, no auto-send over it)", function()
		world = newWorld()
		loadout(world, "adoring", 6)
		tap(find(modals(world), "Offer_heartyRations")) -- drop one
		tap(find(modals(world), "Offer_crowdRally"))
		tap(find(modals(world), "Ready"))
		world:advance(0.2)
		expect(#world.arenaServer.choices).toBe(1)
		local st = world.arenaServer.state
		world.arenaServer:setState({ stage = "loadout", endsAt = st.endsAt + 5, a = st.a, b = st.b })
		world:advance(0.3)
		local picker = find(modals(world), "LoadoutPicker")
		expect(find(picker, "Offer_crowdRally"):GetAttribute("selected")).toBe(true)
		expect(find(picker, "Offer_heartyRations"):GetAttribute("selected")).toBe(false)
		world:advance(9)
		expect(#world.arenaServer.choices).toBe(1) -- nothing sent over it
	end)

	it("nothing chosen: the current choice is sent before the time runs out", function()
		world = newWorld()
		loadout(world, "loyal", 4)
		expect(#world.arenaServer.choices).toBe(0)
		world:advance(3)
		expect(#world.arenaServer.choices).toBe(1)
		local c = world.arenaServer.choices[1]
		expect(c.weapon).toBe("swordShield")
		expect(c.armour).toBe("medium")
		expect(#c.triggers).toBe(3)
	end)

	it("a refusal is said in words and the picker stays", function()
		world = newWorld()
		loadout(world, "adoring")
		world.arenaServer.support[1].slots = 1 -- the server's view changed under the picker
		tap(find(modals(world), "Ready"))
		world:advance(0.2)
		expect(#world.arenaServer.choices).toBe(0)
		expect(texts(find(modals(world), "LoadoutPicker"))).toContain("Too many perks for your slots")
	end)

	it("Hostile support: no perk slots, said in words; a spectator gets no picker", function()
		world = newWorld()
		loadout(world, "hostile")
		expect(texts(find(modals(world), "LoadoutPicker"))).toContain("Hostile support: no perk slots this duel")
		world:destroy()
		world = newWorld({ userId = 9 })
		loadout(world, "adoring")
		expect(find(modals(world), "LoadoutPicker")).toBeNil()
		expect(world.hud.guis.hud.Enabled).toBe(true) -- not a champion: the kingdom HUD stays
	end)

	it("phone 667 × 375: inside the screen below the top bar; every tap target ≥ 44 px", function()
		world = newWorld({ width = 667, height = 375 })
		loadout(world, "adoring")
		local picker = find(modals(world), "LoadoutPicker")
		local panel = picker:FindFirstChild("Panel")
		expect(panel.Position.Y.Offset).toBe(52)
		expect(panel.Size.X.Offset <= 667 - 16).toBe(true)
		expect(panel.Position.Y.Offset + panel.Size.Y.Offset <= 375).toBe(true)
		for _, d in picker:GetDescendants() do
			if string.match(d.Name, "^Offer_") then
				expect(d.Size.Y.Offset >= 44).toBe(true)
			end
		end
		local cells = find(picker, "Weapons"):FindFirstChildOfClass("UIGridLayout").CellSize
		expect(cells.Y.Offset >= 44).toBe(true)
		expect(find(picker, "Ready").Size.Y.Offset >= 44).toBe(true)
	end)

	it(
		"phone tiles use the short blurb where the full one needs three lines (Mace, FL-0138); desktop the full",
		function()
			world = newWorld({ width = 667, height = 317 })
			loadout(world, "adoring")
			expect(find(find(modals(world), "Weapon_mace"), "Blurb").Text).toBe("Breaks guards by draining stamina")
			expect(find(find(modals(world), "Weapon_spear"), "Blurb").Text).toBe("The fastest light attack")
			world:destroy()
			world = newWorld({ width = 1920, height = 1022 })
			loadout(world, "adoring")
			expect(find(find(modals(world), "Weapon_mace"), "Blurb").Text).toBe(
				"Breaks guards: blocked hits cost more stamina"
			)
		end
	)

	it("a gamepad starts on the first weapon and keeps its place across a re-render", function()
		local gui = { SelectedObject = nil }
		world = newWorld({ envServices = { UserInputService = { GamepadEnabled = true }, GuiService = gui } })
		loadout(world, "adoring")
		expect(gui.SelectedObject).toBeTruthy()
		expect(gui.SelectedObject.Name).toBe("Weapon_swordShield")
		gui.SelectedObject = find(modals(world), "Weapon_mace")
		tap(gui.SelectedObject)
		local now = find(modals(world), "Weapon_mace")
		expect(now:GetAttribute("selected")).toBe(true)
		expect(gui.SelectedObject).toBe(now) -- the rebuilt tile, not the destroyed one
	end)
end)

describe("Crown Arena: intro card and duel HUD (FL-0073)", function()
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

	local function duellists()
		local a = ArenaDoubles.duellist(1, "crimson", "adoring", {
			weapon = "spear",
			armour = "light",
			triggers = { "reforge", "crowdRally" },
			triggerCitizens = { reforge = { name = "Bram", role = "blacksmith" } },
		})
		local b = ArenaDoubles.duellist(7, "azure", "divided", { weapon = "mace", armour = "heavy", triggers = {} })
		return a, b
	end

	it("the intro shows both sides with tier, reasons, loadout and perks; the kingdom HUD steps aside", function()
		world = newWorld({ userId = 9 }) -- a watching ruler
		local a, b = duellists()
		world.arenaServer:setState({ stage = "intro", endsAt = world.env.serverTimeNow() + 12, a = a, b = b })
		world:advance(0.3)
		local intro = find(modals(world), "ArenaIntro")
		expect(intro).toBeTruthy()
		local left = find(intro, "Side_left")
		expect(left:GetAttribute("side")).toBe("a")
		expect(texts(left)).toContain("Emberhold")
		expect(texts(left)).toContain("Adoring support · 91")
		expect(texts(left)).toContain("Kept the granary full through the Conflict")
		expect(texts(find(left, "Perk_reforge"))).toContain("Bram · Blacksmith")
		expect(texts(find(intro, "Side_right"))).toContain("No perks")
		expect(world.hud.guis.hud.Enabled).toBe(false)
		expect(world.hud.guis.topbar.Enabled).toBe(false)
	end)

	it("the duel HUD follows hits, snapshots and perks; it sits at the top, clear of the duel buttons", function()
		world = newWorld({ width = 667, height = 375 })
		local a, b = duellists()
		world.arenaServer:setState({ stage = "duel", endsAt = world.env.serverTimeNow() + 120, a = a, b = b })
		world:advance(0.3)
		local hud = find(modals(world), "ArenaHud")
		expect(hud).toBeTruthy()
		expect(find(find(hud, "Side_left"), "Stamina"):GetAttribute("share")).toBeNil()
		world.arenaServer:events({
			{ t = 5, kind = "hit", side = "b", data = { damageShare = 0.1, hpShare = 0.2 } },
			{
				t = 5.1,
				kind = "snapshot",
				side = "a",
				data = { a = { hpShare = 0.2, staminaShare = 0.5 }, b = { hpShare = 1, staminaShare = 0.9 } },
			},
			{
				t = 12,
				kind = "triggerFired",
				side = "a",
				data = { source = "perk:reforge", trigger = "reforge", citizenName = "Bram" },
			},
		})
		world:advance(0.3)
		hud = find(modals(world), "ArenaHud")
		local left = find(hud, "Side_left")
		expect(find(left, "Hp"):GetAttribute("share")).toBe(0.2)
		expect(texts(find(left, "Hp"))).toBe("20%")
		expect(find(left, "Stamina"):GetAttribute("share")).toBe(0.5)
		expect(find(left, "Perk_reforge"):GetAttribute("state")).toBe("active")
		expect(find(left, "Perk_crowdRally"):GetAttribute("state")).toBe("armed")
		-- numbers alone are patched in place: the same bar instances, new fills (FORGE-07 M2)
		local hp = find(find(modals(world), "Side_left"), "Hp")
		world.arenaServer:events({
			{
				t = 13,
				kind = "snapshot",
				side = "a",
				data = { a = { hpShare = 0.15, staminaShare = 0.4 }, b = { hpShare = 0.9, staminaShare = 0.8 } },
			},
		})
		world:advance(0.3)
		expect(find(find(modals(world), "Side_left"), "Hp")).toBe(hp)
		expect(hp:GetAttribute("share")).toBe(0.15)
		expect(math.abs(hp:FindFirstChild("Fill").Size.X.Scale - 0.15) < 1e-4).toBe(true)
		expect(texts(hp)).toBe("15%")
		world:advance(7)
		expect(find(find(modals(world), "ArenaHud"), "Perk_reforge"):GetAttribute("state")).toBe("spent")
		-- placement: the strip ends above the crowd captions band (y 0.72) and the duel buttons (bottom right)
		local strip = find(modals(world), "ArenaHud")
		local bottom = strip.Position.Y.Offset + strip.Size.Y.Offset
		expect(bottom).toBe(ArenaHud.TOP.phone + ArenaHud.height(world.hud:metrics()))
		expect(bottom < 375 * 0.72 - 100).toBe(true)
		expect(world.hud.guis.hud.Enabled).toBe(false)
		-- the duel ends: the HUD goes and the kingdom HUD returns
		world.arenaServer:setState({ stage = "done", a = a, b = b })
		world:advance(0.3)
		expect(find(modals(world), "ArenaHud")).toBeNil()
		expect(world.hud.guis.hud.Enabled).toBe(true)
	end)

	it("control hints for the champion: the quiet start, again after the input changes, never on touch", function()
		local input = { type = "Enum.UserInputType.Keyboard" }
		local uis = {
			GetLastInputType = function()
				return input.type
			end,
		}
		world = newWorld({ input = true, envServices = { UserInputService = uis } })
		local a, b = duellists()
		world.arenaServer:setState({ stage = "duel", endsAt = world.env.serverTimeNow() + 120, a = a, b = b })
		world:advance(0.5)
		local hints = find(modals(world), "Hints")
		expect(texts(hints)).toBe("Left click Light · R Heavy · Hold F Block · E Parry · Q Dodge")
		world:advance(10)
		expect(find(modals(world), "Hints")).toBeNil() -- the quiet start is over
		input.type = "Enum.UserInputType.Gamepad1"
		world:advance(0.5)
		expect(texts(find(modals(world), "Hints"))).toContain("R1 Light")
		world:advance(5)
		expect(find(modals(world), "Hints")).toBeNil()
		input.type = "Enum.UserInputType.Touch"
		world:advance(0.5)
		expect(find(modals(world), "Hints")).toBeNil() -- the touch buttons carry their own labels
		world:destroy()
		-- a touch phone with a gamepad: its labelled duel buttons show, so no hint line either
		uis.TouchEnabled = true
		input.type = "Enum.UserInputType.Gamepad1"
		world = newWorld({ input = true, envServices = { UserInputService = uis }, width = 667, height = 375 })
		world.arenaServer:setState({ stage = "duel", endsAt = world.env.serverTimeNow() + 120, a = a, b = b })
		world:advance(0.5)
		expect(find(modals(world), "Hints")).toBeNil()
		world:destroy()
		-- a touchscreen laptop on keyboard and mouse keeps the line (FORGE-07 L4)
		input.type = "Enum.UserInputType.Keyboard"
		world = newWorld({ input = true, envServices = { UserInputService = uis } })
		world.arenaServer:setState({ stage = "duel", endsAt = world.env.serverTimeNow() + 120, a = a, b = b })
		world:advance(0.5)
		expect(find(modals(world), "Hints")).toBeTruthy()
		world:destroy()
		uis.TouchEnabled = false
		-- a watching ruler never gets hints
		world = newWorld({ userId = 9, input = true, envServices = { UserInputService = uis } })
		input.type = "Enum.UserInputType.Keyboard"
		world.arenaServer:setState({ stage = "duel", endsAt = world.env.serverTimeNow() + 120, a = a, b = b })
		world:advance(0.5)
		expect(find(modals(world), "ArenaHud")).toBeTruthy()
		expect(find(modals(world), "Hints")).toBeNil()
	end)

	it("without the Arena remotes nothing shows and nothing breaks", function()
		world = KingdomWorld.new({ clientDefinitions = { KingdomHudDef, ArenaHudDef, LoadoutDef, ArenaIntroDef } })
		world.hud = world.client:get("KingdomHudController")
		world.hud:setViewport(1920, 1022)
		world:advance(0.5)
		expect(find(world.hud.guis.modals, "LoadoutPicker")).toBeNil()
		expect(find(world.hud.guis.modals, "ArenaHud")).toBeNil()
		expect(world.client:get("ArenaHudController").state).toBeNil()
		expect(world.hud.guis.hud.Enabled).toBe(true)
	end)
end)
