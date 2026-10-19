-- FL-0138 "How to play": six short cards, config-driven, reachable from the Kingdom menu and (in the Lobby) the rail,
-- with Back / Next by touch and keyboard. The real KingdomHudController and HowToPlayController on the spec world.
local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect, beforeEach, afterEach = T.describe, T.it, T.expect, T.beforeEach, T.afterEach

local ArenaConfig = require("@game/ReplicatedStorage/Forge/Config/Arena")
local Caps = require("@game/ReplicatedStorage/Game/Arena/Caps")
local Create = require("@game/ReplicatedStorage/Forge/UI/Create")
local HowToPlayDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/HowToPlayController")
local HowToPlayModel = require("@game/StarterPlayer/StarterPlayerScripts/Game/UI/HowToPlayModel")
local KingdomHudDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/KingdomHudController")
local KingdomWorld = require("./doubles/KingdomWorld")
local Match = require("@game/ReplicatedStorage/Forge/Config/Match")
local Pacing = require("@game/ReplicatedStorage/Forge/Config/Pacing")

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

local function tap(instance)
	assert(instance, "tap: nothing to tap")
	local face = instance:FindFirstChild("Face") or instance
	expect(Create.fire(face, "Activated")).toBeGreaterThan(0)
end

local function newWorld(opts)
	local o = opts or {}
	local defs = { KingdomHudDef }
	if not o.noHelp then
		table.insert(defs, HowToPlayDef)
	end
	local world = KingdomWorld.new({ clientDefinitions = defs, envServices = o.services })
	world.hud = world.client:get("KingdomHudController")
	world.help = if o.noHelp then nil else world.client:get("HowToPlayController")
	world.hud:setViewport(o.width or 1920, o.height or 1022)
	world:advance(0.2)
	return world
end

local function panel(world)
	return find(world.hud.guis.modals, "HowToPlay")
end

