local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect, beforeEach = T.describe, T.it, T.expect, T.beforeEach

local roblox = require("@lune/roblox")
local MockEnv = require("../../../../roblox/tests/mocks/MockEnv")
local Loader = require("@game/ReplicatedStorage/Forge/Contracts/Loader")
local Signal = require("@game/ReplicatedStorage/Forge/Core/Signal")
local Sounds = require("@game/ReplicatedStorage/Forge/Experience/Sounds")
local VfxPresets = require("@game/ReplicatedStorage/Forge/Experience/VfxPresets")
local Vfx = require("@game/ReplicatedStorage/Forge/Config/Vfx")
local Bubbles = require("@game/ReplicatedStorage/Game/Feedback/Bubbles")
local Consequences = require("@game/ReplicatedStorage/Game/Content/Consequences")
local BubbleDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/CitizenBubbleController")
local EntityController = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/EntityController")
local InputModeDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/InputModeController")
local Create = require("@game/ReplicatedStorage/Forge/UI/Create")

describe("Feedback/Bubbles rules (FL-0091, G13.3)", function()
	local clock, bubbles

	beforeEach(function()
		clock = 0
		bubbles = Bubbles.new({
			now = function()
				return clock
			end,
		})
	end)

	it("one bubble per citizen: a reaction replaces the thought, which cannot interrupt the reaction", function()
		bubbles:thought(1, { text = "The granary is empty, my lord.", icon = "request", scenarioId = "hungry_farmer" })
		expect(bubbles:get(1).kind).toBe("thought")
		expect(bubbles:get(1).glyph).toBe("!")
		bubbles:reaction(1, { text = "Bless you!", tone = "happy" })
		expect(bubbles:get(1).kind).toBe("reaction")
		expect(bubbles:thought(1, { text = "Another thing..." })).toBeNil()
		clock += Bubbles.DEFAULTS.reactionSec
		expect(bubbles:tick()).toEqual({ 1 })
		expect(bubbles:thought(1, { text = "Another thing...", icon = "concern" }).glyph).toBe("?")
	end)

	it("uses only the event's text: no text, no bubble; long text is cut with an ellipsis", function()
		expect(bubbles:thought(2, { icon = "request" })).toBeNil()
		expect(bubbles:reaction(2, { text = "   " })).toBeNil()
		expect(bubbles:thought("2", { text = "x" })).toBeNil()
		expect(bubbles.stats.ignored).toBe(3)
		local long = bubbles:thought(2, { text = string.rep("a", 120) })
		expect(utf8.len(long.text)).toBe(Bubbles.DEFAULTS.maxChars)
		expect(string.sub(long.text, -3)).toBe("…")
	end)

	it("meaning never by colour alone: glyphs for every icon, words on placards, unknown tones are neutral", function()
		for icon, glyph in Bubbles.ICON do
			expect(bubbles:thought(10, { text = "t", icon = icon }).glyph).toBe(glyph)
			bubbles:release(10)
		end
		expect(bubbles:reaction(11, { text = "Hm.", tone = "smug" }).tone).toBe("neutral")
		bubbles:strike(12, true)
		expect(bubbles:get(12).text).toBe(Bubbles.STRIKE_TEXT)
		for _, tone in Bubbles.TONES do
			expect(Bubbles.POSE[tone] ~= nil).toBe(true)
		end
	end)

	it("a strike placard lasts until strike off and shows under no other bubble", function()
		bubbles:strike(3, true)
		clock += 1000
		bubbles:tick()
		expect(bubbles:get(3).kind).toBe("strike")
		bubbles:reaction(3, { text = "We want bread!", tone = "angry" })
		expect(bubbles:get(3).kind).toBe("reaction")
		clock += Bubbles.DEFAULTS.reactionSec
		bubbles:tick()
		expect(bubbles:get(3).kind).toBe("strike")
		bubbles:strike(3, false)
		expect(bubbles:get(3)).toBeNil()
	end)

	it(
		"a riot placard reads 'Rioting', wins over a strike placard and lasts until riot off (G13.3 v0.4-g10c)",
		function()
			bubbles:riot(4, true)
			clock += 1000
			bubbles:tick()
			expect(bubbles:get(4).kind).toBe("riot")
			expect(bubbles:get(4).text).toBe(Bubbles.RIOT_TEXT)
			bubbles:strike(4, true) -- never sent for a rioter, but a riot still reads as a riot
			expect(bubbles:get(4).kind).toBe("riot")
			bubbles:riot(4, false)
			expect(bubbles:get(4).kind).toBe("strike")
			bubbles:strike(4, false)
			bubbles:riot(5, true)
			bubbles:release(5)
			expect(bubbles:get(5)).toBeNil()
			local before = bubbles.stats.ignored
			bubbles:riot(0 / 0, true)
			expect(bubbles.stats.ignored).toBe(before + 1)
			-- placed like a strike placard: as words, before any card, even with no words budget
			bubbles:riot(6, true)
			local picked = bubbles:pick({ [6] = Vector3.new(5, 0, 0) }, Vector3.zero)
			expect(bubbles:layout(picked, 0)[6]).toBe("words")
		end
	)

	it("pick(): within maxDistance, at most maxOnScreen, reactions first, then nearest", function()
		local positions = {}
		for id = 1, 12 do
			bubbles:thought(id, { text = `t{id}` })
			positions[id] = Vector3.new(id * 10, 0, 0)
		end
		bubbles:reaction(12, { text = "far but answered" }) -- 120 studs: within range
		positions[13] = Vector3.new(500, 0, 0)
		bubbles:thought(13, { text = "too far" })
		local picked = bubbles:pick(positions, Vector3.zero)
		expect(#picked).toBe(Bubbles.DEFAULTS.maxOnScreen)
		expect(picked[1]).toBe(12)
		expect(picked[2]).toBe(1)
		expect(table.find(picked, 13)).toBeNil()
		expect(table.find(picked, 9)).toBeNil() -- nine nearer thoughts than 8 slots minus the reaction
	end)

	it("a citizen beyond maxDistance is never picked, even with free slots", function()
		bubbles:thought(1, { text = "near" })
		bubbles:thought(2, { text = "far" })
		local picked = bubbles:pick({
			[1] = Vector3.new(10, 0, 0),
			[2] = Vector3.new(Bubbles.DEFAULTS.maxDistance + 1, 0, 0),
		}, Vector3.zero)
		expect(picked).toEqual({ 1 })
	end)

	it(
		"layout(): placards always show words; the nearest thoughts up to the limit; reactions only with room",
		function()
			for id = 1, 5 do
				bubbles:thought(id, { text = `t{id}`, icon = "request" })
			end
			bubbles:reaction(6, { text = "Thanks!", tone = "happy" })
			bubbles:strike(7, true)
			local positions = {}
			for id = 1, 7 do
				positions[id] = Vector3.new(id * 10, 0, 0)
			end
			local picked = bubbles:pick(positions, Vector3.zero)
			expect(picked).toEqual({ 6, 1, 2, 3, 4, 5, 7 })
			expect(bubbles:layout(picked, 3)).toEqual({
				[7] = "words",
				[1] = "words",
				[2] = "words",
				[3] = "words",
				[4] = "badge",
				[5] = "badge", -- the reaction (6) gets no words: the limit went to the requests, so it is not drawn
			})
			expect(bubbles:layout(picked, 6)[6]).toBe("words") -- with room, the reaction shows
			expect(Bubbles.DEFAULTS.withText).toBe(3)
			expect(Vfx.bubbles.withText).toBe(Bubbles.DEFAULTS.withText)
			expect(Vfx.bubbles.gapPixels).toBe(Bubbles.DEFAULTS.gapPixels)
		end
	)

	it("layout(): a card never covers another bubble; requests too close for words both show badges", function()
		for id = 1, 3 do
			bubbles:thought(id, { text = `t{id}`, icon = "request" })
		end
		bubbles:reaction(4, { text = "Thanks!", tone = "happy" })
		bubbles:strike(5, true)
		local card = Bubbles.SIZES.card
		local anchors = {
			[1] = Vector2.new(500, 300),
			[2] = Vector2.new(500 + card.X / 2, 310), -- 1's card would hide 2's badge, and 2's card 1's badge
			[3] = Vector2.new(1000, 300), -- clear of everything
			[4] = Vector2.new(520, 320), -- the reaction's card would cover 1's badge
			[5] = Vector2.new(260, 900), -- the placard, far away
		}
		local picked = { 4, 1, 2, 3, 5 }
		expect(bubbles:layout(picked, 3, anchors)).toEqual({
			[5] = "words",
			[1] = "badge",
			[2] = "badge",
			[3] = "words",
		})
		-- 2 moved clear: both get their words; the reaction would cover 1's card, so it is not drawn
		anchors[2] = Vector2.new(500, 600)
		expect(bubbles:layout(picked, 3, anchors)).toEqual({
			[5] = "words",
			[1] = "words",
			[2] = "words",
			[3] = "words",
		})
		-- a placard is placed first: a request card over it falls back to the badge; the placard stays
		anchors[5] = Vector2.new(500, 300 + Bubbles.SIZES.placard.Y)
		local forms = bubbles:layout(picked, 3, anchors)
		expect(forms[1]).toBe("badge")
		expect(forms[5]).toBe("words")
	end)

	it("textLimit(): fewer words on a phone and with the camera zoomed far out", function()
		expect(bubbles:textLimit(120, false)).toBe(Bubbles.DEFAULTS.withText) -- the start zoom
		expect(bubbles:textLimit(120, true)).toBe(Bubbles.DEFAULTS.withTextPhone)
		expect(bubbles:textLimit(Bubbles.DEFAULTS.farZoom + 1, false)).toBe(Bubbles.DEFAULTS.withTextFar)
		expect(bubbles:textLimit(Bubbles.DEFAULTS.farZoom, false)).toBe(Bubbles.DEFAULTS.withText)
		expect(bubbles:textLimit(nil, nil)).toBe(Bubbles.DEFAULTS.withText)
		for id = 1, 3 do
			bubbles:thought(id, { text = `t{id}` })
		end
		expect(bubbles:layout({ 1, 2, 3 }, 1)).toEqual({ [1] = "words", [2] = "badge", [3] = "badge" })
		for _, key in { "withTextPhone", "withTextFar", "farZoom", "gapPixels" } do
			expect(Vfx.bubbles[key]).toBe(Bubbles.DEFAULTS[key])
		end
	end)

	it("release() clears the bubble and the placard of a pooled rig", function()
		bubbles:thought(5, { text = "t" })
		bubbles:strike(5, true)
		bubbles:release(5)
		expect(bubbles:get(5)).toBeNil()
		bubbles:riot(6, true)
		bubbles:release(6)
		expect(bubbles:get(6)).toBeNil()
	end)

	it("a NaN entity id is ignored, never a table key", function()
		local nan = 0 / 0
		expect(bubbles:thought(nan, { text = "t" })).toBeNil()
		expect(bubbles:reaction(nan, { text = "r", tone = "happy" })).toBeNil()
		bubbles:strike(nan, true)
		bubbles:release(nan)
		expect(bubbles:get(nan)).toBeNil()
		expect(bubbles.stats.ignored).toBe(3)
	end)
end)

describe("config Vfx.luau cues (FL-0091)", function()
	it("maps exactly the G13.3 cue vocabulary; sounds and effects are registered; no cue is sound-only", function()
		local keys = {}
		for id, cue in Vfx.cues do
			table.insert(keys, id)
			assert(cue.pose ~= nil or cue.vfx ~= nil, `cue {id}: needs a pose or an effect`)
			if cue.vfx then
				assert(VfxPresets.byId[cue.vfx] ~= nil, `cue {id}: unknown VFX preset {cue.vfx}`)
			end
			if cue.sound then
				assert(cue.vfx ~= nil, `cue {id}: a sound needs an effect (poses wait for FORGE-01)`)
				assert(Sounds.registry:get(cue.sound) ~= nil, `cue {id}: unknown sound {cue.sound}`)
			end
		end
		table.sort(keys)
		-- CONTRACTS G13.3 `cue` vocabulary
		expect(keys).toEqual({
			"bow",
			"celebrate",
			"cower",
			"grumble",
			"hammer",
			"rest",
			"salute",
			"strike_placard",
			"work_fast",
		})
	end)

	it("a cue with a continuous effect says how long it runs (FORGE-05 #42 M1)", function()
		for id, cue in Vfx.cues do
			local preset = cue.vfx and VfxPresets.byId[cue.vfx]
			local continuous = false
			for _, emitter in (if preset then preset.emitters else {}) do
				continuous = continuous or (emitter.rate ~= nil and preset.durationSec == nil)
			end
			if continuous then
				assert(
					type(cue.seconds) == "number" and cue.seconds > 0,
					`cue {id}: continuous {cue.vfx} needs seconds`
				)
			end
		end
		expect(Vfx.cues.rest.seconds).toBe(6)
	end)

	it("maps every cue_id the content library uses (Content/Consequences, FL-0083)", function()
		local used = 0
		for id, row in Consequences do
			if row.cue_id ~= nil then
				used += 1
				assert(Vfx.cues[row.cue_id] ~= nil, `consequence {id}: cue '{row.cue_id}' has no entry in Vfx.cues`)
			end
		end
		assert(used > 0, "the content library uses cues")
	end)
end)

describe("CitizenBubbleController (FL-0091)", function()
	it(
		"sits the bubble as far above the drawn citizen as at the Kit size: 3.2 studs x the rig's scale (D-059)",
		function()
			expect(BubbleDef.HEIGHT).toBeNear(3.2 * EntityController.RIG_SCALE, 1e-9)
		end
	)

	local env, entities, played, effects, stopped, poses, settingsValues, world, controller

	-- A rendered rig. `hidden` = unparented, as EntityController's LOD leaves a far rig.
	local function citizen(id, x, hidden)
		local model = roblox.Instance.new("Model")
		model.Name = `Citizen{id}`
		local root = roblox.Instance.new("Part")
		root.CFrame = CFrame.new(x, 2, 0)
		root.Parent = model
		model.PrimaryPart = root
		if not hidden then
			model.Parent = world
		end
		entities.rendered:fire(id, model)
		return model
	end

	local function bubbleOf(model)
		return model:FindFirstChild("ForgeCitizenBubble")
	end

	-- A VFXController double whose effects know whether they are continuous, as the real Effect does.
	local function vfxDouble()
		return {
			name = "VFXController",
			new = function()
				return {
					play = function(_, id)
						table.insert(effects, id)
						local continuous = false
						for _, emitter in VfxPresets.byId[id].emitters do
							continuous = continuous or emitter.rate ~= nil
						end
						return { id = id, continuous = continuous and VfxPresets.byId[id].durationSec == nil }
					end,
					stop = function(_, effect)
						table.insert(stopped, effect.id)
					end,
				}
			end,
		}
	end

	-- A second client with its own doubles (camera, conversation): { env, signals, controller }.
	local function bootWith(extra)
		local own = MockEnv.new({ seed = 94, isServer = false, localPlayer = { userId = 9104 } })
		local signals = { rendered = Signal.new(), released = Signal.new(), event = Signal.new() }
		local defs = {
			{
				name = "EntityController",
				new = function()
					return signals
				end,
			},
			BubbleDef,
		}
		for _, def in extra do
			table.insert(defs, def)
		end
		local reg = Loader.load(own, defs)
		return { env = own, signals = signals, controller = reg:get("CitizenBubbleController") }
	end

	local function rigFor(signals, id, x)
		local model = roblox.Instance.new("Model")
		local root = roblox.Instance.new("Part")
		root.CFrame = CFrame.new(x, 2, 0)
		root.Parent = model
		model.PrimaryPart = root
		model.Parent = world
		signals.rendered:fire(id, model)
		signals.event:fire(id, "thought", { text = `t{id}` }, model)
		return model
	end

	beforeEach(function()
		env = MockEnv.new({ seed = 91, isServer = false, localPlayer = { userId = 9101 } })
		world = roblox.Instance.new("Folder")
		entities = {
			rendered = Signal.new(),
			released = Signal.new(),
			event = Signal.new(),
		}
		poses = {}
		function entities.playPose(_, id, pose)
			table.insert(poses, `{id}:{pose}`)
		end
		played, effects, stopped, settingsValues = {}, {}, {}, {}
		local registry = Loader.load(env, {
			{
				name = "EntityController",
				new = function()
					return entities
				end,
			},
			{
				name = "SettingsController",
				new = function()
					return {
						get = function(_, key)
							return settingsValues[key]
						end,
					}
				end,
			},
			{
				name = "AudioController",
				new = function()
					return {
						play = function(_, id)
							table.insert(played, id)
						end,
					}
				end,
			},
			vfxDouble(),
			{
				name = "CitizenBubbleController",
				new = function(e, r)
					return BubbleDef.create(e, r, {
						origin = function()
							return Vector3.zero
						end,
					})
				end,
			},
		})
		controller = registry:get("CitizenBubbleController")
	end)

	it("draws a thought over the citizen; the reaction replaces it and asks for a pose", function()
		local farmer = citizen(1, 20)
		entities.event:fire(
			1,
			"thought",
			{ scenarioId = "hungry_farmer", text = "We are hungry.", icon = "request" },
			farmer
		)
		local gui = bubbleOf(farmer)
		assert(gui, "a bubble is drawn")
		expect(gui:FindFirstChild("Text", true).Text).toBe("We are hungry.")
		expect(gui:FindFirstChild("Glyph", true).Text).toBe("!")
		expect(gui.Active).toBe(false) -- no PlayerGui here: Roblox gives a BillboardGui input only under PlayerGui
		entities.event:fire(1, "reaction", { text = "Thank you, my lord!", tone = "happy" }, farmer)
		expect(bubbleOf(farmer):FindFirstChild("Text", true).Text).toBe("Thank you, my lord!")
		expect(poses).toEqual({ "1:cheer" })
		env.mock:advance(Vfx.bubbles.reactionSec + 0.5)
		expect(bubbleOf(farmer)).toBeNil()
	end)

	it("released rigs lose their bubble at once, and the GUI goes back to the pool", function()
		local a = citizen(1, 10)
		entities.event:fire(1, "thought", { text = "t" }, a)
		local gui = bubbleOf(a)
		entities.released:fire(1, a)
		expect(bubbleOf(a)).toBeNil()
		local b = citizen(2, 12)
		entities.event:fire(2, "thought", { text = "u" }, b)
		expect(bubbleOf(b)).toBe(gui) -- pooled
	end)

	it("draws at most maxOnScreen bubbles and none beyond maxDistance", function()
		local models = {}
		for id = 1, 12 do
			models[id] = citizen(id, id * 10)
			entities.event:fire(id, "thought", { text = `t{id}` }, models[id])
		end
		local far = citizen(99, Vfx.bubbles.maxDistance + 50)
		entities.event:fire(99, "thought", { text = "far" }, far)
		local drawn = 0
		for _, model in models do
			drawn += if bubbleOf(model) then 1 else 0
		end
		expect(drawn).toBe(Vfx.bubbles.maxOnScreen)
		expect(bubbleOf(far)).toBeNil()
		expect(bubbleOf(models[1]).MaxDistance).toBe(0) -- no engine limit: the zoomed-out overview keeps them
	end)

	it("LOD-hidden (unparented) rigs never take a bubble slot (R42-6)", function()
		for id = 1, Vfx.bubbles.maxOnScreen do
			local hiddenRig = citizen(id, 1, true)
			entities.event:fire(id, "thought", { text = `hidden{id}` }, hiddenRig)
		end
		local visible = citizen(50, 100)
		entities.event:fire(50, "thought", { text = "I am here" }, visible)
		assert(bubbleOf(visible), "the visible citizen gets a bubble")
		expect(bubbleOf(visible):FindFirstChild("Text", true).Text).toBe("I am here")
	end)

	it(
		"a job change swaps the rig: the thought and the strike placard stay; a despawn clears both (FORGE-05 #87 M1)",
		function()
			local miner = citizen(3, 20)
			entities.event:fire(3, "thought", { text = "More lamps, please." }, miner)
			local striker = citizen(4, 25)
			entities.event:fire(4, "strike", { occupation = "miner", on = true }, striker)
			-- EntityController's job swap: released, then rendered at once
			entities.released:fire(3, miner)
			local farmer = citizen(3, 20)
			entities.released:fire(4, striker)
			local newStriker = citizen(4, 25)
			env.mock:advance(BubbleDef.POLL_SEC + 0.01)
			assert(bubbleOf(farmer), "the thought follows the citizen to its new rig")
			expect(bubbleOf(farmer):FindFirstChild("Text", true).Text).toBe("More lamps, please.")
			-- a strike belongs to the citizen (v0.4-g6): the server sends "off" only when it ends
			assert(bubbleOf(newStriker), "the placard follows the striker to its new job")
			expect(bubbleOf(newStriker):FindFirstChild("Text", true).Text).toBe(Bubbles.STRIKE_TEXT)
			-- a despawn: released and not rendered again
			entities.released:fire(3, farmer)
			entities.released:fire(4, newStriker)
			env.mock:advance(BubbleDef.POLL_SEC + 0.01)
			local reused = citizen(3, 20) -- the id comes back for another citizen
			local reusedStriker = citizen(4, 25)
			env.mock:advance(BubbleDef.POLL_SEC + 0.01)
			expect(bubbleOf(reused)).toBeNil()
			expect(bubbleOf(reusedStriker)).toBeNil() -- the departed striker's placard is gone
		end
	)

	it("a NaN entity id from the event signal is ignored", function()
		entities.rendered:fire(0 / 0, roblox.Instance.new("Model"))
		entities.released:fire(0 / 0, nil)
		entities.event:fire(0 / 0, "thought", { text = "t" }, nil)
		entities.event:fire(0 / 0, "cue", { cue = "bow" }, nil)
		expect(poses).toEqual({})
		expect(env.mock.threadErrors).toEqual({})
	end)

	it("strike placards stay while on; citizenBarks off hides reactions but not thoughts or placards", function()
		local smith = citizen(4, 30)
		entities.event:fire(4, "strike", { occupation = "miner", on = true }, smith)
		expect(bubbleOf(smith):FindFirstChild("Text", true).Text).toBe(Bubbles.STRIKE_TEXT)
		settingsValues.citizenBarks = false
		entities.event:fire(4, "reaction", { text = "No more!", tone = "angry" }, smith)
		expect(bubbleOf(smith)).toBeNil() -- the reaction bubble is hidden while barks are off
		expect(poses).toEqual({ "4:grumble" }) -- the pose still plays
		env.mock:advance(Vfx.bubbles.reactionSec + 0.5)
		expect(bubbleOf(smith):FindFirstChild("Text", true).Text).toBe(Bubbles.STRIKE_TEXT)
		entities.event:fire(4, "strike", { occupation = "miner", on = false }, smith)
		expect(bubbleOf(smith)).toBeNil()
	end)

	it("a 'riot' event shows a 'Rioting' placard in its own colour until riot off (G13.3 v0.4-g10c)", function()
		local rioter = citizen(5, 30)
		entities.event:fire(5, "riot", { on = true }, rioter)
		local gui = bubbleOf(rioter)
		expect(gui:FindFirstChild("Text", true).Text).toBe(Bubbles.RIOT_TEXT)
		expect(gui.Size).toEqual(BubbleDef.SIZE.placard)
		expect(gui:FindFirstChild("Bubble").BackgroundColor3).toEqual(BubbleDef.STYLE.riot.background)
		expect(BubbleDef.STYLE.riot.background == BubbleDef.STYLE.strike.background).toBe(false)
		entities.event:fire(5, "riot", { on = false }, rioter)
		expect(bubbleOf(rioter)).toBeNil()
	end)

	it("plays a G13.3 cue's pose, sound and effect at the citizen, sent directly or as `cue`", function()
		local smith = citizen(1, 20)
		entities.event:fire(1, "hammer", {}, smith)
		expect(poses).toEqual({ "1:hammer" })
		expect(played).toEqual({ Vfx.cues.hammer.sound })
		expect(effects).toEqual({ Vfx.cues.hammer.vfx })
		entities.event:fire(1, "cue", { cue = "bow" }, smith)
		expect(poses).toEqual({ "1:hammer", "1:bow" })
		expect(played).toEqual({ Vfx.cues.hammer.sound }) -- bow is pose-only
		entities.event:fire(1, "cue", { cueId = "rest" }, smith) -- content/SPEC.md's field name
		expect(poses).toEqual({ "1:hammer", "1:bow", "1:rest" })
	end)

	it("a cue for a citizen with no rendered rig plays no sound or effect (never at the origin)", function()
		entities.event:fire(77, "hammer", {}, nil)
		expect(poses).toEqual({ "77:hammer" }) -- EntityController ignores poses for unrendered entities
		expect(played).toEqual({})
		expect(effects).toEqual({})
	end)

	it("an unknown cue falls back to the reaction tone for its pose and warns once", function()
		local farmer = citizen(1, 20)
		entities.event:fire(1, "cue", { cue = "dragons", tone = "sad" }, farmer)
		expect(poses).toEqual({ "1:slump" })
		entities.event:fire(1, "reaction", { text = "Hooray!", tone = "happy" }, farmer)
		entities.event:fire(1, "cue", { cue = "dragons" }, farmer)
		expect(poses).toEqual({ "1:slump", "1:cheer", "1:cheer" }) -- the reaction's tone
		expect(played).toEqual({})
		expect(effects).toEqual({})
		local warnings = 0
		for _, entry in env.mock.logs do
			if entry.level == "warn" and string.find(entry.message, "unknown cue 'dragons'", 1, true) then
				warnings += 1
			end
		end
		expect(warnings).toBe(1)
	end)

	it("marks exactly the citizens in entityIds, never every citizen of the occupation (CONTRACTS v0.4-g6)", function()
		local miners = { citizen(1, 10), citizen(2, 20), citizen(3, 30) }
		entities.event:fire(nil, "strike", { occupation = "miner", on = true, entityIds = { 1, 3 } }, nil)
		expect(bubbleOf(miners[1]):FindFirstChild("Text", true).Text).toBe(Bubbles.STRIKE_TEXT)
		expect(bubbleOf(miners[2])).toBeNil() -- the same occupation, but not one the server struck
		expect(bubbleOf(miners[3]):FindFirstChild("Text", true).Text).toBe(Bubbles.STRIKE_TEXT)
		entities.event:fire(nil, "cue", { cue = "hammer", occupation = "miner", entityIds = { 2, 2, 0 / 0 } }, nil)
		expect(poses).toEqual({ "2:hammer" }) -- each id once; a NaN id is skipped
		entities.event:fire(1, "cue", { cue = "bow", entityIds = { 1, 3 } }, miners[1])
		expect(poses).toEqual({ "2:hammer", "1:bow", "3:bow" })
		-- neither entityId nor entityIds: the HUD's or the keep's, never on citizens
		entities.event:fire(nil, "hammer", { occupation = "miner" }, nil)
		entities.event:fire(nil, "cue", { cue = "salute", entityIds = {} }, nil)
		expect(poses).toEqual({ "2:hammer", "1:bow", "3:bow" })
		expect(controller.stats.untargeted).toBe(2)
		expect(env.mock.threadErrors).toEqual({})
	end)

	it(
		"a continuous cue effect (rest) stops after its seconds, at the next cue's effect and on release (FORGE-05 #42 M1)",
		function()
			local farmer = citizen(1, 20)
			entities.event:fire(1, "rest", {}, farmer)
			expect(effects).toEqual({ "ambience.motes" })
			env.mock:advance(Vfx.cues.rest.seconds - 0.5)
			expect(stopped).toEqual({})
			env.mock:advance(1)
			expect(stopped).toEqual({ "ambience.motes" }) -- its seconds are up
			entities.event:fire(1, "rest", {}, farmer)
			entities.event:fire(1, "hammer", {}, farmer)
			expect(stopped).toEqual({ "ambience.motes", "ambience.motes" }) -- replaced by the next cue
			entities.event:fire(1, "rest", {}, farmer)
			entities.released:fire(1, farmer)
			expect(#stopped).toBe(3) -- the pooled rig keeps no emitter
			env.mock:advance(Vfx.cues.rest.seconds + 1)
			expect(#stopped).toBe(3) -- stopped once, never twice; bursts (hammer) clean up themselves
		end
	)

	it("an older cue timer never stops a newer effect on the same citizen (FORGE-05 #87 L1)", function()
		local farmer = citizen(1, 20)
		entities.event:fire(1, "rest", {}, farmer)
		env.mock:advance(1)
		entities.event:fire(1, "rest", {}, farmer) -- replaces the first; its timer is still pending
		expect(#stopped).toBe(1)
		env.mock:advance(Vfx.cues.rest.seconds - 0.5) -- the first timer fires here
		expect(#stopped).toBe(1) -- the second rest is still live
		env.mock:advance(1)
		expect(#stopped).toBe(2) -- and ends after its own seconds
	end)

	it("takes only whole entity ids >= 1 from the list part of entityIds (FORGE-05 #87 L3)", function()
		for id = 1, 3 do
			citizen(id, id * 10)
		end
		local listed = { 1, -1, 1.5, math.huge, 0, 3 }
		listed.extra = 2 -- a hash-part value is not part of the list
		entities.event:fire(nil, "cue", { cue = "bow", entityIds = listed }, nil)
		expect(poses).toEqual({ "1:bow", "3:bow" })
		entities.event:fire(0, "cue", { cue = "bow" }, nil)
		entities.event:fire(2.5, "cue", { cue = "bow" }, nil)
		expect(poses).toEqual({ "1:bow", "3:bow" })
	end)

	it("never holds more bubble GUIs than maxOnScreen while bubbles swap (FORGE-05 #42 L4)", function()
		for id = 1, Vfx.bubbles.maxOnScreen do
			entities.event:fire(id, "thought", { text = `t{id}` }, citizen(id, id * 10))
		end
		local near = citizen(50, 5)
		entities.event:fire(50, "thought", { text = "Me first!" }, near) -- takes the farthest one's slot
		assert(bubbleOf(near), "the nearer request is drawn")
		local drawn = 0
		for _ in controller._drawn do
			drawn += 1
		end
		expect(drawn).toBe(Vfx.bubbles.maxOnScreen)
		expect(drawn + #controller._pool).toBe(Vfx.bubbles.maxOnScreen)
	end)

	it("warns about the first UNKNOWN_CUE_LOG unknown cue names only (FORGE-05 #42 L5)", function()
		local farmer = citizen(1, 20)
		for index = 1, 20 do
			entities.event:fire(1, "cue", { cue = `dragons{index}` }, farmer)
			entities.event:fire(1, "cue", { cue = `dragons{index}` }, farmer)
		end
		local warnings = 0
		for _, entry in env.mock.logs do
			if entry.level == "warn" and string.find(entry.message, "unknown cue", 1, true) then
				warnings += 1
			end
		end
		expect(warnings).toBe(BubbleDef.UNKNOWN_CUE_LOG + 1) -- plus one "no longer logged"
		expect(env.mock:hasLog("warn", "more unknown cues; no longer logged")).toBe(true)
	end)

	it("walk mode measures from the camera, not the overview's stale focus (FORGE-05 #42 L3)", function()
		local camera = { mode = "follow" }
		function camera.getFocus()
			return Vector3.new(500, 0, 0) -- left over from the overview
		end
		local client = bootWith({
			{
				name = "RulerCameraController",
				new = function()
					return camera
				end,
			},
		})
		local view = roblox.Instance.new("Camera")
		view.CFrame = CFrame.new(0, 12, 18)
		view.Parent = client.env.Workspace
		client.env.Workspace.CurrentCamera = view
		local beside = rigFor(client.signals, 1, 10)
		assert(bubbleOf(beside), "the citizen next to the walking ruler has a bubble")
		camera.mode = "overview"
		client.controller:refresh()
		expect(bubbleOf(beside)).toBeNil() -- 490 studs from the overview's focus
	end)

	it("hides the citizen's bubble while their conversation is open (G13.8; FORGE-05 #42 L6)", function()
		local talk = { opened = Signal.new(), closed = Signal.new() }
		local client = bootWith({
			{
				name = "ConversationController",
				new = function()
					return talk
				end,
			},
		})
		client.controller._origin = function()
			return Vector3.zero
		end
		local speaker = rigFor(client.signals, 1, 10)
		local other = rigFor(client.signals, 2, 12)
		talk.opened:fire(1, Vector3.new(10, 2, 0))
		expect(bubbleOf(speaker)).toBeNil() -- the panel shows the same words
		assert(bubbleOf(other), "other citizens keep theirs")
		talk.closed:fire(1)
		assert(bubbleOf(speaker), "back after the conversation")
		-- main's ConversationController has no signals yet: its state names the citizen
		local panel = { state = nil }
		local plain = bootWith({
			{
				name = "ConversationController",
				new = function()
					return panel
				end,
			},
		})
		plain.controller._origin = function()
			return Vector3.zero
		end
		local asked = rigFor(plain.signals, 7, 10)
		panel.state = { entityId = 7, phase = "choosing" }
		plain.controller:refresh()
		expect(bubbleOf(asked)).toBeNil()
		panel.state = nil
		plain.controller:refresh()
		assert(bubbleOf(asked), "back once the panel closed")
	end)

	it(
		"measures distance from the camera focus, so a zoomed-out overview shows the citizens under it (R42-1)",
		function()
			local focusEnv = MockEnv.new({ seed = 93, isServer = false, localPlayer = { userId = 9103 } })
			local signals = { rendered = Signal.new(), released = Signal.new(), event = Signal.new() }
			Loader.load(focusEnv, {
				{
					name = "EntityController",
					new = function()
						return signals
					end,
				},
				{
					name = "RulerCameraController",
					new = function()
						return {
							mode = "overview",
							getFocus = function()
								return Vector3.new(500, 0, 0) -- the overview's focus; the camera is up to 220 studs away
							end,
						}
					end,
				},
				BubbleDef,
			})
			local function rig(id, x)
				local model = roblox.Instance.new("Model")
				local root = roblox.Instance.new("Part")
				root.CFrame = CFrame.new(x, 2, 0)
				root.Parent = model
				model.PrimaryPart = root
				model.Parent = world
				signals.rendered:fire(id, model)
				signals.event:fire(id, "thought", { text = `t{id}` }, model)
				return model
			end
			local underView = rig(1, 520)
			local nearOrigin = rig(2, 0)
			assert(bubbleOf(underView), "the citizen at the focus has a bubble")
			expect(bubbleOf(nearOrigin)).toBeNil() -- 500 studs from the focus
		end
	)

	it(
		"reads from the aerial camera: on top, above the head, badge and 17 px words; farther thoughts badge only",
		function()
			local models = {}
			for id = 1, 5 do
				models[id] = citizen(id, id * 10)
				entities.event:fire(id, "thought", { text = `Request {id}`, icon = "request" }, models[id])
			end
			local smith = citizen(6, 70)
			entities.event:fire(6, "strike", { on = true }, smith)
			for id = 1, 5 do
				local gui = bubbleOf(models[id])
				assert(gui, `bubble {id}`)
				expect(gui.AlwaysOnTop).toBe(true) -- roofs and trees never hide it
				expect(gui.SizeOffset).toEqual(Vector2.new(0, 0.5)) -- bottom edge above the head
				local glyph = gui:FindFirstChild("Glyph", true)
				expect(glyph.Text).toBe("!")
				expect(glyph.Parent.BackgroundColor3).toEqual(BubbleDef.BADGE["!"])
				local text = gui:FindFirstChild("Text", true)
				if id <= Vfx.bubbles.withText then
					expect(gui.Size).toEqual(BubbleDef.SIZE.card)
					expect(text.Visible).toBe(true)
					expect(text.TextSize).toBe(BubbleDef.TEXT_SIZE)
					expect(text.TextTruncate).toBe(Enum.TextTruncate.AtEnd)
					expect(text.Text).toBe(`Request {id}`)
				else
					expect(gui.Size).toEqual(BubbleDef.SIZE.badge) -- the badge alone, still tappable
					expect(text.Visible).toBe(false)
				end
			end
			local placard = bubbleOf(smith)
			expect(placard.Size).toEqual(BubbleDef.SIZE.placard)
			expect(placard:FindFirstChild("Text", true).Visible).toBe(true) -- a placard's meaning is its words
			expect(placard:FindFirstChild("Badge", true).Visible).toBe(false)
			-- the nearest request answered: the next one gets its words back
			entities.event:fire(1, "reaction", { text = "Thank you!", tone = "happy" }, models[1])
			env.mock:advance(Vfx.bubbles.reactionSec + 0.5)
			expect(bubbleOf(models[4]).Size).toEqual(BubbleDef.SIZE.card)
		end
	)

	it("a new request's badge pops once; again only for the next request; never under reduced motion", function()
		local farmer = citizen(1, 20)
		entities.event:fire(1, "thought", { scenarioId = "hungry", text = "We are hungry.", icon = "request" }, farmer)
		local gui = bubbleOf(farmer)
		local first = gui:GetAttribute("PulsedAt")
		assert(first, "the new request pops")
		expect(gui:FindFirstChild("Pulse", true).Scale).toBe(1) -- no TweenService here: the end state at once
		env.mock:advance(5)
		entities.event:fire(1, "thought", { scenarioId = "hungry", text = "We are hungry.", icon = "request" }, farmer)
		controller:refresh()
		expect(gui:GetAttribute("PulsedAt")).toBe(first) -- the same request refreshed: no second pop
		entities.event:fire(1, "reaction", { text = "Thank you!", tone = "happy" }, farmer)
		env.mock:advance(Vfx.bubbles.reactionSec + 0.5)
		entities.event:fire(1, "thought", { scenarioId = "cold", text = "It is cold.", icon = "concern" }, farmer)
		expect(bubbleOf(farmer):GetAttribute("PulsedAt") > first).toBe(true) -- a new request pops again
		-- reduced motion: no pop at all
		settingsValues.reduced = true
		local smith = citizen(2, 30)
		controller._settings.reducedMotion = function()
			return settingsValues.reduced == true
		end
		entities.event:fire(2, "thought", { scenarioId = "tools", text = "My hammer broke.", icon = "request" }, smith)
		expect(bubbleOf(smith):GetAttribute("PulsedAt")).toBeNil()
	end)

	it("zoomed far out, only the nearest request keeps its words; the others stay badges", function()
		local view = roblox.Instance.new("Camera")
		view.CFrame = CFrame.new(0, Vfx.bubbles.farZoom + 20, 0) -- the overview's focus is the origin here
		view.Parent = env.Workspace
		env.Workspace.CurrentCamera = view
		local models = {}
		for id = 1, 3 do
			models[id] = citizen(id, id * 10)
			entities.event:fire(id, "thought", { text = `t{id}`, icon = "request" }, models[id])
		end
		expect(bubbleOf(models[1]).Size).toEqual(BubbleDef.SIZE.card)
		expect(bubbleOf(models[2]).Size).toEqual(BubbleDef.SIZE.badge)
		expect(bubbleOf(models[3]).Size).toEqual(BubbleDef.SIZE.badge)
		view.CFrame = CFrame.new(0, 100, 0) -- zoom back in
		controller:refresh()
		for id = 1, 3 do
			expect(bubbleOf(models[id]).Size).toEqual(BubbleDef.SIZE.card)
		end
	end)

	it("on screen, requests too close for words show badges; a request with room shows its words", function()
		local client = bootWith({})
		client.controller._origin = function()
			return Vector3.zero
		end
		client.controller._project = function(position) -- a flat top-down view: 4 px per stud
			return Vector2.new(500 + position.X * 4, 400 + position.Z * 4)
		end
		local near = rigFor(client.signals, 1, 10)
		local beside = rigFor(client.signals, 2, 14) -- 16 px to the right: either card would hide the other's badge
		local apart = rigFor(client.signals, 3, 90) -- 320 px away: room for words
		expect(bubbleOf(near).Size).toEqual(BubbleDef.SIZE.badge)
		expect(bubbleOf(beside).Size).toEqual(BubbleDef.SIZE.badge)
		expect(bubbleOf(apart).Size).toEqual(BubbleDef.SIZE.card)
		-- 2's request answered: its reaction has no room (it would cover 1's card), so it is not drawn,
		-- and 1 gets its words back
		client.signals.event:fire(2, "reaction", { text = "Thank you!", tone = "happy" }, beside)
		expect(bubbleOf(beside)).toBeNil()
		expect(bubbleOf(near).Size).toEqual(BubbleDef.SIZE.card)
	end)

	it("a tap on a bubble selects its citizen through the real InputModeController; not while placing", function()
		Create.useTestConnector()
		local own = MockEnv.new({ seed = 95, isServer = false, localPlayer = { userId = 9105 } })
		local signals = { rendered = Signal.new(), released = Signal.new(), event = Signal.new() }
		local playerGui = roblox.Instance.new("Folder")
		local reg = Loader.load(own, {
			{
				name = "EntityController",
				new = function()
					return signals
				end,
			},
			InputModeDef,
			{
				name = "CitizenBubbleController",
				new = function(e, r)
					return BubbleDef.create(e, r, {
						origin = function()
							return Vector3.zero
						end,
						playerGui = playerGui,
					})
				end,
			},
		})
		local input = reg:get("InputModeController")
		local bubbleController = reg:get("CitizenBubbleController")
		local selected = {}
		input.selected:connect(function(kind, id)
			table.insert(selected, `{kind}:{tostring(id)}`)
		end)
		local a = rigFor(signals, 3, 10)
		local gui = playerGui:FindFirstChild("ForgeCitizenBubble")
		assert(gui, "under PlayerGui, where a BillboardGui takes input")
		expect(gui.Parent).toBe(playerGui)
		expect(gui.Adornee).toBe(a.PrimaryPart)
		expect(gui.Active).toBe(true)
		expect(Create.fire(gui:FindFirstChild("Bubble"), "Activated")).toBe(1)
		expect(selected).toEqual({ "citizen:3" })
		-- placing a building: bubbles take no input, and a tap selects nothing
		input:set("build")
		expect(gui.Active).toBe(false)
		expect(bubbleController:tap(3)).toBe(false)
		input:set("explore")
		own.mock:advance(InputModeDef.DEFAULTS.settleSec + 0.01)
		bubbleController:refresh()
		expect(gui.Active).toBe(true)
		-- a pooled GUI selects the citizen it now belongs to
		signals.released:fire(3, a)
		bubbleController:refresh()
		rigFor(signals, 4, 12)
		expect(playerGui:FindFirstChild("ForgeCitizenBubble")).toBe(gui)
		Create.fire(gui:FindFirstChild("Bubble"), "Activated")
		expect(selected).toEqual({ "citizen:3", "none:", "citizen:4" })
		expect(bubbleController:tap(0 / 0)).toBe(false)
		expect(own.mock.threadErrors).toEqual({})
		Create.setConnector(nil)
	end)

	it("ignores FL-0062's work cues and runs without EntityController (headless boot)", function()
		local farmer = citizen(1, 20)
		entities.event:fire(1, "deposit", { resource = "food" }, farmer)
		expect(bubbleOf(farmer)).toBeNil()
		local bare = MockEnv.new({ seed = 92, isServer = false, localPlayer = { userId = 9102 } })
		Loader.load(bare, { BubbleDef })
		bare.mock:advance(1)
		expect(bare.mock:hasLog("info", "no EntityController yet")).toBe(true)
		expect(bare.mock.threadErrors).toEqual({})
	end)
end)
