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

	it("release() clears the bubble and the placard of a pooled rig", function()
		bubbles:thought(5, { text = "t" })
		bubbles:strike(5, true)
		bubbles:release(5)
		expect(bubbles:get(5)).toBeNil()
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
	local env, entities, played, effects, poses, settingsValues, world

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
		played, effects, settingsValues = {}, {}, {}
		Loader.load(env, {
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
			{
				name = "VFXController",
				new = function()
					return {
						play = function(_, id)
							table.insert(effects, id)
						end,
					}
				end,
			},
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
		expect(gui.Active).toBe(false) -- taps pass through to the selection (G13.6)
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
		"a job change swaps the rig: the thought stays, a strike placard drops; a despawn clears both (R42-3)",
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
			expect(bubbleOf(newStriker)).toBeNil() -- a new occupation: off strike
			-- a despawn: released and not rendered again
			entities.released:fire(3, farmer)
			env.mock:advance(BubbleDef.POLL_SEC + 0.01)
			local reused = citizen(3, 20) -- the id comes back for another citizen
			env.mock:advance(BubbleDef.POLL_SEC + 0.01)
			expect(bubbleOf(reused)).toBeNil()
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