describe("HowToPlayModel (pure)", function()
	it("six cards in match order, each under the word limit, no alliance or betrayal wording", function()
		local cards = HowToPlayModel.cards()
		expect(#cards).toBe(6)
		local ids = {}
		for _, c in cards do
			table.insert(ids, c.id)
			expect(HowToPlayModel.words(c.body)).toBeLessThan(HowToPlayModel.WORD_LIMIT)
			expect(#c.title).toBeGreaterThan(0)
			local lower = string.lower(c.body .. " " .. c.title)
			for _, banned in { "ally", "allies", "alliance", "betray", "robux", "buy now" } do
				expect(string.find(lower, banned, 1, true)).toBeNil()
			end
		end
		expect(table.concat(ids, ",")).toBe("match,crown,kingdom,war,arena,fall")
	end)

	it("Crown Points card names the sources the simulation has (FORGE-07 L1)", function()
		local body = string.lower(HowToPlayModel.cards()[2].body)
		for _, source in { "buildings", "objectives", "enemy units", "keeps" } do
			expect(string.find(body, source, 1, true)).toBeTruthy()
		end
		for _, missing in { "land", "raids" } do
			expect(string.find(body, missing, 1, true)).toBeNil()
		end
	end)

	it("phase lengths come from config Pacing for Match.mode", function()
		local d = Pacing.modes[Match.mode]
		local expected = {}
		for _, phase in HowToPlayModel.PHASES do
			table.insert(expected, `{phase} {math.floor(d[phase] / 60 + 0.5)} min`)
		end
		expect(HowToPlayModel.phases()).toBe(table.concat(expected, ", "))
		expect(HowToPlayModel.cards()[1].body).toContain(HowToPlayModel.phases())
	end)

	it("follows a changed config: phases, the newcomer lock and the support caps", function()
		local pacing = {
			modes = { quick = { Founding = 120, Expansion = 180, Conflict = 240, Endgame = 300 } },
		}
		local match = { mode = "quick", rulers = { newcomerLockSeconds = 45 } }
		local caps = table.clone(Caps.NUMBERS)
		caps.passivePerStat = 0.04
		caps.maxTriggers = 2
		pacing.arena = { duel = 60, intro = 60 }
		local cards = HowToPlayModel.cards({ pacing = pacing, match = match, caps = caps, arena = {} })
		expect(cards[1].body).toContain("Founding 2 min, Expansion 3 min, Conflict 4 min, Endgame 5 min")
		expect(cards[1].body).toContain("about 2 min")
		expect(cards[4].body).toContain("45 seconds")
		expect(cards[5].body).toContain("+4%")
		expect(cards[5].body).toContain("up to 2 short perks")
	end)

	it("the arena's length is Pacing.arena (the expected duel), else config Arena's stages (#237, #244)", function()
		local paced = 0
		for _, sec in Pacing.arena or {} do
			paced += sec
		end
		local staged = 0
		for _, key in HowToPlayModel.ARENA_STAGES do
			staged += ArenaConfig[key] or 0
		end
		local expected = if paced > 0 then paced else staged
		expect(expected).toBeGreaterThan(0)
		local body = HowToPlayModel.cards()[1].body
		expect(body).toContain(`about {math.floor(expected / 60 + 0.5)} min`)
		expect(body).never.toContain("a few min")
		local both = HowToPlayModel.cards({
			arena = { duelMaxSeconds = 600 },
			pacing = { modes = Pacing.modes, arena = { duel = 180 } },
		})
		expect(both[1].body).toContain("about 3 min") -- Pacing.arena wins over config Arena
		local fallback = HowToPlayModel.cards({ arena = { duelMaxSeconds = 240 }, pacing = { modes = Pacing.modes } })
		expect(fallback[1].body).toContain("about 4 min")
		local none = HowToPlayModel.cards({ arena = {}, pacing = { modes = Pacing.modes } })
		expect(none[1].body).toContain("a few min")
	end)

	it("lengths round to the nearest minute", function()
		local s = HowToPlayModel.phases({
			pacing = { modes = { m = { Founding = 150, Expansion = 89, Conflict = 30, Endgame = 600 } } },
			match = { mode = "m" },
		})
		expect(s).toBe("Founding 3 min, Expansion 1 min, Conflict 1 min, Endgame 10 min")
	end)

	it("an untimed phase is named without a length", function()
		local s = HowToPlayModel.phases({
			pacing = { modes = { slice = { Founding = math.huge } } },
			match = { mode = "slice" },
		})
		expect(s).toBe("Founding, Expansion, Conflict, Endgame")
	end)

	it("view: step, first and last, one dot on, index clamped", function()
		local cards = HowToPlayModel.cards()
		local v = HowToPlayModel.view(cards, 2)
		expect(v.step).toBe("2 of 6")
		expect(v.first).toBe(false)
		expect(v.last).toBe(false)
		expect(v.dots[2]).toBe(true)
		expect(v.dots[1]).toBe(false)
		expect(HowToPlayModel.view(cards, 1).first).toBe(true)
		expect(HowToPlayModel.view(cards, 6).last).toBe(true)
		expect(HowToPlayModel.view(cards, 99).index).toBe(6)
		expect(HowToPlayModel.view(cards, 0).index).toBe(1)
	end)
end)

describe("How to play (desktop)", function()
	local world, previous
	beforeEach(function()
		previous = Create.useTestConnector()
		world = newWorld()
	end)
	afterEach(function()
		world:destroy()
		Create.setConnector(previous)
	end)

	it("opens from the Kingdom menu's Overview and returns there when closed", function()
		world.hud:setMenu("kingdom")
		world:advance(0.1)
		local button = find(world.hud.guis.menus, "HowToPlay")
		expect(button).toBeTruthy()
		tap(button)
		world:advance(0.1)
		expect(world.hud.state.menu).toBe("howto")
		local p = panel(world)
		expect(p).toBeTruthy()
		expect(p:GetAttribute("card")).toBe("match")
		expect(find(p, "CardBody").Text).toContain(HowToPlayModel.phases())
		tap(find(p, "Close"))
		world:advance(0.1)
		expect(world.hud.state.menu).toBe("kingdom")
		expect(panel(world)).toBeNil()
	end)

	it("Next and Back walk the six cards; Back is off on the first, Done closes on the last", function()
		world.help:open()
		world:advance(0.1)
		expect(find(panel(world), "Back"):FindFirstChild("Face"):GetAttribute("state")).toBe("disabled")
		for i = 2, 6 do
			tap(find(panel(world), "Next"))
			world:advance(0.05)
			expect(panel(world):GetAttribute("index")).toBe(i)
			expect(find(panel(world), "Step").Text).toBe(`{i} of 6`)
		end
		expect(find(panel(world), "Next"):FindFirstChild("Face"):GetAttribute("last")).toBe(true)
		tap(find(panel(world), "Back"))
		world:advance(0.05)
		expect(panel(world):GetAttribute("index")).toBe(5)
		tap(find(panel(world), "Next"))
		world:advance(0.05)
		tap(find(panel(world), "Next")) -- Done
		world:advance(0.05)
		expect(world.hud.state.menu).toBeNil()
		expect(panel(world)).toBeNil()
	end)

	it("keyboard: Right / Enter go on, Left goes back; keys do nothing while closed", function()
		expect(world.help:key(Enum.KeyCode.Right)).toBe(false)
		world.help:open()
		world:advance(0.05)
		expect(world.help:key(Enum.KeyCode.Left)).toBe(true) -- on the first card: stays there
		expect(world.help.index).toBe(1)
		expect(world.help:key(Enum.KeyCode.Right)).toBe(true)
		expect(world.help.index).toBe(2)
		expect(world.help:key(Enum.KeyCode.Return)).toBe(true)
		expect(world.help.index).toBe(3)
		expect(world.help:key(Enum.KeyCode.Left)).toBe(true)
		expect(world.help.index).toBe(2)
		expect(world.help:key(Enum.KeyCode.DPadRight)).toBe(true)
		expect(world.help.index).toBe(3)
		expect(world.help:key(Enum.KeyCode.Q)).toBe(false)
		world:advance(0.05)
		expect(panel(world):GetAttribute("index")).toBe(3)
	end)

	it("Close goes back to the Kingdom menu only; opened from another menu it just closes (FORGE-07 L3)", function()
		world.hud:setMenu("build")
		world:advance(0.05)
		world.help:open()
		world.help:close()
		expect(world.hud.state.menu).toBeNil()
	end)

	it("the back key steps a card back, then closes", function()
		world.help:open()
		world.help:next()
		world:advance(0.05)
		expect(world.hud:backPressed()).toBe(true)
		expect(world.help.index).toBe(1)
		expect(world.hud.state.menu).toBe("howto")
		expect(world.hud:backPressed()).toBe(true)
		expect(world.hud.state.menu).toBeNil()
	end)

	it("opening it again starts at the first card; another menu closes it", function()
		world.help:open()
		world.help:next()
		world.help:next()
		world.help:close()
		world.help:open()
		expect(world.help.index).toBe(1)
		world.hud:setMenu("build")
		world:advance(0.1)
		expect(panel(world)).toBeNil()
	end)

	it("a HUD re-render (treasury push) leaves the open card alone", function()
		world.help:open()
		world:advance(0.05)
		local p = panel(world)
		world.treasury:deposit("crimson", "food", 5, "howto:food", "test")
		world:advance(0.1)
		expect(panel(world)).toBe(p)
	end)

	it("the Kingdom and Raid onboarding targets do not collide with the How to play rail target", function()
		world.hud:setMenu("kingdom")
		world:advance(0.1)
		expect(find(world.hud.guis.hud, "Menu_kingdom"):GetAttribute("OnboardingTarget")).toBe("HUD.KingdomButton")
	end)
end)

describe("How to play: Lobby, phone, without the controller", function()
	local previous
	beforeEach(function()
		previous = Create.useTestConnector()
	end)
	afterEach(function()
		Create.setConnector(previous)
	end)

	it("a 'How to play' rail button during the Lobby countdown, gone when Founding starts", function()
		local world = newWorld()
		world.match:setPhase("Lobby", world.env.serverTimeNow() + 20)
		world:advance(0.2)
		local rail = find(world.hud.guis.hud, "Menu_howto")
		expect(rail).toBeTruthy()
		expect(rail:GetAttribute("OnboardingTarget")).toBe("HUD.HowToPlayButton")
		tap(rail)
		world:advance(0.1)
		expect(world.hud.state.menu).toBe("howto")
		world.help:close()
		world.match:setPhase("Founding", world.env.serverTimeNow() + 480)
		world:advance(0.2)
		expect(find(world.hud.guis.hud, "Menu_howto")).toBeNil()
		world:destroy()
	end)

	it(
		"keys go through ContextActionService above the camera, on key down only, sunk when handled (FORGE-07 L3)",
		function()
			local actions = { bound = {}, unbound = 0 }
			function actions:BindActionAtPriority(name, handler, _touch, priority, ...)
				self.bound[name] = { handler = handler, priority = priority, keys = { ... } }
			end
			function actions:UnbindAction(name)
				self.bound[name] = nil
				self.unbound += 1
			end
			local world = newWorld({ services = { ContextActionService = actions } })
			world.help:open()
			world:advance(0.05)
			local entry = actions.bound.ForgeHowToPlay
			expect(entry).toBeTruthy()
			expect(entry.priority).toBe(Enum.ContextActionPriority.High.Value + 10)
			expect(table.find(entry.keys, Enum.KeyCode.Right)).toBeTruthy()
			expect(table.find(entry.keys, Enum.KeyCode.Left)).toBeTruthy()
			local Begin, End = Enum.UserInputState.Begin, Enum.UserInputState.End
			local Sink, Pass = Enum.ContextActionResult.Sink, Enum.ContextActionResult.Pass
			expect(entry.handler("x", Begin, { KeyCode = Enum.KeyCode.Right })).toBe(Sink)
			expect(world.help.index).toBe(2)
			expect(entry.handler("x", End, { KeyCode = Enum.KeyCode.Right })).toBe(Sink)
			expect(world.help.index).toBe(2) -- key up does not step again
			expect(entry.handler("x", Begin, { KeyCode = Enum.KeyCode.Q })).toBe(Pass)
			world.help:close()
			world:advance(0.05)
			expect(actions.bound.ForgeHowToPlay).toBeNil()
			expect(actions.unbound).toBe(1)
			world:destroy()
		end
	)

	it("destroy takes the Lobby rail button away (FORGE-07 L3)", function()
		local world = newWorld()
		world.match:setPhase("Lobby", world.env.serverTimeNow() + 20)
		world:advance(0.2)
		expect(find(world.hud.guis.hud, "Menu_howto")).toBeTruthy()
		world.help:destroy()
		world.hud:render()
		world:advance(0.1)
		expect(find(world.hud.guis.hud, "Menu_howto")).toBeNil()
		world:destroy()
	end)

	it("phone 667 × 375: the panel fits the screen with 44 px Back and Next", function()
		local world = newWorld({ width = 667, height = 375 })
		world.help:open()
		world:advance(0.1)
		local p = panel(world)
		local box = find(p, "Panel") or p:FindFirstChildWhichIsA("Frame", true)
		local m = world.hud:metrics()
		expect(find(p, "Back").Size.Y.Offset).toBe(44)
		expect(find(p, "Next").Size.Y.Offset).toBe(44)
		local panelFrame = p:FindFirstChild("Panel")
		expect(panelFrame.Size.X.Offset).toBeLessThan(m.width - 15)
		-- below the Roblox top bar (58 px): centred 4 px low
		local top = m.height * 0.5 + panelFrame.Position.Y.Offset - panelFrame.Size.Y.Offset / 2
		expect(top).toBeGreaterThan(57)
		expect(top + panelFrame.Size.Y.Offset).toBeLessThan(m.height + 1)
		expect(box).toBeTruthy()
		world:destroy()
	end)

	it("without HowToPlayController the Kingdom menu has no How to play button", function()
		local world = newWorld({ noHelp = true })
		world.hud:setMenu("kingdom")
		world:advance(0.1)
		expect(find(world.hud.guis.menus, "HowToPlay")).toBeNil()
		world:destroy()
	end)
end)
