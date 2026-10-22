-- D-059 B22.4 prototype: job icons over citizens in the overview (FeedbackJobGlyphController, FORGE-04).
local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect, beforeEach = T.describe, T.it, T.expect, T.beforeEach

local roblox = require("@lune/roblox")
local MockEnv = require("../../../../roblox/tests/mocks/MockEnv")
local Loader = require("@game/ReplicatedStorage/Forge/Contracts/Loader")
local Signal = require("@game/ReplicatedStorage/Forge/Core/Signal")
local Schema = require("@game/ReplicatedStorage/Forge/Experience/Schema")
local Theme = require("@game/ReplicatedStorage/Forge/UI/Theme")
local CameraDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/RulerCameraController")
local GlyphDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/FeedbackJobGlyphController")

describe("FeedbackJobGlyphController (D-059 B22.4 prototype)", function()
	local env, entities, world, controller
	local settingValues, camera, input, conversation, bubbleOf
	local origin, zoom, screenMaxX, phone, pxPerStud

	local function rig(id, x, job, opts)
		local o = opts or {}
		local model = roblox.Instance.new("Model")
		model.Name = `Citizen{id}`
		local root = roblox.Instance.new("Part")
		root.CFrame = CFrame.new(x, 2, o.z or 0)
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

	local function badgeIn(model)
		local gui = glyphIn(model)
		return gui and gui:FindFirstChild("Medallion")
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
		origin, zoom, screenMaxX, phone, pxPerStud = Vector3.zero, 70, 1000, false, 20
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
						project = function(position) -- a top-down screen: pxPerStud px a stud
							return Vector2.new(position.X, position.Z) * pxPerStud, position.X <= screenMaxX
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
		-- FORGE-03's kit badge: the job's UITheme icon (its glyph until images are uploaded) on its colour
		local badge = badgeIn(farmer)
		expect(badge.Size).toEqual(UDim2.fromOffset(GlyphDef.GLYPH_PX, GlyphDef.GLYPH_PX))
		expect(badge.Icon.Text).toBe(Theme.icon("farm").glyph)
		expect(badge.UIGradient.Color.Keypoints[1].Value).toEqual(Theme.resource("food"))
		expect(badgeIn(miner).Icon.Text).toBe(Theme.icon("quarry").glyph)
		expect(badgeIn(miner).UIGradient.Color.Keypoints[1].Value).toEqual(Theme.resource("stone"))
		-- a phone draws them smaller: its citizens are ~25 px tall at the start view
		phone = true
		controller:refresh()
		expect(gui.Size).toEqual(UDim2.fromOffset(GlyphDef.PHONE_PX, GlyphDef.PHONE_PX))
		expect(badgeIn(farmer).Size).toEqual(UDim2.fromOffset(GlyphDef.PHONE_PX, GlyphDef.PHONE_PX))
		expect(#gui:GetChildren()).toBe(1) -- the desktop badge went, not left under the phone's
		expect(GlyphDef.PHONE_PX < GlyphDef.GLYPH_PX).toBe(true)
		-- meaning never by colour alone: every job has its own icon (and glyph) and colour
		local icons, texts, colors = {}, {}, {}
		for job, look in GlyphDef.GLYPH do
			local glyph = Theme.icon(look.icon).glyph
			expect(icons[look.icon]).toBeNil()
			expect(texts[glyph]).toBeNil()
			expect(colors[tostring(look.color)]).toBeNil()
			icons[look.icon], texts[glyph], colors[tostring(look.color)] = job, job, job
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

	it("a cluster shows one icon a job and none overlap (FL-0152: the farm trio on a phone)", function()
		settingValues.jobGlyphs = true
		phone = true
		pxPerStud = 6 -- about a phone at the start view: the trio's 3.6 studs apart is ~22 px, under an icon width
		local px = GlyphDef.PHONE_PX
		rig(1, 0, "farmer") -- nearest the centre: its icon stands for the trio
		rig(2, 3.6, "farmer") -- 22 px from it: shares it
		rig(3, 7.2, "farmer") -- 43 px from it but 22 from farmer 2: chained, shares it too
		rig(4, 0, "miner", { z = 2 }) -- 12 px from the farmer's icon: it would overlap, so it waits
		rig(5, 30, "farmer") -- 180 px away: its own icon
		rig(6, 0, "woodcutter", { z = -1.1 * px / pxPerStud }) -- 1.1 widths from the farmer: clear, drawn
		controller:refresh()
		expect(ids()).toEqual({ 1, 5, 6 })
		-- no two drawn icons closer than one icon width
		local points = {}
		for id, gui in controller:shown() do
			local position = gui.Adornee.CFrame.Position + gui.StudsOffsetWorldSpace
			table.insert(points, { id = id, point = Vector2.new(position.X, position.Z) * pxPerStud })
		end
		for i, a in points do
			for j = i + 1, #points do
				expect((a.point - points[j].point).Magnitude >= GlyphDef.APART * px).toBe(true)
			end
		end
		-- the same job merges a bit farther out than touching (MERGE), another job only when touching
		expect(GlyphDef.MERGE > GlyphDef.APART).toBe(true)
		-- zoom in (more px a stud): the trio splits into an icon each
		pxPerStud = 12 -- 3.6 studs = 43 px, past MERGE widths
		controller:refresh()
		expect(ids()).toEqual({ 1, 2, 3, 4, 5, 6 })
		-- the leader goes (a bubble): the next farmer leads the rest of the trio, and the miner is clear now
		pxPerStud = 6
		bubbleOf[1] = { kind = "thought" }
		controller:refresh()
		expect(ids()).toEqual({ 2, 4, 5, 6 })
	end)

	it("fades with the zoom: full from FADE_FULL out, half way between, gone at FADE_NONE and closer", function()
		settingValues.jobGlyphs = true
		local farmer = rig(1, 10, "farmer")
		zoom = GlyphDef.FADE_FULL
		controller:refresh()
		expect(badgeIn(farmer).BackgroundTransparency).toBeNear(0, 1e-9)
		expect(badgeIn(farmer).Icon.TextTransparency).toBeNear(0, 1e-9)
		expect(badgeIn(farmer).UIStroke.Transparency).toBeNear(0, 1e-9)
		zoom = (GlyphDef.FADE_FULL + GlyphDef.FADE_NONE) / 2
		controller:refresh()
		expect(badgeIn(farmer).BackgroundTransparency).toBeNear(0.5, 1e-6)
		expect(badgeIn(farmer).Icon.TextTransparency).toBeNear(0.5, 1e-6)
		expect(badgeIn(farmer).UIStroke.Transparency).toBeNear(0.5, 1e-6)
		zoom = GlyphDef.FADE_NONE
		controller:refresh()
		expect(ids()).toEqual({})
		expect(glyphIn(farmer)).toBeNil()
		expect(GlyphDef.fade(0 / 0)).toBe(0)
		-- FL-0152: full at the start view, where citizens are hardest to read; gone at the overview's closest
		local overview = CameraDef.DEFAULTS.overview
		expect(GlyphDef.fade(overview.startZoom)).toBe(1)
		expect(GlyphDef.fade(overview.maxZoom)).toBe(1)
		expect(GlyphDef.fade(overview.minZoom)).toBe(0)
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
		expect(badgeIn(builder).Icon.Text).toBe(Theme.icon("build").glyph)
		expect(badgeIn(builder).UIGradient.Color.Keypoints[1].Value).toEqual(Theme.color("gold500"))
		expect(#gui:GetChildren()).toBe(1) -- the farmer's badge went
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
