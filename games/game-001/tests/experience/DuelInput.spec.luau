local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local MockEnv = require("../../../../roblox/tests/mocks/MockEnv")
local D = require("./RulerDoubles")
local ArenaDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/InputModeArenaController")
local InputModeDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/InputModeController")
local DuelDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/DuelController")

local ME = 7501
local RIVAL = 7502

local function duellist(userId, isAI)
	return {
		userId = userId,
		kingdom = "k" .. userId,
		isAI = isAI == true,
		tier = "loyal",
		score = 50,
		triggers = {},
		reasons = {},
	}
end

local function state(stage, a, b)
	return { stage = stage, a = a, b = b }
end

-- FORGE-01's DuelController (G12.6), as a double: records every act() and, like the real one,
-- returns true for an action it sent
local function duelDef(initial, fails)
	return {
		name = "DuelController",
		dependencies = {},
		new = function()
			return {
				acts = {},
				act = function(self, action)
					if fails then
						error("arena remote missing")
					end
					table.insert(self.acts, action)
					return true
				end,
				getState = function()
					return initial
				end,
			}
		end,
	}
end

local function boot(opts)
	opts = opts or {}
	local env = MockEnv.new({ seed = 75, isServer = false, localPlayer = { userId = opts.userId or ME } })
	local actions = if opts.noActions then nil else D.actions()
	local arenaOpts = {
		actions = actions,
		userInput = opts.userInput,
		touch = opts.touch,
		playerGui = opts.playerGui,
		viewport = opts.viewport,
		studio = opts.studio,
	}
	local extra = {
		{
			name = "InputModeArenaController",
			dependencies = { "InputModeController" },
			new = function(e, r)
				return ArenaDef.create(e, r, arenaOpts)
			end,
		},
	}
	if opts.realDuel then -- FORGE-01's real DuelController, with its client copy of the Arena.Action bucket
		table.insert(extra, 1, {
			name = "DuelController",
			dependencies = {},
			new = function(e, r)
				return DuelDef.new(e, r)
			end,
		})
	elseif opts.duel ~= false then
		table.insert(extra, 1, duelDef(opts.initial, opts.fails))
	end
	local registry = D.boot(env, {
		input = { actions = actions },
		ruler = { actions = actions },
		camera = opts.camera or false,
		extra = extra,
	})
	return {
		env = env,
		actions = actions,
		registry = registry,
		input = registry:get("InputModeController"),
		arena = registry:get("InputModeArenaController"),
		duel = registry:find("DuelController"),
	}
end

local function bindingFor(action)
	return ArenaDef.BINDINGS[action].name
end

