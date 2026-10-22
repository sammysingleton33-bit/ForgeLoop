-- D-059 B22.4 prototype: job icons over citizens in the overview (FeedbackJobGlyphController, FORGE-04).
local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect, beforeEach = T.describe, T.it, T.expect, T.beforeEach

local roblox = require("@lune/roblox")
local MockEnv = require("../../../../roblox/tests/mocks/MockEnv")
local Loader = require("@game/ReplicatedStorage/Forge/Contracts/Loader")
local Signal = require("@game/ReplicatedStorage/Forge/Core/Signal")
local Schema = require("@game/ReplicatedStorage/Forge/Experience/Schema")
local GlyphDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/FeedbackJobGlyphController")

describe("FeedbackJobGlyphController (D-059 B22.4 prototype)", function()
	local env, entities, world, controller
	local settingValues, camera, input, conversation, bubbleOf
	local origin, zoom, screenMaxX, phone

	local function rig(id, x, job, opts)
		local o = opts or {}
		local model = roblox.Instance.new("Model")
		model.Name = `Citizen{id}`
		local root = roblox.Instance.new("Part")
		root.CFrame = CFrame.new(x, 2, 0)
		root.Parent = model
		model.PrimaryPart = root
		model:SetAttribute("KitKind", o.kind or "citizen")
		model:SetAttribute("KitJob", job)
		if not o.hidden then
			model.Parent = world
		end
		entities.rendered:fire(id, model)
		return model
	end

	local function glyphIn(model)
		return model:FindFirstChild("ForgeCitizenGlyph")
	end

	local function ids()
		local out = {}
		for id in controller:shown() do
			table.insert(out, id)
		end
		table.sort(out)
		return out
	end

	beforeEach(function()
		env = MockEnv.new({ seed = 59, isServer = false, localPlayer = { userId = 5904 } })
		world = roblox.Instance.new("Folder")
		entities = { rendered = Signal.new(), released = Signal.new(), event = Signal.new() }
		settingValues = {}
		camera = {
			mode = "overview",
			playing = false,
			getFocus = function()
				return origin
			end,
		}
		function camera.shotsPlaying(self)
			return self.playing
		end
		input = { mode = "explore" }
		conversation = { state = nil }
		bubbleOf = {}
		origin, zoom, screenMaxX, phone = Vector3.zero, 70, 1000, false
		local function double(name, value)
			return {
				name = name,
				new = function()
					return value
				end,
			}
		end
		local registry = Loader.load(env, {
			double("EntityController", entities),
			double("SettingsController", {
				get = function(_, key)
					local value = settingValues[key]
					if value == nil then
						return Schema.SETTINGS[key].default
					end
					return value
				end,
			}),
			double("RulerCameraController", camera),
			double("InputModeController", input),
			double("ConversationController", conversation),
			double("CitizenBubbleController", {
				bubbles = {
					get = function(_, id)
						return bubbleOf[id]
					end,
				},
			}),
			{
				name = "FeedbackJobGlyphController",
				dependencies = {},
				new = function(e, r)
					return GlyphDef.create(e, r, {
						origin = function()
							return origin
						end,
						zoom = function()
							return zoom
						end,
						project = function(position)
							return position.X <= screenMaxX
						end,
						phone = function()
							return phone
						end,
					})
				end,
			},
		})
		controller = registry:get("FeedbackJobGlyphController")
	end)

	it("is off by default: the jobGlyphs setting starts false and draws nothing", function()
		expect(Schema.SETTINGS[GlyphDef.SETTING].default).toBe(false)
		local farmer = rig(1, 10, "farmer")
		controller:refresh()
		expect(ids()).toEqual({})
		expect(glyphIn(farmer)).toBeNil()
	end)

	it("on: each citizen's own job glyph over its head; soldiers, unknown jobs and LOD-hidden rigs get none", function()
		settingValues.jobGlyphs = true
		local farmer = rig(1, 10, "farmer")
		local miner = rig(2, 20, "miner")
		rig(3, 30, "farmer", { kind = "soldier" })
		rig(4, 40, "jester")
		rig(5, 50, "farmer", { hidden = true })
		controller:refresh()
		expect(ids()).toEqual({ 1, 2 })
		local gui = glyphIn(farmer)
		expect(gui.Size).toEqual(UDim2.fromOffset(GlyphDef.GLYPH_PX, GlyphDef.GLYPH_PX))
		expect(gui.StudsOffsetWorldSpace.Y).toBeNear(GlyphDef.HEIGHT, 1e-4)
		expect(gui.AlwaysOnTop).toBe(false) -- a roof hides the citizen and its icon together
		expect(gui.Active).toBe(false) -- a tap still picks the citizen
		expect(gui.Adornee).toBe(farmer.PrimaryPart)
		expect(gui.Disc.Glyph.Text).toBe(GlyphDef.GLYPH.farmer.text)
		expect(gui.Disc.BackgroundColor3).toEqual(GlyphDef.GLYPH.farmer.color)
		expect(glyphIn(miner).Disc.Glyph.Text).toBe(GlyphDef.GLYPH.miner.text)
		-- a phone draws them smaller: its citizens are ~25 px tall at the start view
		phone = true
		controller:refresh()
		expect(gui.Size).toEqual(UDim2.fromOffset(GlyphDef.PHONE_PX, GlyphDef.PHONE_PX))
		expect(GlyphDef.PHONE_PX < GlyphDef.GLYPH_PX).toBe(true)
		-- meaning never by colour alone: every job has its own glyph and colour
		local texts, colors = {}, {}
		for job, look in GlyphDef.GLYPH do
			expect(texts[look.text]).toBeNil()
			expect(colors[tostring(look.color)]).toBeNil()
			texts[look.text], colors[tostring(look.color)] = job, job
		end
	end)

	it("draws at most MAX_SHOWN, the nearest on screen to the view's centre; the pool never grows past it", function()
		settingValues.jobGlyphs = true
		local count = GlyphDef.MAX_SHOWN + 20
		for id = 1, count do
			rig(id, id * 3, "hauler")
		end
		screenMaxX = 3 * (GlyphDef.MAX_SHOWN + 10) -- the last ten are off screen
		origin = Vector3.new(3 * 12, 0, 0) -- nearest to citizen 12
		controller:refresh()
		local shown = ids()
		expect(#shown).toBe(GlyphDef.MAX_SHOWN)
		-- the nearest 50 to x = 36 among the 60 on screen: ids 1 .. 50 (id 51 is 45 studs away, id 1 is 33)
		expect(shown[1]).toBe(1)
		expect(shown[#shown]).toBe(GlyphDef.MAX_SHOWN)
		origin = Vector3.new(3 * 60, 0, 0) -- pan right: the far end on screen now leads
		controller:refresh()
		shown = ids()
		expect(#shown).toBe(GlyphDef.MAX_SHOWN)
		expect(table.find(shown, 60)).never.toBeNil()
		expect(table.find(shown, count)).toBeNil() -- off screen
		local guis = 0
		for _ in controller._drawn do
			guis += 1
		end
		guis += #controller._pool
		expect(guis).toBe(GlyphDef.MAX_SHOWN)
	end)

	it("fades with the zoom: full from FADE_FULL out, half way between, gone at FADE_NONE and closer", function()
		settingValues.jobGlyphs = true
		local farmer = rig(1, 10, "farmer")
		zoom = GlyphDef.FADE_FULL
		controller:refresh()
		expect(glyphIn(farmer).Disc.BackgroundTransparency).toBeNear(0, 1e-9)
		expect(glyphIn(farmer).Disc.Glyph.TextTransparency).toBeNear(0, 1e-9)
		zoom = (GlyphDef.FADE_FULL + GlyphDef.FADE_NONE) / 2
		controller:refresh()
		expect(glyphIn(farmer).Disc.BackgroundTransparency).toBeNear(0.5, 1e-6)
		zoom = GlyphDef.FADE_NONE
		controller:refresh()
		expect(ids()).toEqual({})
		expect(glyphIn(farmer)).toBeNil()
		expect(GlyphDef.fade(0 / 0)).toBe(0)
		expect(GlyphDef.fade(70)).toBe(1) -- the start view (FL-0147) shows them at full
	end)

	it("hides in walk mode, a scripted shot, the duel and a conversation, and where a bubble shows", function()
		settingValues.jobGlyphs = true
		rig(1, 10, "farmer")
		rig(2, 20, "woodcutter")
		local function check(expected)
			controller:refresh()
			expect(ids()).toEqual(expected)
		end
		check({ 1, 2 })
		camera.mode = "follow"
		check({})
		camera.mode = "overview"
		camera.playing = true
		check({})
		camera.playing = false
		input.mode = "arena"
		check({})
		input.mode = "explore"
		conversation.state = { entityId = 2, phase = "asking" }
		check({})
		conversation.state = nil
		bubbleOf[1] = { kind = "thought" } -- the bubble sits where the icon would
		check({ 2 })
		bubbleOf[1] = nil
		settingValues.jobGlyphs = false
		check({})
	end)

	it("a released rig gives its glyph back to the pool; the new rig after a job change shows the new job", function()
		settingValues.jobGlyphs = true
		local farmer = rig(1, 10, "farmer")
		controller:refresh()
		local gui = glyphIn(farmer)
		entities.released:fire(1, farmer)
		expect(gui.Parent).toBeNil()
		expect(controller._pool[#controller._pool]).toBe(gui)
		expect(ids()).toEqual({})
		local builder = rig(1, 10, "builder")
		controller:refresh()
		expect(glyphIn(builder)).toBe(gui) -- the same GUI, reused
		expect(gui.Disc.Glyph.Text).toBe(GlyphDef.GLYPH.builder.text)
		entities.released:fire(0 / 0, builder) -- not an id: ignored
		expect(ids()).toEqual({ 1 })
	end)

	it("starts and stops cleanly: destroy takes every GUI down", function()
		settingValues.jobGlyphs = true
		local farmer = rig(1, 10, "farmer")
		controller:refresh()
		local gui = glyphIn(farmer)
		controller:destroy()
		expect(gui.Parent).toBeNil()
		expect(ids()).toEqual({})
	end)
end)