describe("InputModeArenaController: when the duel input is on (FL-0075, G12.6)", function()
	it("the champion enters arena mode at the duel stage; a spectator, an AI namesake or the intro never do", function()
		local t = boot()
		local seen = {}
		t.arena.changed:connect(function(active)
			table.insert(seen, active)
		end)
		t.arena:onArenaState(state("intro", duellist(ME), duellist(RIVAL)))
		expect(t.input.mode).toBe("explore")
		t.arena:onArenaState(state("duel", duellist(RIVAL), duellist(ME)))
		expect(t.input.mode).toBe("arena")
		expect(t.arena.active).toBe(true)
		expect(seen).toEqual({ true })

		local spectator = boot({ userId = 7999 })
		spectator.arena:onArenaState(state("duel", duellist(ME), duellist(RIVAL)))
		expect(spectator.input.mode).toBe("explore")
		expect(spectator.arena.active).toBe(false)

		local namesake = boot()
		namesake.arena:onArenaState(state("duel", duellist(ME, true), duellist(RIVAL)))
		expect(namesake.input.mode).toBe("explore")
		expect(ArenaDef.isDuellist(state("duel", nil, nil), ME)).toBe(false)
		expect(ArenaDef.isDuellist("duel", ME)).toBe(false)
	end)

	it("leaves at crowning or done, when a state stops naming us, and at Results or Lobby", function()
		local t = boot()
		local function enter()
			t.arena:onArenaState(state("duel", duellist(ME), duellist(RIVAL)))
			expect(t.input.mode).toBe("arena")
		end
		enter()
		t.arena:onArenaState(state("crowning", duellist(ME), duellist(RIVAL)))
		expect(t.input.mode).toBe("explore")
		expect(t.arena.active).toBe(false)
		enter()
		t.arena:onArenaState(state("done"))
		expect(t.input.mode).toBe("explore")
		enter()
		t.arena:onArenaState(state("duel", duellist(RIVAL), duellist(7600)))
		expect(t.input.mode).toBe("explore")
		enter()
		t.arena:onPhase("Arena")
		expect(t.input.mode).toBe("arena")
		t.arena:onPhase("Results")
		expect(t.input.mode).toBe("explore")
		enter()
		t.arena:onPhase("Lobby")
		expect(t.input.mode).toBe("explore")
		t.arena:onArenaState("duel") -- not a state: ignored
		expect(t.input.mode).toBe("explore")
	end)

	it("starts from DuelController:getState() when the duel is already on", function()
		local t = boot({ initial = state("duel", duellist(ME), duellist(RIVAL)) })
		expect(t.input.mode).toBe("arena")
		expect(t.arena.active).toBe(true)
	end)

	it("while the duel is ours, a respawn's explore re-enters arena mode and build or edit are refused", function()
		local t = boot()
		t.arena:onArenaState(state("duel", duellist(ME), duellist(RIVAL)))
		t.input:set("explore") -- RulerController on a respawn
		expect(t.input.mode).toBe("arena")
		expect(t.arena.active).toBe(true)
		expect(t.input:set("build")).toBe(false)
		expect(t.input:set("edit")).toBe(false)
		expect(t.input:set("build")).toBe(false)
		expect(t.input.mode).toBe("arena")
		local refusals = 0
		for _, entry in t.env.mock.logs do
			if entry.level == "warn" and string.find(entry.message, "is refused during the arena duel", 1, true) then
				refusals += 1
			end
		end
		expect(refusals).toBe(2)
		-- after the duel every mode works again
		t.arena:onArenaState(state("crowning", duellist(ME), duellist(RIVAL)))
		expect(t.input:set("build")).toBe(true)
		expect(t.input.mode).toBe("build")
	end)

	it("arena mode never binds InputMode's X / B leave keys, and selects, hovers or goes back on nothing", function()
		local t = boot()
		t.input:select("citizen", 12)
		t.arena:onArenaState(state("duel", duellist(ME), duellist(RIVAL)))
		expect(t.actions.bound[InputModeDef.ACTION]).toBeNil()
		expect(t.input.selection.kind).toBe("none") -- panels close for the duel
		t.env.mock:advance(1)
		expect(t.input:accepts("explore")).toBe(false)
		local backs = 0
		local release = t.input:onBack(function()
			backs += 1
			return true
		end)
		expect(t.input:tapAt(Vector2.new(10, 10))).toBeNil()
		release()
		expect(backs).toBe(0)
	end)
end)

describe("InputModeArenaController: keys, gamepad and DuelController:act (FL-0075)", function()
	it("binds the five actions at High priority only while in arena mode, and unbinds them after", function()
		local t = boot()
		for _, action in ArenaDef.ACTIONS do
			expect(t.actions.bound[bindingFor(action)]).toBeNil()
		end
		t.arena:onArenaState(state("duel", duellist(ME), duellist(RIVAL)))
		for _, action in ArenaDef.ACTIONS do
			local bound = t.actions.bound[bindingFor(action)]
			assert(bound ~= nil, `{action} is bound in the duel`)
			expect(bound.keys).toEqual(ArenaDef.BINDINGS[action].keys)
			expect(bound.priority).toBe(Enum.ContextActionPriority.High.Value)
			expect(bound.touch).toBe(false)
		end
		expect(ArenaDef.BINDINGS.light.keys).toEqual({ Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR1 })
		expect(ArenaDef.BINDINGS.dodge.keys).toEqual({ Enum.KeyCode.Q, Enum.KeyCode.ButtonB })
		t.arena:onArenaState(state("crowning", duellist(ME), duellist(RIVAL)))
		for _, action in ArenaDef.ACTIONS do
			expect(t.actions.bound[bindingFor(action)]).toBeNil()
		end
	end)

	it("every press reaches DuelController:act once, on the press, never on the release", function()
		local t = boot()
		t.arena:onArenaState(state("duel", duellist(ME), duellist(RIVAL)))
		local Begin, End = Enum.UserInputState.Begin, Enum.UserInputState.End
		for _, action in { "light", "heavy", "parry", "dodge" } do
			local key = ArenaDef.BINDINGS[action].keys[2]
			expect(t.actions:press(bindingFor(action), Begin, { KeyCode = key })).toBe(Enum.ContextActionResult.Sink)
			t.actions:press(bindingFor(action), End, { KeyCode = key })
		end
		expect(t.duel.acts).toEqual({ "light", "heavy", "parry", "dodge" })
		t.actions:press(bindingFor("light"), Begin, { UserInputType = Enum.UserInputType.MouseButton1 })
		expect(t.duel.acts[5]).toBe("light")
		expect(#t.duel.acts).toBe(5)
	end)

	it("block is held: the press sends block, the last release blockEnd, and leaving mid-block ends it", function()
		local t = boot()
		t.arena:onArenaState(state("duel", duellist(ME), duellist(RIVAL)))
		local Begin, End = Enum.UserInputState.Begin, Enum.UserInputState.End
		local name = bindingFor("block")
		t.actions:press(name, Begin, { KeyCode = Enum.KeyCode.F })
		t.arena:press("block", true, "touch:block")
		expect(t.duel.acts).toEqual({ "block" })
		t.actions:press(name, End, { KeyCode = Enum.KeyCode.F })
		expect(t.duel.acts).toEqual({ "block" }) -- the touch still holds it
		t.arena:press("block", false, "touch:block")
		expect(t.duel.acts).toEqual({ "block", "blockEnd" })
		t.arena:press("block", false, "touch:block") -- a stray release sends nothing
		expect(t.duel.acts).toEqual({ "block", "blockEnd" })
		t.actions:press(name, Begin, { KeyCode = Enum.KeyCode.ButtonL1 })
		t.arena:onArenaState(state("crowning", duellist(ME), duellist(RIVAL)))
		expect(t.duel.acts).toEqual({ "block", "blockEnd", "block", "blockEnd" })
		t.actions:press(name, Enum.UserInputState.Cancel, { KeyCode = Enum.KeyCode.ButtonL1 })
		expect(#t.duel.acts).toBe(4)
	end)

	it("a blockEnd the real DuelController's empty bucket refuses is sent once a token returns (#249)", function()
		local function run(after)
			local t = boot({ realDuel = true })
			local sent = {}
			local realAct = t.duel.act
			t.duel.act = function(self, action)
				local ok = realAct(self, action)
				if ok then
					table.insert(sent, action)
				end
				return ok
			end
			local duel = state("duel", duellist(ME), duellist(RIVAL))
			t.duel:setState(duel)
			t.arena:onArenaState(duel)
			expect(t.arena:press("block", true, "key")).toBe(true)
			for _ = 2, t.duel.BURST do
				expect(t.arena:press("light", true)).toBe(true) -- the bucket is now empty
			end
			expect(t.arena:press("light", true)).toBe(false) -- refused: press() reports act()'s answer
			expect(t.arena:press("block", false, "key")).toBe(false) -- blockEnd refused for now
			after(t, duel)
			return sent
		end
		local function count(list, action)
			local n = 0
			for _, a in list do
				n += if a == action then 1 else 0
			end
			return n
		end
		-- a token comes back within 1/12 s: blockEnd goes out then, once
		local sent = run(function(t)
			t.env.mock:advance(0.05)
			t.env.mock:advance(0.1)
			t.env.mock:advance(1)
		end)
		expect(sent[#sent]).toBe("blockEnd")
		expect(count(sent, "blockEnd")).toBe(1)
		-- block pressed again before a token: the pending blockEnd must not end the new block
		sent = run(function(t)
			t.arena:press("block", true, "key")
			t.env.mock:advance(1)
		end)
		expect(count(sent, "blockEnd")).toBe(0)
		-- the duel ends first: nothing more is tried
		sent = run(function(t, duel)
			local over = table.clone(duel)
			over.stage = "crowning"
			t.duel:setState(over)
			t.arena:onArenaState(over)
			t.env.mock:advance(1)
		end)
		expect(count(sent, "blockEnd")).toBe(0)
	end)

	it("sent fires once for each action act() sent: never for a refused, a throwing or a preview press", function()
		local t = boot({ realDuel = true })
		local fired = {}
		t.arena.sent:connect(function(action)
			table.insert(fired, action)
		end)
		local duel = state("duel", duellist(ME), duellist(RIVAL))
		t.duel:setState(duel)
		t.arena:onArenaState(duel)
		t.arena:press("block", true, "key")
		t.arena:press("block", false, "key")
		expect(fired).toEqual({ "block", "blockEnd" })
		for _ = 1, t.duel.BURST do
			t.arena:press("light", true)
		end
		expect(#fired).toBe(t.duel.BURST) -- the 9th light, refused by the bucket, fired nothing
		local throwing = boot({ fails = true })
		local none = 0
		throwing.arena.sent:connect(function()
			none += 1
		end)
		throwing.arena:onArenaState(state("duel", duellist(ME), duellist(RIVAL)))
		throwing.arena:press("light", true)
		expect(none).toBe(0)
		local preview = boot({ studio = true })
		local previewed = 0
		preview.arena.sent:connect(function()
			previewed += 1
		end)
		preview.arena:preview(true)
		preview.arena:press("light", true)
		expect(previewed).toBe(0) -- nothing was sent
	end)

	it("the refused blockEnd: sent within 0.1 s, and no act() call at all once the duel is over (#259 L1)", function()
		local t = boot({ realDuel = true })
		local calls, sentAt = {}, nil
		local realAct = t.duel.act
		t.duel.act = function(self, action)
			local ok = realAct(self, action)
			table.insert(calls, { action = action, ok = ok, at = t.env.clock() })
			if ok and action == "blockEnd" then
				sentAt = t.env.clock()
			end
			return ok
		end
		local duel = state("duel", duellist(ME), duellist(RIVAL))
		t.duel:setState(duel)
		t.arena:onArenaState(duel)
		t.arena:press("block", true, "key")
		for _ = 2, t.duel.BURST do
			t.arena:press("light", true) -- the bucket is now empty
		end
		local t0 = t.env.clock()
		expect(t.arena:press("block", false, "key")).toBe(false) -- refused for now
		for _ = 1, 12 do
			t.env.mock:advance(1 / 120)
		end
		-- a token returns after 1/12 s (12 a second); the next retry, at most RETRY_SEC later, sends it
		assert(sentAt ~= nil, "the blockEnd went out within 0.1 s")
		expect(sentAt - t0 <= 1 / 12 + ArenaDef.RETRY_SEC + 1e-6).toBe(true)
		-- again, with the duel over before a token returns: the retry stops without calling act() again
		t = boot({ realDuel = true })
		calls = {}
		realAct = t.duel.act
		t.duel.act = function(self, action)
			table.insert(calls, action)
			return realAct(self, action)
		end
		t.duel:setState(duel)
		t.arena:onArenaState(duel)
		t.arena:press("block", true, "key")
		for _ = 2, t.duel.BURST do
			t.arena:press("light", true)
		end
		t.arena:press("block", false, "key")
		local before = #calls
		local over = table.clone(duel)
		over.stage = "crowning"
		t.duel:setState(over)
		t.arena:onArenaState(over)
		t.env.mock:advance(1)
		expect(#calls).toBe(before) -- no act() after the crowning, not even a refused one
	end)

	it("an act() that throws on the release is logged once and not retried (#259 L1)", function()
		local env = MockEnv.new({ seed = 76, isServer = false, localPlayer = { userId = ME } })
		local actions = D.actions()
		local calls = 0
		local throwing = {
			name = "DuelController",
			dependencies = {},
			new = function()
				return {
					act = function()
						calls += 1
						error("arena remote missing")
					end,
					getState = function()
						return nil
					end,
				}
			end,
		}
		local registry = D.boot(env, {
			input = { actions = actions },
			ruler = { actions = actions },
			camera = false,
			extra = {
				throwing,
				{
					name = "InputModeArenaController",
					dependencies = { "InputModeController" },
					new = function(e, r)
						return ArenaDef.create(e, r, { actions = actions })
					end,
				},
			},
		})
		local arena = registry:get("InputModeArenaController")
		arena:onArenaState(state("duel", duellist(ME), duellist(RIVAL)))
		expect(arena:press("block", true, "key")).toBe(false)
		expect(arena:press("block", false, "key")).toBe(false)
		env.mock:advance(1)
		expect(calls).toBe(2) -- the press and the release, never a retry loop of throws
		expect(env.mock:hasLog("warn", "DuelController:act('blockEnd') failed")).toBe(true)
	end)

	it("press() sends nothing outside arena mode or for an unknown action", function()
		local t = boot()
		expect(t.arena:press("light", true)).toBe(false)
		t.arena:onArenaState(state("duel", duellist(ME), duellist(RIVAL)))
		expect(t.arena:press("kick", true)).toBe(false)
		expect(t.arena:press("blockEnd", true)).toBe(false) -- only the release sends it
		expect(t.arena:press(nil, true)).toBe(false)
		expect(t.arena:press("heavy", true)).toBe(true)
		expect(t.duel.acts).toEqual({ "heavy" })
	end)

	it("without a DuelController it sends nothing and logs once; a failing act() is logged once", function()
		local t = boot({ duel = false })
		t.arena:onArenaState(state("duel", duellist(ME), duellist(RIVAL)))
		expect(t.input.mode).toBe("arena")
		expect(t.arena:press("light", true)).toBe(false)
		expect(t.arena:press("heavy", true)).toBe(false)
		local infos = 0
		for _, entry in t.env.mock.logs do
			if string.find(entry.message, "no DuelController yet", 1, true) then
				infos += 1
			end
		end
		expect(infos).toBe(1)

		local failing = boot({ fails = true })
		failing.arena:onArenaState(state("duel", duellist(ME), duellist(RIVAL)))
		expect(failing.arena:press("light", true)).toBe(false)
		expect(failing.arena:press("light", true)).toBe(false)
		expect(failing.env.mock:hasLog("warn", "DuelController:act('light') failed")).toBe(true)
		expect(failing.env.mock.threadErrors).toEqual({})
	end)

	it("works without ContextActionService (headless): the mode still switches, keys are skipped", function()
		local t = boot({ noActions = true })
		t.arena:onArenaState(state("duel", duellist(ME), duellist(RIVAL)))
		expect(t.input.mode).toBe("arena")
		expect(t.arena:press("dodge", true)).toBe(true)
		expect(t.duel.acts).toEqual({ "dodge" })
		expect(t.env.mock.threadErrors).toEqual({})
	end)

	it(
		"Studio preview (E16): the controls without a duel, presses logged and never sent; never outside Studio",
		function()
			local live = boot({ studio = false })
			expect(live.arena:preview(true)).toBe(false)
			expect(live.input.mode).toBe("explore")

			local t = boot({ studio = true })
			expect(t.arena:preview(true)).toBe(true)
			expect(t.input.mode).toBe("arena")
			t.input:set("explore") -- a respawn keeps the preview on
			expect(t.input.mode).toBe("arena")
			expect(t.arena:press("parry", true)).toBe(true)
			expect(t.duel.acts).toEqual({})
			expect(t.env.mock:hasLog("info", "InputModeArenaController preview: parry")).toBe(true)
			-- a real duel takes over: presses are sent again, and its end does not end the preview
			t.arena:onArenaState(state("duel", duellist(ME), duellist(RIVAL)))
			t.arena:press("light", true)
			expect(t.duel.acts).toEqual({ "light" })
			t.arena:onArenaState(state("crowning", duellist(ME), duellist(RIVAL)))
			expect(t.input.mode).toBe("arena")
			t.arena:preview(false)
			expect(t.input.mode).toBe("explore")
			expect(t.arena.active).toBe(false)
		end
	)

	it("controls() lists a keyboard, gamepad and touch hint for each of the five actions", function()
		local t = boot()
		local actions = {}
		for _, row in t.arena:controls() do
			table.insert(actions, row.action)
			expect(type(row.keyboard) == "string" and type(row.gamepad) == "string" and type(row.touch) == "string").toBe(
				true
			)
		end
		expect(actions).toEqual(ArenaDef.ACTIONS)
	end)
end)

describe("InputModeArenaController: touch buttons (FL-0075)", function()
	local function within(button, layout)
		local half = button.size / 2
		return button.x + half <= -4 and button.y + half <= -4 and ArenaDef.reach(button) <= layout.reach
	end

	local function rect(button)
		local half = button.size / 2
		return { left = button.x - half, right = button.x + half, top = button.y - half, bottom = button.y + half }
	end

	local function apart(a, b, gap)
		return a.right + gap <= b.left or b.right + gap <= a.left or a.bottom + gap <= b.top or b.bottom + gap <= a.top
	end

	it(
		"both layouts: five buttons at least 44 px, apart from each other and the jump button, in thumb reach",
		function()
			for _, small in { true, false } do
				local layout = if small then ArenaDef.TOUCH.small else ArenaDef.TOUCH.large
				local buttons = ArenaDef.layout(small)
				expect(#buttons).toBe(5)
				local jump = { left = layout.jump.left, top = layout.jump.top }
				jump.right = jump.left + layout.jump.size
				jump.bottom = jump.top + layout.jump.size
				for i, button in buttons do
					expect(button.size >= ArenaDef.MIN_TOUCH_PX).toBe(true)
					assert(within(button, layout), `{button.action} is on screen and within reach ({small})`)
					assert(apart(rect(button), jump, 8), `{button.action} clears the jump button ({small})`)
					for j = i + 1, #buttons do
						assert(
							apart(rect(button), rect(buttons[j]), 8),
							`{button.action} and {buttons[j].action} are apart`
						)
					end
				end
				expect(buttons[1].action).toBe("light")
				for _, other in buttons do
					expect(buttons[1].size >= other.size).toBe(true) -- the main attack is the biggest
				end
			end
		end
	)

	it("a touch device gets the buttons under PlayerGui only in arena mode; other devices never do", function()
		local env0 = MockEnv.new({ seed = 76, isServer = false })
		local gui = env0.newInstance("Folder")
		local t = boot({ touch = true, playerGui = gui, viewport = Vector2.new(812, 375) })
		expect(gui:FindFirstChild(ArenaDef.GUI_NAME)).toBeNil()
		t.arena:onArenaState(state("duel", duellist(ME), duellist(RIVAL)))
		local screen = gui:FindFirstChild(ArenaDef.GUI_NAME)
		assert(screen ~= nil, "the duel buttons are shown")
		expect(screen.ResetOnSpawn).toBe(false)
		local found = {}
		for _, child in screen:GetChildren() do
			if child:IsA("TextButton") then
				found[child:GetAttribute("DuelAction")] = child
			end
		end
		for _, button in ArenaDef.layout(true) do
			local view = found[button.action]
			assert(view ~= nil, `{button.action} has a button`)
			expect(view.Size.X.Offset).toBe(button.size)
			expect(view.Size.Y.Offset).toBe(button.size)
			expect(view.Position).toEqual(UDim2.new(1, button.x, 1, button.y))
			expect(view.Text).toBe(button.label)
		end
		expect(t.arena:touchArea()).toEqual({ left = 256, top = 224 }) -- for other UI to keep clear
		t.arena:onArenaState(state("crowning", duellist(ME), duellist(RIVAL)))
		expect(gui:FindFirstChild(ArenaDef.GUI_NAME)).toBeNil()
		expect(t.arena:touchArea()).toBeNil()

		local tablet = boot({ touch = true, playerGui = gui, viewport = Vector2.new(1024, 768) })
		tablet.arena:onArenaState(state("duel", duellist(ME), duellist(RIVAL)))
		local light = gui:FindFirstChild(ArenaDef.GUI_NAME):FindFirstChild("Duel_light")
		expect(light.Size.X.Offset).toBe(ArenaDef.TOUCH.large.light.size)
		expect(tablet.arena:touchArea()).toEqual({ left = 383, top = 392 })
		tablet.arena:onArenaState(state("done"))

		local desk = boot({ touch = false, playerGui = gui })
		desk.arena:onArenaState(state("duel", duellist(ME), duellist(RIVAL)))
		expect(desk.input.mode).toBe("arena")
		expect(gui:FindFirstChild(ArenaDef.GUI_NAME)).toBeNil()
		expect(desk.arena:touchArea()).toBeNil() -- no buttons, nothing to keep clear of
	end)
end)

describe("RulerCameraController in the duel (FL-0075)", function()
	it("switches to the walk camera for the duel, refuses the overview meanwhile, and restores it after", function()
		local actions = D.actions()
		local env = MockEnv.new({ seed = 77, isServer = false, localPlayer = { userId = ME } })
		local registry = D.boot(env, {
			input = { actions = actions },
			ruler = { actions = actions },
			camera = { actions = actions, userInput = D.userInput() },
			extra = {
				duelDef(nil),
				{
					name = "InputModeArenaController",
					dependencies = { "InputModeController" },
					new = function(e, r)
						return ArenaDef.create(e, r, { actions = actions })
					end,
				},
			},
		})
		local camera = registry:get("RulerCameraController")
		local arena = registry:get("InputModeArenaController")
		expect(camera.mode).toBe("overview")
		expect(actions.bound["ForgeRulerView"] ~= nil).toBe(true)
		arena:onArenaState(state("duel", duellist(ME), duellist(RIVAL)))
		expect(camera.mode).toBe("follow")
		expect(actions.bound["ForgeRulerView"]).toBeNil() -- no View touch button among the duel's
		expect(camera:setMode("overview")).toBe(false)
		expect(camera:toggle()).toBe(false)
		actions:press("ForgeRulerView", Enum.UserInputState.Begin)
		expect(camera.mode).toBe("follow")
		expect(actions.bound["ForgeOverviewRotate"]).toBeNil() -- Q / E are the duel's dodge and parry
		arena:onArenaState(state("crowning", duellist(ME), duellist(RIVAL)))
		expect(camera.mode).toBe("overview")
		expect(actions.bound["ForgeRulerView"] ~= nil).toBe(true)
		expect(camera:setMode("follow")).toBe(true)
		expect(camera:setMode("overview")).toBe(true)
	end)
end)
